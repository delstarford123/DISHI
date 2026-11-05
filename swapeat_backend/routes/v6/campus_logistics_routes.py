import os
import hmac
import hashlib
import time
import random
import string
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from firebase_admin import firestore
from routes.mpesa_routes import resolve_user_ref, _credit_wallet_safely, _send_notification
from utils.fcm_utils import send_call_fcm_notification

campus_logistics_v6_bp = Blueprint('campus_logistics_v6', __name__)

HMAC_SECRET = os.getenv('QR_TOKEN_SECRET', 'dishi_qr_pickup_hmac_secret_2026').encode('utf-8')

@campus_logistics_v6_bp.route('/calls/ring', methods=['POST'])
def ring_call():
    """
    WhatsApp-Style Incoming Call Push Dispatcher & Signaling Sync.
    1. Resolves caller & callee (by UID, phone, email, or DISHI ID).
    2. Synchronizes active_calls/{call_id} in Firestore (ensures calleeId, status='ringing', timestamp).
    3. Prevents self-call push (caller never gets FCM with own name).
    4. Prevents same-device token reflection (if callee doc has caller's device token from past test login, clear it and suppress push to avoid ringing caller's device).
    5. Dispatches instant high-priority FCM wake-up to callee's device with full 'incoming_call' payload.
    """
    data = request.json or {}
    callee_id = str(data.get('callee_id', '')).strip()
    caller_id = str(data.get('caller_id', '')).strip()
    caller_name = str(data.get('caller_name', 'Comrade')).strip()
    caller_avatar = str(data.get('caller_avatar', '')).strip()
    call_id = str(data.get('call_id', '')).strip()
    is_video = bool(data.get('is_video', False))

    if not callee_id or not call_id:
        return jsonify({"error": "callee_id and call_id required"}), 400

    db = firestore.client()

    # 1. Resolve Caller
    caller_ref, caller_doc, real_caller_uid = resolve_user_ref(db, caller_id)
    caller_data = caller_doc.to_dict() if (caller_doc and caller_doc.exists) else {}
    real_caller_uid = real_caller_uid or (caller_doc.id if caller_doc else caller_id)
    caller_token = caller_data.get('fcmToken')
    if caller_data:
        caller_name = caller_name or caller_data.get('displayName') or caller_data.get('name') or 'Comrade'
        caller_avatar = caller_avatar or caller_data.get('profileImageUrl') or caller_data.get('avatar') or ''

    # 2. Resolve Callee
    callee_ref, callee_doc, real_callee_uid = resolve_user_ref(db, callee_id)
    callee_data = callee_doc.to_dict() if (callee_doc and callee_doc.exists) else {}
    real_callee_uid = real_callee_uid or (callee_doc.id if callee_doc else callee_id)
    callee_token = callee_data.get('fcmToken')
    callee_name = callee_data.get('displayName') or callee_data.get('name') or 'Student'

    # 3. Synchronize active_calls/{call_id} in Firestore so real-time listeners on devices catch it
    now_ts = firestore.SERVER_TIMESTAMP
    call_doc_ref = db.collection('active_calls').document(call_id)
    try:
        call_snapshot = call_doc_ref.get()
        if call_snapshot.exists:
            cdata = call_snapshot.to_dict() or {}
            updates = {}
            if not cdata.get('calleeId') or cdata.get('calleeId') != real_callee_uid:
                updates['calleeId'] = real_callee_uid
            if cdata.get('status') not in ['ringing', 'answered']:
                updates['status'] = 'ringing'
            if not cdata.get('createdAt'):
                updates['createdAt'] = now_ts
            if caller_name and not cdata.get('callerName'):
                updates['callerName'] = caller_name
            if caller_avatar and not cdata.get('callerAvatar'):
                updates['callerAvatar'] = caller_avatar
            if updates:
                call_doc_ref.update(updates)
        else:
            call_doc_ref.set({
                'callerId': real_caller_uid,
                'calleeId': real_callee_uid,
                'callerName': caller_name,
                'callerAvatar': caller_avatar,
                'isVideo': is_video,
                'status': 'ringing',
                'createdAt': now_ts,
            }, merge=True)
    except Exception as e:
        print(f"[CALLS] Error updating active_calls/{call_id}: {e}")

    # 4. Prevent Self-Calling Push Loop (Caller calling themselves)
    if real_caller_uid and real_callee_uid and real_caller_uid == real_callee_uid:
        print(f"[CALLS] Suppressed self-call push notification for user {real_caller_uid}")
        return jsonify({
            "success": True,
            "message": "Self-call detected. Push notification suppressed to prevent ringing caller's own device.",
            "call_id": call_id,
            "caller_id": real_caller_uid,
            "callee_id": real_callee_uid,
            "status": "ringing"
        }), 200

    # 5. Device Token Collision / Stale Test Account Protection
    # If caller and callee have the identical FCM token, it means the caller logged into both accounts on the same phone.
    # We must disassociate the stale token from callee and suppress the push so caller's phone doesn't ring itself.
    if caller_token and callee_token and caller_token == callee_token:
        print(f"[CALLS] Collision: Callee {real_callee_uid} shares device FCM token with caller {real_caller_uid}. Clearing stale token from callee.")
        if callee_ref:
            try:
                callee_ref.update({'fcmToken': firestore.DELETE_FIELD})
            except Exception as e:
                print(f"[CALLS] Failed to delete stale token from callee: {e}")
        callee_token = None

    # 6. Dispatch FCM Push Notification to Callee (if callee has distinct token)
    payload = {
        'type': 'incoming_call',
        'callId': call_id,
        'roomId': call_id,
        'callerId': real_caller_uid,
        'callerName': caller_name,
        'callerAvatar': caller_avatar,
        'isVideo': 'true' if is_video else 'false',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'title': f"Incoming {'Video' if is_video else 'Voice'} Call",
        'body': f"{caller_name} is calling you on DISHI...",
    }

    fcm_success = False
    if callee_token:
        fcm_success = send_call_fcm_notification(
            user_id=real_callee_uid,
            title=f"Incoming {'Video' if is_video else 'Voice'} Call",
            body=f"{caller_name} is calling you on DISHI...",
            data=payload,
            token=callee_token
        )
    else:
        print(f"[CALLS] Callee {real_callee_uid} has no active FCM push token. Firestore realtime listener active.")

    return jsonify({
        "success": True,
        "call_id": call_id,
        "caller_id": real_caller_uid,
        "callee_id": real_callee_uid,
        "callee_name": callee_name,
        "fcm_dispatched": fcm_success,
        "status": "ringing"
    }), 200


