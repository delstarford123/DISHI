from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import uuid

match_campus_bp = Blueprint('match_campus', __name__)

@match_campus_bp.route('/campus/safe_walk/start', methods=['POST'])
def start_safe_walk():
    """ 
    Initiates a live-tracking session. Coordinates are written to a temp subcollection.
    """
    data = request.json
    uid = data.get('uid')
    target_match_uid = data.get('targetMatchUid')

    if not all([uid, target_match_uid]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        session_id = str(uuid.uuid4())
        session_ref = db.collection('safe_walk_sessions').document(session_id)
        session_ref.set({
            'walkerUid': uid,
            'watcherUid': target_match_uid,
            'status': 'active',
            'startedAt': firestore.SERVER_TIMESTAMP,
            'lastLocation': None
        })
        return jsonify({"status": "success", "sessionId": session_id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_campus_bp.route('/campus/partner_venues', methods=['GET'])
def get_partner_venues():
    """ 
    Fetches live list of local campus vendors offering discounts for matched couples.
    """
    try:
        db = firestore.client()
        venues_ref = db.collection('partner_venues').where('isActive', '==', True).stream()
        venues_list = []
        for v in venues_ref:
            v_data = v.to_dict()
            v_data['id'] = v.id
            venues_list.append(v_data)
        
        # Fallback mock data if empty
        if not venues_list:
            venues_list = [
                {"id": "v1", "name": "Campus Cafe", "discount": "15% off Couples Meal", "distance": "200m"},
                {"id": "v2", "name": "Strathmore Sushi", "discount": "Free Dessert", "distance": "500m"}
            ]
            
        return jsonify({"status": "success", "venues": venues_list}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_campus_bp.route('/campus/study_buddy/toggle', methods=['POST'])
def toggle_study_buddy():
    """ 
    Switches the user's matching algorithm state to Academic.
    """
    data = request.json
    uid = data.get('uid')
    is_active = data.get('isActive')

    if not uid:
        return jsonify({"error": "Missing uid"}), 400

    try:
        db = firestore.client()
        profile_ref = db.collection('match_profiles').document(uid)
        profile_ref.set({
            'studyBuddyMode': is_active,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }, merge=True)
        return jsonify({"status": "success", "studyBuddyMode": is_active}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_campus_bp.route('/campus/event_wingman', methods=['POST'])
def link_wingman():
    """ 
    Groups two friends together to swipe on other pairs.
    """
    data = request.json
    uid_1 = data.get('uid1')
    uid_2 = data.get('uid2')

    if not all([uid_1, uid_2]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        group_id = f"wingman_{uid_1}_{uid_2}"
        group_ref = db.collection('wingman_groups').document(group_id)
        group_ref.set({
            'members': [uid_1, uid_2],
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "groupId": group_id, "message": "Wingman linked!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
