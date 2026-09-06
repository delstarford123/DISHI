from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import traceback

allowance_bp = Blueprint('allowance', __name__)

@allowance_bp.route('/schedule', methods=['POST'])
def create_schedule():
    """
    Allow parents to create/edit recurring allowance schedules.
    Expected JSON:
    {
        "parentUid": "string",
        "studentUid": "string",
        "amount": number,
        "frequency": "weekly" | "monthly" | "daily",
        "nextRun": "YYYY-MM-DD"
    }
    """
    data = request.json
    parent_uid = data.get('parentUid')
    student_uid = data.get('studentUid')
    amount = data.get('amount')
    frequency = data.get('frequency', 'weekly')
    next_run = data.get('nextRun')

    if not all([parent_uid, student_uid, amount, next_run]):
        return jsonify({"error": "Missing required parameters"}), 400

    try:
        db = firestore.client()
        # Store in allowance_schedules subcollection under parent
        schedule_ref = db.collection('users').document(parent_uid).collection('allowance_schedules').document(student_uid)
        
        schedule_ref.set({
            "studentUid": student_uid,
            "amount": float(amount),
            "frequency": frequency,
            "nextRun": next_run, # Storing as string YYYY-MM-DD for simplicity
            "status": "active",
            "createdAt": firestore.SERVER_TIMESTAMP
        }, merge=True)
        
        return jsonify({"status": "success", "message": "Allowance schedule saved."}), 200
    except Exception as e:
        return jsonify({"error": "A server error occurred.", "details": str(e), "trace": traceback.format_exc()}), 500


@allowance_bp.route('/cron/process_allowances', methods=['POST'])
def process_allowances():
    """
    Secured route triggered daily by a cron job to move funds from vaultBalance to walletBalance.
    """
    # Simple security check (could use a secret header in production)
    cron_secret = request.headers.get('X-Cron-Secret')
    if cron_secret != "super-secret-cron-key":
        return jsonify({"error": "Unauthorized"}), 401
        
    try:
        db = firestore.client()
        today_str = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
        
        # We need to query all active schedules across all parents.
        # Use a collection group query for 'allowance_schedules'
        schedules = db.collection_group('allowance_schedules').where('status', '==', 'active').where('nextRun', '==', today_str).stream()
        
        processed_count = 0
        
        for sched in schedules:
            data = sched.to_dict()
            parent_ref = sched.reference.parent.parent
            student_uid = data.get('studentUid')
            amount = float(data.get('amount', 0))
            frequency = data.get('frequency', 'weekly')
            
            # Atomic transaction to move funds
            @firestore.transactional
            def process_transfer(transaction, p_ref, s_uid, amt):
                p_doc = p_ref.get(transaction=transaction)
                if not p_doc.exists:
                    return False
                    
                vault_balance = float(p_doc.to_dict().get('vaultBalance', 0.0))
                if vault_balance < amt:
                    return False # Insufficient parent funds
                    
                s_ref = db.collection('users').document(s_uid)
                
                transaction.update(p_ref, {'vaultBalance': firestore.Increment(-amt)})
                transaction.update(s_ref, {'walletBalance': firestore.Increment(amt)})
                
                # Log the transfer
                tx_ref = db.collection('transactions').document()
                transaction.set(tx_ref, {
                    'studentId': s_uid,
                    'amount': amt,
                    'type': 'digital_allowance',
                    'timestamp': firestore.SERVER_TIMESTAMP
                })
                return True
                
            transaction = db.transaction()
            success = process_transfer(transaction, parent_ref, student_uid, amount)
            
            if success:
                # Update nextRun date
                next_date = datetime.datetime.strptime(today_str, '%Y-%m-%d')
                if frequency == 'weekly':
                    next_date += datetime.timedelta(days=7)
                elif frequency == 'monthly':
                    next_date += datetime.timedelta(days=30)
                else: # daily
                    next_date += datetime.timedelta(days=1)
                    
                sched.reference.update({
                    'nextRun': next_date.strftime('%Y-%m-%d'),
                    'lastProcessed': firestore.SERVER_TIMESTAMP
                })
                processed_count += 1
                
        return jsonify({"status": "success", "processed": processed_count}), 200
    except Exception as e:
        return jsonify({"error": "A server error occurred.", "details": str(e), "trace": traceback.format_exc()}), 500
