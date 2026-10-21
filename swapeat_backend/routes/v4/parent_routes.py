import os
import requests
import base64
from datetime import datetime
from flask import Blueprint, request, jsonify
from firebase_admin import firestore, messaging
from routes.mpesa_routes import _fmt_phone, generate_access_token, _send_notification, _notify_parent

parent_v4_bp = Blueprint('parent_v4', __name__)

# =====================================================================
# V4 PARENT SERVICES - ZERO COMMISSION GUARANTEE
# =====================================================================
# In DISHI Version 4, parents pay 0.00% commission on:
# 1. Funding a student's education wallet (M-PESA STK Push)
# 2. Funding the Family Vault / Parent account (M-PESA STK Push)
# 3. Direct Family Vault-to-Student transfers
# 4. Multi-student bulk funding distributions
# 5. Scheduled automated meal allowances
# =====================================================================

@parent_v4_bp.route('/fee_policy', methods=['GET'])
def get_parent_fee_policy():
    """
    Public API verifying the zero-commission policy for parents in DISHI v4.
    """
    return jsonify({
        "status": "success",
        "version": "v4",
        "policy": "ZERO_PARENT_COMMISSION",
        "fees": {
            "fund_student_mpesa_commission": 0.0,
            "fund_vault_mpesa_commission": 0.0,
            "vault_to_student_transfer_fee": 0.0,
            "bulk_funding_fee": 0.0,
            "scheduled_allowance_fee": 0.0,
        },
        "description": "Parents pay strictly KES 0.00 commission when funding students or their Family Vault in DISHI.",
        "updated_at": datetime.utcnow().isoformat()
    }), 200


@parent_v4_bp.route('/fund_student', methods=['POST'])
def fund_student_v4():
    """
    Initiates an M-PESA STK Push to credit a student's wallet with ZERO COMMISSION.
    If parent sends KES 500, parent is charged exactly KES 500 and student receives KES 500.
    """
    data = request.json or {}
    phone_number = (data.get('phone_number') or data.get('phone') or '').strip()
    amount_raw = data.get('amount')
    student_uid = (data.get('student_uid') or data.get('studentUid') or data.get('user_id') or '').strip()
    child_name = data.get('child_name') or data.get('student_name') or 'Student'
    parent_uid = data.get('parent_uid') or data.get('parentUid') or ''
    idempotency_key = data.get('idempotency_key') or data.get('idempotencyKey')

    if not phone_number or not amount_raw or not student_uid:
        return jsonify({"error": "Missing required fields (phone_number, amount, student_uid)"}), 400

    try:
        amount = float(amount_raw)
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid amount value — must be a number"}), 400

    if amount <= 0:
        return jsonify({"error": "Amount must be greater than 0"}), 400

    amount_int = int(amount)
    credit_int = amount_int  # 100% to student with 0 commission deduction!

    formatted_phone = _fmt_phone(phone_number)
    db = firestore.client()

    # Verify student exists
    student_ref = db.collection('users').document(student_uid)
    student_doc = student_ref.get()
    if not student_doc.exists:
        # Fallback query by swapeatCode / dishiId
        q = db.collection('users').where('dishiId', '==', student_uid).limit(1).get()
        if q:
            student_doc = q[0]
            student_uid = student_doc.id
        else:
            return jsonify({"error": f"Student account '{student_uid}' not found."}), 404

    s_data = student_doc.to_dict() or {}
    resolved_name = s_data.get('displayName') or s_data.get('name') or child_name

    # Generate M-PESA token
    access_token = generate_access_token()
    if not access_token:
        return jsonify({"error": "Payment gateway authentication error."}), 500

    passkey = os.getenv('MPESA_PASSKEY', '')
    business_short_code = os.getenv('MPESA_BUSINESS_SHORT_CODE', '')
    if not passkey or not business_short_code:
        return jsonify({"error": "M-PESA credentials not configured on server."}), 500

    timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
    password_str = business_short_code + passkey + timestamp
    password = base64.b64encode(password_str.encode('utf-8')).decode('utf-8')

    env = os.getenv('MPESA_ENV', 'sandbox').lower()
    base_url = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"
    api_url = f"{base_url}/mpesa/stkpush/v1/processrequest"

    clean_acc_ref = ''.join(c for c in resolved_name if c.isalnum()) or "DISHI"

    payload = {
        "BusinessShortCode": business_short_code,
        "Password": password,
        "Timestamp": timestamp,
        "TransactionType": "CustomerPayBillOnline",
        "Amount": amount_int,  # Exactly the requested amount: ZERO COMMISSION!
        "PartyA": formatted_phone,
        "PartyB": business_short_code,
        "PhoneNumber": formatted_phone,
        "CallBackURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/callback",
        "AccountReference": clean_acc_ref[:12],
        "TransactionDesc": f"Fund {clean_acc_ref}"[:12],
    }

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    try:
        response = requests.post(api_url, json=payload, headers=headers, timeout=15)
        response_data = response.json()
    except requests.Timeout:
        return jsonify({
            "error": "M-PESA STK Push timed out.",
            "fallback": True,
            "paybill": business_short_code,
            "account_reference": clean_acc_ref[:12]
        }), 504
    except Exception as e:
        return jsonify({"error": "Failed to reach M-PESA gateway", "details": str(e)}), 502

    if response.status_code == 200 and 'CheckoutRequestID' in response_data:
        checkout_id = response_data['CheckoutRequestID']
        db.collection('mpesa_transactions').document(checkout_id).set({
            'user_id': student_uid,
            'amount': credit_int,
            'charged_amount': amount_int,
            'commission': 0.0,
            'fee': 0.0,
            'is_zero_commission': True,
            'destination': 'walletBalance',
            'status': 'pending',
            'phone': formatted_phone,
            'user_name': resolved_name,
            'sender_id': parent_uid,
            'metadata': {
                'action': 'fund_student',
                'funder_phone': formatted_phone,
                'child_name': resolved_name,
                'role': 'parent',
                'commission': 0.0,
                'fee': 0.0,
                'version': 'v4'
            },
            'timestamp': firestore.SERVER_TIMESTAMP,
        })

        return jsonify({
            "status": "success",
            "message": f"Zero-commission STK prompt of KES {amount_int} sent to {formatted_phone}",
            "amountCharged": amount_int,
            "studentCredit": credit_int,
            "commission": 0.0,
            "CheckoutRequestID": checkout_id
        }), 200

    err_msg = response_data.get('errorMessage') or response_data.get('ResponseDescription') or "M-PESA prompt failed"
    return jsonify({"error": err_msg, "details": response_data}), response.status_code


