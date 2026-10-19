from flask import Blueprint, request, jsonify
from firebase_admin import firestore, messaging
import os
import requests
import datetime
import uuid

c2b_v4_bp = Blueprint('c2b_v4', __name__)

def verify_admin(req):
    auth_header = req.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        token = auth_header.split('Bearer ')[1]
        try:
            from firebase_admin import auth
            decoded = auth.verify_id_token(token)
            return decoded.get('uid')
        except Exception:
            return None
    return None

def normalize_phone(phone_raw: str) -> str:
    if not phone_raw:
        return ''
    cleaned = ''.join(filter(str.isdigit, str(phone_raw)))
    if cleaned.startswith('0') and len(cleaned) == 10:
        return '254' + cleaned[1:]
    if cleaned.startswith('254') and len(cleaned) == 12:
        return cleaned
    if len(cleaned) == 9:
        return '254' + cleaned
    return cleaned

def find_user_by_reference(db, bill_ref: str, phone: str):
    """
    Intelligent C2B Account Resolution Engine.
    Matches BillRefNumber or MSISDN against registered students, staff, and vendors.
    """
    clean_ref = (bill_ref or '').strip()
    clean_phone = normalize_phone(phone)
    alt_phone_0 = '0' + clean_phone[3:] if clean_phone.startswith('254') else ''
    alt_phone_plus = '+' + clean_phone if clean_phone else ''

    # 1. Direct UID match if bill_ref is a document ID
    if clean_ref and len(clean_ref) >= 20:
        try:
            doc = db.collection('users').document(clean_ref).get()
            if doc.exists:
                return doc.id, doc.to_dict()
        except Exception:
            pass

    # 2. Match BillRef against student registration / admission number
    if clean_ref and clean_ref.upper() not in ['WALLET', 'TOPUP', 'DISHI', 'FOOD', 'MEAL']:
        reg_queries = [
            db.collection('users').where('regNumber', '==', clean_ref).limit(1).get(),
            db.collection('users').where('studentId', '==', clean_ref).limit(1).get(),
            db.collection('users').where('admissionNumber', '==', clean_ref).limit(1).get(),
            db.collection('users').where('nfcUid', '==', clean_ref).limit(1).get(),
        ]
        for q in reg_queries:
            if q:
                return q[0].id, q[0].to_dict()

    # 3. Match BillRef as a phone number
    ref_phone = normalize_phone(clean_ref)
    if ref_phone and len(ref_phone) == 12:
        for p in [ref_phone, '0' + ref_phone[3:], '+' + ref_phone]:
            docs = db.collection('users').where('phone', '==', p).limit(1).get()
            if docs:
                return docs[0].id, docs[0].to_dict()

    # 4. Fallback match: Customer MSISDN (Phone number who sent the money)
    if clean_phone:
        for p in [clean_phone, alt_phone_0, alt_phone_plus]:
            if not p:
                continue
            docs = db.collection('users').where('phone', '==', p).limit(1).get()
            if docs:
                return docs[0].id, docs[0].to_dict()

    return None, None

def _notify_user_deposit(db, user_id: str, amount: float, trans_id: str, balance: float):
    title = "M-PESA Paybill Top-up Received"
    body = f"KES {amount:,.2f} received via Paybill 4050545 (Ref: {trans_id}). New Wallet Balance: KES {balance:,.2f}."
    try:
        user_doc = db.collection('users').document(user_id).get()
        if user_doc.exists:
            token = user_doc.to_dict().get('fcmToken')
            if token:
                messaging.send(messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    android=messaging.AndroidConfig(priority='high'),
                    token=token
                ))
    except Exception as e:
        print(f"[C2B] FCM send error: {e}")

    try:
        db.collection('notifications').add({
            'title': title,
            'body': body,
            'targetUserId': user_id,
            'type': 'wallet_funding',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'readBy': [],
            'dismissedBy': []
        })
    except Exception:
        pass


