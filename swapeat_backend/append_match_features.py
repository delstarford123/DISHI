import os

filepath = r"c:\Users\Delstaford\swapeat\swapeat_backend\routes\v2\match_routes.py"
with open(filepath, "a", encoding="utf-8") as f:
    f.write('''

# ── PHASE 11: THE BIG 6 EXPANSION ─────────────────────────────

# 1. SECRET ADMIRER 💌
@match_v2_bp.route('/secret_admirer/send', methods=['POST'])
def send_secret_admirer():
    """Send an anonymous crush notification."""
    data = request.json or {}
    sender_id = data.get('sender_id')
    target_id = data.get('target_id')
    message = data.get('message', 'Someone has a crush on you! 💌')
    
    if not all([sender_id, target_id]):
        return jsonify({"error": "Missing params"}), 400
        
    db = firestore.client()
    db.collection('secret_admirers').add({
        'sender_id': sender_id,
        'target_id': target_id,
        'message': message,
        'is_revealed': False,
        'created_at': firestore.SERVER_TIMESTAMP
    })
    
    return jsonify({"status": "Crush sent anonymously!"}), 200

# 2. CAMPUS IDOL (VOICE NOTES) 🎤
@match_v2_bp.route('/campus_idol/upload', methods=['POST'])
def upload_campus_idol():
    """Upload a 10s voice note to the anonymous feed."""
    data = request.json or {}
    user_id = data.get('user_id')
    audio_url = data.get('audio_url')
    
    if not all([user_id, audio_url]):
        return jsonify({"error": "Missing params"}), 400
        
    db = firestore.client()
    db.collection('campus_idol_feed').add({
        'user_id': user_id,
        'audio_url': audio_url,
        'upvotes': 0,
        'created_at': firestore.SERVER_TIMESTAMP
    })
    
    return jsonify({"status": "Voice note live!"}), 200

@match_v2_bp.route('/campus_idol/feed', methods=['GET'])
def get_campus_idol_feed():
    """Fetch random voice notes."""
    db = firestore.client()
    docs = db.collection('campus_idol_feed').order_by('created_at', direction=firestore.Query.DESCENDING).limit(10).stream()
    feed = []
    for doc in docs:
        d = doc.to_dict()
        d['id'] = doc.id
        # hide user_id for anonymity until matched
        d.pop('user_id', None)
        feed.append(d)
    return jsonify({"feed": feed}), 200

# 3. LIBRARY LOCK-IN 📍
@match_v2_bp.route('/library_lockin/checkin', methods=['POST'])
def library_checkin():
    """Check into the library to find study dates."""
    data = request.json or {}
    user_id = data.get('user_id')
    major = data.get('major', 'Undecided')
    
    db = firestore.client()
    db.collection('library_lockin').document(user_id).set({
        'checked_in_at': firestore.SERVER_TIMESTAMP,
        'major': major,
        'status': 'Studying 📚'
    })
    
    return jsonify({"status": "Checked in successfully"}), 200

# 4. MUSIC MATCH 🎧
@match_v2_bp.route('/music_match/update', methods=['POST'])
def update_music_taste():
    """Update top 3 artists/genres."""
    data = request.json or {}
    user_id = data.get('user_id')
    artists = data.get('artists', [])
    
    db = firestore.client()
    db.collection('match_profiles').document(user_id).update({
        'top_artists': artists
    })
    
    return jsonify({"status": "Music taste updated"}), 200

# 5. TRUTH OR DRINK 🎲
@match_v2_bp.route('/truth_or_drink/prompts', methods=['GET'])
def get_truth_or_drink():
    """Get random bold icebreaker questions."""
    prompts = [
        "What's your biggest campus regret? Truth or Drink!",
        "Who was your last campus crush? Truth or Drink!",
        "Most embarrassing drunk story? Truth or Drink!",
        "Have you ever ghosted someone? Truth or Drink!",
        "What's your most toxic dating trait? Truth or Drink!"
    ]
    import random
    return jsonify({"prompt": random.choice(prompts)}), 200

# 6. A DAY IN THE LIFE 📸
@match_v2_bp.route('/day_in_the_life/upload', methods=['POST'])
def upload_day_in_life():
    """Upload the daily photo prompt response."""
    data = request.json or {}
    user_id = data.get('user_id')
    image_url = data.get('image_url')
    
    db = firestore.client()
    db.collection('day_in_the_life').document(user_id).set({
        'image_url': image_url,
        'uploaded_at': firestore.SERVER_TIMESTAMP
    })
    
    return jsonify({"status": "Daily photo uploaded!"}), 200
''')
