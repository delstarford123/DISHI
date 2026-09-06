from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import random

match_core_bp = Blueprint('match_core', __name__)

@match_core_bp.route('/radar', methods=['GET'])
def get_nearby_radar():
    """ 
    Crush Radar: Returns active students near a given geo-coordinate.
    In production, this requires Geohashing. For now, it mocks proximity.
    """
    uid = request.args.get('uid')
    lat = request.args.get('lat')
    lng = request.args.get('lng')

    if not uid:
        return jsonify({"error": "Missing uid"}), 400

    try:
        db = firestore.client()
        # Mock finding 3-5 random active profiles
        docs = db.collection('match_profiles').limit(10).stream()
        radar_hits = []
        for doc in docs:
            if doc.id != uid:
                data = doc.to_dict()
                radar_hits.append({
                    "uid": doc.id,
                    "distanceMeters": random.randint(10, 150),
                    "isVerified": data.get('isVerified', False),
                    "vibeTags": data.get('vibeTags', []),
                    "name": f"Student {doc.id[:3].upper()}"
                })
        
        return jsonify({"status": "success", "radarHits": radar_hits}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_core_bp.route('/speed_dating/join', methods=['POST'])
def join_speed_dating():
    """ 
    Places user into the Friday Night Roulette queue.
    """
    data = request.json
    uid = data.get('uid')

    if not uid:
        return jsonify({"error": "Missing uid"}), 400

    try:
        db = firestore.client()
        queue_ref = db.collection('speed_dating_queue').document(uid)
        queue_ref.set({
            'joinedAt': firestore.SERVER_TIMESTAMP,
            'status': 'waiting'
        })
        return jsonify({"status": "success", "message": "Joined the Roulette Queue!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_core_bp.route('/secret_admirer/send', methods=['POST'])
def send_secret_admirer():
    """ 
    Sends an anonymous crush notification.
    """
    data = request.json
    sender_uid = data.get('senderUid')
    target_uid = data.get('targetUid')

    if not all([sender_uid, target_uid]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        admirer_ref = db.collection('match_profiles').document(target_uid).collection('secret_admirers').document(sender_uid)
        admirer_ref.set({
            'sentAt': firestore.SERVER_TIMESTAMP,
            'revealed': False
        })
        return jsonify({"status": "success", "message": "Secret admirer note sent anonymously."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
