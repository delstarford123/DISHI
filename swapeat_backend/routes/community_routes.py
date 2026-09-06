from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import traceback

community_bp = Blueprint('community', __name__)

@community_bp.route('/vault/upload', methods=['POST'])
def upload_document():
    """ 
    Save document metadata to Firestore. 
    Actual file upload is handled by client to Firebase Storage, then client passes URL here.
    """
    data = request.json
    parent_uid = data.get('parentUid')
    title = data.get('title')
    doc_url = data.get('docUrl')
    doc_type = data.get('docType', 'other') # e.g., 'id', 'permission_slip'

    if not all([parent_uid, title, doc_url]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        doc_ref = db.collection('users').document(parent_uid).collection('document_vault').document()
        doc_ref.set({
            'title': title,
            'docUrl': doc_url,
            'docType': doc_type,
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Document saved to vault."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@community_bp.route('/calendar/events', methods=['GET', 'POST'])
def calendar_events():
    """ GET retrieves upcoming events. POST adds a family event. """
    try:
        db = firestore.client()
        if request.method == 'GET':
            parent_uid = request.args.get('parentUid')
            if not parent_uid:
                return jsonify({"error": "Missing parentUid"}), 400
                
            # Fetch school events + family events
            now = datetime.datetime.now(datetime.timezone.utc)
            family_events = db.collection('users').document(parent_uid).collection('calendar_events').where('date', '>=', now).stream()
            school_events = db.collection('school_events').where('date', '>=', now).stream()
            
            events = []
            for e in family_events:
                d = e.to_dict()
                d['id'] = e.id
                d['type'] = 'family'
                events.append(d)
                
            for e in school_events:
                d = e.to_dict()
                d['id'] = e.id
                d['type'] = 'school'
                events.append(d)
                
            return jsonify({"status": "success", "events": events}), 200
            
        elif request.method == 'POST':
            data = request.json
            parent_uid = data.get('parentUid')
            title = data.get('title')
            date_str = data.get('date') # ISO format
            
            if not all([parent_uid, title, date_str]):
                return jsonify({"error": "Missing parameters"}), 400
                
            event_date = datetime.datetime.fromisoformat(date_str)
            db.collection('users').document(parent_uid).collection('calendar_events').add({
                'title': title,
                'date': event_date,
                'createdAt': firestore.SERVER_TIMESTAMP
            })
            return jsonify({"status": "success", "message": "Event added."}), 200
            
    except Exception as e:
        import traceback
        return jsonify({"error": str(e), "trace": traceback.format_exc()}), 500

@community_bp.route('/forum/post', methods=['POST'])
def create_forum_post():
    """ Create a post in the parent community forum """
    data = request.json
    parent_uid = data.get('parentUid')
    author_name = data.get('authorName', 'Anonymous Parent')
    content = data.get('content')
    topic = data.get('topic', 'general') # carpool, vendors, etc.

    if not all([parent_uid, content]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        db.collection('parent_forum').add({
            'parentUid': parent_uid,
            'authorName': author_name,
            'content': content,
            'topic': topic,
            'likes': 0,
            'replies': 0,
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Post created."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@community_bp.route('/p2p_transfer', methods=['POST'])
def p2p_parent_transfer():
    """ Atomic transfer from one Parent Vault to another """
    data = request.json
    sender_uid = data.get('senderUid')
    receiver_uid = data.get('receiverUid')
    amount = float(data.get('amount', 0))
    note = data.get('note', '')

    if not all([sender_uid, receiver_uid, amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        sender_ref = db.collection('users').document(sender_uid)
        receiver_ref = db.collection('users').document(receiver_uid)
        
        @firestore.transactional
        def process_p2p(transaction):
            s_doc = sender_ref.get(transaction=transaction)
            r_doc = receiver_ref.get(transaction=transaction)
            
            if not s_doc.exists or not r_doc.exists:
                return False, "User not found"
                
            s_balance = float(s_doc.to_dict().get('vaultBalance', 0.0))
            if s_balance < amount:
                return False, "Insufficient funds"
                
            transaction.update(sender_ref, {'vaultBalance': firestore.Increment(-amount)})
            transaction.update(receiver_ref, {'vaultBalance': firestore.Increment(amount)})
            
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'senderUid': sender_uid,
                'receiverUid': receiver_uid,
                'amount': amount,
                'type': 'p2p_parent_transfer',
                'note': note,
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return True, "Transfer successful."

        transaction = db.transaction()
        success, msg = process_p2p(transaction)
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
