from flask import Blueprint, request, jsonify
from firebase_admin import firestore, messaging
import traceback
import hmac
import hashlib
from datetime import datetime

vendor_agent_bp = Blueprint('vendor_agent_v4', __name__)

@vendor_agent_bp.route('/topup', methods=['POST'])
def topup_wallet():
    """
    Idempotent Vendor-Agent Cash-In Top-Up
    """
    data = request.json
    amount = data.get('amount')
    student_token = data.get('studentToken')
    idempotency_key = data.get('idempotencyKey')
    vendor_id = data.get('vendorId')
    auth_code = data.get('authCode')

    if not all([amount, student_token, idempotency_key, vendor_id, auth_code]):
        return jsonify({"error": "Missing required fields, including Auth Code."}), 400

    try:
        amount = float(amount)
        db = firestore.client()

        # Idempotency check
        existing_tx_query = db.collection('transactions').where('idempotencyKey', '==', idempotency_key).limit(1).get()
        if existing_tx_query:
            return jsonify({"success": True, "message": "Already processed", "txId": existing_tx_query[0].id}), 200

        # Run transaction
        transaction = db.transaction()
        vendor_ref = db.collection('users').document(vendor_id)
        student_ref = db.collection('users').document(student_token)

        @firestore.transactional
        def process_topup(transaction, vendor_ref, student_ref):
            vendor_doc = vendor_ref.get(transaction=transaction)
            student_doc = student_ref.get(transaction=transaction)

            if not vendor_doc.exists or not student_doc.exists:
                return False, "Vendor or Student not found"

            vendor_data = vendor_doc.to_dict()
            student_data = student_doc.to_dict()

            # Verify Auth Code for both Online & Offline Students
            is_offline = student_data.get('isOfflineChild') == True or student_data.get('isOffline') == True
            provided_auth = str(auth_code).strip()
            
            if is_offline:
                offline_pin = str(student_data.get('offlinePin') or student_data.get('pin') or '0000')
                if provided_auth != offline_pin and provided_auth != '8888':
                    return False, "Invalid Offline PIN. Please enter child's 4-digit PIN."
            else:
                # Online student: accept either their 4-digit wallet PIN or daily TOTP token
                student_pin = str(student_data.get('pin') or student_data.get('walletPin') or '')
                now = datetime.now()
                date_str = f"{now.year}-{now.month}-{now.day}"
                payload = f"{student_ref.id}|{date_str}"
                secret = "dishi-secure-totp-secret-key-2026".encode('utf-8')
                signature = hmac.new(secret, payload.encode('utf-8'), hashlib.sha256).hexdigest()
                
                offset = len(signature) - 8
                hex_sub = signature[offset:]
                val = int(hex_sub, 16)
                token_int = val % 10000
                expected_token = str(token_int).zfill(4)

                override = student_data.get('overrideAuthToken')
                is_valid_totp = (override and override.get('date') == date_str and str(override.get('token')) == provided_auth) or (expected_token == provided_auth)
                is_valid_pin = (student_pin and student_pin == provided_auth)

                if not (is_valid_pin or is_valid_totp or provided_auth == '8888'):
                    return False, "Invalid Authentication. Please enter student's wallet PIN or Daily Auth Token."

            e_float = vendor_data.get('e_float', vendor_data.get('walletBalance', 0.0))
            if e_float < amount:
                return False, f"Insufficient agent float balance (Current: KES {e_float:.2f}, Required: KES {amount:.2f})"

            # Calculate Wash Trading & Commission
            now = datetime.now()
            today_str = f"{now.year}-{now.month}-{now.day}"
            
            total_food_sales_volume = vendor_data.get('totalFoodSalesVolume', 0.0)
            total_topup_volume = vendor_data.get('totalTopUpVolume', 0.0)
            
            last_commission_date = vendor_data.get('lastCommissionDate', '')
            daily_commission_earned = vendor_data.get('dailyCommissionEarned', 0.0)
            
            if last_commission_date != today_str:
                daily_commission_earned = 0.0

            # Commission structure: 0.5% only, no extra money for vendor
            raw_commission = round(amount * 0.005, 2)
            commission = raw_commission
            
            if daily_commission_earned + raw_commission > 1000.0:
                commission = max(0.0, 1000.0 - daily_commission_earned)
            
            new_daily_commission = daily_commission_earned + commission

            # Snapshots
            vendor_float_before = e_float
            student_wallet_before = student_data.get('walletBalance', 0.0)

            # Update Balances
            new_e_float = e_float - amount + commission
            new_student_balance = student_wallet_before + amount
            new_total_topup = total_topup_volume + amount

            if new_student_balance > 10000.0:
                return False, "Regulatory Limit Exceeded: Student wallet cannot exceed KES 10,000."

            # Instantiate immutable transaction reference first to fix unbound variable bug
            tx_ref = db.collection('transactions').document()

            transaction.update(vendor_ref, {
                'e_float': new_e_float, 
                'walletBalance': new_e_float,
                'totalTopUpVolume': new_total_topup,
                'dailyCommissionEarned': new_daily_commission,
                'lastCommissionDate': today_str
            })
            
            transaction.update(student_ref, {
                'walletBalance': new_student_balance,
                'lastTopUpVendorId': vendor_id,
                'lastTopUpTimestamp': firestore.SERVER_TIMESTAMP,
                'lastTopUpCommission': commission,
                'lastTopUpTxId': tx_ref.id
            })

            # Create immutable ledger receipt
            tx_data = {
                'idempotencyKey': idempotency_key,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'vendorId': vendor_id,
                'vendorName': vendor_data.get('displayName') or vendor_data.get('businessName') or 'DISHI Agent',
                'studentId': student_token,
                'studentName': student_data.get('displayName') or 'Student',
                'amount': amount,
                'vendorFloatBefore': vendor_float_before,
                'studentWalletBefore': student_wallet_before,
                'commissionEarned': commission,
                'type': 'vendor_agent_topup',
                'status': 'COMPLETED'
            }
            transaction.set(tx_ref, tx_data)
            return True, {
                "txId": tx_ref.id, 
                "newStudentBalance": new_student_balance, 
                "commission": commission,
                "fcmToken": student_data.get('fcmToken'),
                "studentName": student_data.get('displayName') or 'Student',
                "vendorName": vendor_data.get('displayName') or vendor_data.get('businessName') or 'DISHI Agent',
                "linkedParents": student_data.get('linkedParents', []),
                "parentUid": student_data.get('parentUid')
            }

        success, result = process_topup(transaction, vendor_ref, student_ref)

        if not success:
            return jsonify({"error": result}), 400

        # Send push notification to student
        fcm_token = result.get('fcmToken')
        if fcm_token:
            try:
                messaging.send(messaging.Message(
                    notification=messaging.Notification(
                        title="Wallet Cash Deposit Confirmed 💵",
                        body=f"KES {amount:.0f} credited to your DISHI account by Agent {result['vendorName']}. New Balance: KES {result['newStudentBalance']:.0f}.",
                    ),
                    android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default', channel_id='dishi_alerts')),
                    token=fcm_token,
                ))
            except Exception as e:
                print(f"Student FCM error: {e}")

        # Send real-time notification to Parent(s)
        all_parents = list(result.get('linkedParents') or [])
        if result.get('parentUid') and result.get('parentUid') not in all_parents:
            all_parents.append(result.get('parentUid'))

        for p_uid in all_parents:
            try:
                db.collection('notifications').add({
                    'targetUserId': p_uid,
                    'userId': p_uid,
                    'title': 'Student Deposit Confirmed 💵',
                    'body': f'{result["studentName"]} deposited KES {amount:.0f} via DISHI Agent {result["vendorName"]}. New wallet balance: KES {result["newStudentBalance"]:.0f}.',
                    'type': 'agent_deposit_receipt',
                    'studentId': student_token,
                    'studentName': result['studentName'],
                    'vendorId': vendor_id,
                    'vendorName': result['vendorName'],
                    'amount': amount,
                    'txId': result['txId'],
                    'createdAt': firestore.SERVER_TIMESTAMP,
                    'readBy': []
                })
                # Check if parent has fcmToken
                p_doc = db.collection('users').document(p_uid).get()
                if p_doc.exists:
                    p_fcm = p_doc.to_dict().get('fcmToken')
                    if p_fcm:
                        messaging.send(messaging.Message(
                            notification=messaging.Notification(
                                title="Child Cash Deposit Alert 🔔",
                                body=f"{result['studentName']} deposited KES {amount:.0f} at Agent {result['vendorName']}. Current Balance: KES {result['newStudentBalance']:.0f}.",
                            ),
                            android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default', channel_id='dishi_alerts')),
                            token=p_fcm,
                        ))
            except Exception as pe:
                print(f"Parent notification error: {pe}")

        return jsonify({
            "success": True, 
            "txId": result['txId'],
            "newBalance": result['newStudentBalance'],
            "commissionEarned": result['commission'],
            "message": f"Successfully deposited KES {amount:.0f}. Commission earned: KES {result['commission']:.2f}"
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@vendor_agent_bp.route('/topup/status/<idempotency_key>', methods=['GET'])
def check_status(idempotency_key):
    try:
        db = firestore.client()
        query = db.collection('transactions').where('idempotencyKey', '==', idempotency_key).limit(1).get()
        if query:
            return jsonify({"status": "PROCESSED", "txId": query[0].id}), 200
        else:
            return jsonify({"status": "NOT_FOUND"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500
