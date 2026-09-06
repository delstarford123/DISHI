from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import os

admin_bp = Blueprint('admin', __name__)

def verify_admin(req):
    auth = req.headers.get('Authorization', '')
    admin_token = os.getenv('ADMIN_SECRET', 'swapeat-admin-2024')
    return auth == f"Bearer {admin_token}"

@admin_bp.route('/deliv/drivers', methods=['GET'])
def get_all_drivers():
    try:
        db = firestore.client()
        docs = db.collection('deliv_drivers').order_by('created_at', direction=firestore.Query.DESCENDING).get()
        drivers = [doc.to_dict() for doc in docs]
        # Serialize datetime
        for d in drivers:
            if 'created_at' in d and hasattr(d['created_at'], 'isoformat'):
                d['created_at'] = d['created_at'].isoformat()
            else:
                d['created_at'] = str(d.get('created_at'))
        return jsonify({"status": "success", "drivers": drivers}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/match/reports', methods=['GET'])
def get_match_reports():
    try:
        db = firestore.client()
        docs = db.collection('match_incident_reports').order_by('timestamp', direction=firestore.Query.DESCENDING).get()
        reports = [doc.to_dict() for doc in docs]
        for r in reports:
            if 'timestamp' in r and hasattr(r['timestamp'], 'isoformat'):
                r['timestamp'] = r['timestamp'].isoformat()
            else:
                r['timestamp'] = str(r.get('timestamp'))
        return jsonify({"status": "success", "reports": reports}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/match/unban', methods=['POST'])
def unban_match_user():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
    data = request.json or {}
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({"error": "Missing user_id"}), 400
        
    try:
        db = firestore.client()
        db.collection('match_profiles').document(user_id).update({'is_active': True})
        return jsonify({"status": "success", "message": "User unbanned"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/payout', methods=['POST'])
def process_payout():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
        
    data = request.json or {}
    vendor_id = data.get('vendorId')
    amount = data.get('amount')
    
    if not vendor_id or amount is None:
        return jsonify({"error": "Missing vendorId or amount"}), 400
        
    try:
        db = firestore.client()
        vendor_ref = db.collection('users').document(vendor_id)
        
        @firestore.transactional
        def update_in_transaction(transaction, v_ref):
            snapshot = v_ref.get(transaction=transaction)
            if not snapshot.exists:
                raise Exception("Vendor not found")
                
            current_earnings = snapshot.get('vendorEarnings') or 0
            if current_earnings < amount:
                raise Exception("Insufficient vendor earnings")
                
            transaction.update(v_ref, {
                'vendorEarnings': current_earnings - amount
            })
            
            # Log transaction
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'vendorId': vendor_id,
                'amount': -amount,
                'type': 'Admin Payout',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'completed',
                'destination': 'mpesa_b2c' # Tagged for potential Daraja B2C integration
            })

        transaction = db.transaction()
        update_in_transaction(transaction, vendor_ref)
        
        # NOTE: Real M-PESA B2C API call would go here using Daraja credentials.
        
        return jsonify({"status": "success", "message": "Payout processed successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/refund', methods=['POST'])
def process_refund():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
        
    data = request.json or {}
    tx_id = data.get('txId')
    
    if not tx_id:
        return jsonify({"error": "Missing txId"}), 400
        
    try:
        db = firestore.client()
        tx_ref = db.collection('transactions').document(tx_id)
        
        @firestore.transactional
        def refund_in_transaction(transaction, t_ref):
            snapshot = t_ref.get(transaction=transaction)
            if not snapshot.exists:
                raise Exception("Transaction not found")
                
            tx_data = snapshot.to_dict()
            if tx_data.get('status') == 'refunded':
                raise Exception("Transaction is already refunded")
                
            amount = tx_data.get('amount', 0)
            user_id = tx_data.get('user_id') or tx_data.get('studentId') or tx_data.get('uid')
            vendor_id = tx_data.get('vendor_id') or tx_data.get('vendorId')
            
            if not user_id or not vendor_id:
                raise Exception("Transaction missing user or vendor identifiers")
                
            student_ref = db.collection('users').document(user_id)
            vendor_ref = db.collection('users').document(vendor_id)
            
            # Reversing the flow: Add to student, deduct from vendor
            transaction.update(student_ref, {'walletBalance': firestore.Increment(amount)})
            transaction.update(vendor_ref, {'walletBalance': firestore.Increment(-amount)})
            
            # Mark original as refunded
            transaction.update(t_ref, {'status': 'refunded'})
            
            # Log the refund action
            refund_tx_ref = db.collection('transactions').document()
            transaction.set(refund_tx_ref, {
                'originalTxId': tx_id,
                'user_id': user_id,
                'vendorId': vendor_id,
                'amount': amount,
                'type': 'Refund',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'completed'
            })
            
        transaction = db.transaction()
        refund_in_transaction(transaction, tx_ref)
        
        return jsonify({"status": "success", "message": f"Transaction {tx_id} refunded"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/adjust_wallet', methods=['POST'])
def adjust_wallet():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
        
    data = request.json or {}
    user_id = data.get('userId')
    amount = data.get('amount')
    
    if not user_id or amount is None:
        return jsonify({"error": "Missing userId or amount"}), 400
        
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        
        @firestore.transactional
        def adjust_in_transaction(transaction, u_ref):
            snapshot = u_ref.get(transaction=transaction)
            if not snapshot.exists:
                raise Exception("User not found")
                
            transaction.update(u_ref, {'walletBalance': firestore.Increment(amount)})
            
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'user_id': user_id,
                'amount': amount,
                'type': 'Admin Adjustment',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'completed',
                'destination': 'wallet'
            })
            
        transaction = db.transaction()
        adjust_in_transaction(transaction, user_ref)
        
        return jsonify({"status": "success", "message": f"Wallet adjusted by {amount}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/link_nfc', methods=['POST'])
def link_nfc():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
        
    data = request.json or {}
    user_id = data.get('userId')
    nfc_uid = data.get('nfcUid')
    
    if not user_id or not nfc_uid:
        return jsonify({"error": "Missing userId or nfcUid"}), 400
        
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        user_ref.set({'nfcUid': nfc_uid}, merge=True)
        return jsonify({"status": "success", "message": "NFC Linked successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
