from flask import Blueprint, request, jsonify
from firebase_admin import firestore, messaging
import hmac
import hashlib
import json
import time
import datetime

transaction_bp = Blueprint('transaction', __name__)

VENDOR_SECRET = b"super-secret-vendor-key"

# In-memory stores for mock logic
PROCESSED_TX = set()
STUDENT_TX_HISTORY = {} # {uid: [timestamp1, timestamp2]}

def verify_hmac(payload_dict, received_signature):
    uid = str(payload_dict.get('uid', ''))
    amount = str(payload_dict.get('amount', ''))
    vendor_id = str(payload_dict.get('vendorId', ''))
    tx_id = str(payload_dict.get('txId', ''))
    timestamp = str(payload_dict.get('timestamp', ''))
    
    # Construct predictable raw string
    raw_data = f"{uid}:{amount}:{vendor_id}:{tx_id}:{timestamp}"
    
    generated_sig = hmac.new(
        VENDOR_SECRET,
        raw_data.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(generated_sig, received_signature)

def _send_notification(db, user_id: str, title: str, body: str):
    """Generic FCM push to a specific user (Vendor, Parent, or Student)."""
    try:
        user_doc = db.collection('users').document(user_id).get()
        if user_doc.exists:
            token = user_doc.to_dict().get('fcmToken')
            if token:
                messaging.send(messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=body,
                    ),
                    token=token,
                ))
    except Exception as e:
        print(f"FCM generic error: {e}")

def process_bounties(db, batch, student_ref, uid, vendor_name):
    """Checks active bounties, increments counts, and payouts if completed."""
    if not vendor_name: return
    bounties_ref = db.collection('students').document(uid).collection('bounties').where('isCompleted', '==', False).stream()
    for b in bounties_ref:
        b_data = b.to_dict()
        # Case insensitive match
        if str(b_data.get('vendorName', '')).strip().lower() == str(vendor_name).strip().lower():
            current_count = b_data.get('currentCount', 0) + 1
            target_count = b_data.get('targetCount', 1)
            b_update = {'currentCount': current_count}
            
            if current_count >= target_count:
                b_update['isCompleted'] = True
                reward_amount = b_data.get('amount', 0)
                
                # Credit student
                batch.update(student_ref, {'walletBalance': firestore.Increment(reward_amount)})
                
                # Try to deduct from parent vault
                parent_docs = db.collection('users').where('linkedStudentId', '==', uid).limit(1).get()
                if parent_docs:
                    parent_ref = parent_docs[0].reference
                    batch.update(parent_ref, {'vaultBalance': firestore.Increment(-reward_amount)})
                    
            batch.update(b.reference, b_update)

@transaction_bp.route('/lookup', methods=['GET', 'POST'])
def lookup():
    # Allow GET (query params) or POST (json)
    data = request.args if request.method == 'GET' else request.json
    uid = data.get('uid')
    
    if not uid:
        return jsonify({"error": "Missing uid"}), 400

    try:
        db = firestore.client()
        student_ref = db.collection('users').document(uid)
        student_doc = student_ref.get()

        if not student_doc.exists:
            return jsonify({"error": "Student account not found"}), 404

        student_data = student_doc.to_dict()
        
        # Check daily limit remaining (lazy reset logic)
        daily_limit = student_data.get('dailyLimit')
        spent_today = 0.0
        
        if daily_limit is not None:
            current_date_str = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
            last_spend_date = student_data.get('lastSpendDate', '')
            
            if last_spend_date == current_date_str:
                spent_today = float(student_data.get('spentToday', 0.0))
            else:
                # LAZY ROLLOVER: Gamified Keep the Change Savings
                # If a day has passed and they didn't spend their full daily limit yesterday, 
                # sweep the difference into their savings!
                yesterday_limit = float(daily_limit)
                yesterday_spent = float(student_data.get('spentToday', 0.0))
                if yesterday_spent < yesterday_limit and last_spend_date != '':
                    savings_addition = yesterday_limit - yesterday_spent
                    db.collection('users').document(uid).update({
                        'savingsBalance': firestore.Increment(savings_addition),
                        'walletBalance': firestore.Increment(-savings_addition)
                    })
                    # Also update our local copy for the response
                    student_data['walletBalance'] = float(student_data.get('walletBalance', 0.0)) - savings_addition
                    student_data['savingsBalance'] = float(student_data.get('savingsBalance', 0.0)) + savings_addition
                # Reset for today
                spent_today = 0.0
                db.collection('users').document(uid).update({
                    'spentToday': 0.0,
                    'lastSpendDate': current_date_str
                })
        
        return jsonify({
            "status": "success",
            "student": {
                "name": student_data.get('displayName') or student_data.get('name') or 'Student',
                "photoUrl": student_data.get('photoUrl', ''),
                "class": student_data.get('class', ''),
                "walletBalance": float(student_data.get('walletBalance', 0.0)),
                "dailyLimit": daily_limit,
                "spentToday": spent_today,
                "isFrozen": student_data.get('isFrozen', False)
            }
        }), 200
    except Exception as e:
        import traceback
        return jsonify({"error": "A server error occurred.", "details": str(e), "trace": traceback.format_exc()}), 500

