from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import traceback

subscription_bp = Blueprint('subscription', __name__)

@subscription_bp.route('/purchase', methods=['POST'])
def purchase_subscription():
    """
    Allow parents to buy Meal Plan subscriptions from their Vault.
    Expected JSON:
    {
        "parentUid": "string",
        "studentUid": "string",
        "planId": "gold_lunch",
        "amount": 5000.0,
        "durationDays": 30
    }
    """
    data = request.json
    parent_uid = data.get('parentUid')
    student_uid = data.get('studentUid')
    plan_id = data.get('planId')
    amount = float(data.get('amount', 0))
    duration_days = int(data.get('durationDays', 30))

    if not all([parent_uid, student_uid, plan_id, amount > 0]):
        return jsonify({"error": "Missing required parameters"}), 400

    try:
        db = firestore.client()
        parent_ref = db.collection('users').document(parent_uid)
        
        @firestore.transactional
        def process_purchase(transaction):
            p_doc = parent_ref.get(transaction=transaction)
            if not p_doc.exists:
                return False, "Parent not found"
                
            vault_balance = float(p_doc.to_dict().get('vaultBalance', 0.0))
            if vault_balance < amount:
                return False, "Insufficient funds in Vault"
                
            # Deduct from parent
            transaction.update(parent_ref, {'vaultBalance': firestore.Increment(-amount)})
            
            # Create subscription record on student
            expires_at = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=duration_days)
            sub_ref = db.collection('users').document(student_uid).collection('subscriptions').document(plan_id)
            
            transaction.set(sub_ref, {
                'planId': plan_id,
                'status': 'active',
                'purchasedAt': firestore.SERVER_TIMESTAMP,
                'expiresAt': expires_at,
                'amountPaid': amount
            })
            
            # Log purchase
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'parentUid': parent_uid,
                'studentId': student_uid,
                'amount': amount,
                'type': 'subscription_purchase',
                'planId': plan_id,
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return True, "Subscription purchased successfully."

        transaction = db.transaction()
        success, msg = process_purchase(transaction)
        
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400
            
    except Exception as e:
        return jsonify({"error": "Server error", "details": str(e), "trace": traceback.format_exc()}), 500
