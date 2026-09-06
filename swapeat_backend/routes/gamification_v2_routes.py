from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import traceback

gamification_v2_bp = Blueprint('gamification_v2', __name__)

@gamification_v2_bp.route('/chores/assign', methods=['POST'])
def assign_chore():
    """ Parent assigns a chore to a student """
    data = request.json
    parent_uid = data.get('parentUid')
    student_uid = data.get('studentUid')
    title = data.get('title')
    reward = float(data.get('reward', 0))

    if not all([parent_uid, student_uid, title, reward > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        chore_ref = db.collection('users').document(student_uid).collection('chores').document()
        chore_ref.set({
            'parentUid': parent_uid,
            'title': title,
            'reward': reward,
            'status': 'pending', # pending -> completed -> approved
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Chore assigned."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@gamification_v2_bp.route('/chores/approve', methods=['POST'])
def approve_chore():
    """ Parent approves a completed chore and funds are released """
    data = request.json
    parent_uid = data.get('parentUid')
    student_uid = data.get('studentUid')
    chore_id = data.get('choreId')

    if not all([parent_uid, student_uid, chore_id]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        parent_ref = db.collection('users').document(parent_uid)
        student_ref = db.collection('users').document(student_uid)
        chore_ref = student_ref.collection('chores').document(chore_id)

        @firestore.transactional
        def process_approval(transaction):
            c_doc = chore_ref.get(transaction=transaction)
            if not c_doc.exists:
                return False, "Chore not found"
            
            c_data = c_doc.to_dict()
            if c_data.get('status') == 'approved':
                return False, "Chore already approved"

            reward = float(c_data.get('reward', 0))
            
            p_doc = parent_ref.get(transaction=transaction)
            if float(p_doc.to_dict().get('vaultBalance', 0.0)) < reward:
                return False, "Insufficient funds in Parent Vault"

            transaction.update(parent_ref, {'vaultBalance': firestore.Increment(-reward)})
            transaction.update(student_ref, {'walletBalance': firestore.Increment(reward)})
            transaction.update(chore_ref, {'status': 'approved', 'approvedAt': firestore.SERVER_TIMESTAMP})
            
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'studentId': student_uid,
                'parentUid': parent_uid,
                'amount': reward,
                'type': 'chore_reward',
                'choreId': chore_id,
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return True, "Chore approved and reward sent."

        transaction = db.transaction()
        success, msg = process_approval(transaction)
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@gamification_v2_bp.route('/savings/create', methods=['POST'])
def create_saving_goal():
    """ Child sets a savings goal """
    data = request.json
    student_uid = data.get('studentUid')
    title = data.get('title')
    target_amount = float(data.get('targetAmount', 0))

    if not all([student_uid, title, target_amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        goal_ref = db.collection('users').document(student_uid).collection('savings_goals').document()
        goal_ref.set({
            'title': title,
            'targetAmount': target_amount,
            'currentAmount': 0.0,
            'status': 'active',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Savings goal created."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@gamification_v2_bp.route('/savings/match', methods=['POST'])
def match_saving_goal():
    """ Parent contributes/matches to a child's saving goal """
    data = request.json
    parent_uid = data.get('parentUid')
    student_uid = data.get('studentUid')
    goal_id = data.get('goalId')
    match_amount = float(data.get('matchAmount', 0))

    if not all([parent_uid, student_uid, goal_id, match_amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        parent_ref = db.collection('users').document(parent_uid)
        goal_ref = db.collection('users').document(student_uid).collection('savings_goals').document(goal_id)
        student_ref = db.collection('users').document(student_uid)

        @firestore.transactional
        def process_match(transaction):
            p_doc = parent_ref.get(transaction=transaction)
            if float(p_doc.to_dict().get('vaultBalance', 0.0)) < match_amount:
                return False, "Insufficient funds"
                
            transaction.update(parent_ref, {'vaultBalance': firestore.Increment(-match_amount)})
            transaction.update(goal_ref, {'currentAmount': firestore.Increment(match_amount)})
            
            # Also increase student's global savings balance
            transaction.update(student_ref, {'savingsBalance': firestore.Increment(match_amount)})
            return True, "Savings matched successfully."

        transaction = db.transaction()
        success, msg = process_match(transaction)
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@gamification_v2_bp.route('/score/<student_uid>', methods=['GET'])
def get_smart_spender_score(student_uid):
    """ Simple algorithm returning score out of 100 based on healthy vs junk purchases """
    try:
        db = firestore.client()
        txs = db.collection('transactions').where('studentId', '==', student_uid).limit(100).stream()
        
        healthy_count = 0
        junk_count = 0
        
        for tx in txs:
            items = tx.to_dict().get('items', [])
            for item in items:
                cat = str(item.get('category', '')).lower()
                if cat in ['snacks', 'candy', 'soda', 'junk']:
                    junk_count += 1
                elif cat in ['meals', 'lunch', 'breakfast', 'healthy', 'fruit']:
                    healthy_count += 1
                    
        total = healthy_count + junk_count
        if total == 0:
            score = 80 # Default
        else:
            # Score formula: base 50 + (healthy ratio * 50)
            score = 50 + int((healthy_count / total) * 50)
            
        return jsonify({"status": "success", "score": score, "healthyPurchases": healthy_count, "junkPurchases": junk_count}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@gamification_v2_bp.route('/themes/buy', methods=['POST'])
def buy_theme():
    """ Parent unlocks a premium app theme for child """
    data = request.json
    parent_uid = data.get('parentUid')
    student_uid = data.get('studentUid')
    theme_id = data.get('themeId')
    price = float(data.get('price', 50)) # Example: Ksh 50 per theme
    
    if not all([parent_uid, student_uid, theme_id]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        parent_ref = db.collection('users').document(parent_uid)
        student_ref = db.collection('users').document(student_uid)
        
        @firestore.transactional
        def process_theme_purchase(transaction):
            p_doc = parent_ref.get(transaction=transaction)
            if float(p_doc.to_dict().get('vaultBalance', 0.0)) < price:
                return False, "Insufficient funds"
                
            transaction.update(parent_ref, {'vaultBalance': firestore.Increment(-price)})
            
            s_doc = student_ref.get(transaction=transaction)
            unlocked_themes = s_doc.to_dict().get('unlockedThemes', [])
            if theme_id not in unlocked_themes:
                unlocked_themes.append(theme_id)
                transaction.update(student_ref, {'unlockedThemes': unlocked_themes})
                
            return True, "Theme unlocked successfully!"

        transaction = db.transaction()
        success, msg = process_theme_purchase(transaction)
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
