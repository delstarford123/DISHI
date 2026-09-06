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

            # Verify Auth Code
            if student_data.get('isOfflineChild') == True:
                if str(student_data.get('offlinePin')) != str(auth_code):
                    return False, "Invalid Offline PIN"
            else:
                # Validate Daily Auth Token
                now = datetime.now()
                date_str = f"{now.year}-{now.month}-{now.day}"
                payload = f"{student_ref.id}|{date_str}"
                secret = "dishi-secure-totp-secret-key-2026".encode('utf-8')
                signature = hmac.new(secret, payload.encode('utf-8'), hashlib.sha256).hexdigest()
                
                # offset logic from flutter:
                offset = len(signature) - 8
                hex_sub = signature[offset:]
                val = int(hex_sub, 16)
                token_int = val % 10000
                expected_token = str(token_int).zfill(4)

                override = student_data.get('overrideAuthToken')
                if override and override.get('date') == date_str and str(override.get('token')) == str(auth_code):
                    pass # Valid override
                elif expected_token != str(auth_code):
                    return False, "Invalid Daily Auth Token"

            e_float = vendor_data.get('e_float', vendor_data.get('walletBalance', 0.0))
            if e_float < amount:
                return False, "Insufficient e-float to process top-up"

            # Calculate Wash Trading Restrictions
            now = datetime.now()
            today_str = f"{now.year}-{now.month}-{now.day}"
            
            # Pull tracking fields from vendor
            total_food_sales_volume = vendor_data.get('totalFoodSalesVolume', 0.0)
            total_topup_volume = vendor_data.get('totalTopUpVolume', 0.0)
            
            last_commission_date = vendor_data.get('lastCommissionDate', '')
            daily_commission_earned = vendor_data.get('dailyCommissionEarned', 0.0)
            
            if last_commission_date != today_str:
                daily_commission_earned = 0.0

            # 1:1 Ratio Rule Check: You can only earn commission if topup volume doesn't severely outpace food sales.
            eligible_for_commission = (total_topup_volume + amount) <= total_food_sales_volume
            
            # Calculate commission
            raw_commission = 2.0 if amount < 100 else (amount * 0.005)
            commission = 0.0
            
            if eligible_for_commission:
                if daily_commission_earned + raw_commission <= 500.0:
                    commission = raw_commission
                elif daily_commission_earned < 500.0:
                    commission = 500.0 - daily_commission_earned # Cap it exactly at 500
            
            new_daily_commission = daily_commission_earned + commission

            # Snapshots
            vendor_float_before = e_float
            student_wallet_before = student_data.get('walletBalance', 0.0)

            # Update Balances
            new_e_float = e_float - amount + commission
            new_student_balance = student_wallet_before + amount
            new_total_topup = total_topup_volume + amount

            if new_student_balance > 3000.0:
                return False, "Regulatory Limit Exceeded: Wallet cannot hold more than 3,000 KES."

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
            tx_ref = db.collection('transactions').document()
            tx_data = {
                'idempotencyKey': idempotency_key,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'vendorId': vendor_id,
                'studentId': student_token,
                'amount': amount,
                'vendorFloatBefore': vendor_float_before,
                'studentWalletBefore': student_wallet_before,
                'commissionEarned': commission,
                'type': 'vendor_agent_topup',
                'status': 'COMPLETED'
            }
            transaction.set(tx_ref, tx_data)
            return True, {"txId": tx_ref.id, "newStudentBalance": new_student_balance, "fcmToken": student_data.get('fcmToken')}

        success, result = process_topup(transaction, vendor_ref, student_ref)

        if not success:
            return jsonify({"error": result}), 400

        # Send FCM notification
        fcm_token = result.get('fcmToken')
        if fcm_token:
            try:
                messaging.send(messaging.Message(
                    notification=messaging.Notification(
                        title="Wallet Top-Up",
                        body=f"{amount} KES credited to your wallet. New Balance: {result['newStudentBalance']} KES. TxID: {result['txId'][-6:]}",
                    ),
                    token=fcm_token,
                ))
            except Exception as e:
                print(f"FCM error: {e}")

        return jsonify({"success": True, "txId": result['txId']}), 200

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
