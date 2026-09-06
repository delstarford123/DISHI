from flask import Blueprint, request, jsonify
import firebase_admin
from firebase_admin import firestore
import traceback
from datetime import datetime
import random
from utils.fcm_utils import send_fcm_notification

match_v2_bp = Blueprint('match_v2_bp', __name__)

@match_v2_bp.route('/profile', methods=['POST'])
def setup_profile():
    data = request.json or {}
    user_id = data.get('user_id')
    bio = data.get('bio', '')
    major = data.get('major', '')
    institution = data.get('institution', '')
    image_url = data.get('image_url', '')
    referral_code_used = data.get('referral_code_used', '')
    phone_number = data.get('phone_number', '')
    email = data.get('email', '')
    gender = data.get('gender', '')
    age = data.get('age', None)
    lat = data.get('lat', None)
    lng = data.get('lng', None)

    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        profile_ref = db.collection('match_profiles').document(user_id)
        
        # Get existing user details (name, etc.) to merge
        user_doc = db.collection('users').document(user_id).get()
        name = user_doc.to_dict().get('fullName', 'Student') if user_doc.exists else 'Student'
        
        # Auto-generate a referral code if it doesn't exist
        my_referral_code = f"REF-{user_id[:6].upper()}"

        profile_data = {
            'user_id': user_id,
            'name': name,
            'bio': bio,
            'major': major,
            'institution': institution,
            'image_url': image_url,
            'gender': gender,
            'age': age,
            'lat': lat,
            'lng': lng,
            'my_referral_code': my_referral_code,
            'referral_code_used': referral_code_used,
            'phone_number': phone_number,
            'email': email,
            'updated_at': firestore.SERVER_TIMESTAMP,
            'is_active': True
        }
        
        profile_ref.set(profile_data, merge=True)
        return jsonify({"status": "success", "message": "Profile updated successfully"}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/potentials', methods=['GET'])
def get_potentials():
    user_id = request.args.get('user_id')
    
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        
        # Get current user's profile to know gender preference
        user_profile_doc = db.collection('match_profiles').document(user_id).get()
        user_gender = user_profile_doc.to_dict().get('gender', '') if user_profile_doc.exists else ''
        
        # Get the users that this user has already swiped on
        interactions_ref = db.collection('match_profiles').document(user_id).collection('swipes')
        interactions = interactions_ref.stream()
        swiped_ids = [doc.id for doc in interactions]
        swiped_ids.append(user_id) # Exclude self
        
        # Get potentials
        potentials_query = db.collection('match_profiles').where('is_active', '==', True)
            
        potentials_docs = potentials_query.stream()
        
        results = []
        for doc in potentials_docs:
            if doc.id not in swiped_ids:
                data = doc.to_dict()
                results.append(data)
                
        return jsonify({"status": "success", "data": results}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/dashboard_potentials', methods=['GET'])
def get_dashboard_potentials():
    user_id = request.args.get('user_id')
    user_lat = request.args.get('lat', type=float)
    user_lng = request.args.get('lng', type=float)
    
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        user_doc = db.collection('match_profiles').document(user_id).get()
        user_gender = ''
        user_profile = user_doc.to_dict() if user_doc.exists else {}
        if user_profile:
            user_gender = user_profile.get('gender', '')
            
        if not user_gender:
            return jsonify({"error": "User gender must be set to find matches."}), 400
            
        # Get swiped IDs to exclude
        interactions = db.collection('match_profiles').document(user_id).collection('swipes').stream()
        swiped_ids = [doc.id for doc in interactions]
        swiped_ids.append(user_id) # Exclude self
        
        now = datetime.utcnow()
        
        profiles_query = db.collection('match_profiles').where('is_active', '==', True)
        all_profiles = profiles_query.stream()
        
        nearest_list = []
        opposite_gender_list = []
        
        import math
        def haversine(lat1, lon1, lat2, lon2):
            R = 6371.0
            dlat = math.radians(lat2 - lat1)
            dlon = math.radians(lon2 - lon1)
            a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
            return R * c

        for doc in all_profiles:
            if doc.id in swiped_ids:
                continue
            p_data = doc.to_dict()
            p_gender = p_data.get('gender', '')
            is_opposite = bool(user_gender and p_gender and user_gender.lower() != p_gender.lower())
            
            updated_at = p_data.get('updated_at')
            p_lat = p_data.get('lat')
            p_lng = p_data.get('lng')
            
            is_recent = False
            if updated_at:
                try:
                    if hasattr(updated_at, 'replace'):
                        is_recent = (now - updated_at.replace(tzinfo=None)).days <= 7
                    else:
                        is_recent = True
                except Exception:
                    is_recent = True
            
            my_vibe = user_profile.get('vibe_answers', [])
            p_vibe = p_data.get('vibe_answers', [])
            if my_vibe and p_vibe and len(my_vibe) == 5 and len(p_vibe) == 5:
                same_cnt = sum(1 for a, b in zip(my_vibe, p_vibe) if a == b)
                vibe_pct = int((same_cnt / 5.0) * 100)
            else:
                vibe_pct = 80 # Default fallback score

            p_data['vibe_match_pct'] = vibe_pct
            p_data['is_popular'] = bool(p_data.get('likes_received', 0) >= 3 or random.random() > 0.5)

            if is_opposite:
                opposite_gender_list.append(p_data)
                
                if user_lat is not None and user_lng is not None and p_lat is not None and p_lng is not None and is_recent:
                    dist = haversine(user_lat, user_lng, float(p_lat), float(p_lng))
                    if dist <= 50:
                        p_data['distance_km'] = round(dist, 1)
                        nearest_list.append(p_data)

        nearest_list.sort(key=lambda x: x.get('distance_km', 99999))
        
        if len(nearest_list) > 0:
            return jsonify({
                "status": "success",
                "is_fallback": False,
                "data": nearest_list[:40]
            }), 200
        else:
            import random
            fallback_data = random.sample(opposite_gender_list, min(len(opposite_gender_list), 40))
            return jsonify({
                "status": "success",
                "is_fallback": True,
                "data": fallback_data
            }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/swipe', methods=['POST'])
def swipe():
    data = request.json or {}
    user_id = data.get('user_id')
    target_id = data.get('target_id')
    action = data.get('action') # 'like' or 'pass'

    if not user_id or not target_id or not action:
        return jsonify({"error": "user_id, target_id, and action are required"}), 400

    try:
        db = firestore.client()
        
        # 1. Record the swipe
        swipe_ref = db.collection('match_profiles').document(user_id).collection('swipes').document(target_id)
        swipe_ref.set({
            'action': action,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        
        # 2. Check for mutual match if it's a 'like'
        is_match = False
        is_perfect = False
        if action == 'like':
            target_swipe = db.collection('match_profiles').document(target_id).collection('swipes').document(user_id).get()
            if target_swipe.exists and target_swipe.to_dict().get('action') == 'like':
                is_match = True
                
                # Check gender of both users for Perfect Match
                u_doc = db.collection('match_profiles').document(user_id).get()
                t_doc = db.collection('match_profiles').document(target_id).get()
                u_gender = u_doc.to_dict().get('gender', '') if u_doc.exists else ''
                t_gender = t_doc.to_dict().get('gender', '') if t_doc.exists else ''
                
                if u_gender and t_gender and u_gender.lower() != t_gender.lower():
                    is_perfect = True
                
                # Record match for both
                match_id = f"{min(user_id, target_id)}_{max(user_id, target_id)}"
                match_data = {
                    'users': [user_id, target_id],
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'status': 'active',
                    'is_perfect_match': is_perfect
                }
                db.collection('match_connections').document(match_id).set(match_data, merge=True)
                
                # Send FCM Notification to both users
                u_doc = db.collection('match_profiles').document(user_id).get()
                u_name = u_doc.to_dict().get('name', 'Someone') if u_doc.exists else 'Someone'
                t_doc = db.collection('match_profiles').document(target_id).get()
                t_name = t_doc.to_dict().get('name', 'Someone') if t_doc.exists else 'Someone'
                
                send_fcm_notification(
                    user_id=target_id,
                    title="You've got a Match! 💘",
                    body=f"You and {u_name} liked each other. Say hi!"
                )
                
                send_fcm_notification(
                    user_id=user_id,
                    title="You've got a Match! 💘",
                    body=f"You and {t_name} liked each other. Say hi!"
                )

        return jsonify({"status": "success", "is_match": is_match, "is_perfect_match": is_perfect}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/wingman', methods=['POST'])
def wingman():
    data = request.json or {}
    target_bio = data.get('target_bio', '')
    target_major = data.get('target_major', '')
    
    import os
    groq_api_key = os.environ.get('GROQ_API_KEY')
    
    if groq_api_key:
        try:
            from groq import Groq
            client = Groq(api_key=groq_api_key)
            prompt = f"Write a clever, funny, and slightly flirty one-line icebreaker to send to a college student majoring in '{target_major}' who has this in their bio: '{target_bio}'. Do not include quotes, just the line."
            
            chat_completion = client.chat.completions.create(
                messages=[
                    {"role": "system", "content": "You are a witty, charismatic dating app wingman."},
                    {"role": "user", "content": prompt}
                ],
                model="llama3-8b-8192",
                temperature=0.8,
                max_tokens=50,
            )
            selected_line = chat_completion.choices[0].message.content.strip().strip('"')
            
            return jsonify({
                "status": "success",
                "icebreaker": selected_line
            }), 200
        except Exception as e:
            traceback.print_exc()
            # Fallback to random logic if groq fails
            pass
            
    # Fallback logic if no API key or if groq fails
    import random
    icebreakers = [
        f"I see you study {target_major}. Is it true you guys never sleep, or is that just a myth?",
        f"Your bio says '{target_bio}'. I have to know more about that!",
        "Are you an API? Because you are exactly what I’ve been searching for.",
        "We matched! Does this mean we're exclusive now or do we need to negotiate terms?",
        "I was going to say something smooth, but I forgot it when I saw your profile.",
        f"If I take you out, what's the likelihood you explain {target_major} to me the whole time?",
    ]
    selected_line = random.choice(icebreakers)
    
    return jsonify({
        "status": "success",
        "icebreaker": selected_line
    }), 200

@match_v2_bp.route('/direct_match', methods=['POST'])
def direct_match():
    data = request.json or {}
    user_id = data.get('user_id')
    target_id = data.get('target_id') # e.g. a Student ID like COM/12/23
    
    if not user_id or not target_id:
        return jsonify({"error": "user_id and target_id are required"}), 400

    try:
        db = firestore.client()
        
        # In a real scenario, we'd lookup the actual user_id from the student reg number
        # For this prototype, we assume target_id is directly usable or maps to an actual user doc.
        target_profile_ref = db.collection('match_profiles').document(target_id).get()
        if not target_profile_ref.exists:
            return jsonify({"error": "Student ID not found in Match Network."}), 404
            
        # 1. Record the swipe (like)
        swipe_ref = db.collection('match_profiles').document(user_id).collection('swipes').document(target_id)
        swipe_ref.set({
            'action': 'like',
            'timestamp': firestore.SERVER_TIMESTAMP,
            'is_direct': True
        })
        
        # 2. Check for mutual match
        is_match = False
        target_swipe = db.collection('match_profiles').document(target_id).collection('swipes').document(user_id).get()
        if target_swipe.exists and target_swipe.to_dict().get('action') == 'like':
            is_match = True
            match_id = f"{min(user_id, target_id)}_{max(user_id, target_id)}"
            match_data = {
                'users': [user_id, target_id],
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'active'
            }
            db.collection('match_connections').document(match_id).set(match_data)
            
            # Send FCM Notification
            u_doc = db.collection('match_profiles').document(user_id).get()
            u_name = u_doc.to_dict().get('name', 'Someone') if u_doc.exists else 'Someone'
            t_doc = db.collection('match_profiles').document(target_id).get()
            t_name = t_doc.to_dict().get('name', 'Someone') if t_doc.exists else 'Someone'
            
            send_fcm_notification(
                user_id=target_id,
                title="You've got a Direct Match! 💘",
                body=f"You and {u_name} liked each other."
            )
            
            send_fcm_notification(
                user_id=user_id,
                title="You've got a Direct Match! 💘",
                body=f"You and {t_name} liked each other."
            )

        return jsonify({"status": "success", "is_match": is_match}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@match_v2_bp.route('/report', methods=['POST'])
def report_user():
    data = request.json or {}
    reporter_id = data.get('reporter_id')
    offender_id = data.get('offender_id')
    reason = data.get('reason', 'Community Violation')
    
    if not reporter_id or not offender_id:
        return jsonify({"error": "reporter_id and offender_id are required"}), 400

    try:
        db = firestore.client()
        
        # 1. Log the incident
        db.collection('match_incident_reports').add({
            'reporter_id': reporter_id,
            'offender_id': offender_id,
            'reason': reason,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'status': 'pending_review'
        })
        
        # 2. Shadow Ban the offender
        db.collection('match_profiles').document(offender_id).update({
            'is_active': False,
            'shadow_banned_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success", "message": "User reported and temporarily suspended."}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/sos', methods=['POST'])
def match_sos():
    data = request.json or {}
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({"error": "Missing user_id"}), 400
        
    try:
        db = firestore.client()
        db.collection('match_sos_alerts').add({
            'user_id': user_id,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'status': 'active'
        })
        
        # Send Email Alert
        try:
            from flask import current_app
            from flask_mail import Message
            from routes.email_utils import sos_alert_email
            mail = current_app.extensions.get('mail')
            if mail:
                # Try to fetch student name from Firestore
                sos_student_name = 'Unknown Student'
                try:
                    db2 = firestore.client()
                    user_doc2 = db2.collection('users').document(user_id).get()
                    if user_doc2.exists:
                        ud2 = user_doc2.to_dict()
                        sos_student_name = ud2.get('displayName') or ud2.get('name') or 'Unknown Student'
                except Exception:
                    pass
                subj, html_body = sos_alert_email(user_id, sos_student_name)
                msg = Message(
                    subj,
                    sender=current_app.config.get('MAIL_USERNAME', 'admin@swapeat.com'),
                    recipients=['info@delstarfordworks.co.ke']
                )
                msg.html = html_body
                msg.body = f"URGENT: SOS alert triggered by {sos_student_name} (ID: {user_id}). Check admin dashboard immediately."
                mail.send(msg)
        except Exception as email_e:
            print(f"Failed to send SOS email: {email_e}")

        return jsonify({"status": "success", "message": "SOS Alert logged successfully."}), 200
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/cron/match_emails', methods=['GET', 'POST'])
def match_cron_emails():
    # Triggered by Vercel Cron every Mon, Wed, Fri
    try:
        db = firestore.client()
        from firebase_admin import auth
        
        # 1. Fetch all active match profiles
        docs = db.collection('match_profiles').where('is_active', '==', True).get()
        profiles = {doc.id: doc.to_dict() for doc in docs}
        
        emails_sent = 0
        
        for uid, p in profiles.items():
            if not p.get('is_premium'):
                continue # Only send to premium (Gold) users
                
            looking_for = p.get('looking_for') # 'male' or 'female'
            own_gender = p.get('gender')
            
            # Find perfect matches
            perfect_matches = []
            for other_uid, other_p in profiles.items():
                if other_uid == uid:
                    continue
                # Opposite gender logic
                if looking_for and other_p.get('gender') != looking_for:
                    continue
                if other_p.get('looking_for') and other_p.get('looking_for') != own_gender:
                    continue
                
                # Perfect match criteria (e.g. same institution)
                if p.get('institution') == other_p.get('institution'):
                    perfect_matches.append(other_p.get('name', 'A Student'))
                    
            if not perfect_matches:
                continue
                
            # Fetch user email
            try:
                user_record = auth.get_user(uid)
                email = user_record.email
                if not email:
                    continue
            except Exception:
                continue # User not found or no email
                
            # Send Email
            try:
                from flask import current_app
                from flask_mail import Message
                from routes.email_utils import match_digest_email
                mail = current_app.extensions.get('mail')
                if mail:
                    student_name = p.get('name', 'there')
                    subj, html_body = match_digest_email(student_name, perfect_matches)
                    msg = Message(
                        subj,
                        sender=current_app.config.get('MAIL_USERNAME', 'admin@swapeat.com'),
                        recipients=[email]
                    )
                    msg.html = html_body
                    msg.body = f"Hey {student_name},\n\nYou have {len(perfect_matches)} new matches on DISHI! Open the app to see them.\n\nDISHI Gold Team"
                    mail.send(msg)
                    emails_sent += 1
            except Exception as e:
                print(f"Flask-Mail error for {email}: {e}")
                
        return jsonify({"status": "success", "emails_sent": emails_sent}), 200
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── VIRTUAL NIGHT CLUB ENDPOINTS ─────────────────────────────────────────────

@match_v2_bp.route('/night_club/join', methods=['POST'])
def join_night_club():
    data = request.json or {}
    user_id = data.get('user_id')
    name = data.get('name', 'Student Partygoer')
    image_url = data.get('image_url', '')
    gender = data.get('gender', '')
    institution = data.get('institution', '')
    major = data.get('major', '')
    phone_number = data.get('phone_number', '')

    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        member_ref = db.collection('night_club_members').document(user_id)
        member_ref.set({
            'user_id': user_id,
            'name': name,
            'image_url': image_url,
            'gender': gender,
            'institution': institution,
            'major': major,
            'phone_number': phone_number,
            'joined_at': firestore.SERVER_TIMESTAMP,
            'is_active': True
        })
        return jsonify({"status": "success", "message": "Joined Virtual Night Club!"}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/night_club/leave', methods=['POST'])
def leave_night_club():
    data = request.json or {}
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        db.collection('night_club_members').document(user_id).delete()
        return jsonify({"status": "success", "message": "Left Virtual Night Club"}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/night_club/members', methods=['GET'])
def get_night_club_members():
    try:
        db = firestore.client()
        docs = db.collection('night_club_members').stream()
        members = [doc.to_dict() for doc in docs]
        return jsonify({"status": "success", "data": members}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/night_club/start_event', methods=['POST'])
def start_night_club_event():
    try:
        db = firestore.client()
        from firebase_admin import messaging
        
        # Fetch all active match profiles to send FCM notification
        profiles = db.collection('match_profiles').where('is_active', '==', True).stream()
        notified_count = 0
        
        for p in profiles:
            p_data = p.to_dict()
            uid = p_data.get('user_id') or p.id
            user_doc = db.collection('users').document(uid).get()
            if user_doc.exists:
                token = user_doc.to_dict().get('fcmToken')
                if token:
                    try:
                        messaging.send(messaging.Message(
                            notification=messaging.Notification(
                                title="🎉 Virtual Club is NOW LIVE!",
                                body="Join the Virtual Club now! Meet students online from all campuses, listen to DJ party tracks, chat, and call live!",
                            ),
                            token=token,
                        ))
                        notified_count += 1
                    except Exception:
                        pass
                        
        return jsonify({"status": "success", "message": f"Virtual Club broadcast sent to {notified_count} students."}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── BIRTHDAY GIFTING & SAVINGS SYSTEM ENDPOINTS ──────────────────────────────

@match_v2_bp.route('/birthday_gift', methods=['POST'])
def send_birthday_gift():
    data = request.json or {}
    sender_id = data.get('sender_id')
    recipient_id = data.get('recipient_id')
    phone_number = data.get('phone_number', '').strip()
    amount = data.get('amount')
    item_note = data.get('item_note', 'Birthday Drinks & Cake 🍰')

    if not sender_id or not recipient_id or not phone_number or not amount:
        return jsonify({"error": "sender_id, recipient_id, phone_number, and amount are required"}), 400

    try:
        gift_amount = int(float(str(amount)))
        if gift_amount <= 0:
            return jsonify({"error": "Gift amount must be greater than 0"}), 400
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid gift amount"}), 400

    try:
        db = firestore.client()
        
        # 1. Get sender details
        sender_doc = db.collection('match_profiles').document(sender_id).get()
        sender_name = sender_doc.to_dict().get('name', 'Your Crush') if sender_doc.exists else 'Your Crush'

        # 2. Get recipient details
        recipient_doc = db.collection('match_profiles').document(recipient_id).get()
        if not recipient_doc.exists:
            return jsonify({"error": "Recipient profile not found"}), 404

        recipient_name = recipient_doc.to_dict().get('name', 'Recipient')

        # ── SENDER COMMISSION RULE ──
        # Sender pays (Gift Amount + KSh 20 platform commission) for gifts > KSh 100
        commission = 20 if gift_amount > 100 else 0
        charged_amount = gift_amount + commission  # e.g. 200 + 20 = 220 KSh charged to sender
        credit_amount = gift_amount                 # e.g. 200 KSh (100%) credited to recipient

        # 3. Import M-PESA helper functions
        import os, requests, base64
        from routes.mpesa_routes import generate_access_token, _fmt_phone

        access_token = generate_access_token()
        if not access_token:
            return jsonify({"error": "Failed to authenticate with M-PESA Daraja gateway."}), 500

        passkey = os.getenv('MPESA_PASSKEY', '')
        business_short_code = os.getenv('MPESA_BUSINESS_SHORT_CODE', '')
        if not passkey or not business_short_code:
            return jsonify({"error": "MPESA_PASSKEY or MPESA_BUSINESS_SHORT_CODE not configured on server."}), 500

        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        password_str = business_short_code + passkey + timestamp
        password = base64.b64encode(password_str.encode('utf-8')).decode('utf-8')

        env = os.getenv('MPESA_ENV', 'sandbox').lower()
        base_url = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"
        api_url = f"{base_url}/mpesa/stkpush/v1/processrequest"

        formatted_phone = _fmt_phone(phone_number)

        payload = {
            "BusinessShortCode": business_short_code,
            "Password": password,
            "Timestamp": timestamp,
            "TransactionType": "CustomerPayBillOnline",
            "Amount": charged_amount,
            "PartyA": formatted_phone,
            "PartyB": business_short_code,
            "PhoneNumber": formatted_phone,
            "CallBackURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/callback",
            "AccountReference": "DISHIGIFT",
            "TransactionDesc": f"Gift for {recipient_name}",
        }

        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        response = requests.post(api_url, json=payload, headers=headers, timeout=15)
        res_data = response.json()

        if response.status_code == 200 and 'CheckoutRequestID' in res_data:
            checkout_id = res_data['CheckoutRequestID']

            # Record pending transaction targeting recipient's savings account
            db.collection('mpesa_transactions').document(checkout_id).set({
                'user_id': recipient_id,
                'sender_id': sender_id,
                'amount': credit_amount,            # 100% of gift amount credited to recipient
                'charged_amount': charged_amount,    # Gift + Commission charged to sender
                'commission': commission,
                'destination': 'vault_balance',
                'status': 'pending',
                'phone': formatted_phone,
                'user_name': recipient_name,
                'timestamp': firestore.SERVER_TIMESTAMP,
            })

            # Record gift record in birthday_gifts collection
            db.collection('birthday_gifts').document(checkout_id).set({
                'gift_id': checkout_id,
                'sender_id': sender_id,
                'sender_name': sender_name,
                'recipient_id': recipient_id,
                'recipient_name': recipient_name,
                'gift_amount': gift_amount,
                'commission': commission,
                'charged_amount': charged_amount,
                'item_note': item_note,
                'status': 'stk_sent',
                'created_at': firestore.SERVER_TIMESTAMP
            })

            return jsonify({
                "status": "success",
                "message": f"M-PESA STK Push prompt of KSh {charged_amount} sent to {formatted_phone}. Recipient will receive KSh {credit_amount} in their Semester Vault.",
                "charged_amount": charged_amount,
                "gift_amount": gift_amount,
                "commission": commission,
                "checkout_id": checkout_id
            }), 200
        else:
            err_msg = res_data.get('errorMessage') or res_data.get('ResponseDescription') or 'M-PESA STK push failed'
            return jsonify({"error": err_msg, "details": res_data}), 400

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/secret_admirers', methods=['GET'])
def get_secret_admirers():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        
        user_doc = db.collection('match_profiles').document(user_id).get()
        if not user_doc.exists:
            return jsonify({"status": "success", "count": 0, "admirers": []}), 200

        user_gender = user_doc.to_dict().get('gender', '')

        # Find users who swiped 'like' on this user
        own_swipes = [doc.id for doc in db.collection('match_profiles').document(user_id).collection('swipes').stream()]

        all_profiles = {doc.id: doc.to_dict() for doc in db.collection('match_profiles').where('is_active', '==', True).stream()}

        secret_admirers = []
        for uid, p in all_profiles.items():
            if uid == user_id or uid in own_swipes:
                continue
            
            p_gender = p.get('gender', '')
            if user_gender and p_gender and user_gender.lower() == p_gender.lower():
                continue

            swipe_doc = db.collection('match_profiles').document(uid).collection('swipes').document(user_id).get()
            if swipe_doc.exists and swipe_doc.to_dict().get('action') == 'like':
                secret_admirers.append({
                    'user_id': uid,
                    'name': p.get('name', 'Secret Admirer'),
                    'institution': p.get('institution', ''),
                    'gender': p_gender,
                    'image_url': p.get('image_url', ''),
                })

        return jsonify({
            "status": "success",
            "count": len(secret_admirers),
            "admirers": secret_admirers
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 1: SPEED DATING ENDPOINTS ──────────────────────────────────────────

@match_v2_bp.route('/speed_dating/join_queue', methods=['POST'])
def speed_dating_join_queue():
    data = request.json or {}
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        user_doc = db.collection('match_profiles').document(user_id).get()
        user_data = user_doc.to_dict() if user_doc.exists else {}

        # Save to queue
        db.collection('speed_dating_queue').document(user_id).set({
            'user_id': user_id,
            'name': user_data.get('name', 'Student'),
            'gender': user_data.get('gender', ''),
            'image_url': user_data.get('image_url', ''),
            'joined_at': firestore.SERVER_TIMESTAMP
        })

        # Try to pair with an opposite gender user in queue
        queue_docs = db.collection('speed_dating_queue').stream()
        my_gender = user_data.get('gender', '')
        partner = None

        for doc in queue_docs:
            if doc.id == user_id:
                continue
            q_data = doc.to_dict()
            q_gender = q_data.get('gender', '')
            if my_gender and q_gender and my_gender.lower() != q_gender.lower():
                partner = q_data
                break

        if partner:
            # Pair them up
            partner_id = partner['user_id']
            session_id = f"sd_{min(user_id, partner_id)}_{max(user_id, partner_id)}"
            session_data = {
                'session_id': session_id,
                'user1': user_id,
                'user2': partner_id,
                'user1_data': user_data,
                'user2_data': partner,
                'user1_liked': False,
                'user2_liked': False,
                'status': 'active',
                'created_at': firestore.SERVER_TIMESTAMP
            }
            db.collection('speed_dating_sessions').document(session_id).set(session_data)

            # Remove both from queue
            db.collection('speed_dating_queue').document(user_id).delete()
            db.collection('speed_dating_queue').document(partner_id).delete()

            return jsonify({"status": "success", "is_paired": True, "session": session_data}), 200

        return jsonify({"status": "success", "is_paired": False, "message": "In queue waiting for a speed date partner..."}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/speed_dating/match', methods=['POST'])
def speed_dating_match():
    data = request.json or {}
    session_id = data.get('session_id')
    user_id = data.get('user_id')

    if not session_id or not user_id:
        return jsonify({"error": "session_id and user_id are required"}), 400

    try:
        db = firestore.client()
        session_ref = db.collection('speed_dating_sessions').document(session_id)
        doc = session_ref.get()

        if not doc.exists:
            return jsonify({"error": "Speed date session not found"}), 404

        s_data = doc.to_dict()
        if s_data.get('user1') == user_id:
            session_ref.update({'user1_liked': True})
            s_data['user1_liked'] = True
        elif s_data.get('user2') == user_id:
            session_ref.update({'user2_liked': True})
            s_data['user2_liked'] = True

        # Check if both liked
        is_mutual = bool(s_data.get('user1_liked') and s_data.get('user2_liked'))
        if is_mutual:
            session_ref.update({'status': 'matched', 'is_unblurred': True})
            # Create match connection
            match_id = f"{min(s_data['user1'], s_data['user2'])}_{max(s_data['user1'], s_data['user2'])}"
            db.collection('match_connections').document(match_id).set({
                'users': [s_data['user1'], s_data['user2']],
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'active',
                'is_perfect_match': True,
                'source': 'speed_dating'
            }, merge=True)

        return jsonify({"status": "success", "is_mutual": is_mutual}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 2: DISHI DATE 50/50 SPLIT BILL ENDPOINT ───────────────────────────

@match_v2_bp.route('/dishi_date/split_bill', methods=['POST'])
def dishi_date_split_bill():
    data = request.json or {}
    user_id = data.get('user_id')
    match_id = data.get('match_id')
    total_bill = data.get('total_bill')
    restaurant_name = data.get('restaurant_name', 'Campus Date Venue')
    item_description = data.get('item_description', 'Date Meal & Drinks 🍔🍹')

    if not user_id or not match_id or not total_bill:
        return jsonify({"error": "user_id, match_id, and total_bill are required"}), 400

    try:
        bill_float = float(total_bill)
        split_amount = bill_float / 2.0
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid total_bill amount"}), 400

    try:
        db = firestore.client()
        match_doc = db.collection('match_connections').document(match_id).get()
        if not match_doc.exists:
            return jsonify({"error": "Match connection not found"}), 404

        users = match_doc.to_dict().get('users', [])
        partner_id = next((u for u in users if u != user_id), None)

        split_ref = db.collection('dishi_date_splits').document()
        split_ref.set({
            'split_id': split_ref.id,
            'match_id': match_id,
            'creator_id': user_id,
            'partner_id': partner_id,
            'total_bill': bill_float,
            'split_per_person': split_amount,
            'restaurant_name': restaurant_name,
            'item_description': item_description,
            'status': 'pending_payment',
            'created_at': firestore.SERVER_TIMESTAMP
        })

        return jsonify({
            "status": "success",
            "message": f"50/50 Split created! Each person pays KSh {split_amount:.0f}.",
            "split_per_person": split_amount,
            "split_id": split_ref.id
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/dishi_date/send_voucher', methods=['POST'])
def send_dishi_voucher():
    data = request.json or {}
    sender_id = data.get('sender_id')
    recipient_id = data.get('recipient_id')
    phone_number = data.get('phone_number', '').strip()
    amount = data.get('amount')
    note = data.get('note', 'Coffee & Snacks ☕')

    if not sender_id or not recipient_id or not amount:
        return jsonify({"error": "sender_id, recipient_id, and amount are required"}), 400

    try:
        amt_float = float(amount)
        if amt_float <= 0:
            return jsonify({"error": "Amount must be greater than 0"}), 400
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid amount number"}), 400

    try:
        db = firestore.client()

        # If recipient_id is a match connection ID (e.g. userA_userB), resolve target user_id
        if '_' in recipient_id and not recipient_id.startswith('user'):
            match_doc = db.collection('match_connections').document(recipient_id).get()
            if match_doc.exists:
                users = match_doc.to_dict().get('users', [])
                recipient_id = next((u for u in users if u != sender_id), recipient_id)

        recipient_doc = db.collection('users').document(recipient_id).get()
        if not recipient_doc.exists:
            return jsonify({"error": "Recipient profile not found"}), 404
        
        recipient_name = recipient_doc.to_dict().get('displayName') or recipient_doc.to_dict().get('name') or 'Recipient'

        # Auto-fetch sender phone number if not supplied
        if not phone_number:
            sender_doc = db.collection('match_profiles').document(sender_id).get()
            if sender_doc.exists:
                phone_number = sender_doc.to_dict().get('phone_number', '')
            if not phone_number:
                u_doc = db.collection('users').document(sender_id).get()
                if u_doc.exists:
                    phone_number = u_doc.to_dict().get('phone_number', '')
            if not phone_number:
                return jsonify({"error": "No phone number provided."}), 400

        # Sender Commission Rule
        commission = 20 if amt_float > 100 else 0
        charged_amount = amt_float + commission
        credit_amount = amt_float

        import os, requests, base64
        from routes.mpesa_routes import generate_access_token, _fmt_phone

        access_token = generate_access_token()
        if not access_token:
            return jsonify({"error": "Failed to authenticate with M-PESA Daraja gateway."}), 500

        passkey = os.getenv('MPESA_PASSKEY', '')
        business_short_code = os.getenv('MPESA_BUSINESS_SHORT_CODE', '')
        if not passkey or not business_short_code:
            return jsonify({"error": "MPESA_PASSKEY or MPESA_BUSINESS_SHORT_CODE not configured on server."}), 500

        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        password_str = business_short_code + passkey + timestamp
        password = base64.b64encode(password_str.encode('utf-8')).decode('utf-8')

        env = os.getenv('MPESA_ENV', 'sandbox').lower()
        base_url = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"
        api_url = f"{base_url}/mpesa/stkpush/v1/processrequest"

        formatted_phone = _fmt_phone(phone_number)

        payload = {
            "BusinessShortCode": business_short_code,
            "Password": password,
            "Timestamp": timestamp,
            "TransactionType": "CustomerPayBillOnline",
            "Amount": charged_amount,
            "PartyA": formatted_phone,
            "PartyB": business_short_code,
            "PhoneNumber": formatted_phone,
            "CallBackURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/callback",
            "AccountReference": "DISHIVOUCHER",
            "TransactionDesc": f"Food Voucher for {recipient_name}",
        }

        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        response = requests.post(api_url, json=payload, headers=headers, timeout=15)
        res_data = response.json()

        if response.status_code == 200 and 'CheckoutRequestID' in res_data:
            checkout_id = res_data['CheckoutRequestID']

            # Record pending transaction targeting recipient's savings account
            db.collection('mpesa_transactions').document(checkout_id).set({
                'user_id': recipient_id,
                'sender_id': sender_id,
                'amount': credit_amount,
                'charged_amount': charged_amount,
                'commission': commission,
                'destination': 'savingsBalance',
                'status': 'pending',
                'phone': formatted_phone,
                'user_name': recipient_name,
                'timestamp': firestore.SERVER_TIMESTAMP,
            })

            # Record voucher in Firestore
            v_ref = db.collection('dishi_vouchers').document(checkout_id)
            v_ref.set({
                'voucher_id': checkout_id,
                'sender_id': sender_id,
                'recipient_id': recipient_id,
                'phone_number': formatted_phone,
                'amount': amt_float,
                'charged_amount': charged_amount,
                'commission': commission,
                'note': note,
                'status': 'stk_sent',
                'created_at': firestore.SERVER_TIMESTAMP
            })

            return jsonify({
                "status": "success",
                "message": f"M-PESA STK Push prompt of KSh {charged_amount} sent to {formatted_phone}. Recipient will get KSh {credit_amount}.",
                "voucher_id": checkout_id
            }), 200
        else:
            err_msg = res_data.get('errorMessage') or res_data.get('ResponseDescription') or 'M-PESA STK push failed'
            return jsonify({"error": err_msg, "details": res_data}), 400

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 3: DOUBLE DATE ENDPOINTS ──────────────────────────────────────────

@match_v2_bp.route('/double_date/create_team', methods=['POST'])
def create_double_date_team():
    data = request.json or {}
    user_id = data.get('user_id')
    friend_id = data.get('friend_id')
    team_name = data.get('team_name', 'Dynamic Duo')

    if not user_id or not friend_id:
        return jsonify({"error": "user_id and friend_id are required"}), 400

    try:
        db = firestore.client()
        team_id = f"dt_{min(user_id, friend_id)}_{max(user_id, friend_id)}"
        
        u1_doc = db.collection('match_profiles').document(user_id).get()
        u2_doc = db.collection('match_profiles').document(friend_id).get()

        team_data = {
            'team_id': team_id,
            'team_name': team_name,
            'members': [user_id, friend_id],
            'member1_profile': u1_doc.to_dict() if u1_doc.exists else {},
            'member2_profile': u2_doc.to_dict() if u2_doc.exists else {},
            'created_at': firestore.SERVER_TIMESTAMP,
            'is_active': True
        }

        db.collection('double_date_teams').document(team_id).set(team_data)
        return jsonify({"status": "success", "team": team_data}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/double_date/potentials', methods=['GET'])
def get_double_date_potentials():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        teams = db.collection('double_date_teams').where('is_active', '==', True).stream()
        result = []

        for t in teams:
            t_data = t.to_dict()
            members = t_data.get('members', [])
            if user_id not in members:
                result.append(t_data)

        return jsonify({"status": "success", "data": result}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 4: STUDY BUDDY ENDPOINTS ──────────────────────────────────────────

@match_v2_bp.route('/study_buddy/search', methods=['GET'])
def search_study_buddies():
    user_id = request.args.get('user_id')
    unit_code = request.args.get('unit_code', '').strip().upper()

    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        profiles = db.collection('match_profiles').where('is_active', '==', True).stream()
        buddies = []

        for p in profiles:
            if p.id == user_id:
                continue
            p_data = p.to_dict()
            units = [str(u).upper() for u in p_data.get('study_units', [])]
            major = str(p_data.get('major', '')).upper()

            if not unit_code or unit_code in units or unit_code in major:
                buddies.append(p_data)

        return jsonify({"status": "success", "data": buddies}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 5: 5-QUESTION DAILY VIBE CHECK ENDPOINTS ──────────────────────────

@match_v2_bp.route('/vibe_check/submit', methods=['POST'])
def submit_vibe_check():
    data = request.json or {}
    user_id = data.get('user_id')
    answers = data.get('answers', []) # List of 5 integers / strings

    if not user_id or len(answers) < 5:
        return jsonify({"error": "user_id and 5 answers are required"}), 400

    try:
        db = firestore.client()
        db.collection('match_profiles').document(user_id).update({
            'vibe_answers': answers,
            'vibe_updated_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Daily Vibe Check saved!"}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 6: CRUSH CONFESSION NOTIFICATION ENDPOINT ──────────────────────────

@match_v2_bp.route('/crush_confession/notify_author', methods=['POST'])
def notify_confession_author():
    data = request.json or {}
    post_id = data.get('post_id')
    reader_id = data.get('reader_id')

    if not post_id or not reader_id:
        return jsonify({"error": "post_id and reader_id are required"}), 400

    try:
        db = firestore.client()
        from firebase_admin import messaging

        post_doc = db.collection('match_campus_feed').document(post_id).get()
        if not post_doc.exists:
            return jsonify({"error": "Post not found"}), 404

        post_data = post_doc.to_dict()
        author_id = post_data.get('user_id')

        reader_doc = db.collection('match_profiles').document(reader_id).get()
        reader_name = reader_doc.to_dict().get('name', 'A Student') if reader_doc.exists else 'A Student'

        # Record the suspect in the post document
        db.collection('match_campus_feed').document(post_id).update({
            'suspect_ids': firestore.ArrayUnion([reader_id])
        })

        # Send push notification to post author
        author_user = db.collection('users').document(author_id).get()
        if author_user.exists:
            token = author_user.to_dict().get('fcmToken')
            if token:
                try:
                    messaging.send(messaging.Message(
                        notification=messaging.Notification(
                            title="👀 Crush Confession Alert!",
                            body=f"{reader_name} just tapped 'Is this about me?' on your campus confession post!",
                        ),
                        token=token,
                    ))
                except Exception:
                    pass

        return jsonify({"status": "success", "message": "Author notified!"}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 7: VOICE INTRO ENDPOINT ──────────────────────────────────────────────

@match_v2_bp.route('/voice_intro/save', methods=['POST'])
def save_voice_intro():
    data = request.json or {}
    user_id = data.get('user_id')
    voice_url = data.get('voice_url')

    if not user_id or not voice_url:
        return jsonify({"error": "user_id and voice_url are required"}), 400

    try:
        db = firestore.client()
        profile_ref = db.collection('match_profiles').document(user_id)
        if not profile_ref.get().exists:
            return jsonify({"error": "Profile not found"}), 404

        profile_ref.update({
            'voice_intro_url': voice_url,
            'updated_at': firestore.SERVER_TIMESTAMP
        })

        return jsonify({"status": "success", "message": "Voice intro saved"}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 1: CRUSH RADAR (PROXIMITY & WINKS) ──────────────────────────────────

@match_v2_bp.route('/crush_radar/nearby', methods=['GET'])
def get_nearby_radar():
    user_id = request.args.get('user_id')
    landmark = request.args.get('landmark', 'Main Campus')
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    try:
        db = firestore.client()
        docs = db.collection('match_profiles').where('is_active', '==', True).limit(40).stream()

        students = []
        for d in docs:
            p = d.to_dict()
            if p.get('user_id') != user_id:
                p['landmark'] = landmark
                students.append(p)

        return jsonify({"status": "success", "landmark": landmark, "students": students}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/crush_radar/wink', methods=['POST'])
def send_radar_wink():
    data = request.json or {}
    sender_id = data.get('sender_id')
    recipient_id = data.get('recipient_id')
    action_type = data.get('action_type', 'wink')  # wink or wave
    landmark = data.get('landmark', 'Campus')

    if not sender_id or not recipient_id:
        return jsonify({"error": "sender_id and recipient_id are required"}), 400

    try:
        db = firestore.client()
        from firebase_admin import messaging

        sender_doc = db.collection('match_profiles').document(sender_id).get()
        sender_name = sender_doc.to_dict().get('name', 'Someone nearby') if sender_doc.exists else 'Someone nearby'

        # Push FCM alert to recipient
        user_doc = db.collection('users').document(recipient_id).get()
        if user_doc.exists:
            token = user_doc.to_dict().get('fcmToken')
            if token:
                emoji = "👁️" if action_type == 'wink' else "👋"
                title = f"{emoji} Secret Radar {action_type.capitalize()}!"
                body = f"{sender_name} studying near {landmark} just sent you a {action_type}!"
                try:
                    messaging.send(messaging.Message(
                        notification=messaging.Notification(title=title, body=body),
                        token=token,
                    ))
                except Exception:
                    pass

        return jsonify({"status": "success", "message": f"{action_type.capitalize()} sent successfully!"}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 8: SQUAD MATCH ─────────────────────────────────────────────────────

@match_v2_bp.route('/squad/create', methods=['POST'])
def create_squad():
    data = request.json or {}
    host_id = data.get('host_id')
    squad_name = data.get('squad_name')
    squad_type = data.get('squad_type', 'Group Hangout') # e.g. Study Group, Night Out
    
    if not host_id or not squad_name:
        return jsonify({"error": "host_id and squad_name are required"}), 400

    try:
        db = firestore.client()
        import string, random
        invite_code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        
        squad_data = {
            'squad_name': squad_name,
            'squad_type': squad_type,
            'host_id': host_id,
            'members': [host_id],
            'invite_code': invite_code,
            'is_active': True,
            'created_at': firestore.SERVER_TIMESTAMP
        }
        
        squad_ref = db.collection('match_squads').add(squad_data)
        return jsonify({"status": "success", "squad_id": squad_ref[1].id, "invite_code": invite_code}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@match_v2_bp.route('/squad/join', methods=['POST'])
def join_squad():
    data = request.json or {}
    user_id = data.get('user_id')
    invite_code = data.get('invite_code')

    if not user_id or not invite_code:
        return jsonify({"error": "user_id and invite_code are required"}), 400

    try:
        db = firestore.client()
        squads = db.collection('match_squads').where('invite_code', '==', invite_code.upper()).limit(1).get()
        if not squads:
            return jsonify({"error": "Invalid invite code"}), 404
            
        squad_ref = squads[0].reference
        squad_data = squads[0].to_dict()
        
        if len(squad_data.get('members', [])) >= 4:
            return jsonify({"error": "Squad is full (max 4 members)"}), 400
            
        if user_id not in squad_data.get('members', []):
            squad_ref.update({'members': firestore.ArrayUnion([user_id])})
            
        return jsonify({"status": "success", "squad_id": squads[0].id}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@match_v2_bp.route('/squad/feed', methods=['GET'])
def get_squad_feed():
    user_id = request.args.get('user_id')
    squad_id = request.args.get('squad_id') # The user's squad
    
    try:
        db = firestore.client()
        squads = db.collection('match_squads').where('is_active', '==', True).limit(20).get()
        
        feed = []
        for doc in squads:
            if doc.id == squad_id:
                continue
            feed.append({'id': doc.id, **doc.to_dict()})
            
        return jsonify({"status": "success", "data": feed}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@match_v2_bp.route('/squad/swipe', methods=['POST'])
def squad_swipe():
    data = request.json or {}
    from_squad_id = data.get('from_squad_id')
    to_squad_id = data.get('to_squad_id')
    action = data.get('action') # 'like' or 'pass'
    
    if not from_squad_id or not to_squad_id or not action:
        return jsonify({"error": "Missing required fields"}), 400

    try:
        db = firestore.client()
        
        # 1. Record the swipe
        swipe_ref = db.collection('match_squads').document(from_squad_id).collection('swipes').document(to_squad_id)
        swipe_ref.set({
            'action': action,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        
        # 2. Check mutual match
        is_match = False
        if action == 'like':
            target_swipe = db.collection('match_squads').document(to_squad_id).collection('swipes').document(from_squad_id).get()
            if target_swipe.exists and target_swipe.to_dict().get('action') == 'like':
                is_match = True
                
                match_id = f"squad_{min(from_squad_id, to_squad_id)}_{max(from_squad_id, to_squad_id)}"
                match_data = {
                    'squads': [from_squad_id, to_squad_id],
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'status': 'active'
                }
                db.collection('squad_connections').document(match_id).set(match_data)
                
                # We can trigger push notifications to all members of both squads here
                # (For brevity, skipping full member loop here, but they are notified via the client logic)

        return jsonify({"status": "success", "is_match": is_match}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500# ── PHASE 3: CAMPUS EVENT & VARSITY DATE FINDER ─────────────────────────────

@match_v2_bp.route('/events/list', methods=['GET'])
def list_campus_events():
    try:
        db = firestore.client()
        events_ref = db.collection('campus_events').order_by('created_at', direction=firestore.Query.DESCENDING).limit(30).stream()

        events = []
        for e in events_ref:
            ed = e.to_dict()
            ed['event_id'] = e.id
            events.append(ed)

        if not events:
            # Seed default campus events if empty
            defaults = [
                {'title': '⚽ Inter-Varsity Football Derby', 'venue': 'Main Stadium', 'date': 'This Friday 4 PM', 'category': 'Sports'},
                {'title': '🍿 Campus Outdoor Movie Night', 'venue': 'Student Centre Lawn', 'date': 'Saturday 7 PM', 'category': 'Entertainment'},
                {'title': '💻 AI & Code Hackathon', 'venue': 'Tech Innovation Lab', 'date': 'Sunday 10 AM', 'category': 'Academics'},
            ]
            for d in defaults:
                ref = db.collection('campus_events').document()
                d['event_id'] = ref.id
                d['created_at'] = firestore.SERVER_TIMESTAMP
                ref.set(d)
                events.append(d)

        return jsonify({"status": "success", "events": events}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@match_v2_bp.route('/events/go_together', methods=['POST'])
def go_together_event():
    data = request.json or {}
    user_id = data.get('user_id')
    event_id = data.get('event_id')
    partner_id = data.get('partner_id')

    if not user_id or not event_id or not partner_id:
        return jsonify({"error": "user_id, event_id, and partner_id are required"}), 400

    try:
        db = firestore.client()
        ref = db.collection('event_dates').document()
        ref.set({
            'date_id': ref.id,
            'event_id': event_id,
            'user_id': user_id,
            'partner_id': partner_id,
            'status': 'matched',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "You are paired up for this campus event! 🎟️"}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 4: ANONYMOUS SECRET ADMIRER MATCHER ─────────────────────────────────

@match_v2_bp.route('/secret_admirer/add', methods=['POST'])
def add_secret_admirer():
    data = request.json or {}
    user_id = data.get('user_id')
    target_handle = data.get('target_handle', '').strip()  # Phone or handle

    if not user_id or not target_handle:
        return jsonify({"error": "user_id and target_handle are required"}), 400

    try:
        db = firestore.client()
        admirer_ref = db.collection('secret_admirers').document(f"{user_id}_{target_handle}")
        admirer_ref.set({
            'user_id': user_id,
            'target_handle': target_handle,
            'created_at': firestore.SERVER_TIMESTAMP
        })

        # Check if target also added user_id
        reverse_check = db.collection('secret_admirers').where('user_id', '==', target_handle).where('target_handle', '==', user_id).limit(1).get()
        is_mutual = len(reverse_check) > 0

        if is_mutual:
            return jsonify({
                "status": "success",
                "is_mutual": True,
                "message": "🎉 MUTUAL SECRET CRUSH UNLOCKED! You both added each other to your secret list!"
            }), 200

        return jsonify({
            "status": "success",
            "is_mutual": False,
            "message": "Secret admirer added! If they add you back, it will trigger an instant mutual crush alert! 🤫"
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 5: LOVE LANGUAGES & ZODIAC COMPATIBILITY ───────────────────────────

@match_v2_bp.route('/love_language/save', methods=['POST'])
def save_love_language():
    data = request.json or {}
    user_id = data.get('user_id')
    love_language = data.get('love_language')  # Words, Quality Time, Gifts, Acts, Touch
    zodiac = data.get('zodiac')

    if not user_id or not love_language:
        return jsonify({"error": "user_id and love_language are required"}), 400

    try:
        db = firestore.client()
        db.collection('match_profiles').document(user_id).set({
            'love_language': love_language,
            'zodiac': zodiac
        }, merge=True)
        return jsonify({"status": "success", "message": "Love Language & Zodiac saved!"}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── PHASE 6: WINGMAN AI CHAT ICEBREAKERS ──────────────────────────────────────

@match_v2_bp.route('/wingman/icebreaker', methods=['GET'])
def get_wingman_icebreaker():
    topic = request.args.get('topic', 'general')
    icebreakers = [
        "If we could skip the small talk, what's your absolute favorite spot on campus?",
        "Quick debate: Best campus cafeteria meal — Chapati & Beans vs Rice & Chicken? 🍲",
        "Scale of 1-10, how stressed are you about upcoming exams? Let's get coffee instead! ☕",
        "What's one song that automatically puts you in a good mood for a Friday night?",
        "If you could teleport anywhere right now for a weekend date, where would we go? ✈️"
    ]
    import random
    selected = random.choice(icebreakers)
    return jsonify({"status": "success", "icebreaker": selected}), 200


# ── PHASE 7: CO-WATCH MOVIE & MUSIC LOUNGE ────────────────────────────────────

@match_v2_bp.route('/cowatch/create', methods=['POST'])
def create_cowatch_session():
    data = request.json or {}
    user_id = data.get('user_id')
    match_id = data.get('match_id')
    video_url = data.get('video_url', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ')

    if not user_id or not match_id:
        return jsonify({"error": "user_id and match_id are required"}), 400

    try:
        db = firestore.client()
        ref = db.collection('cowatch_sessions').document(match_id)
        ref.set({
            'session_id': match_id,
            'host_id': user_id,
            'video_url': video_url,
            'is_playing': True,
            'current_time': 0,
            'updated_at': firestore.SERVER_TIMESTAMP
        }, merge=True)

        return jsonify({"status": "success", "message": "Co-Watch Lounge created!", "session_id": match_id}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500




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


# ── PHASE 10: GAMIFICATION & STREAKS ──────────────────────────

@match_v2_bp.route('/gamification/log_activity', methods=['POST'])
def log_activity():
    """
    Logs user activity (login, match, swipe) and updates their Comrade Score & Streaks.
    Awards free delivery vouchers for 7-day streaks.
    """
    data = request.json or {}
    user_id = data.get('user_id')
    activity_type = data.get('activity_type', 'login') # login, swipe, match, message
    
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400
        
    try:
        db = firestore.client()
        user_ref = db.collection('match_profiles').document(user_id)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            return jsonify({"error": "User profile not found"}), 404
            
        profile_data = user_doc.to_dict()
        
        # Calculate score points
        points_map = {'login': 10, 'swipe': 2, 'match': 50, 'message': 5}
        points_earned = points_map.get(activity_type, 0)
        
        current_score = profile_data.get('comrade_score', 0)
        current_streak = profile_data.get('comrade_streak_days', 0)
        last_active = profile_data.get('last_active_date')
        
        now = datetime.utcnow()
        today_str = now.strftime('%Y-%m-%d')
        yesterday_str = (now - __import__('datetime').timedelta(days=1)).strftime('%Y-%m-%d')
        
        reward_issued = False
        reward_msg = ""
        
        if last_active == today_str:
            # Already logged in today, just add points
            new_score = current_score + points_earned
            new_streak = current_streak
        elif last_active == yesterday_str:
            # Maintained streak!
            new_streak = current_streak + 1
            new_score = current_score + points_earned + 20 # Streak bonus
            
            # 7-Day Vendor Bribe!
            if new_streak % 7 == 0:
                reward_issued = True
                reward_msg = "🔥 7-Day Comrade Streak! You earned a Free Delivery Voucher!"
                # Mint a voucher in their wallet
                db.collection('users').document(user_id).collection('vouchers').add({
                    'type': 'free_delivery',
                    'title': 'Comrade 7-Day Streak Reward',
                    'discount_ksh': 50,
                    'is_used': False,
                    'created_at': firestore.SERVER_TIMESTAMP,
                    'expires_at': now + __import__('datetime').timedelta(days=7)
                })
        else:
            # Streak broken
            new_streak = 1
            new_score = current_score + points_earned
            
        update_data = {
            'comrade_score': new_score,
            'comrade_streak_days': new_streak,
            'last_active_date': today_str,
            'updated_at': firestore.SERVER_TIMESTAMP
        }
        
        user_ref.update(update_data)
        
        return jsonify({
            "status": "success",
            "comrade_score": new_score,
            "streak_days": new_streak,
            "points_earned": points_earned,
            "reward_issued": reward_issued,
            "reward_msg": reward_msg
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


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


# ==========================================
# SUPPORT TICKETS (Cross-Dashboard)
# ==========================================
@match_v2_bp.route('/support/create_ticket', methods=['POST'])
def create_support_ticket():
    try:
        from firebase_admin import messaging
        data = request.json
        user_id = data.get('user_id')
        user_role = data.get('user_role')
        message = data.get('message')

        if not all([user_id, user_role, message]):
            return jsonify({'error': 'Missing required fields'}), 400

        ticket_ref = db.collection('support_tickets').document()
        ticket_ref.set({
            'user_id': user_id,
            'user_role': user_role,
            'message': message,
            'status': 'open',
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        # Send FCM to admins
        try:
            admin_msg = messaging.Message(
                notification=messaging.Notification(
                    title=f"New Support Ticket ({user_role.capitalize()})",
                    body=f"{message[:50]}..."
                ),
                topic='admin_alerts'
            )
            messaging.send(admin_msg)
        except Exception as e:
            print(f"Error sending admin FCM: {e}")

        return jsonify({'message': 'Ticket created successfully', 'ticket_id': ticket_ref.id}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