@transaction_bp.route('/charge', methods=['POST'])
def charge():
    data = request.json
    
    uid = data.get('uid')
    base_amount = data.get('amount')
    vendor_id = data.get('vendorId')
    signature = data.get('signature')
    tx_id = data.get('txId')
    
    is_buddy_meal = data.get('isBuddyMeal', False)
    amount = base_amount * 2 if is_buddy_meal else base_amount

    if not all([uid, amount, vendor_id, signature, tx_id]):
        return jsonify({"error": "Missing parameters"}), 400

    # 0. Idempotency Key Enforcement
    if tx_id in PROCESSED_TX:
        return jsonify({"error": "Duplicate transaction"}), 409

    # 1. Verify Signature
    if not verify_hmac(data, signature):
        return jsonify({"error": "Invalid signature"}), 403
        
    # 2. Velocity Attack Detection
    current_time = time.time()
    history = STUDENT_TX_HISTORY.get(uid, [])
    # Filter tx in the last 3 minutes (180 seconds)
    recent_tx = [t for t in history if current_time - t < 180]
    if len(recent_tx) >= 2:
        return jsonify({"error": "Velocity limit exceeded. Account temporarily locked."}), 429

    try:
        db = firestore.client()
        student_ref = db.collection('users').document(uid)
        student_doc = student_ref.get()

        if not student_doc.exists:
            return jsonify({"error": "Student account not found"}), 404

        student_data = student_doc.to_dict()

        # -------------------------------------
        # Advanced Security & Biometrics Checks
        # -------------------------------------
        
        # 1. Vendor Whitelisting & Blacklisting
        whitelisted_vendors = student_data.get('whitelistedVendors', [])
        if whitelisted_vendors and vendor_id not in whitelisted_vendors:
            return jsonify({"error": "Tag is locked and not authorized for use at this vendor."}), 403
            
        blacklisted_vendors = student_data.get('blacklistedVendors', [])
        if blacklisted_vendors and vendor_id in blacklisted_vendors:
            return jsonify({"error": "This vendor is blocked by parental controls."}), 403

        # 2. Restricted Time Windows
        time_windows = student_data.get('allowedTimeWindows', [])
        if time_windows:
            import datetime
            # Get current time in East Africa Time (EAT) UTC+3
            eat_now = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=3)
            current_time_str = eat_now.strftime('%H:%M')
            
            is_within_window = False
            for window in time_windows:
                if window.get('start', '00:00') <= current_time_str <= window.get('end', '23:59'):
                    is_within_window = True
                    break
                    
            if not is_within_window:
                return jsonify({"error": "Transactions are restricted at this hour by parent settings."}), 403

        # -------------------------------------
        # Health & Nutrition Checks
        # -------------------------------------
        items = data.get('items', [])
        allergies = set([str(a).lower() for a in student_data.get('allergies', [])])
        category_limits = student_data.get('categoryLimits', {})
        category_spent_today = student_data.get('categorySpentToday', {})
        
        # Validation loop
        for item in items:
            # Check Allergens
            item_allergens = set([str(a).lower() for a in item.get('allergens', [])])
            intersection = allergies.intersection(item_allergens)
            if intersection:
                return jsonify({"error": f"Blocked: Item contains allergens ({', '.join(intersection)})"}), 403
                
            # Check Category Limits
            category = str(item.get('category', '')).lower()
            if category and category in category_limits:
                limit = category_limits[category]
                qty = item.get('qty', 1)
                spent = category_spent_today.get(category, 0)
                if spent + qty > limit:
                    return jsonify({"error": f"Category limit exceeded for {category}"}), 403

        # PIN Verification for transactions >= 200 (or if data has a PIN provided for biometric bypass)
        provided_pin = data.get('pin')
        if amount >= 200 or provided_pin:
            actual_pin = student_data.get('pin')
            temp_pin_data = student_data.get('tempPin')
            
            # Check Temp PIN First
            is_valid_temp = False
            if temp_pin_data:
                t_pin = temp_pin_data.get('pin')
                t_exp = temp_pin_data.get('expiresAt')
                if t_pin and t_exp:
                    # check if not expired
                    import datetime
                    if isinstance(t_exp, datetime.datetime):
                        if datetime.datetime.now(datetime.timezone.utc) < t_exp.astimezone(datetime.timezone.utc):
                            if str(provided_pin) == str(t_pin):
                                is_valid_temp = True

            if not is_valid_temp:
                if not actual_pin:
                    return jsonify({"error": "PIN not set on student account"}), 403
                if str(provided_pin) != str(actual_pin):
                    return jsonify({"error": "Invalid PIN"}), 403

        # Wash Trading Cooldown Check
        # If student topped up at this vendor in the last 30 minutes, flag it
        thirty_mins_ago = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=30)
        recent_topups = db.collection('transactions')\
            .where('studentId', '==', uid)\
            .where('vendorId', '==', vendor_id)\
            .where('type', '==', 'vendor_agent_topup')\
            .where('timestamp', '>', thirty_mins_ago).limit(1).get()
        
        is_wash_trade_anomaly = len(recent_topups) > 0

        # 3. Check Tag Freeze Status
        is_frozen = student_data.get('isFrozen', False)
        if is_frozen:
            return jsonify({"error": "Tag is frozen"}), 403

        # Check Buddy Meal Permission
        if is_buddy_meal and not student_data.get('allowBuddyTransfers', False):
            return jsonify({"error": "Buddy meal transfers are disabled by parent"}), 403

        wallet_balance = float(student_data.get('walletBalance', 0.0))
        okoa_food_eligible = student_data.get('okoaFoodEligible', True)
        split_pay_uids = data.get('splitUids', [])

        if len(split_pay_uids) > 0:
            # Split-Pay Logic
            split_amount = amount / (len(split_pay_uids) + 1)
        else:
            split_amount = amount
            
        # Daily Limits & Rollover Check
        daily_limit = student_data.get('dailyLimit')
        current_date_str = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
        last_spend_date = student_data.get('lastSpendDate', '')
        spent_today = 0.0
        
        if daily_limit is not None:
            if last_spend_date == current_date_str:
                spent_today = float(student_data.get('spentToday', 0.0))
            else:
                # LAZY ROLLOVER: Gamified Keep the Change Savings
                yesterday_limit = float(daily_limit)
                yesterday_spent = float(student_data.get('spentToday', 0.0))
                if yesterday_spent < yesterday_limit and last_spend_date != '':
                    savings_addition = yesterday_limit - yesterday_spent
                    student_ref.update({
                        'savingsBalance': firestore.Increment(savings_addition),
                        'walletBalance': firestore.Increment(-savings_addition)
                    })
                    wallet_balance -= savings_addition
                spent_today = 0.0
                
            if spent_today + split_amount > float(daily_limit):
                return jsonify({"error": f"Daily spending limit of {daily_limit} exceeded"}), 400
            
        used_okoa = False
        
        # Shared Family Wallet logic
        use_shared_wallet = student_data.get('useSharedWallet', False)
        parent_uid = student_data.get('parentUid')
        parent_ref = None
        if use_shared_wallet and parent_uid:
            parent_ref = db.collection('users').document(parent_uid)
            parent_doc = parent_ref.get()
            if parent_doc.exists and float(parent_doc.to_dict().get('vaultBalance', 0.0)) >= split_amount:
                # Enough in parent vault
                pass
            else:
                return jsonify({"error": "Insufficient funds in shared parent vault"}), 400
        else:
            if wallet_balance < split_amount:
                # Check for overdraft limit first
                overdraft_limit = float(student_data.get('overdraftLimit', 0.0))
                shortfall = split_amount - wallet_balance
                if shortfall <= overdraft_limit:
                    # Allow overdraft
                    pass
                elif okoa_food_eligible and shortfall <= 500:
                    # Grant Okoa Food Micro-Credit
                    used_okoa = True
                else:
                    return jsonify({"error": "Insufficient funds (exceeds overdraft limit)"}), 400

        # 4. Perform Atomic Transaction
        batch = db.batch()
        
        if parent_ref and use_shared_wallet:
            # Deduct from parent vault
            batch.update(parent_ref, {'vaultBalance': firestore.Increment(-split_amount)})
            student_updates = {}
        else:
            # Deduct from student
            round_up_amount = 0.0
            if student_data.get('autoRoundUp', False):
                import math
                ceil_amount = math.ceil(split_amount / 10.0) * 10
                round_up_amount = ceil_amount - split_amount
                # Ensure they have enough for the round-up
                if wallet_balance < (split_amount + round_up_amount):
                    round_up_amount = 0.0

            student_updates = {'walletBalance': firestore.Increment(-(split_amount + round_up_amount))}
            if round_up_amount > 0:
                student_updates['savingsVaultBalance'] = firestore.Increment(round_up_amount)
            
        if daily_limit is not None:
            if last_spend_date == current_date_str:
                student_updates['spentToday'] = firestore.Increment(split_amount)
            else:
                student_updates['spentToday'] = split_amount
                student_updates['lastSpendDate'] = current_date_str
                
        if student_updates:
            # Update category spent today
            if items:
                for item in items:
                    cat = str(item.get('category', '')).lower()
                    if cat:
                        category_spent_today[cat] = category_spent_today.get(cat, 0) + item.get('qty', 1)
                student_updates['categorySpentToday'] = category_spent_today
            batch.update(student_ref, student_updates)
        
        # Log the actual transaction
        tx_ref = db.collection('transactions').document(tx_id)
        
        # Fetch vendor location for check-ins
        vendor_location = data.get('vendorLocation') or data.get('campusZone') or 'Main Campus'
        
        batch.set(tx_ref, {
            'studentId': uid,
            'vendorId': vendor_id,
            'amount': split_amount,
            'type': 'vendor_agent_topup',
            'timestamp': firestore.SERVER_TIMESTAMP,
            'items': items,
            'location': vendor_location
        })
        
        # Add to vendor (minus 0.4 Ksh system fee)
        vendor_earned = amount - 0.4
        vendor_ref = db.collection('vendors').document(vendor_id)
        # Ensure vendor doc exists or set it with merge
        batch.set(vendor_ref, {'walletBalance': firestore.Increment(vendor_earned)}, merge=True)
        
        # Log system revenue
        system_ref = db.collection('system_revenue').document()
        batch.set(system_ref, {
            'tx_id': tx_id,
            'fee_amount': 0.4,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'source': 'vendor_b2b_fee'
        })
        
        # Process Gamification Bounties
        vendor_name = data.get('vendorName', '')
        process_bounties(db, batch, student_ref, uid, vendor_name)
        
        # Log Wash Trading Anomaly if detected
        if is_wash_trade_anomaly:
            fraud_ref = db.collection('fraud_flags').document()
            batch.set(fraud_ref, {
                'vendorId': vendor_id,
                'studentId': uid,
                'txId': tx_id,
                'reason': 'cooldown_violation',
                'description': 'Food purchase within 30 minutes of a top-up at the same vendor.',
                'timestamp': firestore.SERVER_TIMESTAMP
            })

        batch.commit()
        
        # Send Push Notification to Parent (Real-Time Safety Ping)
        try:
            p_uid = student_data.get('parentUid')
            if not p_uid:
                parent_docs = db.collection('users').where('linkedStudentId', '==', uid).limit(1).get()
                if parent_docs:
                    p_uid = parent_docs[0].id
            
            if p_uid:
                child_name = student_data.get('displayName', 'Student')
                _send_notification(db, p_uid, "Safety Ping - Access Recorded", f"{child_name} safely used their tag to spend Ksh {amount} at {vendor_name or 'a vendor'}.")
                
                # Auto-Replenish check
                if not use_shared_wallet:
                    new_balance = wallet_balance - split_amount
                    auto_threshold = student_data.get('autoTopUpThreshold')
                    auto_amount = student_data.get('autoTopUpAmount')
                    if auto_threshold is not None and auto_amount is not None and new_balance < float(auto_threshold):
                        # Trigger auto topup
                        parent_doc = db.collection('users').document(p_uid).get()
                        if parent_doc.exists and float(parent_doc.to_dict().get('vaultBalance', 0.0)) >= float(auto_amount):
                            db.collection('users').document(p_uid).update({'vaultBalance': firestore.Increment(-float(auto_amount))})
                            db.collection('users').document(uid).update({'walletBalance': firestore.Increment(float(auto_amount))})
                            _send_notification(db, p_uid, "Auto Top-Up Triggered", f"Ksh {auto_amount} transferred to {child_name} as their balance fell below {auto_threshold}.")
        except Exception as e:
            print(f"Error notifying parent: {e}")

        # Send Push Notification to Vendor
        try:
            _send_notification(db, vendor_id, "DISHI Sales Alert", f"Received Ksh {amount} from a POS sale.")
        except Exception as e:
            print(f"Error notifying vendor: {e}")
            
        # Register success state
        PROCESSED_TX.add(tx_id)
        recent_tx.append(current_time)
        STUDENT_TX_HISTORY[uid] = recent_tx

        return jsonify({
            "status": "success",
            "student": {
                "name": student_data.get('displayName', 'Student'),
                "swapeatCode": student_data.get('swapeatCode', 'Unknown'),
                "remainingBalance": wallet_balance - split_amount,
                "usedOkoa": used_okoa
            }
        }), 200
    except Exception as e:
        import traceback
        return jsonify({
            "error": "A server error occurred during transaction processing.",
            "details": str(e),
            "trace": traceback.format_exc()
        }), 500

