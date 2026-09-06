from flask import Blueprint, jsonify, request
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import firestore

gamification_bp = Blueprint('gamification', __name__)

@gamification_bp.route('/<student_id>/update_streak', methods=['POST'])
def update_streak(student_id):
    """
    Updates the student's daily login streak.
    If lastActiveDate is yesterday, increment streak.
    If lastActiveDate is older, reset streak to 1.
    If lastActiveDate is today, do nothing.
    """
    db = firestore.client()
    user_ref = db.collection('users').doc(student_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        return jsonify({"error": "User not found"}), 404

    data = user_doc.to_dict()
    login_streak = data.get('loginStreak', 0)
    last_login_date = data.get('lastLoginDate')

    today_str = datetime.utcnow().strftime('%Y-%m-%d')
    yesterday_str = (datetime.utcnow() - timedelta(days=1)).strftime('%Y-%m-%d')

    if last_login_date == today_str:
        # Already logged in today
        pass
    elif last_login_date == yesterday_str:
        # Logged in yesterday, increment streak
        login_streak += 1
    else:
        # Missed a day or first time, reset to 1
        login_streak = 1

    user_ref.update({
        'loginStreak': login_streak,
        'lastLoginDate': today_str
    })

    return jsonify({
        "status": "success",
        "loginStreak": login_streak,
        "message": f"Login streak updated to {login_streak}"
    }), 200

@gamification_bp.route('/<student_id>/evaluate_badges', methods=['POST'])
def evaluate_badges(student_id):
    """
    Evaluates and assigns badges based on transaction volume.
    Called periodically or after significant actions.
    """
    db = firestore.client()
    
    # Calculate total spent
    txs = db.collection('transactions').where('studentId', '==', student_id).where('status', '==', 'completed').get()
    
    total_spent = sum([abs(tx.to_dict().get('amount', 0)) for tx in txs])
    
    user_ref = db.collection('users').doc(student_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        return jsonify({"error": "User not found"}), 404

    current_badges = user_doc.to_dict().get('badges', [])
    new_badges = list(current_badges)

    if total_spent >= 1000 and "Big Spender" not in new_badges:
        new_badges.append("Big Spender")
    
    if len(txs) >= 10 and "Loyalist" not in new_badges:
        new_badges.append("Loyalist")

    if new_badges != current_badges:
        user_ref.update({'badges': new_badges})

    return jsonify({
        "status": "success",
        "badges": new_badges,
        "total_spent": total_spent
    }), 200