@campus_logistics_v6_bp.route('/calls/<call_id>/status', methods=['GET'])
def get_call_status(call_id):
    """Returns the current status of an active or past call."""
    db = firestore.client()
    doc = db.collection('active_calls').document(call_id).get()
    if not doc.exists:
        return jsonify({"error": "Call not found", "status": "ended"}), 404
    data = doc.to_dict() or {}
    return jsonify({
        "call_id": call_id,
        "status": data.get('status', 'ended'),
        "caller_id": data.get('callerId'),
        "callee_id": data.get('calleeId'),
        "caller_name": data.get('callerName'),
        "is_video": data.get('isVideo', False),
    }), 200


@campus_logistics_v6_bp.route('/calls/<call_id>/answer', methods=['POST'])
def answer_call(call_id):
    """Explicit endpoint to answer call and transition status to answered."""
    db = firestore.client()
    call_ref = db.collection('active_calls').document(call_id)
    doc = call_ref.get()
    if not doc.exists:
        return jsonify({"error": "Call not found"}), 404
    call_ref.update({
        'status': 'answered',
        'answeredAt': firestore.SERVER_TIMESTAMP
    })
    return jsonify({"success": True, "call_id": call_id, "status": "answered"}), 200


@campus_logistics_v6_bp.route('/calls/<call_id>/decline', methods=['POST'])
def decline_call(call_id):
    """Explicit endpoint to decline call and transition status to declined."""
    db = firestore.client()
    call_ref = db.collection('active_calls').document(call_id)
    doc = call_ref.get()
    if not doc.exists:
        return jsonify({"error": "Call not found"}), 404
    req_data = request.json or {}
    message = req_data.get('message', 'Call declined')
    call_ref.update({
        'status': 'declined',
        'declineMessage': message,
        'endedAt': firestore.SERVER_TIMESTAMP
    })
    return jsonify({"success": True, "call_id": call_id, "status": "declined"}), 200


