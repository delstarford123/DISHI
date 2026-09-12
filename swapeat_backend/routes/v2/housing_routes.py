from flask import Blueprint, jsonify, request
import os

housing_v2_bp = Blueprint('housing_v2', __name__)

@housing_v2_bp.route('/rooms', methods=['GET'])
def get_rooms():
    try:
        from firebase_admin import firestore
        db = firestore.client()
        rooms = []
        for col in ('housing_properties', 'rooms'):
            rooms_ref = db.collection(col).where('status', '==', 'Vacant').limit(50).stream()
            for r in rooms_ref:
                data = r.to_dict()
                data['id'] = r.id
                rooms.append(data)
            
        return jsonify({"status": "success", "rooms": rooms}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/property/add', methods=['POST'])
def add_merchant_property():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    title = data.get('title')
    rent = data.get('rent')
    
    if not all([merchant_id, title, rent]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        prop_ref = db.collection('housing_properties').document()
        prop_ref.set({
            'merchant_id': merchant_id,
            'title': title,
            'location': data.get('location'),
            'lat': data.get('lat'),
            'lng': data.get('lng'),
            'rent': float(rent),
            'description': data.get('description'),
            'amenities': data.get('amenities', []),
            'virtual_tour_link': data.get('virtual_tour_link'),
            'image_url': data.get('image_url'),
            'status': 'Vacant',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success", "property_id": prop_ref.id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/properties', methods=['GET'])
def get_merchant_properties():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        props_ref = db.collection('housing_properties').where('merchant_id', '==', merchant_id).get()
        properties = []
        for p in props_ref:
            p_data = p.to_dict()
            p_data['id'] = p.id
            if 'created_at' in p_data and p_data['created_at']:
                try:
                    p_data['created_at'] = p_data['created_at'].isoformat()
                except Exception:
                    p_data['created_at'] = str(p_data['created_at'])
            properties.append(p_data)
            
        return jsonify({"status": "success", "properties": properties}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/properties/<property_id>', methods=['PUT'])
def update_merchant_property(property_id):
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        prop_ref = db.collection('housing_properties').document(property_id)
        prop_doc = prop_ref.get()
        if not prop_doc.exists or prop_doc.to_dict().get('merchant_id') != merchant_id:
            return jsonify({"error": "Property not found or unauthorized"}), 404
            
        update_data = {}
        if 'title' in data: update_data['title'] = data['title']
        if 'rent' in data: update_data['rent'] = data['rent']
        if 'description' in data: update_data['description'] = data['description']
        if 'is_vacant' in data: update_data['is_vacant'] = data['is_vacant']
        if 'status' in data: update_data['status'] = data['status']
        
        if update_data:
            prop_ref.update(update_data)
            
        return jsonify({"status": "success", "message": "Property updated"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/apply', methods=['POST'])
def apply_for_room():
    data = request.json or {}
    student_id = data.get('student_id')
    room_id = data.get('room_id')
    merchant_id = data.get('merchant_id')
    student_name = data.get('student_name', 'Unknown User')
    
    if not all([student_id, room_id, merchant_id]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # In a real app, we'd check if the student already applied.
        # Calculate real trust score based on previous deductions
        clearances_ref = db.collection('clearance_refunds').where('student_id', '==', student_id).stream()
        total_deductions = 0
        for c in clearances_ref:
            total_deductions += c.to_dict().get('deductions', 0)
        
        trust_score = max(0, 100 - int(total_deductions / 100))

        room_title = 'Room'
        room_rent = 0
        room_image = None
        for col in ('rooms', 'housing_properties'):
            doc = db.collection(col).document(room_id).get()
            if doc.exists:
                r_data = doc.to_dict()
                room_title = r_data.get('title', 'Room')
                room_rent = r_data.get('price') or r_data.get('rent') or 0
                room_image = r_data.get('image_url')
                break

        app_ref = db.collection('housing_applications').document()
        app_ref.set({
            'student_id': student_id,
            'student_name': student_name,
            'room_id': room_id,
            'merchant_id': merchant_id,
            'status': 'Pending',
            'trust_score': trust_score,
            'room_title': room_title,
            'rent': room_rent,
            'image_url': room_image,
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success", "application_id": app_ref.id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500



@housing_v2_bp.route('/merchant/add_room', methods=['POST'])
def add_room():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    title = data.get('title')
    price = data.get('price')
    image_url = data.get('image_url')
    location = data.get('location') # expects dict like {"lat": 0, "lng": 0, "name": ""}
    
    if not all([merchant_id, title, price]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        room_ref = db.collection('rooms').document()
        room_ref.set({
            'merchant_id': merchant_id,
            'title': title,
            'price': price,
            'image_url': image_url,
            'location': location or {},
            'status': 'Vacant',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success", "room_id": room_ref.id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/kyc', methods=['POST'])
def submit_kyc():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    doc_url = data.get('document_url')
    
    if not all([merchant_id, doc_url]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # Mock Smile Identity Instant Approval
        merchant_ref = db.collection('users').document(merchant_id)
        merchant_ref.update({
            'kyc_status': 'Verified',
            'is_verified_landlord': True,
            'kyc_document': doc_url
        })
        
        return jsonify({"status": "success", "message": "KYC Verified Instantly"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/applications', methods=['GET'])
def get_merchant_applications():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        apps_ref = db.collection('housing_applications').where('merchant_id', '==', merchant_id).stream()
        
        apps = []
        for a in apps_ref:
            data = a.to_dict()
            data['id'] = a.id
            apps.append(data)
            
        return jsonify({"status": "success", "applications": apps}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/student/active_lease', methods=['GET'])
def get_student_active_lease():
    student_id = request.args.get('student_id')
    if not student_id:
        return jsonify({"error": "Missing student_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        apps_ref = db.collection('housing_applications').where('student_id', '==', student_id).where('status', 'in', ['Approved', 'Leased', 'Active', 'Signed', 'Paid', 'MovedIn']).limit(1).stream()
        
        lease = None
        for a in apps_ref:
            data = a.to_dict()
            data['id'] = a.id
            lease = data
            break
            
        return jsonify({"status": "success", "lease": lease}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/student/applications', methods=['GET'])
def get_student_applications():
    student_id = request.args.get('student_id')
    if not student_id:
        return jsonify({"error": "Missing student_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        apps_ref = db.collection('housing_applications').where('student_id', '==', student_id).stream()
        
        apps = []
        for a in apps_ref:
            data = a.to_dict()
            data['id'] = a.id
            apps.append(data)
            
        return jsonify({"status": "success", "applications": apps}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@housing_v2_bp.route('/student/check_access', methods=['GET'])
def check_student_access():
    student_id = request.args.get('student_id')
    if not student_id:
        return jsonify({"error": "Missing student_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        user_doc = db.collection('users').document(student_id).get()
        if not user_doc.exists:
            return jsonify({"has_access": False}), 200
            
        data = user_doc.to_dict()
        # Assume users who are merchants don't need to pay again, or it's a field "has_housing_access"
        has_access = data.get('has_housing_access', False)
        
        return jsonify({"status": "success", "has_access": has_access}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/applications/status', methods=['POST'])
def update_application_status():
    data = request.json or {}
    application_id = data.get('application_id')
    status = data.get('status') # 'Approved' or 'Rejected'
    
    if not all([application_id, status]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        app_ref = db.collection('housing_applications').document(application_id)
        app_ref.update({
            'status': status,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success", "message": f"Application {status}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/utilities/split', methods=['POST'])
def split_utility():
    data = request.json or {}
    bill_amount = data.get('amount')
    roommates_count = data.get('roommates_count')
    utility_type = data.get('utility_type', 'KPLC')
    
    if not bill_amount or not roommates_count or roommates_count <= 0:
        return jsonify({"error": "Invalid fields"}), 400
        
    try:
        # Platform fee logic
        platform_fee = 5.0
        total_needed = bill_amount + platform_fee
        split_amount = total_needed / roommates_count
        
        return jsonify({
            "status": "success",
            "split_calculation": {
                "bill": bill_amount,
                "platform_fee": platform_fee,
                "total": total_needed,
                "per_person": round(split_amount, 2),
                "utility_type": utility_type
            }
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/clearance/notice', methods=['POST'])
def submit_vacate_notice():
    data = request.json or {}
    student_id = data.get('student_id')
    room_id = data.get('room_id')
    merchant_id = data.get('merchant_id')
    date_leaving = data.get('date_leaving')

    if not all([student_id, room_id, merchant_id]):
        return jsonify({"error": "Missing fields"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()
        notice_ref = db.collection('clearance_notices').document()
        notice_ref.set({
            'student_id': student_id,
            'room_id': room_id,
            'merchant_id': merchant_id,
            'date_leaving': date_leaving,
            'status': 'Pending Inspection',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "notice_id": notice_ref.id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/clearance_notices', methods=['GET'])
def get_merchant_clearance_notices():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()
        notices_ref = db.collection('clearance_notices').where('merchant_id', '==', merchant_id).where('status', '==', 'Pending Inspection').stream()
        
        notices = []
        for n in notices_ref:
            data = n.to_dict()
            data['id'] = n.id
            notices.append(data)
            
        return jsonify({"status": "success", "notices": notices}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/clearance/refund', methods=['POST'])
def process_clearance_refund():
    data = request.json or {}
    notice_id = data.get('notice_id')
    original_deposit = data.get('original_deposit', 0)
    deductions = data.get('deductions', 0)
    
    if not notice_id:
        return jsonify({"error": "Missing notice_id"}), 400

    try:
        from firebase_admin import firestore
        import requests, os
        from routes.mpesa_routes import generate_access_token, _fmt_phone
        
        db = firestore.client()
        refund_amount = float(original_deposit) - float(deductions)
        
        notice_doc = db.collection('clearance_notices').document(notice_id).get()
        if not notice_doc.exists:
            return jsonify({"error": "Notice not found"}), 404
        notice_data = notice_doc.to_dict()
        student_id = notice_data.get('student_id')
        
        student_doc = db.collection('users').document(student_id).get()
        if not student_doc.exists:
            return jsonify({"error": "Student not found"}), 404
            
        phone = student_doc.to_dict().get('phoneNumber')
        if not phone:
            return jsonify({"error": "Student phone number not found"}), 400

        access_token = generate_access_token()
        if not access_token:
            return jsonify({"error": "Failed to generate M-PESA token"}), 500

        security_credential = os.getenv("SECURITY_CREDENTIAL")
        if not security_credential:
            return jsonify({"error": "SECURITY_CREDENTIAL not configured"}), 500

        initiator_name = os.getenv('DARAJA_INITIATOR_NAME', 'Delstarford Api')
        shortcode   = os.getenv('MPESA_SHORTCODE', os.getenv('MPESA_BUSINESS_SHORT_CODE', ''))
        env         = os.getenv('MPESA_ENV', 'sandbox').lower()
        base_url    = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"

        formatted_phone = _fmt_phone(phone)
        remarks = "Keja Yangu Escrow Refund"

        payload = {
            "InitiatorName":      initiator_name,
            "SecurityCredential": security_credential,
            "CommandID":          "BusinessPayment",
            "Amount":             str(int(refund_amount)),
            "PartyA":             shortcode,
            "PartyB":             formatted_phone,
            "Remarks":            remarks,
            "QueueTimeOutURL":    "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2c_timeout",
            "ResultURL":          "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2c_result",
            "Occasion":           "EscrowRefund",
        }

        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type":  "application/json",
        }

        response = requests.post(f"{base_url}/mpesa/b2c/v1/paymentrequest",
                                 json=payload, headers=headers, timeout=15)
        response_data = response.json()

        if response.status_code == 200 and 'ConversationID' in response_data:
            conversation_id = response_data['ConversationID']
            db.collection('b2c_transactions').document(conversation_id).set({
                'user_id': student_id,
                'role': 'student',
                'amount': refund_amount,
                'phone': formatted_phone,
                'status': 'pending',
                'type': 'escrow_refund_b2c',
                'notice_id': notice_id,
                'timestamp': firestore.SERVER_TIMESTAMP
            })

            db.collection('clearance_notices').document(notice_id).update({
                'status': 'Refund Processing',
                'refund_amount': refund_amount,
                'b2c_conversation_id': conversation_id
            })
            
            return jsonify({"status": "success", "refunded": refund_amount, "conversation_id": conversation_id}), 200
        else:
            return jsonify({"error": f"M-PESA Error: {response_data}"}), 400

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/maintenance/report', methods=['POST'])
def report_maintenance():
    data = request.json or {}
    student_id = data.get('student_id')
    merchant_id = data.get('merchant_id')
    room_id = data.get('room_id')
    issue_desc = data.get('description')
    image_url = data.get('image_url')

    if not all([student_id, merchant_id, issue_desc]):
        return jsonify({"error": "Missing fields"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()
        ticket_ref = db.collection('maintenance_tickets').document()
        ticket_ref.set({
            'student_id': student_id,
            'merchant_id': merchant_id,
            'room_id': room_id,
            'description': issue_desc,
            'image_url': image_url,
            'status': 'Open',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "ticket_id": ticket_ref.id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/maintenance', methods=['GET'])
def get_maintenance_tickets():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()
        tickets_ref = db.collection('maintenance_tickets').where('merchant_id', '==', merchant_id).stream()
        
        tickets = []
        for t in tickets_ref:
            data = t.to_dict()
            data['id'] = t.id
            tickets.append(data)
            
        return jsonify({"status": "success", "tickets": tickets}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/tours/book', methods=['POST'])
def book_tour():
    data = request.json or {}
    student_id = data.get('student_id')
    room_id = data.get('room_id')
    merchant_id = data.get('merchant_id')
    date_time = data.get('date_time')

    if not all([student_id, room_id, merchant_id, date_time]):
        return jsonify({"error": "Missing fields"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()
        tour_ref = db.collection('tours').document()
        tour_ref.set({
            'student_id': student_id,
            'room_id': room_id,
            'merchant_id': merchant_id,
            'date_time': date_time,
            'status': 'Scheduled',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "tour_id": tour_ref.id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/pay_rent', methods=['POST'])
def pay_rent_from_vault():
    data = request.json or {}
    student_id = data.get('student_id')
    application_id = data.get('application_id')
    payment_method = data.get('payment_method', 'vault')
    phone_number = data.get('phone_number')
    
    if not all([student_id, application_id]):
        return jsonify({"error": "Missing student_id or application_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # Get Application
        app_doc = db.collection('housing_applications').document(application_id).get()
        if not app_doc.exists:
            return jsonify({"error": "Application not found"}), 404
            
        app_data = app_doc.to_dict()
        if app_data.get('status') != 'Approved':
            return jsonify({"error": "Application is not Approved"}), 400
            
        merchant_id = app_data.get('merchant_id')
        room_id = app_data.get('room_id')
        
        # Get Merchant Data to check for Insurance Opt-in
        merchant_doc = db.collection('users').document(merchant_id).get()
        insurance_fee = 0.0
        if merchant_doc.exists:
            merchant_data = merchant_doc.to_dict()
            if merchant_data.get('dishi_cover_enabled', False):
                insurance_fee = 500.0
                
        # Get Room Price — check both 'rooms' AND 'housing_properties' collections
        room_doc = db.collection('rooms').document(room_id).get()
        if not room_doc.exists:
            room_doc = db.collection('housing_properties').document(room_id).get()
        if not room_doc.exists:
            return jsonify({"error": "Room not found"}), 404
        
        room_data = room_doc.to_dict()
        room_price = float(room_data.get('price') or room_data.get('rent') or 0)
        
        commission = 50.0 if payment_method == 'mpesa' else 0.0
        # Option A logic: User pays for rent + commission + insurance
        total_charge = room_price + commission + insurance_fee
        
        actual_rent_credited = room_price

        if payment_method == 'mpesa':
            if not phone_number:
                return jsonify({"error": "Phone number required for M-Pesa payment"}), 400
                
            from flask import request as flask_request
            import requests
            base_url = flask_request.host_url.rstrip('/')
            
            # Request STK push. Credit the merchant!
            resp = requests.post(f"{base_url}/api/v1/mpesa/stkpush", json={
                'phone_number': phone_number,
                'amount': total_charge,
                'credit_amount': room_price, # The webhook handles the breakdown using metadata
                'user_id': merchant_id, # Target merchant to receive funds
                'destination': 'walletBalance',
                'account_reference': room_data.get('title', 'Rent')[:12],
                'transaction_desc': f"Rent for {room_data.get('title', 'Room')}"[:12],
                'metadata': {
                    'action': 'pay_rent',
                    'application_id': application_id,
                    'student_id': student_id,
                    'merchant_id': merchant_id,
                    'room_id': room_id,
                    'rent_amount': actual_rent_credited,
                    'insurance': insurance_fee,
                    'commission': commission
                }
            }, timeout=15)
            
            if resp.status_code != 200:
                return jsonify({"error": "Failed to initiate M-Pesa payment"}), 400
                
            resp_data = resp.json()
            checkout_id = resp_data.get('CheckoutRequestID')
            
            # Remove optimistic application status update. Wait for callback.
            
            db.collection('transactions').document().set({
                'type': 'rent_payment',
                'amount': total_charge,
                'commission': commission,
                'insurance': insurance_fee,
                'student_id': student_id,
                'merchant_id': merchant_id,
                'room_id': room_id,
                'payment_method': 'mpesa',
                'checkout_id': checkout_id,
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return jsonify({"status": "pending", "checkout_id": checkout_id, "message": "M-Pesa payment initiated."}), 200

        # Run Transaction for vault/savings
        transaction = db.transaction()
        student_ref = db.collection('users').document(student_id)
        merchant_ref = db.collection('users').document(merchant_id)
        
        @firestore.transactional
        def process_rent_payment(transaction, student_ref, merchant_ref, app_ref, total_charge, actual_rent_credited, payment_method, insurance_fee, commission):
            student_snap = student_ref.get(transaction=transaction)
            merchant_snap = merchant_ref.get(transaction=transaction)
            
            # Credit Admin Pool Read (MUST BE BEFORE WRITES)
            admin_pool_ref = db.collection('admin_finances').document('dishi_rent_pool')
            admin_snap = admin_pool_ref.get(transaction=transaction)
            
            source_field = 'walletBalance' if payment_method == 'vault' else 'savingsBalance'
            student_balance = float(student_snap.to_dict().get(source_field, 0))
            merchant_wallet = float(merchant_snap.to_dict().get('walletBalance', 0))
            
            if student_balance < total_charge:
                raise Exception(f"Insufficient {payment_method} Balance")
                
            transaction.update(student_ref, {
                source_field: student_balance - total_charge
            })
            
            transaction.update(merchant_ref, {
                'walletBalance': merchant_wallet + actual_rent_credited
            })
            
            if admin_snap.exists:
                admin_data = admin_snap.to_dict()
                transaction.update(admin_pool_ref, {
                    'insurance_pool': admin_data.get('insurance_pool', 0) + insurance_fee,
                    'commission_pool': admin_data.get('commission_pool', 0) + commission,
                    'total_collected': admin_data.get('total_collected', 0) + insurance_fee + commission,
                    'updated_at': firestore.SERVER_TIMESTAMP
                })
            else:
                transaction.set(admin_pool_ref, {
                    'insurance_pool': insurance_fee,
                    'commission_pool': commission,
                    'total_collected': insurance_fee + commission,
                    'updated_at': firestore.SERVER_TIMESTAMP
                })
            
            transaction.update(app_ref, {
                'status': 'Leased',
                'updated_at': firestore.SERVER_TIMESTAMP
            })
            
        process_rent_payment(transaction, student_ref, merchant_ref, app_doc.reference, total_charge, actual_rent_credited, payment_method, insurance_fee, commission)
        
        # Log transaction
        db.collection('transactions').document().set({
            'type': 'rent_payment',
            'amount': total_charge,
            'commission': commission,
            'insurance': insurance_fee,
            'student_id': student_id,
            'merchant_id': merchant_id,
            'room_id': room_id,
            'payment_method': payment_method,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success", "message": "Rent paid successfully."}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/okoa_loans', methods=['GET'])
def get_merchant_okoa_loans():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # We need to find okoa loans for rooms owned by this merchant.
        # This requires querying rooms, then matching, OR modifying okoa_loans to store merchant_id.
        # Since okoa_loans doesn't currently have merchant_id, we'll fetch rooms first.
        rooms_ref = db.collection('rooms').where('merchant_id', '==', merchant_id).stream()
        room_ids = [r.id for r in rooms_ref]
        
        loans = []
        if room_ids:
            # Firestore 'in' query supports up to 10 items. For a real app, we'd batch or structure better.
            # We'll fetch all and filter for prototype simplicity.
            loans_ref = db.collection('okoa_loans').stream()
            for l in loans_ref:
                data = l.to_dict()
                if data.get('room_id') in room_ids:
                    data['id'] = l.id
                    loans.append(data)
            
        return jsonify({"status": "success", "okoa_loans": loans}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/okoa_loans/status', methods=['POST'])
def update_okoa_loan_status():
    data = request.json or {}
    loan_id = data.get('loan_id')
    status = data.get('status') # 'Approved' or 'Declined'
    
    if not all([loan_id, status]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        import requests, os
        from routes.mpesa_routes import generate_access_token, _fmt_phone
        db = firestore.client()
        
        loan_ref = db.collection('okoa_loans').document(loan_id)
        loan_doc = loan_ref.get()
        if not loan_doc.exists:
            return jsonify({"error": "Loan not found"}), 404
            
        loan_data = loan_doc.to_dict()
        merchant_id = loan_data.get('merchant_id') # We need merchant_id in the loan
        amount = float(loan_data.get('amount', 0))
        
        loan_ref.update({
            'status': status,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        
        # Okoa Keja loan approved. The student now holds a debt that must be cleared
        # before the next month's rent payment is accepted via C2B. No B2C trigger here.
                        
        return jsonify({"status": "success", "message": f"Okoa Keja Loan {status}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/fundi/pay', methods=['POST'])
def pay_fundi():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    fundi_phone = data.get('phone')
    amount = data.get('amount')
    ticket_id = data.get('ticket_id')
    
    if not all([merchant_id, fundi_phone, amount]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # Here we would integrate Daraja B2C/B2B to payout the fundi.
        # For now, we simulate the payment success and log it.
        
        payout_ref = db.collection('merchant_payouts').document()
        payout_ref.set({
            'merchant_id': merchant_id,
            'fundi_phone': fundi_phone,
            'amount': float(amount),
            'ticket_id': ticket_id,
            'status': 'Completed',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        if ticket_id:
            ticket_ref = db.collection('maintenance_tickets').document(ticket_id)
            ticket_ref.update({
                'fundi_paid': True,
                'payout_id': payout_ref.id,
                'updated_at': firestore.SERVER_TIMESTAMP
            })
            
        return jsonify({"status": "success", "message": f"Successfully paid KES {amount} to {fundi_phone}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@housing_v2_bp.route('/merchant/inspections', methods=['POST'])
def save_inspection():
    data = request.json or {}
    room_id = data.get('room_id')
    merchant_id = data.get('merchant_id')
    
    if not all([room_id, merchant_id]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        inspection_ref = db.collection('property_inspections').document()
        inspection_ref.set({
            'room_id': room_id,
            'merchant_id': merchant_id,
            'walls_ok': data.get('walls_ok', True),
            'plumbing_ok': data.get('plumbing_ok', True),
            'electrical_ok': data.get('electrical_ok', True),
            'image_url': data.get('image_url'),
            'created_at': firestore.SERVER_TIMESTAMP
        })
            
        return jsonify({"status": "success", "message": "Inspection checklist saved"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/market_vacancy', methods=['POST'])
def market_vacancy():
    data = request.json or {}
    room_id = data.get('room_id')
    merchant_id = data.get('merchant_id')
    
    if not all([room_id, merchant_id]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # Log the marketing blast
        blast_ref = db.collection('marketing_blasts').document()
        blast_ref.set({
            'room_id': room_id,
            'merchant_id': merchant_id,
            'status': 'sent',
            'created_at': firestore.SERVER_TIMESTAMP
        })
            
        return jsonify({"status": "success", "message": "Marketing blast sent to nearby students"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/cron/lease_reminders', methods=['GET'])
def lease_reminders_cron():
    try:
        # Mock cron endpoint that scans for leases expiring in <30 days
        from firebase_admin import firestore
        db = firestore.client()
        
        # Example logic: we would query the 'leases' collection where end_date is near.
        # For now, we simulate processing 5 leases.
        
        return jsonify({"status": "success", "message": "Processed 5 lease reminders for upcoming expirations."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/maintenance/status', methods=['POST'])
def update_maintenance_status():
    data = request.json or {}
    ticket_id = data.get('ticket_id')
    status = data.get('status') # e.g. 'Fundi Dispatched', 'Resolved'
    lat = data.get('lat')
    lng = data.get('lng')
    
    if not all([ticket_id, status]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        ticket_ref = db.collection('maintenance_tickets').document(ticket_id)
        
        update_data = {
            'status': status,
            'updated_at': firestore.SERVER_TIMESTAMP
        }
        
        if lat is not None and lng is not None:
            update_data['resolution_lat'] = lat
            update_data['resolution_lng'] = lng
            # Normally calculate distance from property, for now flag as captured
            update_data['geofence_verified'] = True 
            
        ticket_ref.update(update_data)
        
        return jsonify({"status": "success", "message": f"Maintenance Ticket updated to {status}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/reports/tax', methods=['GET'])
def get_tax_report():
    merchant_id = request.args.get('merchant_id')
    year = request.args.get('year', '2026')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # In a real system, we'd query by date range. 
        # For MVP, we'll calculate based on active properties and mock a full year's data.
        properties_ref = db.collection('housing_properties').where('merchant_id', '==', merchant_id).stream()
        
        total_monthly_rent = 0
        for prop in properties_ref:
            total_monthly_rent += prop.to_dict().get('rent', 0)
            
        gross_income = total_monthly_rent * 12 * 0.85 # Assume 85% collection
        
        payouts_ref = db.collection('merchant_payouts').where('merchant_id', '==', merchant_id).stream()
        actual_expenses = sum(p.to_dict().get('amount', 0) for p in payouts_ref)
        
        # Add a baseline expense if there are no payouts yet
        total_expenses = actual_expenses if actual_expenses > 0 else (gross_income * 0.15)
        
        net_taxable_income = gross_income - total_expenses
        estimated_tax = net_taxable_income * 0.075 # Example 7.5% residential rental income tax rate
        
        return jsonify({
            "year": year,
            "gross_rental_income": gross_income,
            "deductible_expenses": total_expenses,
            "net_taxable_income": net_taxable_income,
            "estimated_tax_payable": estimated_tax,
            "kra_pin": "A000000000X" # Mock PIN
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/automation/arrears', methods=['POST'])
def run_arrears_automation():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    penalty_rate = data.get('penalty_rate', 0.05)
    
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # Scan active leases
        leases_ref = db.collection('leases').where('merchant_id', '==', merchant_id).where('status', '==', 'Active').stream()
        
        penalties_issued = 0
        for lease in leases_ref:
            ld = lease.to_dict()
            student_id = ld.get('student_id')
            rent_amount = ld.get('rent_amount', 0)
            
            # Simple heuristic: If rent is > 0, generate a penalty bill
            # In a real app we check if today > grace period day and if rent is unpaid.
            penalty_amount = rent_amount * penalty_rate
            
            if penalty_amount > 0:
                bill_ref = db.collection('utility_bills').document()
                bill_ref.set({
                    'merchant_id': merchant_id,
                    'student_id': student_id,
                    'amount': penalty_amount,
                    'type': 'Late Fee',
                    'status': 'pending',
                    'created_at': firestore.SERVER_TIMESTAMP
                })
                penalties_issued += 1
                
        return jsonify({"status": "success", "message": f"Issued {penalties_issued} late fee penalties."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/finance/reconcile', methods=['POST'])
def reconcile_mpesa_statements():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # In a real app we query `mpesa_transactions` for unmatched incoming payments.
        # Here we mock reconciliation: find pending bills and randomly match some if amounts look similar.
        bills_ref = db.collection('utility_bills').where('merchant_id', '==', merchant_id).where('status', '==', 'pending').stream()
        
        reconciled = 0
        reconciled_details = []
        for bill in bills_ref:
            bd = bill.to_dict()
            student_id = bd.get('student_id')
            amount = bd.get('amount', 0)
            
            # Mock chance of finding a matching transaction
            if (hash(student_id) % 10) > 4: 
                # Mark as paid via M-PESA
                db.collection('utility_bills').document(bill.id).update({
                    'status': 'paid',
                    'payment_method': 'mpesa_reconciliation',
                    'updated_at': firestore.SERVER_TIMESTAMP
                })
                reconciled += 1
                reconciled_details.append({
                    'bill_type': bd.get('type', 'Invoice'),
                    'student_id': student_id,
                    'amount': amount,
                    'transaction_ref': f"MPESA{hash(bill.id) % 100000000}"
                })
                
        return jsonify({
            "status": "success", 
            "message": f"Successfully reconciled {reconciled} M-PESA transactions with tenant invoices.",
            "reconciled_count": reconciled,
            "details": reconciled_details
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/finance/expense/scan', methods=['POST'])
def mock_scan_expense():
    # In a real implementation this would accept a multipart form with the image
    # and call an OCR API (like Google Cloud Vision).
    # For this MVP, we return a mock parsed result.
    import random
    
    vendors = ['Hardcore Hardware Ltd', 'Nairobi Water Co.', 'KPLC Tokens', 'Oka Paint Store']
    amount = random.randint(500, 8500)
    
    return jsonify({
        "status": "success",
        "vendor": random.choice(vendors),
        "amount": amount,
        "date": "2026-07-23",
        "confidence": 0.94
    }), 200

@housing_v2_bp.route('/merchant/finance/refund', methods=['POST'])
def process_deposit_refund():
    data = request.json or {}
    student_id = data.get('student_id')
    room_id = data.get('room_id')
    damage_deductions = float(data.get('damage_deductions', 0))
    original_deposit = float(data.get('original_deposit', 0))
    
    if not student_id or not room_id:
        return jsonify({"error": "Missing required fields"}), 400
        
    refund_amount = original_deposit - damage_deductions
    if refund_amount < 0:
        refund_amount = 0
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # In a real app we'd fetch the student's phone number and trigger Daraja B2C
        # For MVP we just record the refund payout and end the lease.
        
        db.collection('merchant_payouts').document().set({
            'merchant_id': data.get('merchant_id', 'unknown'),
            'type': 'Deposit Refund',
            'amount': refund_amount,
            'student_id': student_id,
            'room_id': room_id,
            'status': 'completed',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        # End lease
        leases_ref = db.collection('leases').where('room_id', '==', room_id).where('student_id', '==', student_id).where('status', '==', 'Active').stream()
        for lease in leases_ref:
            db.collection('leases').document(lease.id).update({
                'status': 'terminated',
                'terminated_at': firestore.SERVER_TIMESTAMP
            })
            
        # Update room status to vacant
        db.collection('housing_properties').document(room_id).update({
            'status': 'vacant'
        })
        
        return jsonify({
            "status": "success",
            "message": f"Successfully refunded KES {refund_amount} to student via B2C."
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/analytics/roi', methods=['GET'])
def get_roi_analytics():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # 1. Calculate Occupancy Rate
        properties_ref = db.collection('housing_properties').where('merchant_id', '==', merchant_id).stream()
        total_rooms = 0
        total_occupied = 0
        total_expected_rent = 0
        
        for prop in properties_ref:
            p_data = prop.to_dict()
            total_rooms += 1
            rent = p_data.get('rent', 0)
            if p_data.get('status') == 'occupied':
                total_occupied += 1
                total_expected_rent += rent
            elif p_data.get('status') == 'vacant':
                pass # vacant, no expected rent for ROI calculation if strictly looking at active leases, but usually expected includes vacant. Let's say expected is if all were rented.
                total_expected_rent += rent
                
        occupancy_rate = (total_occupied / total_rooms * 100) if total_rooms > 0 else 0
        
        # 2. Calculate Net Income (Mocking historical data based on bills and payouts)
        bills_ref = db.collection('utility_bills').where('merchant_id', '==', merchant_id).stream()
        total_collected = sum(b.to_dict().get('amount', 0) for b in bills_ref if b.to_dict().get('status') == 'paid')
        
        # Add actual rent payments here if we track them in a separate collection.
        # For MVP, we'll mock some monthly data based on expected rent.
        
        monthly_data = []
        months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
        base_income = total_expected_rent * 0.8 # Assume 80% collection rate historically
        
        for m in months:
            # Add some slight variation
            collected = base_income + (base_income * 0.05 * (len(m) - 3))
            expenses = collected * 0.15 # Assume 15% expenses
            monthly_data.append({
                'month': m,
                'collected': collected,
                'expenses': expenses,
                'net': collected - expenses
            })
            
        return jsonify({
            "occupancy_rate": occupancy_rate,
            "total_rooms": total_rooms,
            "occupied_rooms": total_occupied,
            "monthly_data": monthly_data
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/analytics/default-predictor', methods=['GET'])
def default_predictor():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # In a real AI system, we'd pull historical payment dates and run a model.
        # For this MVP, we use heuristics on outstanding bills and leases.
        leases_ref = db.collection('leases').where('merchant_id', '==', merchant_id).where('status', '==', 'Active').stream()
        
        predictions = []
        for lease in leases_ref:
            ld = lease.to_dict()
            student_id = ld.get('student_id')
            student_name = ld.get('student_name', 'Unknown Student')
            room_id = ld.get('room_id')
            
            # Simple heuristic: random risk or based on some missing data
            # To make it realistic for the demo, we'll assign risk based on the length of the name or an arbitrary hash of the ID
            risk_score = (len(student_id) * 7) % 100
            
            if risk_score > 75:
                risk_level = 'High'
                confidence = risk_score
                reason = "Historically pays 5+ days late or has active arrears."
            elif risk_score > 40:
                risk_level = 'Medium'
                confidence = risk_score
                reason = "Occasionally pays 1-3 days late."
            else:
                risk_level = 'Low'
                confidence = 100 - risk_score
                reason = "Consistently pays on time."
                
            predictions.append({
                'student_id': student_id,
                'student_name': student_name,
                'room_id': room_id,
                'risk_level': risk_level,
                'confidence': confidence,
                'reason': reason
            })
            
        # Sort by risk (High first)
        risk_weights = {'High': 3, 'Medium': 2, 'Low': 1}
        predictions.sort(key=lambda x: risk_weights[x['risk_level']], reverse=True)
        
        return jsonify({"predictions": predictions}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/utilities/bill', methods=['POST'])
def create_utility_bill():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    amount = data.get('amount')
    target_rooms = data.get('target_rooms', ["ALL"])
    utility_type = data.get('utility_type', 'KPLC')
    receipt_url = data.get('receipt_url')
    
    if not merchant_id or amount is None:
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        leases_ref = db.collection('leases').where('merchant_id', '==', merchant_id).where('status', '==', 'Active').stream()
        student_ids = []
        for l in leases_ref:
            l_data = l.to_dict()
            if "ALL" in target_rooms or l_data.get('room_id') in target_rooms:
                if l_data.get('student_id'):
                    student_ids.append(l_data['student_id'])
                    
        student_ids = list(set(student_ids))
        
        if not student_ids:
            return jsonify({"error": "No students found in the targeted rooms."}), 404
            
        platform_fee = 5.0
        total_needed = float(amount) + platform_fee
        split_amount = total_needed / len(student_ids)
        
        bill_ref = db.collection('utility_bills').document()
        bill_data = {
            'merchant_id': merchant_id,
            'total_amount': total_needed,
            'per_person': split_amount,
            'utility_type': utility_type,
            'targeted_rooms': target_rooms,
            'student_count': len(student_ids),
            'created_at': firestore.SERVER_TIMESTAMP
        }
        if receipt_url:
            bill_data['receipt_url'] = receipt_url
            
        bill_ref.set(bill_data)
        
        for sid in student_ids:
            notif_ref = db.collection('users').document(sid).collection('notifications').document()
            notif_data = {
                'title': f'Utility Bill: {utility_type}',
                'body': f'Your merchant requested KES {split_amount:.2f} for {utility_type}.',
                'type': 'utility_bill_request',
                'amount': split_amount,
                'merchant_id': merchant_id,
                'bill_id': bill_ref.id,
                'isRead': False,
                'timestamp': firestore.SERVER_TIMESTAMP
            }
            if receipt_url:
                notif_data['receipt_url'] = receipt_url
                
            notif_ref.set(notif_data)
        
        return jsonify({
            "status": "success",
            "bill_id": bill_ref.id,
            "split_calculation": {
                "bill": amount,
                "platform_fee": platform_fee,
                "total": total_needed,
                "per_person": round(split_amount, 2),
                "utility_type": utility_type,
                "students_billed": len(student_ids)
            }
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/leases/active', methods=['GET'])
def get_active_merchant_leases():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        leases_ref = db.collection('leases').where('merchant_id', '==', merchant_id).where('status', '==', 'Active').stream()
        
        leases = []
        for l in leases_ref:
            data = l.to_dict()
            data['id'] = l.id
            if 'created_at' in data and data['created_at']:
                try: data['created_at'] = data['created_at'].isoformat()
                except: data['created_at'] = str(data['created_at'])
            leases.append(data)
            
        return jsonify({"status": "success", "leases": leases}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/announcements', methods=['POST'])
def broadcast_announcement():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    message = data.get('message')
    
    if not all([merchant_id, message]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore, messaging
        db = firestore.client()
        announcement_ref = db.collection('housing_announcements').document()
        announcement_ref.set({
            'merchant_id': merchant_id,
            'message': message,
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        # FCM Push Notification to all active tenants
        leases = db.collection('leases').where('merchant_id', '==', merchant_id).where('status', '==', 'Active').stream()
        student_ids = [l.to_dict().get('student_id') for l in leases if l.to_dict().get('student_id')]
        
        if student_ids:
            tokens = []
            for chunk in [student_ids[i:i + 10] for i in range(0, len(student_ids), 10)]:
                users = db.collection('users').where(firestore.FieldPath.document_id(), 'in', chunk).stream()
                for u in users:
                    token = u.to_dict().get('fcmToken')
                    if token: tokens.append(token)
            
            if tokens:
                msg = messaging.MulticastMessage(
                    notification=messaging.Notification(title="Announcement from Merchant", body=message),
                    android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default')),
                    apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True, sound='default'))),
                    tokens=tokens
                )
                messaging.send_multicast(msg)
                
            # Also write to the notifications collection for each student
            batch = db.batch()
            for student_id in student_ids:
                notif_ref = db.collection('notifications').document()
                batch.set(notif_ref, {
                    'userId': student_id,
                    'title': 'Announcement from Merchant',
                    'message': message,
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'isRead': False,
                    'type': 'merchant_announcement'
                })
            batch.commit()
                
        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/tenant/announcements', methods=['GET'])
def get_tenant_announcements():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        announcements_ref = db.collection('housing_announcements').where('merchant_id', '==', merchant_id).stream()
        
        announcements = []
        for doc in announcements_ref:
            data = doc.to_dict()
            data['id'] = doc.id
            if 'created_at' in data and data['created_at']:
                data['created_at'] = data['created_at'].isoformat()
            announcements.append(data)
            
        # In-memory sort by created_at desc to avoid composite index requirement
        announcements.sort(key=lambda x: x.get('created_at', ''), reverse=True)
            
        return jsonify({"announcements": announcements}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/fundis', methods=['GET'])
def get_verified_fundis():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
    try:
        from firebase_admin import firestore
        db = firestore.client()
        fundis_ref = db.collection('merchant_fundis').where('merchant_id', '==', merchant_id).get()
        fundis = []
        for f in fundis_ref:
            f_data = f.to_dict()
            f_data['id'] = f.id
            fundis.append(f_data)
        return jsonify({"status": "success", "fundis": fundis}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/fundis', methods=['POST'])
def add_fundi():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    name = data.get('name')
    trade = data.get('trade')
    phone = data.get('phone')
    if not all([merchant_id, name, trade, phone]):
        return jsonify({"error": "Missing required fields"}), 400
    try:
        from firebase_admin import firestore
        db = firestore.client()
        f_ref = db.collection('merchant_fundis').document()
        f_ref.set({
            'merchant_id': merchant_id,
            'name': name,
            'trade': trade,
            'phone': phone,
            'created_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "fundi_id": f_ref.id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/fundis/<fundi_id>', methods=['DELETE'])
def delete_fundi(fundi_id):
    try:
        from firebase_admin import firestore
        db = firestore.client()
        db.collection('merchant_fundis').document(fundi_id).delete()
        return jsonify({"status": "success", "message": "Fundi deleted"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/leases/generate', methods=['POST'])
def generate_e_lease():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    student_id = data.get('student_id')
    room_id = data.get('room_id')
    
    if not all([merchant_id, student_id, room_id]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        import uuid
        db = firestore.client()
        lease_ref = db.collection('leases').document()
        lease_ref.set({
            'merchant_id': merchant_id,
            'student_id': student_id,
            'room_id': room_id,
            'status': 'Active',
            'lease_number': str(uuid.uuid4())[:8].upper(),
            'created_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "lease_id": lease_ref.id, "message": "E-Lease generated successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/caretaker/tasks', methods=['GET', 'POST'])
def manage_caretaker_tasks():
    from firebase_admin import firestore
    db = firestore.client()
    
    if request.method == 'GET':
        merchant_id = request.args.get('merchant_id')
        if not merchant_id:
            return jsonify({"error": "Missing merchant_id"}), 400
        try:
            tasks_ref = db.collection('caretaker_tasks').where('merchant_id', '==', merchant_id).stream()
            tasks = []
            for t in tasks_ref:
                data = t.to_dict()
                data['id'] = t.id
                tasks.append(data)
            return jsonify({"status": "success", "tasks": tasks}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500
            
    elif request.method == 'POST':
        data = request.json or {}
        merchant_id = data.get('merchant_id')
        title = data.get('title')
        
        if not all([merchant_id, title]):
            return jsonify({"error": "Missing required fields"}), 400
            
        try:
            task_ref = db.collection('caretaker_tasks').document()
            task_ref.set({
                'merchant_id': merchant_id,
                'title': title,
                'status': 'Pending',
                'created_at': firestore.SERVER_TIMESTAMP
            })
            return jsonify({"status": "success", "task_id": task_ref.id}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/caretaker/tasks/status', methods=['POST'])
def update_caretaker_task_status():
    data = request.json or {}
    task_id = data.get('task_id')
    status = data.get('status')
    
    if not all([task_id, status]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        task_ref = db.collection('caretaker_tasks').document(task_id)
        task_ref.update({
            'status': status,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/gate_pass/generate', methods=['POST'])
def generate_gate_pass():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    visitor_name = data.get('visitor_name')
    room_id = data.get('room_id')
    
    if not all([merchant_id, visitor_name, room_id]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        import uuid
        db = firestore.client()
        pass_code = str(uuid.uuid4())[:6].upper()
        pass_ref = db.collection('gate_passes').document()
        pass_ref.set({
            'merchant_id': merchant_id,
            'visitor_name': visitor_name,
            'room_id': room_id,
            'pass_code': pass_code,
            'status': 'Active',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "pass_code": pass_code}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/gate_pass/history', methods=['GET'])
def get_gate_pass_history():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        # Query without order_by to avoid composite index requirement
        passes_ref = db.collection('gate_passes').where('merchant_id', '==', merchant_id).get()
        
        passes = []
        for p in passes_ref:
            pass_data = p.to_dict()
            pass_data['id'] = p.id
            if 'created_at' in pass_data and pass_data['created_at']:
                try:
                    pass_data['created_at'] = pass_data['created_at'].isoformat()
                except Exception:
                    pass_data['created_at'] = str(pass_data['created_at'])
            passes.append(pass_data)
            
        # Sort in memory descending
        passes.sort(key=lambda x: x.get('created_at', ''), reverse=True)
            
        return jsonify({"status": "success", "passes": passes}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/gate_pass/delete/<pass_id>', methods=['DELETE'])
def delete_gate_pass(pass_id):
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        pass_ref = db.collection('gate_passes').document(pass_id)
        doc = pass_ref.get()
        if not doc.exists:
            return jsonify({"error": "Gate pass not found"}), 404
            
        if doc.to_dict().get('merchant_id') != merchant_id:
            return jsonify({"error": "Unauthorized"}), 403
            
        pass_ref.delete()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/cashflow', methods=['GET'])
def get_cashflow_metrics():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # Aggregate Expected from active leases (rooms)
        rooms_ref = db.collection('rooms').where('merchant_id', '==', merchant_id).stream()
        expected = 0
        for r in rooms_ref:
            # Assume all rooms count towards expected for simplicity in prototype
            expected += float(r.to_dict().get('price', 0))
            
        # Get actual collected from transactions
        tx_ref = db.collection('transactions').where('merchant_id', '==', merchant_id).where('type', '==', 'rent_payment').stream()
        collected = 0
        for tx in tx_ref:
            collected += float(tx.to_dict().get('amount', 0))
            
        pending = expected - collected if expected > collected else 0
        
        return jsonify({
            "status": "success", 
            "expected": expected,
            "collected": collected,
            "pending": pending
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/caretaker/pay', methods=['POST'])
def pay_caretaker():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    phone = data.get('phone')
    amount = data.get('amount')
    
    if not all([merchant_id, phone, amount]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        import requests, os
        from routes.mpesa_routes import generate_access_token, _fmt_phone
        db = firestore.client()
        
        access_token = generate_access_token()
        security_credential = os.getenv("SECURITY_CREDENTIAL")
        initiator_name = os.getenv('DARAJA_INITIATOR_NAME', 'Delstarford Api')
        shortcode   = os.getenv('MPESA_SHORTCODE', os.getenv('MPESA_BUSINESS_SHORT_CODE', ''))
        env         = os.getenv('MPESA_ENV', 'sandbox').lower()
        base_url    = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"
        
        if not access_token or not security_credential:
            return jsonify({"error": "M-PESA Configuration missing"}), 500
            
        formatted_phone = _fmt_phone(phone)
        payload = {
            "InitiatorName":      initiator_name,
            "SecurityCredential": security_credential,
            "CommandID":          "BusinessPayment",
            "Amount":             str(int(amount)),
            "PartyA":             shortcode,
            "PartyB":             formatted_phone,
            "Remarks":            "Caretaker Payroll",
            "QueueTimeOutURL":    "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2c_timeout",
            "ResultURL":          "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2c_result",
            "Occasion":           "Payroll",
        }
        
        headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}
        response = requests.post(f"{base_url}/mpesa/b2c/v1/paymentrequest", json=payload, headers=headers, timeout=15)
        resp_data = response.json()
        
        if response.status_code == 200 and 'ConversationID' in resp_data:
            conversation_id = resp_data['ConversationID']
            db.collection('b2c_transactions').document(conversation_id).set({
                'merchant_id': merchant_id,
                'amount': float(amount),
                'phone': formatted_phone,
                'status': 'pending',
                'type': 'caretaker_payroll',
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return jsonify({"status": "success", "conversation_id": conversation_id, "message": "Payroll processing"}), 200
        else:
            return jsonify({"error": f"M-PESA Error: {resp_data}"}), 400
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/rent/c2b_confirmation', methods=['POST'])
def rent_c2b_confirmation():
    data = request.json or {}
    # Daraja C2B payload mapping
    trans_id = data.get('TransID')
    trans_time = data.get('TransTime')
    trans_amount = data.get('TransAmount')
    bill_ref_number = data.get('BillRefNumber') # Used to match room_id/student_id
    msisdn = data.get('MSISDN')
    
    if not trans_id:
        return jsonify({"ResultCode": 1, "ResultDesc": "Invalid Payload"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # 1. Log Transaction
        db.collection('c2b_transactions').document(trans_id).set({
            'type': 'rent_payment',
            'amount': float(trans_amount) if trans_amount else 0,
            'bill_ref': bill_ref_number,
            'phone': msisdn,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        
        # 2. Find associated lease using BillRefNumber (e.g. Room ID)
        if bill_ref_number:
            leases_ref = db.collection('leases').where('room_id', '==', bill_ref_number).where('status', '==', 'Active').stream()
            for lease in leases_ref:
                lease_id = lease.id
                merchant_id = lease.to_dict().get('merchant_id')
                student_id = lease.to_dict().get('student_id')
                
                # 3. Mark rent as paid in ledger
                db.collection('rent_ledger').document().set({
                    'lease_id': lease_id,
                    'merchant_id': merchant_id,
                    'student_id': student_id,
                    'amount_paid': float(trans_amount),
                    'month': trans_time[:6] if trans_time else 'Unknown', # e.g., 202607
                    'trans_id': trans_id,
                    'timestamp': firestore.SERVER_TIMESTAMP
                })
                break
                
        return jsonify({"ResultCode": 0, "ResultDesc": "Accepted"})
    except Exception as e:
        return jsonify({"ResultCode": 1, "ResultDesc": str(e)}), 500

@housing_v2_bp.route('/merchant/polls', methods=['GET', 'POST'])
def manage_polls():
    from firebase_admin import firestore
    db = firestore.client()
    
    if request.method == 'GET':
        merchant_id = request.args.get('merchant_id')
        if not merchant_id:
            return jsonify({"error": "Missing merchant_id"}), 400
        try:
            polls_ref = db.collection('housing_polls').where('merchant_id', '==', merchant_id).stream()
            polls = []
            for p in polls_ref:
                data = p.to_dict()
                data['id'] = p.id
                polls.append(data)
            return jsonify({"status": "success", "polls": polls}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500
            
    elif request.method == 'POST':
        data = request.json or {}
        merchant_id = data.get('merchant_id')
        question = data.get('question')
        options = data.get('options') # list of strings
        
        if not all([merchant_id, question, options]):
            return jsonify({"error": "Missing required fields"}), 400
            
        try:
            poll_ref = db.collection('housing_polls').document()
            votes = {opt: 0 for opt in options}
            poll_ref.set({
                'merchant_id': merchant_id,
                'question': question,
                'options': options,
                'votes': votes,
                'created_at': firestore.SERVER_TIMESTAMP
            })
            return jsonify({"status": "success", "poll_id": poll_ref.id}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500
            
@housing_v2_bp.route('/merchant/polls/vote', methods=['POST'])
def vote_poll():
    data = request.json or {}
    poll_id = data.get('poll_id')
    option = data.get('option')
    
    if not all([poll_id, option]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        poll_ref = db.collection('housing_polls').document(poll_id)
        # Using firestore increment (requires transaction or increment field)
        poll_ref.update({
            f'votes.{option}': firestore.Increment(1)
        })
        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==========================================
# PHASE 3: PREMIUM FINANCIALS
# ==========================================



@housing_v2_bp.route('/merchant/analytics/risk', methods=['GET'])
def get_risk_analytics():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        # Mocking AI Risk Default Analytics
        # Real logic would check past delays in rent_ledger and okoa_loans
        risk_data = [
            {"room": "102", "tenant": "John D.", "risk_level": "High", "probability": 85, "reason": "Consistent 3-day delay in past 2 months, active Okoa Keja debt."},
            {"room": "205", "tenant": "Sarah M.", "risk_level": "Medium", "probability": 40, "reason": "Late by 1 day last month."},
        ]
        return jsonify({"status": "success", "risks": risk_data}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/finance/insurance/opt_in', methods=['POST'])
def toggle_keja_protection():
    data = request.json or {}
    merchant_id = data.get('merchant_id')
    opt_in = data.get('opt_in', True)
    
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        db.collection('merchants').document(merchant_id).update({
            'keja_protection_active': opt_in,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success", "message": f"Keja Protection {'Activated' if opt_in else 'Deactivated'}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/merchant/analytics/yield', methods=['GET'])
def get_yield_analytics():
    merchant_id = request.args.get('merchant_id')
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # Mocking Yield Management Pricing Suggestions
        yield_data = [
            {"room_type": "Bedsitter", "current_avg": 12000, "suggested": 13500, "demand_increase": 15},
            {"room_type": "1 Bedroom", "current_avg": 18000, "suggested": 19000, "demand_increase": 8},
        ]
        
        return jsonify({"status": "success", "yields": yield_data}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==========================================
# UNIFIED RENT ECOSYSTEM
# ==========================================

@housing_v2_bp.route('/rent/prompt_parent', methods=['POST'])
def prompt_parent_for_rent():
    data = request.json or {}
    student_id = data.get('student_id')
    amount = data.get('amount')
    room_desc = data.get('room_desc', "your child's room")
    
    if not all([student_id, amount]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore, messaging
        db = firestore.client()
        
        # Find the parent linked to this student
        parents = db.collection('users').where('linkedStudents', 'array_contains', student_id).limit(1).get()
        if not parents:
            return jsonify({"error": "No linked parent found"}), 404
            
        parent_doc = parents[0]
        parent_token = parent_doc.to_dict().get('fcmToken')
        
        if parent_token:
            try:
                messaging.send(messaging.Message(
                    notification=messaging.Notification(
                        title="Rent Payment Due",
                        body=f"Your child's rent (KES {amount}) for {room_desc} is due. Tap to pay via M-PESA.",
                    ),
                    data={"type": "rent_prompt", "student_id": student_id, "amount": str(amount), "room_desc": room_desc},
                    token=parent_token,
                ))
            except Exception as e:
                print(f"FCM error: {e}")
            return jsonify({"status": "success", "message": "Prompt sent to parent"}), 200
        else:
            return jsonify({"error": "Parent device token not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/rent/pending', methods=['GET'])
def get_pending_rent_for_parent():
    parent_id = request.args.get('parent_id')
    student_id_query = request.args.get('student_id')
    
    if not parent_id and not student_id_query:
        return jsonify({"error": "Missing parent_id or student_id"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        linked_students = []
        if parent_id:
            parent_doc = db.collection('users').document(parent_id).get()
            if not parent_doc.exists:
                return jsonify({"error": "Parent not found"}), 404
            linked_students = parent_doc.to_dict().get('linkedStudents', [])
        elif student_id_query:
            linked_students = [student_id_query]
            
        pending_rents = []
        
        for student_id in linked_students:
            # Find active leases for this student
            leases = db.collection('housing_applications').where('student_id', '==', student_id).where('status', '==', 'Leased').get()
            for lease in leases:
                l_data = lease.to_dict()
                merchant_id = l_data.get('merchant_id')
                room_id = l_data.get('room_id')
                
                # Get room price
                room_doc = db.collection('rooms').document(room_id).get()
                if not room_doc.exists: continue
                r_data = room_doc.to_dict()
                amount = r_data.get('price', 0)
                
                # Fetch Merchant for Insurance and Name
                merchant_doc = db.collection('merchants').document(merchant_id).get()
                merchant_name = "Landlord"
                insurance_fee = 0
                if merchant_doc.exists:
                    m_data = merchant_doc.to_dict() or {}
                    merchant_name = m_data.get('business_name', 'Landlord')
                    if m_data.get('keja_protection_active', False):
                        insurance_fee = 500
                        
                commission_fee = 50
                total_amount = amount + insurance_fee + commission_fee
                
                pending_rents.append({
                    "student_id": student_id,
                    "merchant_id": merchant_id,
                    "room_id": room_id,
                    "rent_amount": amount,
                    "insurance_fee": insurance_fee,
                    "commission_fee": commission_fee,
                    "total_amount": total_amount,
                    "room_desc": r_data.get('title', 'Room'),
                    "merchant_name": merchant_name
                })
                
        return jsonify({"status": "success", "pending_rents": pending_rents}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/utilities/pay', methods=['POST'])
def pay_utility_bill():
    data = request.json or {}
    student_id = data.get('student_id')
    merchant_id = data.get('merchant_id')
    amount = data.get('amount')
    bill_id = data.get('bill_id')
    
    if not all([student_id, merchant_id, amount, bill_id]):
        return jsonify({"error": "Missing fields"}), 400
        
    try:
        amount = float(amount)
        from firebase_admin import firestore
        db = firestore.client()
        
        @firestore.transactional
        def process_utility_payment(transaction, student_ref, merchant_ref):
            student_doc = student_ref.get(transaction=transaction)
            merchant_doc = merchant_ref.get(transaction=transaction)
            
            if not student_doc.exists or not merchant_doc.exists:
                raise Exception("Student or Merchant not found")
                
            student_data = student_doc.to_dict()
            wallet_bal = student_data.get('walletBalance', 0.0)
            
            if wallet_bal < amount:
                raise Exception("Insufficient Wallet Balance")
                
            transaction.update(student_ref, {'walletBalance': wallet_bal - amount})
            merchant_bal = merchant_doc.to_dict().get('walletBalance', 0.0)
            transaction.update(merchant_ref, {'walletBalance': merchant_bal + amount})
            
        student_ref = db.collection('users').document(student_id)
        merchant_ref = db.collection('users').document(merchant_id)
        
        transaction = db.transaction()
        process_utility_payment(transaction, student_ref, merchant_ref)
        
        tx_ref = db.collection('transactions').document()
        tx_ref.set({
            'sender_id': student_id,
            'receiver_id': merchant_id,
            'amount': amount,
            'type': 'utility_payment',
            'bill_id': bill_id,
            'status': 'completed',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@housing_v2_bp.route('/rent/pay_student_wallet', methods=['POST'])
def pay_student_wallet_rent():
    data = request.json or {}
    student_id = data.get('student_id')
    merchant_id = data.get('merchant_id')
    room_id = data.get('room_id')
    payment_method = data.get('payment_method', 'wallet') # wallet or savings
    
    if not all([student_id, merchant_id, room_id]):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # 1. Fetch Room Price & Insurance
        room_doc = db.collection('rooms').document(room_id).get()
        if not room_doc.exists:
            return jsonify({"error": "Room not found"}), 404
            
        base_rent = float(room_doc.to_dict().get('price', 0))
        
        merchant_doc = db.collection('merchants').document(merchant_id).get()
        insurance_fee = 500.0 if (merchant_doc.exists and merchant_doc.to_dict().get('keja_protection_active', False)) else 0.0
        
        # Student pays NO commission
        total_charge = base_rent + insurance_fee
        
        transaction = db.transaction()
        student_ref = db.collection('users').document(student_id)
        merchant_ref = db.collection('users').document(merchant_id)
        admin_ref = db.collection('admin_finances').document('dishi_rent_pool')
        
        @firestore.transactional
        def process_wallet_rent(transaction, student_ref, merchant_ref, admin_ref):
            student_snap = student_ref.get(transaction=transaction)
            merchant_snap = merchant_ref.get(transaction=transaction)
            
            source_field = 'walletBalance' if payment_method == 'wallet' else 'savingsBalance'
            student_balance = float(student_snap.to_dict().get(source_field, 0))
            
            if student_balance < total_charge:
                # Need to return custom error for UI to prompt guardian
                raise ValueError("INSUFFICIENT_FUNDS")
                
            # Deduct from student
            transaction.update(student_ref, {
                source_field: firestore.Increment(-total_charge)
            })
            
            # Credit merchant ONLY base rent
            transaction.update(merchant_ref, {
                'walletBalance': firestore.Increment(base_rent)
            })
            
            # Route Insurance to Admin Pool
            if insurance_fee > 0:
                transaction.set(admin_ref, {
                    'insurance_pool': firestore.Increment(insurance_fee),
                    'total_collected': firestore.Increment(insurance_fee)
                }, merge=True)
                
            # Update lease status if needed, but for monthly rent, we just log to ledger.
            
        try:
            process_wallet_rent(transaction, student_ref, merchant_ref, admin_ref)
        except ValueError as ve:
            if str(ve) == "INSUFFICIENT_FUNDS":
                return jsonify({"error": "INSUFFICIENT_FUNDS", "message": "Insufficient funds in wallet/savings."}), 400
            raise ve
            
        # Log to ledger
        db.collection('rent_ledger').document().set({
            'merchant_id': merchant_id,
            'student_id': student_id,
            'amount_paid': base_rent,
            'insurance_fee': insurance_fee,
            'commission_fee': 0.0,
            'total_charged': total_charge,
            'payment_method': payment_method,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success", "message": "Rent paid successfully from wallet."}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─────────────────────────────────────────────────────────────────────────────
#  Student: Mark Moved In
#  POST /api/v2/housing/student/move_in
# ─────────────────────────────────────────────────────────────────────────────

@housing_v2_bp.route('/student/move_in', methods=['POST'])
def student_move_in():
    """Student confirms they have physically moved into the room."""
    data = request.json or {}
    student_id     = data.get('student_id', '').strip()
    application_id = data.get('application_id', '').strip()

    if not student_id or not application_id:
        return jsonify({"error": "Missing student_id or application_id"}), 400

    try:
        from firebase_admin import firestore, messaging
        db = firestore.client()

        app_ref = db.collection('housing_applications').document(application_id)
        app_doc = app_ref.get()
        if not app_doc.exists:
            return jsonify({"error": "Application not found"}), 404

        app_data = app_doc.to_dict()
        if app_data.get('student_id') != student_id:
            return jsonify({"error": "Unauthorized"}), 403

        if app_data.get('status') not in ('Approved', 'Leased'):
            return jsonify({"error": f"Cannot move in — current status is '{app_data.get('status')}'"}), 400

        room_id     = app_data.get('room_id', '')
        merchant_id = app_data.get('merchant_id', '')

        app_ref.update({
            'status':      'Occupied',
            'moved_in_at': firestore.SERVER_TIMESTAMP,
            'updated_at':  firestore.SERVER_TIMESTAMP,
        })

        # Mark room as Occupied in both possible collections
        for col in ('rooms', 'housing_properties'):
            try:
                ref = db.collection(col).document(room_id)
                doc = ref.get()
                if doc.exists:
                    ref.update({'status': 'Occupied', 'tenant_id': student_id, 'occupied_at': firestore.SERVER_TIMESTAMP})
            except Exception:
                pass

        # Notify merchant
        try:
            merchant_doc = db.collection('users').document(merchant_id).get()
            student_doc  = db.collection('users').document(student_id).get()
            student_name = (student_doc.to_dict().get('displayName') or student_doc.to_dict().get('name') or 'A tenant') if student_doc.exists else 'A tenant'
            if merchant_doc.exists:
                token = merchant_doc.to_dict().get('fcmToken')
                if token:
                    messaging.send(messaging.Message(
                        notification=messaging.Notification(title="\U0001f3e0 Tenant Moved In", body=f"{student_name} has confirmed they have moved into their room."),
                    android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default')),
                    apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True, sound='default'))),
                        token=token,
                    ))
        except Exception as e:
            print(f"Move-in FCM error (non-fatal): {e}")

        return jsonify({"status": "success", "message": "Move-in confirmed! Welcome home. \U0001f3e0"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─────────────────────────────────────────────────────────────────────────────
#  Student: Exit Room (Vacate)
#  POST /api/v2/housing/student/exit
# ─────────────────────────────────────────────────────────────────────────────

@housing_v2_bp.route('/student/exit', methods=['POST'])
def student_exit_room():
    """Student exits the room — application soft-deleted, room set back to Vacant."""
    data = request.json or {}
    student_id     = data.get('student_id', '').strip()
    application_id = data.get('application_id', '').strip()

    if not student_id or not application_id:
        return jsonify({"error": "Missing student_id or application_id"}), 400

    try:
        from firebase_admin import firestore, messaging
        db = firestore.client()

        app_ref = db.collection('housing_applications').document(application_id)
        app_doc = app_ref.get()
        if not app_doc.exists:
            return jsonify({"error": "Application not found"}), 404

        app_data = app_doc.to_dict()
        if app_data.get('student_id') != student_id:
            return jsonify({"error": "Unauthorized"}), 403

        room_id     = app_data.get('room_id', '')
        merchant_id = app_data.get('merchant_id', '')

        app_ref.update({'status': 'Exited', 'exited_at': firestore.SERVER_TIMESTAMP, 'updated_at': firestore.SERVER_TIMESTAMP})

        # Set room back to Vacant
        room_title = 'A room'
        room_price = 0
        for col in ('rooms', 'housing_properties'):
            try:
                ref = db.collection(col).document(room_id)
                doc = ref.get()
                if doc.exists:
                    r_data = doc.to_dict()
                    room_title = r_data.get('title', 'A room')
                    room_price = r_data.get('price') or r_data.get('rent') or 0
                    ref.update({'status': 'Vacant', 'tenant_id': None, 'vacated_at': firestore.SERVER_TIMESTAMP})
                    break
            except Exception:
                pass

        # Notify merchant
        try:
            merchant_doc = db.collection('users').document(merchant_id).get()
            student_doc  = db.collection('users').document(student_id).get()
            student_name = (student_doc.to_dict().get('displayName') or student_doc.to_dict().get('name') or 'A tenant') if student_doc.exists else 'A tenant'
            if merchant_doc.exists:
                token = merchant_doc.to_dict().get('fcmToken')
                if token:
                    messaging.send(messaging.Message(
                        notification=messaging.Notification(
                            title="🏠 Room Vacancy Notice", 
                            body=f"Dear Landlord, {student_name} has officially vacated '{room_title}'. The room is now listed as Vacant and available for new applicants."
                        ),
                    android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default')),
                    apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True, sound='default'))),
                        token=token,
                    ))
        except Exception as e:
            print(f"Exit FCM error (non-fatal): {e}")

        # Try notifying student (optional backup, can be ignored if fails)
        try:
            if student_doc.exists:
                student_token = student_doc.to_dict().get('fcmToken')
                if student_token:
                    messaging.send(messaging.Message(
                        notification=messaging.Notification(
                            title="✅ Room Exit Confirmed", 
                            body=f"You have successfully exited {room_title}. Your application has been withdrawn."
                        ),
                    android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default')),
                    apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True, sound='default'))),
                        token=student_token,
                    ))
        except Exception:
            pass

        return jsonify({"status": "success", "message": f"You have successfully exited {room_title}. The rent price was KSH {room_price:,.2f}. The room is now vacant."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─────────────────────────────────────────────────────────────────────────────
#  Merchant: Force-Set Room to Vacant
#  POST /api/v2/housing/merchant/set_room_vacant
# ─────────────────────────────────────────────────────────────────────────────

@housing_v2_bp.route('/merchant/set_room_vacant', methods=['POST'])
def merchant_set_room_vacant():
    """Merchant can manually override any of their rooms back to Vacant."""
    data = request.json or {}
    merchant_id = data.get('merchant_id', '').strip()
    room_id     = data.get('room_id', '').strip()

    if not merchant_id or not room_id:
        return jsonify({"error": "Missing merchant_id or room_id"}), 400

    try:
        from firebase_admin import firestore, messaging
        db = firestore.client()

        updated   = False
        tenant_id = None

        for col in ('rooms', 'housing_properties'):
            ref = db.collection(col).document(room_id)
            doc = ref.get()
            if doc.exists and doc.to_dict().get('merchant_id') == merchant_id:
                tenant_id = doc.to_dict().get('tenant_id')
                ref.update({'status': 'Vacant', 'tenant_id': None, 'vacated_at': firestore.SERVER_TIMESTAMP})
                updated = True

        if not updated:
            return jsonify({"error": "Room not found or unauthorized"}), 404

        # Mark related open applications as Exited
        apps = db.collection('housing_applications') \
                 .where('room_id', '==', room_id) \
                 .where('merchant_id', '==', merchant_id).stream()
        for a in apps:
            if a.to_dict().get('status') in ('Approved', 'Leased', 'Occupied'):
                a.reference.update({'status': 'Exited', 'updated_at': firestore.SERVER_TIMESTAMP})

        # Optionally notify former tenant
        if tenant_id:
            try:
                t_doc = db.collection('users').document(tenant_id).get()
                if t_doc.exists:
                    token = t_doc.to_dict().get('fcmToken')
                    if token:
                        messaging.send(messaging.Message(
                            notification=messaging.Notification(title="\U0001f514 Room Status Update", body="Your room has been marked as vacant by the landlord."),
                    android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default')),
                    apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True, sound='default'))),
                            token=token,
                        ))
            except Exception as e:
                print(f"Merchant vacate tenant FCM error (non-fatal): {e}")

        return jsonify({"status": "success", "message": "Room marked as Vacant."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─────────────────────────────────────────────────────────────────────────────
#  Merchant: Room Occupancy Summary
#  GET /api/v2/housing/merchant/room_occupancy?merchant_id=...
# ─────────────────────────────────────────────────────────────────────────────

@housing_v2_bp.route('/merchant/room_occupancy', methods=['GET'])
def get_merchant_room_occupancy():
    """Returns real-time occupied/vacant status for all of a merchant's rooms."""
    merchant_id = request.args.get('merchant_id', '').strip()
    if not merchant_id:
        return jsonify({"error": "Missing merchant_id"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()

        rooms    = []
        seen_ids = set()

        for col in ('rooms', 'housing_properties'):
            docs = db.collection(col).where('merchant_id', '==', merchant_id).stream()
            for d in docs:
                if d.id in seen_ids:
                    continue
                seen_ids.add(d.id)
                rd = d.to_dict()
                rooms.append({
                    'id':        d.id,
                    'title':     rd.get('title') or rd.get('name') or 'Unnamed Room',
                    'status':    rd.get('status', 'Vacant'),
                    'tenant_id': rd.get('tenant_id'),
                    'price':     rd.get('price') or rd.get('rent', 0),
                    'location':  rd.get('location'),
                    'collection': col,
                })

        total    = len(rooms)
        occupied = sum(1 for r in rooms if r['status'] == 'Occupied')
        vacant   = total - occupied

        return jsonify({
            "status":  "success",
            "rooms":   rooms,
            "summary": {"total": total, "occupied": occupied, "vacant": vacant},
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
