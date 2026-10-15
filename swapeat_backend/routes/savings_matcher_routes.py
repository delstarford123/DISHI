from flask import Blueprint, request, jsonify
import firebase_admin
from firebase_admin import firestore
from datetime import datetime

savings_matcher_bp = Blueprint('savings_matcher_bp', __name__)

@savings_matcher_bp.route('/api/savings/deposit', methods=['POST'])
def deposit_savings():
    """
    Endpoint for a student to deposit money into a savings target.
    Expects JSON: { "studentUid": "uid", "targetId": "doc_id", "amount": 100 }
    """
    try:
        data = request.json
        student_uid = data.get('studentUid')
        target_id = data.get('targetId')
        amount = float(data.get('amount', 0))

        if not student_uid or not target_id or amount <= 0:
            return jsonify({'error': 'Invalid parameters. Need studentUid, targetId, and positive amount.'}), 400

        db = firestore.client()
        
        # 1. Verify student has enough walletBalance
        student_ref = db.collection('users').document(student_uid)
        student_doc = student_ref.get()
        if not student_doc.exists:
            return jsonify({'error': 'Student not found.'}), 404
        
        student_data = student_doc.to_dict()
        current_balance = student_data.get('walletBalance', 0.0)
        
        if current_balance < amount:
            return jsonify({'error': f'Insufficient wallet balance. You have {current_balance}.'}), 400

        # 2. Get Savings Target
        target_ref = db.collection('savings_targets').document(target_id)
        target_doc = target_ref.get()
        if not target_doc.exists:
            return jsonify({'error': 'Savings target not found.'}), 404
        
        target_data = target_doc.to_dict()
        if target_data.get('status') == 'Achieved':
            return jsonify({'error': 'Savings target already achieved.'}), 400
        if target_data.get('studentUid') != student_uid:
            return jsonify({'error': 'Not authorized for this target.'}), 403

        parent_uid = target_data.get('parentUid')
        match_percentage = float(target_data.get('matchPercentage', 0))
        target_amount = float(target_data.get('targetAmount', 0))
        current_saved = float(target_data.get('currentSaved', 0))

        # Perform the deposit transaction
        @firestore.transactional
        def process_deposit(transaction, student_ref, target_ref):
            s_doc = student_ref.get(transaction=transaction)
            t_doc = target_ref.get(transaction=transaction)
            
            new_wallet_balance = s_doc.get('walletBalance') - amount
            new_current_saved = t_doc.get('currentSaved') + amount
            
            status = 'Active'
            is_achieved = False
            match_amount = 0.0

            if new_current_saved >= target_amount:
                status = 'Achieved'
                is_achieved = True
                # Calculate the match amount
                match_amount = (target_amount * (match_percentage / 100.0))
            
            transaction.update(student_ref, {
                'walletBalance': new_wallet_balance
            })
            transaction.update(target_ref, {
                'currentSaved': new_current_saved,
                'status': status
            })
            
            return is_achieved, match_amount, parent_uid

        transaction = db.transaction()
        is_achieved, match_amount, parent_uid = process_deposit(transaction, student_ref, target_ref)

        response_data = {
            'message': 'Deposit successful.',
            'deposited': amount,
            'achieved': is_achieved
        }

        # 3. If achieved, trigger the Match from Parent to Student
        if is_achieved and match_amount > 0 and parent_uid:
            parent_ref = db.collection('users').document(parent_uid)
            parent_doc = parent_ref.get()
            if parent_doc.exists:
                p_data = parent_doc.to_dict()
                parent_balance = p_data.get('walletBalance', 0.0)
                
                # Check if parent has enough to fulfill match (or we can just grant it anyway, or deduct to negative, or send notification)
                # For this implementation, we will deduct from parent if they have enough, else just create a pending Match payout.
                if parent_balance >= match_amount:
                    @firestore.transactional
                    def process_match(trans, p_ref, s_ref):
                        p_snap = p_ref.get(transaction=trans)
                        s_snap = s_ref.get(transaction=trans)
                        
                        trans.update(p_ref, {'walletBalance': p_snap.get('walletBalance') - match_amount})
                        trans.update(s_ref, {'walletBalance': s_snap.get('walletBalance') + match_amount})
                    
                    match_trans = db.transaction()
                    process_match(match_trans, parent_ref, student_ref)
                    
                    # Record transaction
                    db.collection('transactions').add({
                        'senderUid': parent_uid,
                        'senderName': p_data.get('displayName', 'Parent'),
                        'receiverUid': student_uid,
                        'receiverName': student_data.get('displayName', 'Student'),
                        'amount': match_amount,
                        'type': 'savings_match',
                        'status': 'completed',
                        'timestamp': firestore.SERVER_TIMESTAMP,
                        'reference': f'MATCH_{target_id}'
                    })
                    response_data['match_applied'] = match_amount
                    response_data['match_status'] = 'paid'
                else:
                    # Notify parent they need to fund to complete the match
                    db.collection('notifications').add({
                        'userId': parent_uid,
                        'title': 'Savings Goal Achieved!',
                        'body': f'{student_data.get("displayName")} hit their savings goal! Top up your wallet to fulfill the Ksh {match_amount} match pledge.',
                        'type': 'savings_match_pending',
                        'read': False,
                        'createdAt': firestore.SERVER_TIMESTAMP
                    })
                    response_data['match_status'] = 'pending_parent_funds'
                    response_data['match_applied'] = 0.0

        return jsonify(response_data), 200

    except Exception as e:
        print(f"Error in savings deposit: {e}")
        return jsonify({'error': str(e)}), 500

@savings_matcher_bp.route('/api/savings/targets/<student_uid>', methods=['GET'])
def get_student_targets(student_uid):
    """ Get all active savings targets for a student """
    try:
        db = firestore.client()
        targets = db.collection('savings_targets').where('studentUid', '==', student_uid).where('status', '==', 'Active').get()
        
        result = []
        for t in targets:
            data = t.to_dict()
            data['id'] = t.id
            result.append(data)
            
        return jsonify({'targets': result}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