@campus_logistics_v6_bp.route('/calls/<call_id>/end', methods=['POST'])
def end_call(call_id):
    """Explicit endpoint to end call and clean up."""
    db = firestore.client()
    call_ref = db.collection('active_calls').document(call_id)
    doc = call_ref.get()
    if not doc.exists:
        return jsonify({"success": True, "status": "ended"}), 200
    call_ref.update({
        'status': 'ended',
        'endedAt': firestore.SERVER_TIMESTAMP
    })
    return jsonify({"success": True, "call_id": call_id, "status": "ended"}), 200


@campus_logistics_v6_bp.route('/calls/cleanup_stale', methods=['POST', 'GET'])
def cleanup_stale_calls():
    """Auto-cleans any calls ringing for more than 2 minutes."""
    db = firestore.client()
    threshold = datetime.utcnow() - timedelta(minutes=2)
    cleaned = 0
    try:
        ringing_docs = db.collection('active_calls').where('status', '==', 'ringing').stream()
        for doc in ringing_docs:
            d = doc.to_dict() or {}
            created = d.get('createdAt')
            if not created:
                doc.reference.update({'status': 'ended', 'endedAt': firestore.SERVER_TIMESTAMP})
                cleaned += 1
            elif isinstance(created, datetime) and created.replace(tzinfo=None) < threshold:
                doc.reference.update({'status': 'ended', 'endedAt': firestore.SERVER_TIMESTAMP})
                cleaned += 1
    except Exception as e:
        print(f"[CALLS] Error during cleanup_stale_calls: {e}")
    return jsonify({"success": True, "cleaned_count": cleaned}), 200

# =====================================================================
# PILLAR 3 & 5: SMART LOGISTICS, PRE-ORDERS, SAFETY & ECOSYSTEM (V6)
# =====================================================================

@campus_logistics_v6_bp.route('/queue/<order_id>/status', methods=['GET', 'POST'])
def manage_order_queue(order_id):
    """
    Feature 16: Live Preparation Queue ("Queued -> Cooking -> Ready for Pickup").
    """
    db = firestore.client()
    order_ref = db.collection('orders').document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        return jsonify({"error": "Order not found"}), 404

    if request.method == 'GET':
        data = order_doc.to_dict()
        status = data.get('prep_status') or data.get('status') or 'Queued'
        est_minutes = data.get('est_prep_minutes', 15)
        return jsonify({
            "order_id": order_id,
            "status": status,
            "steps": ["Queued", "Cooking", "Ready for Pickup", "Collected"],
            "current_step": status,
            "est_prep_minutes": est_minutes,
            "pickup_time": data.get('pickup_time', 'ASAP')
        }), 200

    # POST: Vendor advances status
    body = request.json or {}
    new_status = str(body.get('status', '')).strip()
    if new_status not in ["Queued", "Cooking", "Ready for Pickup", "Collected"]:
        return jsonify({"error": "Invalid queue status"}), 400

    order_ref.update({
        'prep_status': new_status,
        'status': new_status,
        'queue_updated_at': firestore.SERVER_TIMESTAMP
    })

    # If Ready for Pickup, trigger notification to student
    order_data = order_doc.to_dict()
    student_uid = order_data.get('studentUid') or order_data.get('student_id')
    if new_status == "Ready for Pickup" and student_uid:
        _send_notification(
            db, student_uid,
            "🍲 Your Order is Ready!",
            f"Order #{order_id[-5:]} is hot and ready for pickup at the counter."
        )

    return jsonify({"success": True, "order_id": order_id, "new_status": new_status}), 200