# ─────────────────────────────────────────────────────────────────────────────
# 1. C2B Validation Endpoint (Safaricom Pre-Validation)
# ─────────────────────────────────────────────────────────────────────────────
@c2b_v4_bp.route('/validation', methods=['POST'])
def c2b_validation():
    """
    Safaricom M-PESA C2B Validation Webhook.
    Called by Safaricom before deducting money to verify transaction validity.
    """
    data = request.json or {}
    print(f"[C2B v4 Validation] Inbound packet: {data}")
    trans_amount = data.get('TransAmount', 0)

    try:
        amt = float(trans_amount)
        if amt <= 0:
            return jsonify({"ResultCode": "C2B00012", "ResultDesc": "Invalid amount"}), 200
    except (ValueError, TypeError):
        return jsonify({"ResultCode": "C2B00012", "ResultDesc": "Invalid amount format"}), 200

    # Accept all genuine customer deposits
    return jsonify({"ResultCode": 0, "ResultDesc": "Accepted"}), 200


# ─────────────────────────────────────────────────────────────────────────────
# 2. C2B Confirmation Endpoint (Accurate Inbound Wallet Crediting)
# ─────────────────────────────────────────────────────────────────────────────
@c2b_v4_bp.route('/confirmation', methods=['POST'])
def c2b_confirmation():
    """
    Safaricom M-PESA C2B Confirmation Webhook.
    Called when customer completes payment via Paybill 4050545.
    Performs atomic crediting, idempotent duplicate prevention, and user resolution.
    """
    data = request.json or {}
    print(f"[C2B v4 Confirmation] Processing confirmation: {data}")

    trans_id = (data.get('TransID') or data.get('trans_id') or '').strip().upper()
    trans_amount_raw = data.get('TransAmount') or data.get('trans_amount') or 0
    bill_ref = (data.get('BillRefNumber') or data.get('bill_ref') or '').strip()
    msisdn = (data.get('MSISDN') or data.get('phone') or '').strip()
    trans_time = data.get('TransTime') or data.get('trans_time') or ''
    first_name = (data.get('FirstName') or '').strip().title()
    middle_name = (data.get('MiddleName') or '').strip().title()
    last_name = (data.get('LastName') or '').strip().title()
    customer_name = " ".join(filter(None, [first_name, middle_name, last_name])) or "Customer"

    if not trans_id:
        return jsonify({"ResultCode": 1, "ResultDesc": "Missing TransID"}), 400

    try:
        amount = float(trans_amount_raw)
    except (ValueError, TypeError):
        amount = 0.0

    db = firestore.client()

    # 1. Idempotency Check: prevent duplicate processing
    existing_c2b = db.collection('c2b_transactions').document(trans_id).get()
    if existing_c2b.exists and existing_c2b.to_dict().get('status') == 'completed':
        print(f"[C2B v4] Duplicate confirmation skipped for {trans_id}")
        return jsonify({"ResultCode": 0, "ResultDesc": "Transaction already processed"}), 200

    # 2. Account Resolution Engine
    matched_uid, user_data = find_user_by_reference(db, bill_ref, msisdn)

    now_utc = datetime.datetime.now(datetime.timezone.utc)
    batch = db.batch()

    if matched_uid and user_data:
        # User matched! Atomic wallet credit
        current_bal = float(user_data.get('walletBalance') or user_data.get('wallet_balance') or user_data.get('balance') or 0.0)
        new_bal = current_bal + amount
        matched_user_name = user_data.get('displayName') or user_data.get('name') or customer_name

        user_ref = db.collection('users').document(matched_uid)
        batch.update(user_ref, {
            'walletBalance': new_bal,
            'wallet_balance': new_bal,
            'lastTopupAmount': amount,
            'lastTopupReceipt': trans_id,
            'lastTopupAt': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP
        })

        # Record in ledger transactions collection
        tx_ref = db.collection('transactions').document()
        batch.set(tx_ref, {
            'type': 'c2b_paybill_topup',
            'amount': amount,
            'receipt': trans_id,
            'status': 'completed',
            'user_id': matched_uid,
            'student_id': matched_uid,
            'user_name': matched_user_name,
            'phone': msisdn,
            'bill_ref': bill_ref,
            'description': f"M-PESA C2B Paybill Top-up (Ref: {trans_id})",
            'source': 'M-PESA Paybill 4050545',
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        # Record in c2b_transactions
        c2b_ref = db.collection('c2b_transactions').document(trans_id)
        batch.set(c2b_ref, {
            'trans_id': trans_id,
            'amount': amount,
            'trans_amount': amount,
            'phone': msisdn,
            'bill_ref': bill_ref,
            'bill_ref_number': bill_ref,
            'customer_name': customer_name,
            'first_name': first_name,
            'last_name': last_name,
            'status': 'completed',
            'reconciled': True,
            'matched_user_id': matched_uid,
            'matched_user_name': matched_user_name,
            'trans_time': trans_time or now_utc.strftime("%Y%m%d%H%M%S"),
            'created_at': firestore.SERVER_TIMESTAMP
        })

        # Also register in mpesa_transactions for unified reporting
        mpesa_ref = db.collection('mpesa_transactions').document(trans_id)
        batch.set(mpesa_ref, {
            'user_id': matched_uid,
            'user_name': matched_user_name,
            'amount': amount,
            'phone': msisdn,
            'receipt': trans_id,
            'destination': 'WALLET-TOPUP',
            'status': 'completed',
            'source': 'c2b_paybill',
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        batch.commit()
        print(f"[C2B v4] Credited KES {amount} to user {matched_uid} ({matched_user_name}). New balance: {new_bal}")

        # Send push notification
        _notify_user_deposit(db, matched_uid, amount, trans_id, new_bal)

        return jsonify({
            "ResultCode": 0,
            "ResultDesc": "Success",
            "matched": True,
            "user_id": matched_uid,
            "user_name": matched_user_name,
            "new_balance": new_bal
        }), 200

    else:
        # Unmatched Deposit: Persist safely for admin manual one-tap reconciliation
        c2b_ref = db.collection('c2b_transactions').document(trans_id)
        batch.set(c2b_ref, {
            'trans_id': trans_id,
            'amount': amount,
            'trans_amount': amount,
            'phone': msisdn,
            'bill_ref': bill_ref,
            'bill_ref_number': bill_ref,
            'customer_name': customer_name,
            'first_name': first_name,
            'last_name': last_name,
            'status': 'unmatched',
            'reconciled': False,
            'matched_user_id': None,
            'matched_user_name': None,
            'trans_time': trans_time or now_utc.strftime("%Y%m%d%H%M%S"),
            'created_at': firestore.SERVER_TIMESTAMP,
            'note': 'Customer account reference could not be resolved automatically. Admin action required.'
        })
        batch.commit()
        print(f"[C2B v4] Unmatched C2B deposit recorded: {trans_id} (KES {amount}, Ref: {bill_ref}, Phone: {msisdn})")

        return jsonify({
            "ResultCode": 0,
            "ResultDesc": "Accepted - Unmatched deposit logged for manual reconciliation",
            "matched": False,
            "trans_id": trans_id
        }), 200


# ─────────────────────────────────────────────────────────────────────────────
# 3. C2B Collections Overview Endpoint
# ─────────────────────────────────────────────────────────────────────────────
@c2b_v4_bp.route('/overview', methods=['GET'])
def c2b_overview():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        db = firestore.client()
        collections = []
        seen_tx_ids = set()
        total_volume = 0.0
        success_count = 0
        unmatched_count = 0

        # Query c2b_transactions
        c2b_docs = db.collection('c2b_transactions').order_by('created_at', direction=firestore.Query.DESCENDING).limit(60).get()
        for d in c2b_docs:
            item = d.to_dict()
            tx_id = item.get('trans_id') or d.id
            if tx_id in seen_tx_ids:
                continue
            seen_tx_ids.add(tx_id)

            amt = float(item.get('amount') or item.get('trans_amount') or 0.0)
            status = item.get('status', 'completed')
            if status in ['completed', 'reconciled']:
                total_volume += amt
                success_count += 1
            elif status == 'unmatched':
                unmatched_count += 1

            ts = item.get('created_at') or item.get('timestamp')
            ts_str = ts.isoformat() if hasattr(ts, 'isoformat') else str(ts or '')

            collections.append({
                'id': d.id,
                'trans_id': tx_id,
                'amount': amt,
                'trans_amount': amt,
                'msisdn': item.get('phone') or item.get('msisdn', ''),
                'phoneNumber': item.get('phone') or item.get('msisdn', ''),
                'bill_ref_number': item.get('bill_ref') or item.get('bill_ref_number', 'WALLET-TOPUP'),
                'accountReference': item.get('bill_ref') or item.get('bill_ref_number', 'WALLET-TOPUP'),
                'first_name': item.get('customer_name', '').split()[0] if item.get('customer_name') else item.get('first_name', ''),
                'last_name': " ".join(item.get('customer_name', '').split()[1:]) if item.get('customer_name') else item.get('last_name', ''),
                'status': status,
                'reconciled': item.get('reconciled', status != 'unmatched'),
                'matched_user_name': item.get('matched_user_name', ''),
                'matched_user_id': item.get('matched_user_id', ''),
                'trans_time': ts_str,
                'timestamp': ts_str,
                'source': 'Safaricom C2B Webhook'
            })

        # Supplementary mpesa_transactions
        mpesa_docs = db.collection('mpesa_transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(30).get()
        for d in mpesa_docs:
            item = d.to_dict()
            tx_id = item.get('receipt') or item.get('MpesaReceiptNumber') or d.id
            if tx_id in seen_tx_ids:
                continue
            seen_tx_ids.add(tx_id)

            amt = float(item.get('amount') or item.get('Amount') or 0.0)
            status = item.get('status', 'completed')
            if status == 'completed':
                total_volume += amt
                success_count += 1

            ts = item.get('timestamp')
            ts_str = ts.isoformat() if hasattr(ts, 'isoformat') else str(ts or '')
            u_name = item.get('user_name', '')

            collections.append({
                'id': d.id,
                'trans_id': tx_id,
                'amount': amt,
                'trans_amount': amt,
                'msisdn': item.get('phone', ''),
                'phoneNumber': item.get('phone', ''),
                'bill_ref_number': item.get('destination', 'WALLET-TOPUP'),
                'accountReference': item.get('destination', 'WALLET-TOPUP'),
                'first_name': u_name.split()[0] if u_name else '',
                'last_name': " ".join(u_name.split()[1:]) if u_name else '',
                'status': status,
                'reconciled': True,
                'matched_user_name': u_name,
                'matched_user_id': item.get('user_id', ''),
                'trans_time': ts_str,
                'timestamp': ts_str,
                'source': 'M-PESA Direct'
            })

        collections.sort(key=lambda x: x.get('timestamp', ''), reverse=True)

        return jsonify({
            'paybill_number': os.getenv('MPESA_SHORTCODE', '4050545'),
            'total_collected': total_volume,
            'total_volume': total_volume,
            'total_transactions': len(collections),
            'unmatched_count': unmatched_count,
            'success_rate': f"{(success_count / max(1, len(collections))) * 100:.1f}%",
            'recent_collections': collections[:60]
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ─────────────────────────────────────────────────────────────────────────────
# 4. C2B Live Test Simulation Endpoint (For Admin Verification)
# ─────────────────────────────────────────────────────────────────────────────
@c2b_v4_bp.route('/simulate', methods=['POST'])
def c2b_simulate():
    """
    Simulates an inbound C2B Paybill payment for testing and verification.
    Executes the exact confirmation and wallet crediting flow.
    """
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.json or {}
    phone = data.get('phone', '254712345678').strip()
    amount = float(data.get('amount', 100.0))
    bill_ref = data.get('bill_ref', 'WALLET-TOPUP').strip()
    customer_name = data.get('customer_name', 'Test Student').strip()
    trans_id = f"TI{uuid.uuid4().hex[:8].upper()}"

    sim_payload = {
        'TransType': 'Pay Bill',
        'TransID': trans_id,
        'TransTime': datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%S"),
        'TransAmount': amount,
        'BusinessShortCode': os.getenv('MPESA_SHORTCODE', '4050545'),
        'BillRefNumber': bill_ref,
        'MSISDN': phone,
        'FirstName': customer_name.split()[0] if customer_name else 'Test',
        'LastName': " ".join(customer_name.split()[1:]) if customer_name else 'Comrade'
    }

    # Execute confirmation flow directly
    db = firestore.client()
    matched_uid, user_data = find_user_by_reference(db, bill_ref, phone)

    batch = db.batch()
    if matched_uid and user_data:
        current_bal = float(user_data.get('walletBalance') or user_data.get('wallet_balance') or 0.0)
        new_bal = current_bal + amount
        matched_user_name = user_data.get('displayName') or user_data.get('name') or customer_name

        user_ref = db.collection('users').document(matched_uid)
        batch.update(user_ref, {
            'walletBalance': new_bal,
            'wallet_balance': new_bal,
            'lastTopupAmount': amount,
            'lastTopupReceipt': trans_id,
            'lastTopupAt': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP
        })

        tx_ref = db.collection('transactions').document()
        batch.set(tx_ref, {
            'type': 'c2b_paybill_topup',
            'amount': amount,
            'receipt': trans_id,
            'status': 'completed',
            'user_id': matched_uid,
            'user_name': matched_user_name,
            'phone': phone,
            'bill_ref': bill_ref,
            'description': f"[SIMULATED] M-PESA C2B Paybill Top-up (Ref: {trans_id})",
            'source': 'Simulation Test',
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        c2b_ref = db.collection('c2b_transactions').document(trans_id)
        batch.set(c2b_ref, {
            'trans_id': trans_id,
            'amount': amount,
            'trans_amount': amount,
            'phone': phone,
            'bill_ref': bill_ref,
            'bill_ref_number': bill_ref,
            'customer_name': customer_name,
            'status': 'completed',
            'reconciled': True,
            'matched_user_id': matched_uid,
            'matched_user_name': matched_user_name,
            'is_simulation': True,
            'created_at': firestore.SERVER_TIMESTAMP
        })

        batch.commit()
        return jsonify({
            'status': 'success',
            'matched': True,
            'trans_id': trans_id,
            'matched_user': matched_user_name,
            'user_id': matched_uid,
            'credited_amount': amount,
            'new_balance': new_bal,
            'message': f"Simulated KES {amount:.2f} deposit matched to {matched_user_name}. Wallet credited successfully!"
        }), 200

    else:
        c2b_ref = db.collection('c2b_transactions').document(trans_id)
        batch.set(c2b_ref, {
            'trans_id': trans_id,
            'amount': amount,
            'trans_amount': amount,
            'phone': phone,
            'bill_ref': bill_ref,
            'bill_ref_number': bill_ref,
            'customer_name': customer_name,
            'status': 'unmatched',
            'reconciled': False,
            'is_simulation': True,
            'created_at': firestore.SERVER_TIMESTAMP
        })
        batch.commit()

        return jsonify({
            'status': 'success',
            'matched': False,
            'trans_id': trans_id,
            'message': f"Simulated KES {amount:.2f} deposit received, but no user matched reference '{bill_ref}' or phone '{phone}'. Logged as unmatched for manual admin reconciliation."
        }), 200


# ─────────────────────────────────────────────────────────────────────────────
# 5. Manual Reconciliation Endpoint (Match Unlinked C2B Deposit to a User)
# ─────────────────────────────────────────────────────────────────────────────
@c2b_v4_bp.route('/reconcile', methods=['POST'])
def c2b_reconcile():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.json or {}
    trans_id = data.get('trans_id', '').strip()
    target_user_id = data.get('user_id', '').strip()

    if not trans_id or not target_user_id:
        return jsonify({"error": "trans_id and user_id are required"}), 400

    db = firestore.client()
    c2b_doc = db.collection('c2b_transactions').document(trans_id).get()
    if not c2b_doc.exists:
        return jsonify({"error": "Transaction not found"}), 404

    c2b_data = c2b_doc.to_dict()
    if c2b_data.get('reconciled') is True:
        return jsonify({"error": "Transaction has already been reconciled"}), 400

    user_doc = db.collection('users').document(target_user_id).get()
    if not user_doc.exists:
        return jsonify({"error": "Target user not found"}), 404

    u_data = user_doc.to_dict()
    amount = float(c2b_data.get('amount') or c2b_data.get('trans_amount') or 0.0)
    current_bal = float(u_data.get('walletBalance') or u_data.get('wallet_balance') or 0.0)
    new_bal = current_bal + amount
    target_name = u_data.get('displayName') or u_data.get('name') or 'User'

    batch = db.batch()
    # 1. Update User Balance
    user_ref = db.collection('users').document(target_user_id)
    batch.update(user_ref, {
        'walletBalance': new_bal,
        'wallet_balance': new_bal,
        'lastTopupAmount': amount,
        'lastTopupReceipt': trans_id,
        'lastTopupAt': firestore.SERVER_TIMESTAMP
    })

    # 2. Update C2B Record
    c2b_ref = db.collection('c2b_transactions').document(trans_id)
    batch.update(c2b_ref, {
        'status': 'reconciled',
        'reconciled': True,
        'matched_user_id': target_user_id,
        'matched_user_name': target_name,
        'reconciled_by': admin_id,
        'reconciled_at': firestore.SERVER_TIMESTAMP
    })

    # 3. Create ledger transaction
    tx_ref = db.collection('transactions').document()
    batch.set(tx_ref, {
        'type': 'c2b_paybill_topup',
        'amount': amount,
        'receipt': trans_id,
        'status': 'completed',
        'user_id': target_user_id,
        'user_name': target_name,
        'description': f"Manual Reconciliation: C2B Paybill Ref {trans_id}",
        'source': 'Admin Manual Reconcile',
        'timestamp': firestore.SERVER_TIMESTAMP
    })

    batch.commit()
    _notify_user_deposit(db, target_user_id, amount, trans_id, new_bal)

    return jsonify({
        "status": "success",
        "message": f"Successfully linked {trans_id} (KES {amount:,.2f}) to {target_name}. New Balance: KES {new_bal:,.2f}",
        "new_balance": new_bal
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# 6. Safaricom C2B URL Registration Endpoint
# ─────────────────────────────────────────────────────────────────────────────
@c2b_v4_bp.route('/register_url', methods=['POST'])
def c2b_register_url():
    """
    Registers C2B validation and confirmation URLs with Safaricom Daraja API.
    """
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        from routes.mpesa_routes import get_mpesa_access_token
        token = get_mpesa_access_token()
        if not token:
            return jsonify({"error": "Failed to generate M-PESA access token"}), 500

        env = os.getenv('MPESA_ENV', 'production').lower()
        base_url = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"
        api_url = f"{base_url}/mpesa/c2b/v1/registerurl"
        shortcode = os.getenv('MPESA_SHORTCODE', '4050545')

        payload = {
            "ShortCode": shortcode,
            "ResponseType": "Completed",
            "ConfirmationURL": "https://dishi.delstarfordworks.co.ke/api/v4/c2b/confirmation",
            "ValidationURL": "https://dishi.delstarfordworks.co.ke/api/v4/c2b/validation"
        }

        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }

        # Rule: All external HTTP calls to Daraja must have timeout=15
        resp = requests.post(api_url, json=payload, headers=headers, timeout=15)
        resp_data = resp.json() if resp.text else {}

        return jsonify({
            "status": "success" if resp.status_code == 200 else "error",
            "daraja_status": resp.status_code,
            "response": resp_data,
            "registered_urls": payload
        }), resp.status_code

    except Exception as e:
        return jsonify({"error": str(e)}), 500
