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
    
    if not request_id or not driver_id:
        return jsonify({"error": "Missing required fields"}), 400
        
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

@deliv_v2_bp.route('/pay', methods=['POST'])
def pay_deliv_vault():
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
        service_type = req_data.get('service_type', 'Errand')
        payment_method = req_data.get('payment_method', 'vault')
        phone_number = req_data.get('phone_number')
        is_rain_surge = req_data.get('is_rain_surge', False)
        is_night_owl = req_data.get('is_night_owl', False)
        
        is_ride = service_type.lower() == 'ride'
        user_commission = 10.0 if is_ride else 25.0
        if is_rain_surge:
            user_commission += 30.0
        if is_night_owl:
            user_commission += 20.0
            
        total_user_charge = price + user_commission
        
        if not driver_id or price <= 0:
            return jsonify({"error": "Invalid driver or price"}), 400
            
        transaction = db.transaction()
        user_ref = db.collection('users').document(user_id)
        driver_ref = db.collection('users').document(driver_id)
        
        if payment_method == 'mpesa':
            if not phone_number:
                return jsonify({"error": "Phone number required for M-Pesa payment"}), 400
                
            from flask import request as flask_request
            import requests
            base_url = flask_request.host_url.rstrip('/')
            
            resp = requests.post(f"{base_url}/api/v1/mpesa/stkpush", json={
                'phone_number': phone_number,
                'amount': total_user_charge,
                'credit_amount': price,
                'user_id': driver_id, # Driver receives funds
                'destination': 'vault_balance', # Add to driver's vault balance
                'metadata': {
                    'action': 'pay_deliv',
                    'request_id': request_id
                }
            }, timeout=15)
            
            if resp.status_code != 200:
                return jsonify({"error": "Failed to initiate M-Pesa payment"}), 400
                
            resp_data = resp.json()
            checkout_id = resp_data.get('CheckoutRequestID')
            
            db.collection('transactions').add({
                'sender_id': user_id,
                'receiver_id': driver_id,
                'amount': total_user_charge,
                'type': 'DeLiv Payment',
                'source': 'mpesa',
                'request_id': request_id,
                'checkout_id': checkout_id,
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            
            # Removed optimistic status update
            
            return jsonify({"status": "pending", "checkout_id": checkout_id, "message": "M-Pesa payment initiated for Driver."}), 200
            
        @firestore.transactional
        def process_payment(transaction, user_ref, driver_ref, price, total_user_charge, payment_method):
            user_snap = user_ref.get(transaction=transaction)
            if not user_snap.exists:
                raise Exception("User not found")
                
            user_data = user_snap.to_dict()
            
            source_field = 'walletBalance' if payment_method == 'vault' else 'savingsBalance'
            user_balance = float(user_data.get(source_field, 0))
            
            if user_balance >= total_user_charge:
                new_balance = user_balance - total_user_charge
            else:
                raise Exception(f"Insufficient funds. You need Ksh {total_user_charge} (includes Ksh {user_commission} system fee).")
                
            driver_snap = driver_ref.get(transaction=transaction)
            driver_vault = 0.0
            if driver_snap.exists:
                driver_data = driver_snap.to_dict()
                driver_vault = float(driver_data.get('vault_balance', 0))
                
            transaction.update(user_ref, {
                source_field: new_balance
            })
            
            transaction.update(driver_ref, {
                'vault_balance': driver_vault + price
            })
            
            return source_field
            
        source = process_payment(transaction, user_ref, driver_ref, price, total_user_charge, payment_method)
        
        db.collection('transactions').add({
            'sender_id': user_id,
            'receiver_id': driver_id,
            'amount': total_user_charge,
            'type': 'DeLiv Payment',
            'source': source,
            'request_id': request_id,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        
        db.collection('deliv_requests').document(request_id).update({
            'payment_status': 'paid'
        })
        
        return jsonify({"status": "success", "message": f"Paid KSH {price} to driver successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