@campus_logistics_v6_bp.route('/qr_token', methods=['POST'])
def generate_pickup_token():
    """
    Feature 17: Fraud-Proof Dynamic QR Pickup Token with Time-based HMAC & 4-digit PIN.
    Prevents screenshot theft and receipt reuse.
    """
    data = request.json or {}
    order_id = str(data.get('order_id', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()

    if not order_id or not student_uid:
        return jsonify({"error": "order_id and student_uid are required"}), 400

    # 1. 30-second epoch timestamp
    epoch = int(time.time() // 30)
    raw_message = f"{order_id}:{student_uid}:{epoch}"
    token_hmac = hmac.new(HMAC_SECRET, raw_message.encode('utf-8'), hashlib.sha256).hexdigest()[:16].upper()
    
    # 4-digit numeric fallback PIN for cashiers without high-res scanners
    pin_hash = int(hashlib.md5(f"{order_id}:{epoch}".encode('utf-8')).hexdigest()[:6], 16)
    short_pin = f"{pin_hash % 10000:04d}"

    return jsonify({
        "order_id": order_id,
        "token": token_hmac,
        "short_pin": short_pin,
        "expires_in_seconds": 30 - int(time.time() % 30),
        "qr_payload": f"DISHI:PICKUP:{order_id}:{token_hmac}:{short_pin}"
    }), 200


@campus_logistics_v6_bp.route('/validate_token', methods=['POST'])
def validate_pickup_token():
    """
    Vendor POS scans the student's dynamic QR code and verifies validity.
    """
    data = request.json or {}
    order_id = str(data.get('order_id', '')).strip()
    token = str(data.get('token', '')).strip().upper()
    pin = str(data.get('short_pin') or data.get('pin', '')).strip()

    if not order_id:
        return jsonify({"error": "order_id required"}), 400

    db = firestore.client()
    order_ref = db.collection('orders').document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        return jsonify({"valid": False, "error": "Order not found"}), 404

    order = order_doc.to_dict()
    student_uid = order.get('studentUid') or order.get('student_id', '')

    # Allow current epoch and previous epoch (60-second grace window)
    now_epoch = int(time.time() // 30)
    is_valid = False

    for ep in [now_epoch, now_epoch - 1]:
        raw_msg = f"{order_id}:{student_uid}:{ep}"
        calc_hmac = hmac.new(HMAC_SECRET, raw_msg.encode('utf-8'), hashlib.sha256).hexdigest()[:16].upper()
        p_hash = int(hashlib.md5(f"{order_id}:{ep}".encode('utf-8')).hexdigest()[:6], 16)
        calc_pin = f"{p_hash % 10000:04d}"

        if (token and token == calc_hmac) or (pin and pin == calc_pin):
            is_valid = True
            break

    if not is_valid:
        return jsonify({"valid": False, "error": "QR Token or PIN has expired. Please refresh the student screen."}), 403

    # Mark order collected
    order_ref.update({
        'status': 'Collected',
        'prep_status': 'Collected',
        'collected_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "valid": True,
        "order_id": order_id,
        "items": order.get('items', []),
        "student_name": order.get('student_name', 'Student'),
        "message": "Token verified! Food collection confirmed."
    }), 200


@campus_logistics_v6_bp.route('/dine_in/order', methods=['POST'])
def create_dine_in_order():
    """
    Feature 19: Table & Cafeteria Seat Delivery (Dine-In QR Table Ordering).
    """
    data = request.json or {}
    vendor_id = str(data.get('vendor_id', '')).strip()
    table_number = str(data.get('table_number', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()
    items = data.get('items', [])
    total_price = float(data.get('total_price', 0))

    if not vendor_id or not table_number or not student_uid or total_price <= 0:
        return jsonify({"error": "vendor_id, table_number, student_uid, and items required"}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({"error": "Student account not found"}), 404

    cur_bal = float(user_doc.to_dict().get('walletBalance', 0))
    if cur_bal < total_price:
        return jsonify({"error": f"Insufficient wallet balance. Available: KES {cur_bal:,.2f}"}), 400

    # Deduct student wallet
    _credit_wallet_safely(db, user_ref, real_uid, -total_price, destination='walletBalance')

    # Create dine-in order
    order_ref = db.collection('orders').document()
    order_data = {
        'type': 'dine_in',
        'vendorUid': vendor_id,
        'vendor_id': vendor_id,
        'studentUid': real_uid,
        'student_id': real_uid,
        'table_number': table_number,
        'items': items,
        'totalAmount': total_price,
        'prep_status': 'Queued',
        'status': 'Queued',
        'is_paid': True,
        'created_at': firestore.SERVER_TIMESTAMP
    }
    order_ref.set(order_data)

    return jsonify({
        "success": True,
        "order_id": order_ref.id,
        "table_number": table_number,
        "message": f"Dine-in order placed for Table {table_number}! Meals will be served to your seat."
    }), 201


@campus_logistics_v6_bp.route('/subscription/consume', methods=['POST'])
def consume_meal_pass_token():
    """
    Feature 20: 30-Day Subscription Meal Pass (Mess Card).
    Deducts 1 token per scanned meal.
    """
    data = request.json or {}
    subscription_id = str(data.get('subscription_id', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()

    db = firestore.client()
    sub_ref = db.collection('meal_subscriptions').document(subscription_id)
    sub_doc = sub_ref.get()

    if not sub_doc.exists:
        return jsonify({"error": "Subscription meal pass not found"}), 404

    sub_data = sub_doc.to_dict()
    remaining = int(sub_data.get('remaining_tokens', 0))

    if remaining <= 0:
        return jsonify({"error": "Meal Pass exhausted. 0 tokens remaining."}), 400

    sub_ref.update({
        'remaining_tokens': remaining - 1,
        'last_consumed_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "success": True,
        "remaining_tokens": remaining - 1,
        "plan_title": sub_data.get('plan_title', 'Monthly Cafeteria Pass'),
        "message": f"Meal pass approved! 1 meal token deducted. {remaining - 1} meals remaining."
    }), 200


@campus_logistics_v6_bp.route('/safety/okoa_meal/eligibility/<student_uid>', methods=['GET'])
def get_okoa_eligibility(student_uid):
    """
    Returns live OKOA food eligibility, track record check, and active debt status.
    """
    db = firestore.client()
    u_ref, u_doc, real_uid = resolve_user_ref(db, student_uid)
    if not u_doc or not u_doc.exists:
        return jsonify({"error": "Student account not found"}), 404

    u_data = u_doc.to_dict() or {}
    debt = float(u_data.get('okoa_debt', 0.0) or 0.0)
    has_debt = debt > 0
    cur_bal = float(u_data.get('walletBalance', 0.0) or 0.0)

    # Cross-debt check: overdue loans
    overdue_loans = db.collection('student_loans') \
        .where('student_uid', '==', real_uid) \
        .where('status', '==', 'overdue') \
        .limit(1).stream()
    has_overdue_loan = any(True for _ in overdue_loans)

    # Track record check: verified phone or at least 1 completed transaction
    has_phone = bool(u_data.get('phoneNumber') or u_data.get('phone'))
    tx_check = db.collection('transactions').where('userId', '==', real_uid).limit(1).stream()
    has_tx = any(True for _ in tx_check)
    track_record_passed = has_phone or has_tx

    eligible = (not has_debt) and (not has_overdue_loan) and track_record_passed and (cur_bal <= 150)

    reason = "Eligible for Zero-Hunger Emergency Food Credit."
    if has_debt:
        reason = f"Active voucher of KES {debt:.0f} must be settled first."
    elif has_overdue_loan:
        reason = "Overdue student study loan must be cleared first."
    elif not track_record_passed:
        reason = "Please verify your phone number or make a first campus meal purchase to establish track record."
    elif cur_bal > 150:
        reason = f"Wallet balance (KES {cur_bal:.2f}) exceeds the KES 150 emergency threshold."

    return jsonify({
        "success": True,
        "student_uid": real_uid,
        "eligible": eligible,
        "okoa_debt": debt,
        "display_balance": -debt if has_debt else 0.0,
        "formatted_display": f"-KES {debt:.2f}" if has_debt else "KES 0.00",
        "has_debt": has_debt,
        "has_overdue_loan": has_overdue_loan,
        "track_record_passed": track_record_passed,
        "reason": reason
    }), 200


@campus_logistics_v6_bp.route('/safety/okoa_meal/request', methods=['POST'])
def request_okoa_meal():
    """
    Feature 27: "Okoa Meal" Emergency Credit (Zero-Hunger Safety Net).
    Provides a small meal voucher (KES 100 - 350) with strict single-voucher security & track record.
    """
    data = request.json or {}
    student_uid = str(data.get('student_uid', '')).strip()
    amount = float(data.get('amount', 200))
    amount = max(100.0, min(350.0, amount))

    db = firestore.client()
    u_ref, u_doc, real_uid = resolve_user_ref(db, student_uid)
    if not u_doc or not u_doc.exists:
        return jsonify({"error": "Student account not found"}), 404

    u_data = u_doc.to_dict() or {}

    # 1. Security Protocol: Prevent multiple vouchers before paying
    existing_debt = float(u_data.get('okoa_debt', 0))
    if existing_debt > 0:
        return jsonify({
            "error": f"Security Block: You already have an active Okoa Food voucher of KES {existing_debt:.0f}. DISHI Zero-Hunger policy strictly limits to 1 active voucher at a time. Top up your wallet to auto-settle before requesting another."
        }), 400

    # 2. Security Protocol: Cross-debt check (overdue loan)
    overdue_loans = db.collection('student_loans') \
        .where('student_uid', '==', real_uid) \
        .where('status', '==', 'overdue') \
        .limit(1).stream()
    for ol in overdue_loans:
        old = ol.to_dict()
        return jsonify({
            "error": f"Security Block: You have an overdue student loan of KES {old.get('amount', 0):.0f}. Please settle your overdue loan before taking emergency food credits."
        }), 400

    # 3. Security Protocol: Track record check
    has_phone = bool(u_data.get('phoneNumber') or u_data.get('phone'))
    tx_check = db.collection('transactions').where('userId', '==', real_uid).limit(1).stream()
    has_tx = any(True for _ in tx_check)
    if not has_phone and not has_tx:
        return jsonify({
            "error": "Track Record Required: Please complete your profile with a valid phone number or make your first campus meal purchase before requesting Okoa Food."
        }), 400

    cur_bal = float(u_data.get('walletBalance', 0))
    if cur_bal > 150:
        return jsonify({"error": "Okoa Meal is only available when balance is below KES 150."}), 400

    # Credit student food allowance and record debt (displaying -amount)
    u_ref.update({
        'food_allowance_balance': firestore.Increment(amount),
        'walletBalance': firestore.Increment(amount),
        'wallet_balance': firestore.Increment(amount),
        'okoa_debt': amount,
        'okoaBalance': -amount,
        'okoa_issued_at': firestore.SERVER_TIMESTAMP
    })

    # Record in safety pool
    db.collection('okoa_records').add({
        'student_uid': real_uid,
        'amount': amount,
        'status': 'active_debt',
        'timestamp': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "success": True,
        "voucher_credited": amount,
        "okoa_debt": amount,
        "display_balance": -amount,
        "formatted_display": f"-KES {amount:.2f}",
        "message": f"DISHI Zero-Hunger Safety Net activated. KES {amount:.0f} credited to your food wallet. Balance displays -KES {amount:.0f} debt. It will be auto-deducted on your next wallet top-up."
    }), 200


@campus_logistics_v6_bp.route('/social/split_expense/create', methods=['POST'])
@campus_logistics_v6_bp.route('/split-expenses', methods=['POST'])
def create_split_expense():
    """
    Feature 28: Hostel & Roommate Split-Expense Hub (Meals, Groceries, Tokens, Wi-Fi).
    Dispatches instant notification to comrades to put their DISHI ID or PIN to pay.
    """
    data = request.json or {}
    creator_uid = str(data.get('creator_uid', '')).strip()
    creator_name = str(data.get('creator_name', 'Comrade')).strip()
    title = str(data.get('title', 'Campus Meal Split')).strip()
    total_amount = float(data.get('total_amount', 0))
    friends = data.get('friends', []) or data.get('roommates', [])  # list of DISHI IDs, UIDs, or phone numbers

    if not creator_uid or total_amount <= 0 or not friends:
        return jsonify({"error": "creator_uid, total_amount, and friends list required"}), 400

    split_count = len(friends) + 1  # includes creator
    per_person = round(total_amount / split_count, 2)

    db = firestore.client()

    # Resolve each friend's UID and DISHI ID from users collection
    resolved_participants = {}
    participant_uids = []

    for f_id in friends:
        f_clean = str(f_id).strip()
        matched_uid = None
        matched_name = f_clean

        # Check by UID
        u_doc = db.collection('users').document(f_clean).get()
        if u_doc.exists:
            matched_uid = u_doc.id
            matched_name = u_doc.to_dict().get('displayName') or f_clean
        else:
            # Check by dishiId / dishi_id / swapeatCode
            for field in ['dishiId', 'dishi_id', 'swapeatCode', 'phoneNumber', 'phone']:
                q = db.collection('users').where(field, '==', f_clean).limit(1).get()
                if q:
                    matched_uid = q[0].id
                    matched_name = q[0].to_dict().get('displayName') or f_clean
                    break

        target_uid = matched_uid or f_clean
        participant_uids.append(target_uid)
        resolved_participants[target_uid] = {
            'dishiId': f_clean,
            'name': matched_name,
            'amount': per_person,
            'status': 'pending',
            'paidAt': None
        }

    # Save to split_bills collection (used by Flutter SplitBillView)
    split_ref = db.collection('split_bills').document()
    split_data = {
        'splitId': split_ref.id,
        'creatorId': creator_uid,
        'creatorName': creator_name,
        'title': title,
        'totalAmount': total_amount,
        'perPersonAmount': per_person,
        'friends': friends,
        'participantUids': participant_uids,
        'participants': resolved_participants,
        'paidMembers': [creator_uid],
        'status': 'pending',
        'createdAt': firestore.SERVER_TIMESTAMP
    }
    split_ref.set(split_data)

    # Also sync to split_expenses for cross-feature compatibility
    db.collection('split_expenses').document(split_ref.id).set(split_data)

    # DISPATCH NOTIFICATION TO ALL PARTICIPANTS
    for p_uid, p_data in resolved_participants.items():
        try:
            notif_ref = db.collection('notifications').document()
            notif_ref.set({
                'id': notif_ref.id,
                'targetUserId': p_uid,
                'title': 'Comrade Bill Split Request 👥',
                'message': f"{creator_name} has split a bill of KES {total_amount:,.0f} for '{title}'. Your share is KES {per_person:,.0f}. Put your PIN to pay.",
                'type': 'split_bill_request',
                'splitBillId': split_ref.id,
                'amount': per_person,
                'creatorId': creator_uid,
                'creatorName': creator_name,
                'createdAt': firestore.SERVER_TIMESTAMP,
                'status': 'unread'
            })
        except Exception:
            pass

    return jsonify({
        "success": True,
        "split_id": split_ref.id,
        "per_person": per_person,
        "participants_count": len(resolved_participants),
        "message": f"Split request created! KES {per_person:,.2f} requested from each of {len(resolved_participants)} comrades. Notifications dispatched with PIN payment prompts."
    }), 201


@campus_logistics_v6_bp.route('/social/split_expense/pay', methods=['POST'])
@campus_logistics_v6_bp.route('/split-expenses/pay', methods=['POST'])
def pay_split_expense():
    """
    Feature 28b: Comrade PIN Payment & Settlement.
    Verifies payer's PIN, transfers share from payer to bill creator, and updates split status.
    """
    data = request.json or {}
    split_id = str(data.get('split_id', '')).strip()
    payer_uid = str(data.get('payer_uid', '')).strip()
    pin = str(data.get('pin', '')).strip()

    if not split_id or not payer_uid or not pin:
        return jsonify({"error": "split_id, payer_uid, and pin are required"}), 400

    db = firestore.client()

    # 1. Fetch split bill
    split_doc = db.collection('split_bills').document(split_id).get()
    if not split_doc.exists:
        split_doc = db.collection('split_expenses').document(split_id).get()

    if not split_doc.exists:
        return jsonify({"error": "Split bill not found"}), 404

    sdata = split_doc.to_dict()
    creator_id = sdata.get('creatorId') or sdata.get('creator_uid')
    per_person = float(sdata.get('perPersonAmount') or sdata.get('per_person') or 0.0)
    participants = sdata.get('participants') or {}
    paid_members = list(sdata.get('paidMembers') or sdata.get('paid_members') or [])

    if payer_uid in paid_members:
        return jsonify({"error": "You have already paid your share for this bill."}), 400

    # 2. Verify Payer PIN & Balance
    payer_doc = db.collection('users').document(payer_uid).get()
    if not payer_doc.exists:
        return jsonify({"error": "Payer account not found"}), 404

    pdata = payer_doc.to_dict()
    stored_pin = str(pdata.get('pin') or pdata.get('walletPin') or '1234').strip()
    if stored_pin and stored_pin != pin:
        # Check safety_pins collection
        sp_doc = db.collection('safety_pins').document(payer_uid).get()
        if sp_doc.exists and str(sp_doc.to_dict().get('pin', '')).strip() == pin:
            pass
        else:
            return jsonify({"error": "Incorrect DISHI Wallet PIN. Please try again."}), 401

    payer_balance = float(pdata.get('walletBalance') or 0.0)
    if payer_balance < per_person:
        return jsonify({
            "error": f"Insufficient wallet balance. You have KES {payer_balance:,.0f}, but your share is KES {per_person:,.0f}. Please top up first."
        }), 400

    # 3. Transact payment: Deduct from payer, credit to creator
    payer_name = pdata.get('displayName') or pdata.get('name') or 'Comrade'
    creator_doc = db.collection('users').document(creator_id).get()
    cdata = creator_doc.to_dict() if creator_doc.exists else {}
    creator_name = sdata.get('creatorName') or cdata.get('displayName') or 'Comrade'

    new_payer_bal = payer_balance - per_person
    db.collection('users').document(payer_uid).update({'walletBalance': new_payer_bal})

    if creator_doc.exists:
        cur_creator_bal = float(cdata.get('walletBalance') or 0.0)
        db.collection('users').document(creator_id).update({'walletBalance': cur_creator_bal + per_person})

    # Record Transactions
    now = firestore.SERVER_TIMESTAMP
    db.collection('transactions').add({
        'userId': payer_uid,
        'title': f"Split Bill Paid: {sdata.get('title', 'Meal')}",
        'amount': per_person,
        'type': 'debit',
        'category': 'split_bill',
        'recipientId': creator_id,
        'recipientName': creator_name,
        'createdAt': now
    })

    db.collection('transactions').add({
        'userId': creator_id,
        'title': f"Split Share Received from {payer_name}",
        'amount': per_person,
        'type': 'credit',
        'category': 'split_bill',
        'senderId': payer_uid,
        'senderName': payer_name,
        'createdAt': now
    })

    # Update split bill state
    paid_members.append(payer_uid)
    if payer_uid in participants:
        participants[payer_uid]['status'] = 'paid'
        participants[payer_uid]['paidAt'] = datetime.utcnow().isoformat()

    all_paid = len(paid_members) >= (len(sdata.get('friends') or sdata.get('participantUids') or []) + 1)
    new_status = 'completed' if all_paid else 'partially_paid'

    updates = {
        'paidMembers': paid_members,
        'participants': participants,
        'status': new_status,
        'updatedAt': now
    }
    db.collection('split_bills').document(split_id).update(updates)
    try:
        db.collection('split_expenses').document(split_id).update(updates)
    except Exception:
        pass

    # Notify Creator
    try:
        c_notif = db.collection('notifications').document()
        c_notif.set({
            'id': c_notif.id,
            'targetUserId': creator_id,
            'title': 'Comrade Paid Bill Share! 💰',
            'message': f"{payer_name} has entered their PIN and paid KES {per_person:,.0f} for '{sdata.get('title', 'Meal')}'.",
            'type': 'split_bill_paid',
            'splitBillId': split_id,
            'createdAt': now,
            'status': 'unread'
        })
    except Exception:
        pass

    return jsonify({
        "success": True,
        "amount_paid": per_person,
        "new_balance": new_payer_bal,
        "status": new_status,
        "message": f"Payment of KES {per_person:,.2f} successful! Transferred to {creator_name}."
    }), 200


@campus_logistics_v6_bp.route('/social/split_expense/user/<uid>', methods=['GET'])
@campus_logistics_v6_bp.route('/split-expenses/user/<uid>', methods=['GET'])
def get_user_split_expenses(uid):
    """
    Returns pending incoming bill split requests requiring the user's PIN,
    as well as outgoing bills created by the user.
    """
    db = firestore.client()
    incoming = []
    outgoing = []

    try:
        out_docs = db.collection('split_bills').where('creatorId', '==', uid).order_by('createdAt', direction=firestore.Query.DESCENDING).limit(20).stream()
        for d in out_docs:
            item = d.to_dict()
            item['id'] = d.id
            outgoing.append(item)
    except Exception:
        pass

    try:
        in_docs = db.collection('split_bills').where('participantUids', 'array_contains', uid).order_by('createdAt', direction=firestore.Query.DESCENDING).limit(20).stream()
        for d in in_docs:
            item = d.to_dict()
            item['id'] = d.id
            paid_list = item.get('paidMembers', [])
            if uid not in paid_list:
                incoming.append(item)
    except Exception:
        pass

    return jsonify({
        "incoming_pending": incoming,
        "outgoing_bills": outgoing,
        "count_pending": len(incoming)
    }), 200

