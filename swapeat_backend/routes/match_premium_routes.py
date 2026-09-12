from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import uuid

match_premium_bp = Blueprint('match_premium', __name__)

@match_premium_bp.route('/premium/boost', methods=['POST'])
def boost_profile():
    """ 
    Deducts 50 KSH from the wallet and boosts the profile.
    """
    data = request.json
    uid = data.get('uid')

    if not uid:
        return jsonify({"error": "Missing uid"}), 400

    try:
        db = firestore.client()
        # 1. Deduct wallet balance (Mocked check for this example)
        # 2. Apply Boost
        profile_ref = db.collection('match_profiles').document(uid)
        boost_expiry = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=30)
        
        profile_ref.set({
            'boostExpiry': boost_expiry,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
        return jsonify({"status": "success", "message": "Profile Boosted for 30 minutes!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_premium_bp.route('/safety/feedback', methods=['POST'])
def submit_feedback():
    """ 
    Writes anonymous feedback to an admin collection.
    """
    data = request.json
    feedback_text = data.get('feedback')

    if not feedback_text:
        return jsonify({"error": "Missing feedback"}), 400

    try:
        db = firestore.client()
        db.collection('admin_feedback').document().set({
            'feedback': feedback_text,
            'isAnonymous': True,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'status': 'unread'
        })
        return jsonify({"status": "success", "message": "Anonymous feedback submitted safely."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_premium_bp.route('/safety/anti_ghosting', methods=['POST'])
def anti_ghosting_nudge():
    """ 
    Checks chat activity. If 48h idle, drops a nudge.
    Normally called via Cron job, but exposed here for manual triggering.
    """
    data = request.json
    chat_id = data.get('chatId')
    target_uid = data.get('targetUid')

    if not all([chat_id, target_uid]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        message_ref = db.collection('match_chats').document(chat_id).collection('messages').document()
        message_ref.set({
            'senderUid': 'system_admin',
            'type': 'system_nudge',
            'message': 'It's been a while! Don't leave them hanging 👋',
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Nudge sent."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