@transaction_bp.route('/preorder', methods=['POST'])
def preorder():
    data = request.json
    
    uid = data.get('uid')
    amount = data.get('amount')
    vendor_id = data.get('vendorId')
    meal_name = data.get('mealName')
    vendor_name = data.get('vendorName')
    signature = data.get('signature')
    tx_id = data.get('txId')
    timestamp = data.get('timestamp')

    if not all([uid, amount, vendor_id, meal_name, signature, tx_id, timestamp]):
        return jsonify({"error": "Missing parameters"}), 400

    if tx_id in PROCESSED_TX:
        return jsonify({"error": "Duplicate transaction"}), 409

    if not verify_hmac(data, signature):
        return jsonify({"error": "Invalid signature"}), 403

    try:
        db = firestore.client()
        student_ref = db.collection('users').document(uid)
        student_doc = student_ref.get()

        if not student_doc.exists:
            return jsonify({"error": "Student account not found"}), 404

        student_data = student_doc.to_dict()
        wallet_balance = float(student_data.get('walletBalance', 0.0))
        okoa_food_eligible = student_data.get('okoaFoodEligible', True)

        used_okoa = False
        if wallet_balance < amount:
            if okoa_food_eligible and (amount - wallet_balance) <= 500:
                used_okoa = True
            else:
                return jsonify({"error": "Insufficient funds"}), 400

        batch = db.batch()
        # Deduct from student
        batch.update(student_ref, {'walletBalance': firestore.Increment(-amount)})
        
        # Credit vendor immediately (minus 0.4 Ksh fee)
        vendor_earned = amount - 0.4
        vendor_ref = db.collection('vendors').document(vendor_id)
        batch.set(vendor_ref, {'walletBalance': firestore.Increment(vendor_earned)}, merge=True)
        
        # Log system revenue
        system_ref = db.collection('system_revenue').document()
        batch.set(system_ref, {
            'tx_id': tx_id,
            'fee_amount': 0.4,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'source': 'vendor_preorder_fee'
        })
        
        # Create top-level preorder document
        preorder_ref = db.collection('preorders').document(tx_id)
        batch.set(preorder_ref, {
            'studentId': uid,
            'studentName': student_data.get('displayName', 'Student'),
            'vendorId': vendor_id,
            'vendorName': vendor_name,
            'mealName': meal_name,
            'price': amount,
            'status': 'pending',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # Process Gamification Bounties
        vendor_name = data.get('vendorName', '')
        process_bounties(db, batch, student_ref, uid, vendor_name)
        
        batch.commit()
        
        # Send Push Notification to Parent
        try:
            parent_docs = db.collection('users').where('linkedStudentId', '==', uid).limit(1).get()
            if parent_docs:
                parent_id = parent_docs[0].id
                _send_notification(db, parent_id, "DISHI Preorder Alert", f"Your student preordered {meal_name} for Ksh {amount} at {vendor_name or 'a vendor'}.")
        except Exception as e:
            print(f"Error notifying parent for preorder: {e}")

        # Send Push Notification to Vendor
        try:
            _send_notification(db, vendor_id, "DISHI Preorder Alert", f"New preorder for {meal_name} (Ksh {amount}).")
        except Exception as e:
            print(f"Error notifying vendor for preorder: {e}")
        PROCESSED_TX.add(tx_id)

        return jsonify({
            "status": "success",
            "message": "Preorder placed successfully",
            "student": {
                "remainingBalance": wallet_balance - amount,
                "usedOkoa": used_okoa
            }
        }), 200
    except Exception as e:
        import traceback
        return jsonify({
            "error": "A server error occurred.",
            "details": str(e),
            "trace": traceback.format_exc()
        }), 500

@transaction_bp.route('/sos', methods=['POST'])
def sos():
    data = request.json
    uid = data.get('uid')
    vendor_id = data.get('vendorId')
    
    if not all([uid, vendor_id]):
        return jsonify({"error": "Missing uid or vendorId"}), 400
        
    try:
        db = firestore.client()
        student_doc = db.collection('users').document(uid).get()
        if not student_doc.exists:
            return jsonify({"error": "Student not found"}), 404
            
        student_data = student_doc.to_dict()
        p_uid = student_data.get('parentUid')
        if p_uid:
            vendor_doc = db.collection('users').document(vendor_id).get()
            vendor_name = vendor_doc.to_dict().get('displayName', 'a vendor') if vendor_doc.exists else 'a vendor'
            _send_notification(db, p_uid, "🚨 SOS Emergency Request", f"{student_data.get('displayName', 'Your child')} has requested emergency funds at {vendor_name}.")
            return jsonify({"status": "success"}), 200
        return jsonify({"error": "No parent linked"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@transaction_bp.route('/cashout', methods=['POST'])
def cashout():
    data = request.json
    
    uid = data.get('uid')
    amount = data.get('amount')
    vendor_id = data.get('vendorId')
    signature = data.get('signature')
    tx_id = data.get('txId')

    if not all([uid, amount, vendor_id, signature, tx_id]):
        return jsonify({"error": "Missing parameters"}), 400

    if not verify_hmac(data, signature):
        return jsonify({"error": "Invalid signature"}), 403

    try:
        db = firestore.client()
        student_ref = db.collection('users').document(uid)
        student_doc = student_ref.get()

        if not student_doc.exists:
            return jsonify({"error": "Student not found"}), 404

        wallet_balance = float(student_doc.to_dict().get('walletBalance', 0.0))
        if wallet_balance < amount:
            return jsonify({"error": "Insufficient student funds for cash-out"}), 400

        batch = db.batch()
        batch.update(student_ref, {'walletBalance': firestore.Increment(-amount)})
        batch.set(db.collection('vendors').document(vendor_id), {'walletBalance': firestore.Increment(amount)}, merge=True)
        
        batch.set(db.collection('transactions').document(tx_id), {
            'studentId': uid,
            'vendorId': vendor_id,
            'amount': amount,
            'type': 'cashout',
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        
        batch.commit()
        return jsonify({"status": "success", "message": "Cash out approved"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@transaction_bp.route('/<tx_id>/dispute', methods=['POST'])
def dispute_transaction(tx_id):
    try:
        from firebase_admin import firestore
        data = request.json
        parent_uid = data.get('parentUid')
        reason = data.get('reason', 'suspicious')
        
        if not parent_uid:
            return jsonify({"error": "Missing parentUid"}), 400
            
        db = firestore.client()
        tx_ref = db.collection('transactions').document(tx_id)
        tx_doc = tx_ref.get()
        
        if not tx_doc.exists:
            return jsonify({"error": "Transaction not found"}), 404
            
        # Create a dispute record
        db.collection('disputes').add({
            'txId': tx_id,
            'parentUid': parent_uid,
            'studentId': tx_doc.to_dict().get('studentId'),
            'vendorId': tx_doc.to_dict().get('vendorId'),
            'amount': tx_doc.to_dict().get('amount'),
            'reason': reason,
            'status': 'pending',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # Optionally flag the transaction document
        tx_ref.update({'isDisputed': True})
        
        return jsonify({"status": "success", "message": "Transaction disputed successfully."}), 200
    except Exception as e:
        return jsonify({"error": "Server error", "details": str(e)}), 500