@parent_v4_bp.route('/fund_vault', methods=['POST'])
def fund_vault_v4():
    """
    Initiates an M-PESA STK Push to deposit funds into the Parent Family Vault with ZERO COMMISSION.
    """
    data = request.json or {}
    phone_number = (data.get('phone_number') or data.get('phone') or '').strip()
    amount_raw = data.get('amount')
    parent_uid = (data.get('parent_uid') or data.get('parentUid') or data.get('user_id') or '').strip()

    if not phone_number or not amount_raw or not parent_uid:
        return jsonify({"error": "Missing required fields (phone_number, amount, parent_uid)"}), 400

    try:
        amount = float(amount_raw)
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid amount value — must be a number"}), 400

    if amount <= 0:
        return jsonify({"error": "Amount must be greater than 0"}), 400

    amount_int = int(amount)
    credit_int = amount_int  # Exactly 100% into vault with ZERO COMMISSION

    formatted_phone = _fmt_phone(phone_number)
    db = firestore.client()

    # Generate M-PESA token
    access_token = generate_access_token()
    if not access_token:
        return jsonify({"error": "Payment gateway authentication error."}), 500

    passkey = os.getenv('MPESA_PASSKEY', '')
    business_short_code = os.getenv('MPESA_BUSINESS_SHORT_CODE', '')
    if not passkey or not business_short_code:
        return jsonify({"error": "M-PESA credentials not configured on server."}), 500

    timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
    password_str = business_short_code + passkey + timestamp
    password = base64.b64encode(password_str.encode('utf-8')).decode('utf-8')

    env = os.getenv('MPESA_ENV', 'sandbox').lower()
    base_url = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"
    api_url = f"{base_url}/mpesa/stkpush/v1/processrequest"

    payload = {
        "BusinessShortCode": business_short_code,
        "Password": password,
        "Timestamp": timestamp,
        "TransactionType": "CustomerPayBillOnline",
        "Amount": amount_int,  # Exactly the requested amount: ZERO COMMISSION!
        "PartyA": formatted_phone,
        "PartyB": business_short_code,
        "PhoneNumber": formatted_phone,
        "CallBackURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/callback",
        "AccountReference": "FamilyVault",
        "TransactionDesc": "VaultDeposit",
    }

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    try:
        response = requests.post(api_url, json=payload, headers=headers, timeout=15)
        response_data = response.json()
    except requests.Timeout:
        return jsonify({
            "error": "M-PESA STK Push timed out.",
            "fallback": True,
            "paybill": business_short_code,
            "account_reference": "FamilyVault"
        }), 504
    except Exception as e:
        return jsonify({"error": "Failed to reach M-PESA gateway", "details": str(e)}), 502

    if response.status_code == 200 and 'CheckoutRequestID' in response_data:
        checkout_id = response_data['CheckoutRequestID']
        db.collection('mpesa_transactions').document(checkout_id).set({
            'user_id': parent_uid,
            'amount': credit_int,
            'charged_amount': amount_int,
            'commission': 0.0,
            'fee': 0.0,
            'is_zero_commission': True,
            'destination': 'savingsBalance',
            'status': 'pending',
            'phone': formatted_phone,
            'user_name': 'Parent Family Vault',
            'sender_id': parent_uid,
            'metadata': {
                'action': 'fund_vault',
                'funder_phone': formatted_phone,
                'role': 'parent',
                'commission': 0.0,
                'fee': 0.0,
                'version': 'v4'
            },
            'timestamp': firestore.SERVER_TIMESTAMP,
        })

        return jsonify({
            "status": "success",
            "message": f"Zero-commission STK prompt of KES {amount_int} sent to {formatted_phone}",
            "amountCharged": amount_int,
            "vaultCredit": credit_int,
            "commission": 0.0,
            "CheckoutRequestID": checkout_id
        }), 200

    err_msg = response_data.get('errorMessage') or response_data.get('ResponseDescription') or "M-PESA prompt failed"
    return jsonify({"error": err_msg, "details": response_data}), response.status_code


