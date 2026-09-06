from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import datetime
import uuid

vibe_bp = Blueprint('vibe_bp', __name__)
db = firestore.client()

@vibe_bp.route('/send', methods=['POST'])
def send_vibe():
    data = request.json
    sender_id = data.get('senderId')
    receiver_id = data.get('receiverId')
    is_super = data.get('isSuper', False)
    is_secret = data.get('isSecret', False)
    icebreaker = data.get('icebreaker', '')
    
    if not sender_id or not receiver_id:
        return jsonify({"error": "Missing sender or receiver ID"}), 400

    # Handle Super Vibe Wallet Deduction
    if is_super:
        user_ref = db.collection('users').document(sender_id)
        user_doc = user_ref.get()
        if not user_doc.exists:
            return jsonify({"error": "User not found"}), 404
            
        current_balance = user_doc.to_dict().get('walletBalance', 0)
        if current_balance < 10:
            return jsonify({"error": "Insufficient balance for Super Vibe (Requires Ksh 10)"}), 400
            
        user_ref.update({
            'walletBalance': firestore.Increment(-10)
        })

    # Create Vibe Document
    vibe_id = str(uuid.uuid4())
    expiration = datetime.datetime.utcnow() + datetime.timedelta(hours=24)
    
    sender_ref = db.collection('users').document(sender_id).get()
    sender_name = sender_ref.to_dict().get('displayName', sender_ref.to_dict().get('firstName', 'Anonymous'))
    sender_avatar = sender_ref.to_dict().get('profileImageUrl', '')

    vibe_doc = {
        'vibeId': vibe_id,
        'senderId': sender_id,
        'receiverId': receiver_id,
        'senderName': sender_name if not is_secret else 'Secret Admirer',
        'senderAvatar': sender_avatar if not is_secret else '',
        'isSuper': is_super,
        'isSecret': is_secret,
        'icebreaker': icebreaker,
        'status': 'pending',
        'createdAt': firestore.SERVER_TIMESTAMP,
        'expiresAt': expiration,
    }

    db.collection('vibes').document(vibe_id).set(vibe_doc)
    
    # Increment Vibe Streak/Score
    db.collection('users').document(sender_id).update({
        'vibeScore': firestore.Increment(1)
    })
    db.collection('users').document(receiver_id).update({
        'vibeScore': firestore.Increment(1)
    })

    return jsonify({"message": "Vibe sent successfully", "vibeId": vibe_id}), 200

@vibe_bp.route('/respond', methods=['POST'])
def respond_vibe():
    data = request.json
    vibe_id = data.get('vibeId')
    action = data.get('action') # 'accept' or 'reject'
    
    if not vibe_id or action not in ['accept', 'reject']:
        return jsonify({"error": "Invalid parameters"}), 400

    vibe_ref = db.collection('vibes').document(vibe_id)
    vibe_doc = vibe_ref.get()
    
    if not vibe_doc.exists:
        return jsonify({"error": "Vibe not found"}), 404
        
    vibe_data = vibe_doc.to_dict()
    
    if vibe_data.get('status') != 'pending':
        return jsonify({"error": "Vibe already processed"}), 400

    vibe_ref.update({
        'status': action,
        'respondedAt': firestore.SERVER_TIMESTAMP
    })
    
    if action == 'accept':
        # Create a Match!
        match_id = str(uuid.uuid4())
        db.collection('matches').document(match_id).set({
            'users': [vibe_data['senderId'], vibe_data['receiverId']],
            'createdAt': firestore.SERVER_TIMESTAMP,
            'source': 'vibe_check'
        })
        return jsonify({"message": "It's a Match!"}), 200

    return jsonify({"message": "Vibe rejected"}), 200
