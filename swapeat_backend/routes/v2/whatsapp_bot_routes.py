from flask import Blueprint, request, jsonify
from firebase_admin import firestore

whatsapp_bot_bp = Blueprint('whatsapp_bot_v2', __name__)

@whatsapp_bot_bp.route('/whatsapp/webhook', methods=['POST'])
def whatsapp_webhook():
    from twilio.twiml.messaging_response import MessagingResponse
    
    db = firestore.client()
    
    incoming_msg = request.values.get('Body', '').strip()
    sender = request.values.get('From', '')
    
    # Twilio sends phone numbers as 'whatsapp:+2547XXXXXXXX'
    phone_number = sender.replace('whatsapp:', '')
    
    resp = MessagingResponse()
    msg = resp.message()
    
    try:
        # 1. Identify User
        users_ref = db.collection('users').where('phone', '==', phone_number).limit(1).stream()
        user_doc = None
        for u in users_ref:
            user_doc = u
            break
            
        if not user_doc:
            msg.body("Welcome to Keja Yangu! We couldn't find an account linked to this phone number. Please register on the web portal first.")
            return str(resp)
            
        user_data = user_doc.to_dict()
        role = user_data.get('role', 'student')
        user_id = user_doc.id
        
        # 2. Get/Create Session State
        session_ref = db.collection('whatsapp_sessions').document(phone_number)
        session_doc = session_ref.get()
        
        if not session_doc.exists:
            session_ref.set({'step': 'main_menu', 'user_id': user_id, 'role': role})
            step = 'main_menu'
        else:
            step = session_doc.to_dict().get('step', 'main_menu')
            
        # 3. Handle Main Menu
        if incoming_msg.lower() in ['hi', 'hello', 'menu', 'home']:
            session_ref.update({'step': 'main_menu'})
            step = 'main_menu'
            
        if step == 'main_menu':
            if role == 'merchant':
                msg.body("👋 Welcome to House Owner Hub!\n\nReply with a number:\n1️⃣ Manage Listings\n2️⃣ Review Applications\n3️⃣ Maintenance Hub\n4️⃣ KYC Verification")
                session_ref.update({'step': 'awaiting_menu_selection'})
            else:
                msg.body("👋 Welcome to Keja Yangu!\n\nReply with a number:\n1️⃣ Report Maintenance Issue")
                session_ref.update({'step': 'awaiting_menu_selection'})
            return str(resp)
            
        # 4. Handle Merchant Selections
        if role == 'merchant' and step == 'awaiting_menu_selection':
            if incoming_msg == '1':
                # Quick count of rooms
                rooms_ref = db.collection('rooms').where('merchant_id', '==', user_id).stream()
                count = sum(1 for _ in rooms_ref)
                msg.body(f"🏠 You have {count} active rooms. To edit them, please use the web dashboard.")
            elif incoming_msg == '2':
                # Get pending apps
                apps = db.collection('housing_applications').where('merchant_id', '==', user_id).where('status', '==', 'Pending').stream()
                app_list = list(apps)
                if not app_list:
                    msg.body("✅ You have no pending applications right now.")
                else:
                    msg.body(f"🔔 You have {len(app_list)} pending application(s). Check the web dashboard to review.")
            elif incoming_msg == '3':
                # Maintenance Hub
                msg.body("🔧 Maintenance Hub: Please check your web dashboard for open tickets.")
            elif incoming_msg == '4':
                msg.body("To complete KYC, reply with a secure link (Google Drive, Imgur) to your ID or Title Deed.")
                session_ref.update({'step': 'awaiting_kyc_link'})
            else:
                msg.body("Invalid choice. Reply 'Menu' to go back.")
                
        # Handle Merchant KYC link
        elif role == 'merchant' and step == 'awaiting_kyc_link':
            if 'http' in incoming_msg:
                # Mock save to KYC
                db.collection('users').document(user_id).update({'kyc_document': incoming_msg, 'is_verified': 'Pending'})
                msg.body("✅ KYC Document received! Admin will review it shortly. Reply 'Menu' for options.")
                session_ref.update({'step': 'main_menu'})
            else:
                msg.body("Please send a valid secure link (starting with http/https).")
                
        # 5. Handle Student Selections
        elif role == 'student' and step == 'awaiting_menu_selection':
            if incoming_msg == '1':
                msg.body("🔧 To report maintenance, please reply with a short description of the issue.")
                session_ref.update({'step': 'awaiting_maintenance_desc'})
            else:
                msg.body("Invalid choice. Reply 'Menu' to go back.")
                
        elif role == 'student' and step == 'awaiting_maintenance_desc':
            session_ref.update({'step': 'awaiting_maintenance_link', 'temp_desc': incoming_msg})
            msg.body("Got it. Now reply with a secure link to a photo/video of the issue (Google Drive, Imgur, etc).")
            
        elif role == 'student' and step == 'awaiting_maintenance_link':
            if 'http' in incoming_msg:
                desc = session_doc.to_dict().get('temp_desc', 'Reported via WhatsApp')
                # Try to find their active room
                apps = db.collection('housing_applications').where('student_id', '==', user_id).where('status', '==', 'Approved').limit(1).stream()
                room_id = 'Unknown'
                merchant_id = 'Unknown'
                for app in apps:
                    data = app.to_dict()
                    room_id = data.get('room_id', 'Unknown')
                    merchant_id = data.get('merchant_id', 'Unknown')
                    
                db.collection('maintenance').document().set({
                    'student_id': user_id,
                    'room_id': room_id,
                    'merchant_id': merchant_id,
                    'issue_type': 'WhatsApp Report',
                    'description': desc,
                    'image_url': incoming_msg,
                    'status': 'Open',
                    'timestamp': firestore.SERVER_TIMESTAMP
                })
                msg.body("✅ Maintenance ticket created! The House Owner has been notified. Reply 'Menu' for options.")
                session_ref.update({'step': 'main_menu'})
            else:
                msg.body("Please send a valid secure link (starting with http/https).")
                
        return str(resp)

    except Exception as e:
        msg.body(f"Oops! Something went wrong: {str(e)}")
        return str(resp)
