from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import uuid

match_interactive_bp = Blueprint('match_interactive', __name__)

@match_interactive_bp.route('/voice_prompt/upload', methods=['POST'])
def upload_voice_prompt():
    """ 
    Links an uploaded audio clip to the user's MatchProfileModel.
    In a real app, the audio file would be sent to Firebase Storage and the URL saved.
    """
    data = request.json
    uid = data.get('uid')
    audio_url = data.get('audioUrl') # Mocked for now

    if not all([uid, audio_url]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        profile_ref = db.collection('match_profiles').document(uid)
        profile_ref.set({
            'voiceIntroUrl': audio_url,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }, merge=True)
        return jsonify({"status": "success", "message": "Voice prompt uploaded successfully!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_interactive_bp.route('/chat/icebreaker', methods=['POST'])
def send_icebreaker():
    """ 
    Injects an interactive game state (e.g., Two Truths and a Lie) into a chat.
    """
    data = request.json
    chat_id = data.get('chatId')
    sender_uid = data.get('senderUid')
    game_data = data.get('gameData') # Dictionary of the game content

    if not all([chat_id, sender_uid, game_data]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        message_ref = db.collection('match_chats').document(chat_id).collection('messages').document()
        message_ref.set({
            'senderUid': sender_uid,
            'type': 'icebreaker_game',
            'gameData': game_data,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Icebreaker sent!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_interactive_bp.route('/chat/whisper', methods=['POST'])
def send_whisper():
    """ 
    Sends a message with a 10-second TTL (Time To Live).
    """
    data = request.json
    chat_id = data.get('chatId')
    sender_uid = data.get('senderUid')
    message_text = data.get('message')

    if not all([chat_id, sender_uid, message_text]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        message_ref = db.collection('match_chats').document(chat_id).collection('messages').document()
        message_ref.set({
            'senderUid': sender_uid,
            'type': 'whisper',
            'message': message_text,
            'isRead': False,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Whisper sent."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_interactive_bp.route('/date/propose', methods=['POST'])
def propose_date():
    """ 
    Sends an official 'Dishi Date' request with a pre-order split via the Wallet.
    """
    data = request.json
    chat_id = data.get('chatId')
    sender_uid = data.get('senderUid')
    venue = data.get('venue')
    split_amount = data.get('splitAmount')

    if not all([chat_id, sender_uid, venue, split_amount]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        message_ref = db.collection('match_chats').document(chat_id).collection('messages').document()
        message_ref.set({
            'senderUid': sender_uid,
            'type': 'dishi_date_proposal',
            'venue': venue,
            'splitAmount': split_amount,
            'status': 'pending',
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Date proposed!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@match_interactive_bp.route('/gift/send', methods=['POST'])
def send_gift():
    """ 
    Sends funds to a match. If the gift is > 100 KSH, a 10 KSH commission is deducted from sender.
    """
    data = request.json
    sender_uid = data.get('senderUid')
    recipient_uid = data.get('recipientUid')
    amount = data.get('amount')
    chat_id = data.get('chatId')

    if not all([sender_uid, recipient_uid, amount]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        amount_float = float(amount)
        if amount_float <= 0:
            return jsonify({"error": "Invalid amount"}), 400
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid amount format"}), 400

    db = firestore.client()
    
    commission = 10.0 if amount_float > 100 else 0.0
    total_deduct = amount_float + commission

    transaction = db.transaction()
    sender_ref = db.collection('users').document(sender_uid)
    recipient_ref = db.collection('users').document(recipient_uid)
    
    @firestore.transactional
    def process_gift(transaction, sender_ref, recipient_ref):
        sender_doc = sender_ref.get(transaction=transaction)
        if not sender_doc.exists:
            return False, "Sender not found"
            
        current_balance = float(sender_doc.to_dict().get('walletBalance', 0.0))
        if current_balance < total_deduct:
            return False, f"Insufficient balance. You need {total_deduct} KSH (including any applicable commission) to send this gift."
            
        transaction.update(sender_ref, {'walletBalance': current_balance - total_deduct})
        transaction.set(recipient_ref, {'walletBalance': firestore.Increment(amount_float)}, merge=True)
        
        if commission > 0:
            admin_ref = db.collection('admin_finances').document('dishi_system_pool')
            transaction.set(admin_ref, {'system_commissions': firestore.Increment(commission)}, merge=True)
            
        return True, "Success"

    success, message = process_gift(transaction, sender_ref, recipient_ref)
    if not success:
        return jsonify({"error": message}), 400
        
    if chat_id:
        message_ref = db.collection('match_chats').document(chat_id).collection('messages').document()
        message_ref.set({
            'senderUid': sender_uid,
            'type': 'gift',
            'amount': amount_float,
            'timestamp': firestore.SERVER_TIMESTAMP
        })

    return jsonify({"status": "success", "message": f"Gift of KSh {amount_float} sent successfully!"}), 200
