import os

filepath = r"c:\Users\Delstaford\swapeat\swapeat_backend\routes\v2\match_routes.py"
with open(filepath, "a", encoding="utf-8") as f:
    f.write('''

# ── PHASE 9: SHOT IN THE DARK (BLIND CHAT ROULETTE) ──────────────────────────

@match_v2_bp.route('/blind_chat/queue', methods=['POST'])
def blind_chat_queue():
    data = request.json or {}
    user_id = data.get('user_id')
    user_gender = data.get('gender')
    
    if not user_id or not user_gender:
        return jsonify({"error": "user_id and gender are required"}), 400

    try:
        db = firestore.client()
        queue_ref = db.collection('blind_chat_queue')
        opposite_gender = 'female' if user_gender.lower() == 'male' else 'male'
        
        query = queue_ref.where('gender', '==', opposite_gender).where('status', '==', 'waiting').limit(1).get()
        
        if query:
            match_doc = query[0]
            matched_user_id = match_doc.to_dict().get('user_id')
            
            session_id = f"blind_{min(user_id, matched_user_id)}_{max(user_id, matched_user_id)}"
            db.collection('blind_chat_sessions').document(session_id).set({
                'users': [user_id, matched_user_id],
                'status': 'active',
                'created_at': firestore.SERVER_TIMESTAMP,
                'expires_at': datetime.utcnow() + __import__('datetime').timedelta(minutes=3),
                'reveals': []
            })
            
            match_doc.reference.update({'status': 'matched', 'session_id': session_id})
            return jsonify({"status": "success", "session_id": session_id}), 200
            
        else:
            queue_ref.document(user_id).set({
                'user_id': user_id,
                'gender': user_gender.lower(),
                'status': 'waiting',
                'joined_at': firestore.SERVER_TIMESTAMP
            })
            return jsonify({"status": "queued", "message": "Waiting for a match..."}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@match_v2_bp.route('/blind_chat/reveal', methods=['POST'])
def blind_chat_reveal():
    data = request.json or {}
    session_id = data.get('session_id')
    user_id = data.get('user_id')
    
    if not session_id or not user_id:
        return jsonify({"error": "session_id and user_id are required"}), 400
        
    try:
        db = firestore.client()
        session_ref = db.collection('blind_chat_sessions').document(session_id)
        session_doc = session_ref.get()
        
        if not session_doc.exists:
            return jsonify({"error": "Session not found"}), 404
            
        session_data = session_doc.to_dict()
        reveals = session_data.get('reveals', [])
        
        if user_id not in reveals:
            reveals.append(user_id)
            session_ref.update({'reveals': reveals})
            
        users = session_data.get('users', [])
        if len(reveals) == 2 and len(users) == 2:
            match_id = f"{min(users[0], users[1])}_{max(users[0], users[1])}"
            db.collection('match_connections').document(match_id).set({
                'users': users,
                'status': 'active',
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            session_ref.update({'status': 'revealed'})
            return jsonify({"status": "success", "is_mutual": True}), 200
            
        return jsonify({"status": "success", "is_mutual": False}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
''')