@parent_v4_bp.route('/transfer', methods=['POST'])
def transfer_from_vault_v4():
    """
    Atomically transfers funds from the Parent Family Vault to student's wallet with ZERO COMMISSION.
    Deduction order: savingsBalance -> vaultBalance -> walletBalance.
    """
    data = request.json or {}
    parent_uid = data.get('parentUid') or data.get('parent_uid') or data.get('senderUid')
    student_uid = data.get('studentUid') or data.get('student_uid') or data.get('childUid')
    amount_raw = data.get('amount')

    if not all([parent_uid, student_uid, amount_raw is not None]):
        return jsonify({'error': 'Missing required fields (parentUid, studentUid, amount)'}), 400

    try:
        amount = float(amount_raw)
    except (ValueError, TypeError):
        return jsonify({'error': 'Amount must be a valid number'}), 400

    if amount <= 0:
        return jsonify({'error': 'Amount must be greater than 0'}), 400

    db = firestore.client()
    parent_ref = db.collection('users').document(parent_uid)
    student_ref = db.collection('users').document(student_uid)

    @firestore.transactional
    def run_zero_fee_transfer(transaction):
        parent_snap = parent_ref.get(transaction=transaction)
        student_snap = student_ref.get(transaction=transaction)

        if not parent_snap.exists:
            return {'error': 'Parent account not found'}, 404
        if not student_snap.exists:
            return {'error': 'Student account not found'}, 404

        parent_data = parent_snap.to_dict() or {}
        student_data = student_snap.to_dict() or {}

        parent_wallet = float(parent_data.get('walletBalance', 0.0) or 0.0)
        parent_savings = float(parent_data.get('savingsBalance', 0.0) or 0.0)
        parent_vault = float(parent_data.get('vaultBalance', 0.0) or 0.0)

        total_available = parent_savings + parent_vault + parent_wallet
        if total_available < amount:
            return {'error': f'Insufficient funds in Family Vault. Available: Ksh {total_available:,.2f}'}, 400

        student_wallet = float(student_data.get('walletBalance', 0.0) or 0.0)

        remaining_to_deduct = amount
        parent_updates = {}

        if parent_savings > 0:
            deduct_savings = min(parent_savings, remaining_to_deduct)
            parent_updates['savingsBalance'] = parent_savings - deduct_savings
            remaining_to_deduct -= deduct_savings

        if remaining_to_deduct > 0 and parent_vault > 0:
            deduct_vault = min(parent_vault, remaining_to_deduct)
            parent_updates['vaultBalance'] = parent_vault - deduct_vault
            remaining_to_deduct -= deduct_vault

        if remaining_to_deduct > 0 and parent_wallet > 0:
            deduct_wallet = min(parent_wallet, remaining_to_deduct)
            parent_updates['walletBalance'] = parent_wallet - deduct_wallet
            remaining_to_deduct -= deduct_wallet

        transaction.update(parent_ref, parent_updates)
        transaction.update(student_ref, {
            'walletBalance': student_wallet + amount
        })

        student_name = student_data.get('name') or student_data.get('displayName') or 'Student'

        tx_ref = db.collection('transactions').document()
        transaction.set(tx_ref, {
            'type': 'parent_transfer',
            'senderUid': parent_uid,
            'receiverUid': student_uid,
            'amount': amount,
            'commission': 0.0,
            'fee': 0.0,
            'is_zero_commission': True,
            'version': 'v4',
            'timestamp': firestore.SERVER_TIMESTAMP,
            'status': 'completed',
            'description': f'Zero-commission Family Vault transfer to {student_name}'
        })

        ledger_ref = db.collection('wallet_ledger').document()
        transaction.set(ledger_ref, {
            'type': 'parent_transfer',
            'user_id': student_uid,
            'sender_id': parent_uid,
            'amount': amount,
            'commission': 0.0,
            'destination': 'walletBalance',
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        return {
            'success': True,
            'txId': tx_ref.id,
            'transferred': amount,
            'commission': 0.0,
            'studentNewBalance': student_wallet + amount,
            'message': f'Transferred Ksh {amount:,.2f} from Family Vault to {student_name} with KES 0.00 commission'
        }

    try:
        result = run_zero_fee_transfer(db.transaction())
        if isinstance(result, dict) and 'error' in result:
            return jsonify(result), result.get('status_code', 400)
        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': 'Transfer transaction failed', 'details': str(e)}), 500


@parent_v4_bp.route('/bulk_fund', methods=['POST'])
def bulk_fund_students_v4():
    """
    Executes bulk funding for multiple students from Family Vault with ZERO COMMISSION.
    """
    data = request.json or {}
    parent_uid = data.get('parentUid') or data.get('parent_uid')
    allocations = data.get('allocations') or []  # List of {'studentUid': '...', 'amount': 100}

    if not parent_uid or not allocations:
        return jsonify({'error': 'Missing parentUid or allocations list'}), 400

    total_needed = sum(float(item.get('amount', 0)) for item in allocations)
    if total_needed <= 0:
        return jsonify({'error': 'Total bulk allocation must be greater than 0'}), 400

    db = firestore.client()
    parent_ref = db.collection('users').document(parent_uid)

    @firestore.transactional
    def run_bulk_transfer(transaction):
        parent_snap = parent_ref.get(transaction=transaction)
        if not parent_snap.exists:
            return {'error': 'Parent account not found'}, 404

        p_data = parent_snap.to_dict() or {}
        parent_savings = float(p_data.get('savingsBalance', 0.0) or 0.0)
        parent_vault = float(p_data.get('vaultBalance', 0.0) or 0.0)
        parent_wallet = float(p_data.get('walletBalance', 0.0) or 0.0)

        total_avail = parent_savings + parent_vault + parent_wallet
        if total_avail < total_needed:
            return {'error': f'Insufficient funds in Family Vault (Available: Ksh {total_avail:,.2f}, Required: Ksh {total_needed:,.2f})'}, 400

        # Deduct total from parent
        rem = total_needed
        p_up = {}
        if parent_savings > 0:
            d = min(parent_savings, rem)
            p_up['savingsBalance'] = parent_savings - d
            rem -= d
        if rem > 0 and parent_vault > 0:
            d = min(parent_vault, rem)
            p_up['vaultBalance'] = parent_vault - d
            rem -= d
        if rem > 0 and parent_wallet > 0:
            d = min(parent_wallet, rem)
            p_up['walletBalance'] = parent_wallet - d
            rem -= d

        transaction.update(parent_ref, p_up)

        # Credit each student
        for item in allocations:
            s_uid = item.get('studentUid')
            amt = float(item.get('amount', 0))
            if not s_uid or amt <= 0:
                continue

            s_ref = db.collection('users').document(s_uid)
            s_snap = s_ref.get(transaction=transaction)
            if s_snap.exists:
                cur_bal = float((s_snap.to_dict() or {}).get('walletBalance', 0.0) or 0.0)
                transaction.update(s_ref, {'walletBalance': cur_bal + amt})

                tx_ref = db.collection('transactions').document()
                transaction.set(tx_ref, {
                    'type': 'parent_bulk_transfer',
                    'senderUid': parent_uid,
                    'receiverUid': s_uid,
                    'amount': amt,
                    'commission': 0.0,
                    'fee': 0.0,
                    'is_zero_commission': True,
                    'version': 'v4',
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'status': 'completed',
                    'description': f'Zero-commission Family Vault bulk allocation of Ksh {amt:,.2f}'
                })

        return {
            'success': True,
            'totalFunded': total_needed,
            'studentsCount': len(allocations),
            'commission': 0.0,
            'message': f'Successfully allocated Ksh {total_needed:,.2f} to {len(allocations)} students with ZERO fees'
        }

    try:
        res = run_bulk_transfer(db.transaction())
        if isinstance(res, dict) and 'error' in res:
            return jsonify(res), 400
        return jsonify(res), 200
    except Exception as e:
        return jsonify({'error': 'Bulk transfer failed', 'details': str(e)}), 500
