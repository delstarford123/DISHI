from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import uuid

deliv_v2_bp = Blueprint('deliv_v2', __name__)

@deliv_v2_bp.route('/register_driver', methods=['POST'])
def register_driver():
    data = request.json or {}
    user_id = data.get('user_id')
    vehicle_type = data.get('vehicle_type') # Motorbike, Van, Tuk Tuk
    plate_number = data.get('plate_number')
    
    phone = data.get('phone')
    capacity = data.get('capacity', 1)
    vehicle_image = data.get('vehicle_image')
    
    if not user_id or not vehicle_type or not phone:
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        db = firestore.client()
        driver_ref = db.collection('deliv_drivers').document(user_id)
        driver_ref.set({
            'user_id': user_id,
            'vehicle_type': vehicle_type,
            'plate_number': plate_number,
            'phone': phone,
            'capacity': int(capacity),
            'vehicle_image': vehicle_image,
            'active_passengers': 0,
            'is_available': False, # Needs admin approval first
            'status': 'pending_approval',
            'created_at': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
        return jsonify({"status": "success", "message": "Registered as driver. Pending admin approval."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@deliv_v2_bp.route('/request', methods=['POST'])
def request_delivery():
    data = request.json or {}
    user_id = data.get('user_id')
    service_type = data.get('service_type') # Ride, Food, Gas, Errand
    details = data.get('details') # "Want 2 gas cylinders", or "Ride to campus"
    pickup_location = data.get('pickup_location', '')
    delivery_location = data.get('delivery_location', '')
    delivery_time = data.get('delivery_time', 'ASAP')
    payment_method = data.get('payment_method', 'Cash') # Vault or Cash
    
    is_gift = data.get('is_gift', False)
    gift_note = data.get('gift_note', '')
    is_rain_surge = data.get('is_rain_surge', False)
    is_night_owl = data.get('is_night_owl', False)
    
    if not user_id or not service_type or not details:
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        db = firestore.client()
        request_id = str(uuid.uuid4())
        
        db.collection('deliv_requests').document(request_id).set({
            'request_id': request_id,
            'user_id': user_id,
            'service_type': service_type,
            'details': details,
            'pickup_location': pickup_location,
            'delivery_location': delivery_location,
            'delivery_time': delivery_time,
            'payment_method': payment_method,
            'status': 'pending', # pending, accepted, completed, cancelled
            'driver_id': None,
            'price': 0.0, # Determined later or negotiated
            'is_gift': is_gift,
            'gift_note': gift_note,
            'is_rain_surge': is_rain_surge,
            'is_night_owl': is_night_owl,
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success", "request_id": request_id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@deliv_v2_bp.route('/requests/available', methods=['GET'])
def get_available_requests():
    try:
        db = firestore.client()
        docs = db.collection('deliv_requests').where('status', '==', 'pending').order_by('created_at', direction=firestore.Query.DESCENDING).get()
        
        requests = []
        for doc in docs:
            d = doc.to_dict()
            if 'created_at' in d and hasattr(d['created_at'], 'isoformat'):
                d['created_at'] = d['created_at'].isoformat()
            else:
                d['created_at'] = str(d.get('created_at'))
            requests.append(d)
            
        return jsonify({"status": "success", "requests": requests}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@deliv_v2_bp.route('/requests/accept', methods=['POST'])
def accept_request():
    data = request.json or {}
    request_id = data.get('request_id')
    driver_id = data.get('driver_id')
    price = data.get('price', 0.0)
    eta = data.get('eta')
    
    if not request_id or not driver_id or not eta:
        return jsonify({"error": "Missing request_id, driver_id, or eta"}), 400
        
    try:
        db = firestore.client()
        req_ref = db.collection('deliv_requests').document(request_id)
        
        doc = req_ref.get()
        if not doc.exists:
            return jsonify({"error": "Request not found"}), 404
            
        if doc.to_dict().get('status') != 'pending':
            return jsonify({"error": "Request is no longer available"}), 400
            
        req_ref.update({
            'status': 'accepted',
            'driver_id': driver_id,
            'price': float(price),
            'eta': eta,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        
        driver_ref = db.collection('deliv_drivers').document(driver_id)
        driver_doc = driver_ref.get()
        if driver_doc.exists:
            driver_data = driver_doc.to_dict()
            current_passengers = driver_data.get('active_passengers', 0)
            capacity = driver_data.get('capacity', 1)
            
            new_passengers = current_passengers + 1
            new_status = 'busy' if new_passengers >= capacity else 'free'
            
            driver_ref.update({
                'active_passengers': new_passengers,
                'status': new_status
            })
        
        return jsonify({"status": "success", "message": "Request accepted"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@deliv_v2_bp.route('/requests/complete', methods=['POST'])
def complete_request():
    data = request.json or {}
    request_id = data.get('request_id')
    driver_id = data.get('driver_id')
    
    if not request_id or not driver_id:
        return jsonify({"error": "Missing request_id or driver_id"}), 400
        
    try:
        db = firestore.client()
        req_ref = db.collection('deliv_requests').document(request_id)
        
        doc = req_ref.get()
        if not doc.exists:
            return jsonify({"error": "Request not found"}), 404
            
        if doc.to_dict().get('driver_id') != driver_id:
            return jsonify({"error": "You are not the driver for this request"}), 403
            
        req_ref.update({
            'status': 'completed',
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        
        driver_ref = db.collection('deliv_drivers').document(driver_id)
        driver_doc = driver_ref.get()
        if driver_doc.exists:
            driver_data = driver_doc.to_dict()
            current_passengers = driver_data.get('active_passengers', 0)
            capacity = driver_data.get('capacity', 1)
            
            if current_passengers > 0:
                new_passengers = current_passengers - 1
                new_status = 'busy' if new_passengers >= capacity else 'free'
                driver_ref.update({
                    'active_passengers': new_passengers,
                    'status': new_status
                })
        
        return jsonify({"status": "success", "message": "Request completed"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@deliv_v2_bp.route('/pay_escrow', methods=['POST'])
def pay_deliv_escrow():
    data = request.json or {}
    request_id = data.get('request_id')
    user_id = data.get('user_id')
    
    if not request_id or not user_id:
        return jsonify({"error": "Missing request_id or user_id"}), 400
        
    try:
        db = firestore.client()
        req_doc = db.collection('deliv_requests').document(request_id).get()
        
        if not req_doc.exists:
            return jsonify({"error": "Request not found"}), 404
            
        req_data = req_doc.to_dict()
        driver_id = req_data.get('driver_id')
        price = float(req_data.get('price', 0))
        
        if not driver_id or price <= 0:
            return jsonify({"error": "Invalid driver or price"}), 400

        # Flat 3 KSH platform fee
        fee = 3.0
        total_user_charge = price + fee
            
        transaction_ref = db.transaction()
        user_ref = db.collection('users').document(user_id)
        req_ref = db.collection('deliv_requests').document(request_id)
        
        @firestore.transactional
        def process_escrow(transaction):
            user_snap = user_ref.get(transaction=transaction)
            if not user_snap.exists:
                raise Exception("User not found")
                
            user_data = user_snap.to_dict()
            user_balance = float(user_data.get('walletBalance', 0))
            
            if user_balance < total_user_charge:
                raise Exception(f"Insufficient funds. You need Ksh {total_user_charge} (includes Ksh {fee} system fee).")
                
            transaction.update(user_ref, {
                'walletBalance': user_balance - total_user_charge
            })
            
            transaction.update(req_ref, {
                'escrow_status': 'HELD',
                'payment_status': 'in_escrow',
                'fee_deducted': fee,
                'net_amount': price
            })
            
            # Record escrow out transaction
            import uuid
            tx_id_out = str(uuid.uuid4())
            tx_out_ref = user_ref.collection('transactions').document(tx_id_out)
            
            transaction.set(tx_out_ref, {
                'type': 'ESCROW_LOCK',
                'amount': total_user_charge,
                'desc': 'DeLiv Escrow Hold',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'request_id': request_id
            })
            
        process_escrow(transaction_ref)
        return jsonify({"status": "success", "message": "Funds locked in Escrow", "escrow_amount": total_user_charge}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@deliv_v2_bp.route('/release_escrow', methods=['POST'])
def release_deliv_escrow():
    data = request.json or {}
    request_id = data.get('request_id')
    user_id = data.get('user_id')

    if not request_id or not user_id:
        return jsonify({"error": "Missing request_id or user_id"}), 400

    db = firestore.client()

    try:
        transaction_ref = db.transaction()
        req_ref = db.collection('deliv_requests').document(request_id)

        @firestore.transactional
        def process_release(transaction):
            req_doc = req_ref.get(transaction=transaction)
            if not req_doc.exists:
                raise Exception("Request not found")

            req_data = req_doc.to_dict()
            if req_data.get('escrow_status') != 'HELD':
                raise Exception("Funds are not currently in Escrow for this request")
            
            if req_data.get('user_id') != user_id:
                raise Exception("Only the requester can release escrow funds")

            driver_id = req_data.get('driver_id')
            net_amount = req_data.get('net_amount', 0)
            fee = req_data.get('fee_deducted', 0)

            driver_ref = db.collection('users').document(driver_id)
            driver_doc = driver_ref.get(transaction=transaction)
            if not driver_doc.exists:
                raise Exception("Driver not found")

            driver_data = driver_doc.to_dict()
            driver_balance = driver_data.get('walletBalance', 0)

            # Credit Driver
            transaction.update(driver_ref, {
                'walletBalance': driver_balance + net_amount
            })

            # Update Request status
            transaction.update(req_ref, {
                'status': 'completed',
                'payment_status': 'paid',
                'escrow_status': 'RELEASED',
                'updated_at': firestore.SERVER_TIMESTAMP
            })

            import uuid
            # Record incoming transaction for Driver
            tx_id_in = str(uuid.uuid4())
            tx_in_ref = driver_ref.collection('transactions').document(tx_id_in)
            transaction.set(tx_in_ref, {
                'type': 'ESCROW_RELEASED',
                'amount': net_amount,
                'desc': 'DeLiv Payment Released',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'request_id': request_id,
                'fee': fee
            })

            # Collect system fee
            system_fee_ref = db.collection('system_revenue').document()
            transaction.set(system_fee_ref, {
                'type': 'DELIV_FEE',
                'amount': fee,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'request_id': request_id,
                'driver_id': driver_id
            })

        process_release(transaction_ref)
        return jsonify({"status": "success", "message": "Funds released to Driver successfully"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500
