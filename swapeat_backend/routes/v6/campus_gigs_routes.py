import math
from flask import Blueprint, request, jsonify, current_app
from firebase_admin import firestore
import uuid
import traceback
import random

def haversine_distance(lat1, lon1, lat2, lon2):
    if None in (lat1, lon1, lat2, lon2):
        return float('inf')
    try:
        R = 6371.0
        dLat = math.radians(float(lat2) - float(lat1))
        dLon = math.radians(float(lon2) - float(lon1))
        a = math.sin(dLat/2)**2 + math.cos(math.radians(float(lat1))) * math.cos(math.radians(float(lat2))) * math.sin(dLon/2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        return R * c
    except (ValueError, TypeError):
        return float('inf')

campus_gigs_v6_bp = Blueprint('campus_gigs_v6', __name__)

@campus_gigs_v6_bp.route('/register', methods=['POST'])
def register_worker():
    data = request.json or {}
    user_id = data.get('user_id')
    category = data.get('category')
    portfolio_images = data.get('portfolio_images', [])
    description = data.get('description', '')
    latitude = data.get('latitude')
    longitude = data.get('longitude')
    
    if not user_id or not category:
        return jsonify({"error": "Missing user_id or category"}), 400
        
    try:
        db = firestore.client()
        worker_ref = db.collection('campus_gig_workers').document(user_id)
        
        worker_data = {
            'user_id': user_id,
            'category': category,
            'portfolio_images': portfolio_images,
            'description': description,
            'is_available': True,
            'status': 'active',
            'rating': 5.0,
            'completed_gigs': 0,
            'created_at': firestore.SERVER_TIMESTAMP
        }
        if latitude is not None and longitude is not None:
            worker_data['latitude'] = float(latitude)
            worker_data['longitude'] = float(longitude)
            
        worker_ref.set(worker_data, merge=True)
        
        return jsonify({"status": "success", "message": f"Successfully registered as {category}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@campus_gigs_v6_bp.route('/request', methods=['POST'])
def request_gig():
    data = request.json or {}
    requester_id = data.get('requester_id')
    category = data.get('category')
    details = data.get('details')
    price_offer = data.get('price_offer', 0.0)
    req_lat = data.get('latitude')
    req_lon = data.get('longitude')
    
    if not requester_id or not category or not details:
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        db = firestore.client()
        request_id = str(uuid.uuid4())
        
        gig_data = {
            'request_id': request_id,
            'requester_id': requester_id,
            'category': category,
            'details': details,
            'price_offer': float(price_offer),
            'status': 'pending',
            'worker_id': None,
            'created_at': firestore.SERVER_TIMESTAMP
        }
        if req_lat is not None and req_lon is not None:
            gig_data['latitude'] = float(req_lat)
            gig_data['longitude'] = float(req_lon)
            
        db.collection('campus_gig_requests').document(request_id).set(gig_data)
        
        # Broadcast FCM and Emails to online workers
        try:
            from utils.fcm_utils import send_fcm_notification
            from flask_mail import Message
            from app import mail
            from routes.email_utils import campus_gig_alert_email
            from flask import current_app
            
            admin_email = current_app.config.get('MAIL_USERNAME', 'dishi@delstarfordworks.co.ke')
            
            workers = db.collection('campus_gig_workers').where('category', '==', category).where('is_available', '==', True).stream()
            
            eligible_workers = []
            fallback_workers = []
            
            for worker in workers:
                w_data = worker.to_dict()
                w_lat = w_data.get('latitude')
                w_lon = w_data.get('longitude')
                w_rating = float(w_data.get('rating', 5.0))
                
                dist = haversine_distance(req_lat, req_lon, w_lat, w_lon)
                
                # Primary: <= 2km and rating >= 4.0
                if dist <= 2.0 and w_rating >= 4.0:
                    eligible_workers.append(worker.id)
                # Fallback: <= 5km and rating >= 3.0 (also include those without location if needed, dist is inf, so they are excluded unless we allow inf)
                elif (dist <= 5.0 or math.isinf(dist)) and w_rating >= 3.0:
                    fallback_workers.append(worker.id)
            
            # Use fallback if primary is empty
            target_workers = eligible_workers if len(eligible_workers) > 0 else fallback_workers
            
            for worker_id in target_workers:
                
                # Fetch worker details to get email and name
                worker_email = None
                worker_name = "DISHI Partner"
                try:
                    user_doc = db.collection('users').document(worker_id).get()
                    if user_doc.exists:
                        u_data = user_doc.to_dict()
                        worker_email = u_data.get('email')
                        worker_name = u_data.get('displayName') or u_data.get('name') or "DISHI Partner"
                except Exception:
                    pass
                
                # Send Professional FCM
                send_fcm_notification(
                    worker_id, 
                    "Gig Opportunity! 💼", 
                    f"Congratulations! Your {category} services are in demand. Offer: Ksh {price_offer}", 
                    data={"type": "gig_request", "request_id": request_id}
                )
                
                # Send Professional Email
                if worker_email and mail:
                    subject, html_body = campus_gig_alert_email(worker_name, category, float(price_offer))
                    msg = Message(
                        subject=subject,
                        sender=admin_email,
                        recipients=[worker_email],
                        html=html_body
                    )
                    try:
                        mail.send(msg)
                    except Exception as email_err:
                        print("Failed to send gig email:", email_err)
                        
        except Exception as e:
            print("Failed to broadcast FCM or emails:", e)
        
        return jsonify({"status": "success", "request_id": request_id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@campus_gigs_v6_bp.route('/accept', methods=['POST'])
def accept_gig():
    data = request.json or {}
    request_id = data.get('request_id')
    worker_id = data.get('worker_id')
    eta = data.get('eta')
    
    if not request_id or not worker_id or not eta:
        return jsonify({"error": "Missing request_id, worker_id, or eta"}), 400
        
    try:
        db = firestore.client()
        req_ref = db.collection('campus_gig_requests').document(request_id)
        
        doc = req_ref.get()
        if not doc.exists:
            return jsonify({"error": "Gig request not found"}), 404
            
        if doc.to_dict().get('status') != 'pending':
            return jsonify({"error": "Gig is no longer available"}), 400
            
        req_ref.update({
            'status': 'accepted',
            'worker_id': worker_id,
            'eta': eta,
            'accepted_at': firestore.SERVER_TIMESTAMP
        })
        
        # Notify requester
        try:
            from utils.fcm_utils import send_fcm_notification
            from flask_mail import Message
            from app import mail
            from routes.email_utils import campus_gig_accepted_email
            from flask import current_app
            
            requester_id = doc.to_dict().get('requester_id')
            category = doc.to_dict().get('category')
            
            req_user_doc = db.collection('users').document(requester_id).get()
            worker_user_doc = db.collection('users').document(worker_id).get()
            
            req_name = "Student"
            req_email = None
            if req_user_doc.exists:
                rd = req_user_doc.to_dict()
                req_name = rd.get('displayName') or rd.get('name') or "Student"
                req_email = rd.get('email')
                
            w_name = "A DISHI Provider"
            if worker_user_doc.exists:
                wd = worker_user_doc.to_dict()
                w_name = wd.get('displayName') or wd.get('name') or "A DISHI Provider"
            
            send_fcm_notification(
                requester_id, 
                "Gig Accepted! ✅", 
                f"Good news! {w_name} has accepted your {category} gig. Open the app to chat.", 
                data={"type": "gig_accepted", "request_id": request_id}
            )
            
            if req_email and mail:
                admin_email = current_app.config.get('MAIL_USERNAME', 'dishi@delstarfordworks.co.ke')
                subject, html_body = campus_gig_accepted_email(req_name, w_name, category)
                msg = Message(subject=subject, sender=admin_email, recipients=[req_email], html=html_body)
                mail.send(msg)
                
        except Exception as e:
            print("Failed to notify requester of gig acceptance:", e)
        
        return jsonify({"status": "success", "message": "Gig accepted"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@campus_gigs_v6_bp.route('/pay_escrow', methods=['POST'])
def pay_escrow():
    data = request.json or {}
    request_id = data.get('request_id')
    requester_id = data.get('requester_id')
    
    if not request_id or not requester_id:
        return jsonify({"error": "Missing request_id or requester_id"}), 400
        
    try:
        db = firestore.client()
        transaction_ref = db.transaction()
        req_ref = db.collection('campus_gig_requests').document(request_id)
        user_ref = db.collection('users').document(requester_id)
        
        @firestore.transactional
        def process_escrow(transaction):
            req_doc = req_ref.get(transaction=transaction)
            if not req_doc.exists:
                raise Exception("Gig not found")
                
            req_data = req_doc.to_dict()
            price = float(req_data.get('price_offer', 0))
            worker_id = req_data.get('worker_id')
            
            if not worker_id or price <= 0:
                raise Exception("Invalid worker or price")
                
            fee = 3.0
            total_charge = price + fee
            
            user_snap = user_ref.get(transaction=transaction)
            if not user_snap.exists:
                raise Exception("Requester not found")
                
            user_data = user_snap.to_dict()
            user_balance = float(user_data.get('walletBalance', 0))
            
            if user_balance < total_charge:
                raise Exception(f"Insufficient funds. You need Ksh {total_charge} (includes Ksh {fee} system fee).")
                
            transaction.update(user_ref, {
                'walletBalance': user_balance - total_charge
            })
            
            completion_pin = str(random.randint(1000, 9999))
            transaction.update(req_ref, {
                'escrow_status': 'HELD',
                'fee_deducted': fee,
                'net_amount': price,
                'completion_pin': completion_pin
            })
            
            # Notify the worker that funds are locked
            try:
                from utils.fcm_utils import send_fcm_notification
                send_fcm_notification(worker_id, "Job Secured! \U0001f512", f"Escrow locked Ksh {price}. Proceed to student.", data={"type": "escrow_locked", "request_id": request_id})
            except: pass
            
            tx_id_out = str(uuid.uuid4())
            tx_out_ref = user_ref.collection('transactions').document(tx_id_out)
            
            transaction.set(tx_out_ref, {
                'type': 'ESCROW_LOCK',
                'amount': total_charge,
                'desc': f"Campus Gig Escrow Hold ({req_data.get('category')})",
                'timestamp': firestore.SERVER_TIMESTAMP,
                'request_id': request_id
            })
            
        process_escrow(transaction_ref)
        return jsonify({"status": "success", "message": "Funds securely locked in Escrow"}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@campus_gigs_v6_bp.route('/release_escrow', methods=['POST'])
def release_escrow():
    data = request.json or {}
    request_id = data.get('request_id')
    requester_id = data.get('requester_id')
    pin = data.get('pin')

    if not request_id or not requester_id or not pin:
        return jsonify({"error": "Missing request_id, requester_id, or pin"}), 400

    db = firestore.client()

    try:
        transaction_ref = db.transaction()
        req_ref = db.collection('campus_gig_requests').document(request_id)

        @firestore.transactional
        def process_release(transaction):
            req_doc = req_ref.get(transaction=transaction)
            if not req_doc.exists:
                raise Exception("Gig not found")

            req_data = req_doc.to_dict()
            if req_data.get('escrow_status') != 'HELD':
                raise Exception("Funds are not currently in Escrow for this gig")
            
            if req_data.get('requester_id') != requester_id:
                raise Exception("Only the requester can release escrow funds")
                
            if str(req_data.get('completion_pin', '')) != str(pin):
                raise Exception("Invalid completion PIN. Worker must provide the correct PIN to release funds.")

            worker_id = req_data.get('worker_id')
            net_amount = req_data.get('net_amount', 0)
            fee = req_data.get('fee_deducted', 0)
            category = req_data.get('category', 'Gig')

            worker_ref = db.collection('users').document(worker_id)
            worker_doc = worker_ref.get(transaction=transaction)
            if not worker_doc.exists:
                raise Exception("Worker not found")

            worker_data = worker_doc.to_dict()
            worker_balance = float(worker_data.get('walletBalance', 0))

            transaction.update(worker_ref, {
                'walletBalance': worker_balance + net_amount
            })

            transaction.update(req_ref, {
                'status': 'completed',
                'escrow_status': 'RELEASED',
                'completed_at': firestore.SERVER_TIMESTAMP
            })

            tx_id_in = str(uuid.uuid4())
            tx_in_ref = worker_ref.collection('transactions').document(tx_id_in)
            transaction.set(tx_in_ref, {
                'type': 'ESCROW_RELEASED',
                'amount': net_amount,
                'desc': f"Campus Gig Payment Released ({category})",
                'timestamp': firestore.SERVER_TIMESTAMP,
                'request_id': request_id,
                'fee': fee
            })

            system_fee_ref = db.collection('system_revenue').document()
            transaction.set(system_fee_ref, {
                'type': 'CAMPUS_GIG_FEE',
                'amount': fee,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'request_id': request_id,
                'worker_id': worker_id
            })

            gig_worker_ref = db.collection('campus_gig_workers').document(worker_id)
            gig_worker_doc = gig_worker_ref.get(transaction=transaction)
            if gig_worker_doc.exists:
                completed = gig_worker_doc.to_dict().get('completed_gigs', 0)
                transaction.update(gig_worker_ref, {
                    'completed_gigs': completed + 1
                })

        process_release(transaction_ref)
        return jsonify({"status": "success", "message": "Funds released to worker successfully"}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@campus_gigs_v6_bp.route('/refund_escrow', methods=['POST'])
def refund_escrow():
    """
    Refunds escrow back to the requester when a gig is cancelled,
    the worker never showed up, or was unable to complete the job.
    Can be initiated by either the requester or the worker.
    """
    data = request.json or {}
    request_id = data.get('request_id')
    caller_id = data.get('caller_id') or data.get('requester_id') or data.get('worker_id')
    reason = data.get('reason', 'Worker did not show up / unable to complete')

    if not request_id or not caller_id:
        return jsonify({"error": "Missing request_id or caller_id"}), 400

    db = firestore.client()

    try:
        transaction_ref = db.transaction()
        req_ref = db.collection('campus_gig_requests').document(request_id)

        @firestore.transactional
        def process_refund(transaction):
            req_doc = req_ref.get(transaction=transaction)
            if not req_doc.exists:
                raise Exception("Gig not found")

            req_data = req_doc.to_dict()
            escrow_status = req_data.get('escrow_status')
            if escrow_status != 'HELD':
                raise Exception(f"Cannot refund escrow: status is '{escrow_status}' (must be 'HELD')")

            requester_id = req_data.get('requester_id')
            worker_id = req_data.get('worker_id')

            if caller_id not in [requester_id, worker_id, 'admin']:
                raise Exception("Unauthorized: Only the requester or worker can cancel and refund escrow.")

            price = float(req_data.get('net_amount') or req_data.get('price_offer', 0))
            fee = float(req_data.get('fee_deducted', 3.0))
            total_refund = price + fee
            category = req_data.get('category', 'Gig')

            requester_ref = db.collection('users').document(requester_id)
            requester_doc = requester_ref.get(transaction=transaction)
            if not requester_doc.exists:
                raise Exception("Requester user record not found")

            requester_balance = float(requester_doc.to_dict().get('walletBalance', 0))

            transaction.update(requester_ref, {
                'walletBalance': requester_balance + total_refund
            })

            transaction.update(req_ref, {
                'status': 'cancelled',
                'escrow_status': 'REFUNDED',
                'cancellation_reason': reason,
                'cancelled_by': caller_id,
                'refunded_amount': total_refund,
                'refunded_at': firestore.SERVER_TIMESTAMP
            })

            tx_id_refund = str(uuid.uuid4())
            tx_refund_ref = requester_ref.collection('transactions').document(tx_id_refund)
            transaction.set(tx_refund_ref, {
                'type': 'ESCROW_REFUND',
                'amount': total_refund,
                'desc': f"Campus Gig Escrow Refund: {category} ({reason})",
                'timestamp': firestore.SERVER_TIMESTAMP,
                'request_id': request_id
            })

            try:
                db.collection('transactions').add({
                    'userId': requester_id,
                    'type': 'escrow_refund',
                    'amount': total_refund,
                    'description': f"Campus Gig Escrow Refund: {category}",
                    'reason': reason,
                    'timestamp': firestore.SERVER_TIMESTAMP
                })
                db.collection('notifications').add({
                    'targetUserId': requester_id,
                    'title': 'Escrow Refunded 💰',
                    'body': f'KES {total_refund:.2f} has been refunded to your wallet for "{category}". Reason: {reason}',
                    'type': 'escrow_refund',
                    'amount': total_refund,
                    'createdAt': firestore.SERVER_TIMESTAMP,
                    'readBy': []
                })
                if worker_id:
                    db.collection('notifications').add({
                        'targetUserId': worker_id,
                        'title': 'Gig Cancelled ⚠️',
                        'body': f'Gig for "{category}" was cancelled and escrow has been returned to the student.',
                        'type': 'gig_cancelled',
                        'createdAt': firestore.SERVER_TIMESTAMP,
                        'readBy': []
                    })
            except:
                pass

        process_refund(transaction_ref)
        return jsonify({
            "status": "success",
            "message": "Escrow successfully refunded back to student wallet."
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500



@campus_gigs_v6_bp.route('/verify_handoff', methods=['POST'])
def verify_courier_handoff():
    """
    Called by Vendor to securely verify that the DeLiv Courier at the counter
    matches the order before handing over prepared food or valuable electronics.
    """
    data = request.json or {}
    order_id = data.get('order_id')
    vendor_id = data.get('vendor_id')
    provided_pin = str(data.get('vendor_pickup_pin', '')).strip()

    if not order_id or not provided_pin:
        return jsonify({'error': 'Missing order_id or vendor_pickup_pin'}), 400

    db = firestore.client()

    try:
        # Check in orders collection first
        order_ref = db.collection('orders').document(order_id)
        order_doc = order_ref.get()

        deliv_req_doc = None
        deliv_req_ref = None

        if not order_doc.exists:
            # Maybe order_id is actually a deliv_requests ID
            deliv_req_ref = db.collection('deliv_requests').document(order_id)
            deliv_req_doc = deliv_req_ref.get()
            if not deliv_req_doc.exists:
                return jsonify({'error': 'Order or delivery request not found'}), 404
            order_data = deliv_req_doc.to_dict()
        else:
            order_data = order_doc.to_dict()
            linked_gig_id = order_data.get('deliv_request_id') or order_data.get('gig_id')
            if linked_gig_id:
                deliv_req_ref = db.collection('deliv_requests').document(linked_gig_id)
                deliv_req_doc = deliv_req_ref.get()

        # Validate vendor pickup pin
        expected_pin = str(order_data.get('vendor_pickup_pin') or order_data.get('pickup_pin') or '').strip()
        if not expected_pin and deliv_req_doc and deliv_req_doc.exists:
            expected_pin = str(deliv_req_doc.to_dict().get('vendor_pickup_pin', '')).strip()

        if expected_pin and provided_pin != expected_pin:
            return jsonify({'error': 'Incorrect Vendor Pickup PIN. Courier must provide PIN matching the order.'}), 400

        # Update order status to in_transit
        update_payload = {
            'status': 'in_transit',
            'prep_status': 'in_transit',
            'handed_to_courier': True,
            'handed_to_courier_at': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        }
        if order_doc.exists:
            order_ref.update(update_payload)

        # Update deliv_requests stage to delivering
        if deliv_req_ref:
            deliv_req_ref.update({
                'stage': 'delivering',
                'status': 'in_transit',
                'handed_to_courier_at': firestore.SERVER_TIMESTAMP,
                'updatedAt': firestore.SERVER_TIMESTAMP,
            })

        student_uid = order_data.get('studentUid') or order_data.get('student_id') or order_data.get('userId') or order_data.get('postedBy')
        vendor_name = order_data.get('vendorName') or order_data.get('vendor_name') or 'Vendor'

        # Send push notification to student
        if student_uid:
            try:
                from utils.fcm_utils import send_fcm_notification
                send_fcm_notification(
                    student_uid,
                    'Order In Transit! 🛵',
                    f'Your order from {vendor_name} has been picked up by your courier and is on the way!',
                    data={'type': 'order_in_transit', 'order_id': order_id}
                )
            except Exception as fcm_err:
                print('FCM notification error:', fcm_err)

        return jsonify({
            'status': 'success',
            'message': 'Courier handover verified successfully. Order is now en-route to the student.'
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@campus_gigs_v6_bp.route('/complete', methods=['POST'])
def complete_courier_delivery():
    """
    Called by DeLiv Courier upon arrival at student's doorstep/seat.
    Requires Student's 4-digit Delivery PIN to complete and unlock Escrow payout.
    """
    data = request.json or {}
    request_id = data.get('request_id')
    driver_id = data.get('driver_id')
    provided_pin = str(data.get('delivery_pin', '')).strip()

    if not request_id or not provided_pin:
        return jsonify({'error': 'Missing request_id or delivery_pin'}), 400

    db = firestore.client()

    try:
        # Search deliv_requests first
        gig_ref = db.collection('deliv_requests').document(request_id)
        gig_doc = gig_ref.get()

        order_ref = None
        order_doc = None

        if not gig_doc.exists:
            # Check if request_id is an order_id
            order_ref = db.collection('orders').document(request_id)
            order_doc = order_ref.get()
            if not order_doc.exists:
                return jsonify({'error': 'Delivery gig not found'}), 404
            gig_data = order_doc.to_dict()
        else:
            gig_data = gig_doc.to_dict()
            linked_order_id = gig_data.get('orderId') or gig_data.get('order_id')
            if linked_order_id:
                order_ref = db.collection('orders').document(linked_order_id)
                order_doc = order_ref.get()

        # Validate delivery pin
        expected_pin = str(gig_data.get('studentDeliveryPin') or gig_data.get('student_delivery_pin') or gig_data.get('completion_pin') or '').strip()
        if not expected_pin and order_doc and order_doc.exists:
            expected_pin = str(order_doc.to_dict().get('studentDeliveryPin') or order_doc.to_dict().get('student_delivery_pin') or '').strip()

        if expected_pin and provided_pin != expected_pin:
            return jsonify({'error': 'Incorrect Student Delivery PIN. Please ask the student for their 4-digit PIN.'}), 400

        delivery_fee = float(gig_data.get('deliveryFee') or gig_data.get('delivery_fee') or gig_data.get('pay') or 50.0)
        actual_driver_id = driver_id or gig_data.get('driverId') or gig_data.get('worker_id')
        student_uid = gig_data.get('studentUid') or gig_data.get('student_id') or gig_data.get('userId') or gig_data.get('postedBy')

        # Credit delivery fee to Driver's wallet
        if actual_driver_id:
            driver_ref = db.collection('users').document(actual_driver_id)
            driver_snap = driver_ref.get()
            if driver_snap.exists:
                cur_bal = float(driver_snap.to_dict().get('walletBalance') or 0.0)
                driver_ref.update({
                    'walletBalance': cur_bal + delivery_fee,
                    'updatedAt': firestore.SERVER_TIMESTAMP
                })
                # Add transaction record
                driver_ref.collection('transactions').add({
                    'type': 'DELIV_EARNING',
                    'amount': delivery_fee,
                    'desc': f'Campus Courier Delivery Completed (#{request_id[:6]})',
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'request_id': request_id
                })

        # Mark delivery request as completed
        if gig_doc.exists:
            gig_ref.update({
                'status': 'completed',
                'stage': 'completed',
                'escrow_status': 'RELEASED',
                'completedAt': firestore.SERVER_TIMESTAMP,
                'updatedAt': firestore.SERVER_TIMESTAMP
            })

        # Mark linked order as fulfilled/completed
        if order_ref and order_doc and order_doc.exists:
            order_ref.update({
                'status': 'completed',
                'prep_status': 'fulfilled',
                'delivery_status': 'delivered',
                'completedAt': firestore.SERVER_TIMESTAMP,
                'updatedAt': firestore.SERVER_TIMESTAMP
            })

        # Send FCM notification to Student and Driver
        try:
            from utils.fcm_utils import send_fcm_notification
            if student_uid:
                send_fcm_notification(
                    student_uid,
                    'Order Delivered! 🎉',
                    'Your order has been safely delivered. Thank you for using DISHI!',
                    data={'type': 'order_delivered', 'request_id': request_id}
                )
            if actual_driver_id:
                send_fcm_notification(
                    actual_driver_id,
                    'Delivery Completed! 💵',
                    f'You earned KES {delivery_fee:.0f} for this delivery. Great job!',
                    data={'type': 'payout_credited', 'amount': str(delivery_fee)}
                )
        except Exception as fcm_err:
            print('FCM delivery completion error:', fcm_err)

        return jsonify({
            'status': 'success',
            'message': 'Delivery successfully verified and completed! Courier fee paid.',
            'earned': delivery_fee
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@campus_gigs_v6_bp.route('/request_order_delivery', methods=['POST'])
def request_order_delivery():
    """
    Dispatches a DeLiv Campus Courier for an existing preorder or supermarket purchase.
    Locks courier delivery fee in Escrow and creates dual OTP pins for secure handoff.
    """
    data = request.json or {}
    order_id = data.get('order_id')
    student_id = data.get('student_id')
    dropoff_location = data.get('dropoff_location', 'Campus Hostel')
    dropoff_lat = data.get('dropoff_lat')
    dropoff_lng = data.get('dropoff_lng')
    delivery_fee = float(data.get('delivery_fee', 50.0))

    if not order_id or not student_id:
        return jsonify({'error': 'Missing order_id or student_id'}), 400

    db = firestore.client()

    try:
        # Check student balance
        student_ref = db.collection('users').document(student_id)
        student_snap = student_ref.get()
        if not student_snap.exists:
            return jsonify({'error': 'Student user not found'}), 404

        student_data = student_snap.to_dict()
        cur_bal = float(student_data.get('walletBalance') or 0.0)

        if cur_bal < delivery_fee:
            return jsonify({'error': f'Insufficient wallet balance. Courier fee requires KES {delivery_fee:.2f}'}), 400

        # Fetch order details
        order_ref = db.collection('orders').document(order_id)
        order_snap = order_ref.get()
        vendor_name = 'Campus Vendor'
        vendor_id = ''
        items_summary = 'Food / Goods'
        if order_snap.exists:
            o_data = order_snap.to_dict()
            vendor_name = o_data.get('vendorName') or o_data.get('vendor_name') or 'Campus Vendor'
            vendor_id = o_data.get('vendorId') or o_data.get('vendor_id') or ''
            items = o_data.get('items', [])
            if items:
                items_summary = ', '.join([f"{it.get('quantity', 1)}x {it.get('name', 'Item')}" for it in items[:3]])

        # Generate 4-digit Vendor Pickup PIN and Student Delivery PIN
        vendor_pickup_pin = f"{random.randint(1000, 9999)}"
        student_delivery_pin = f"{random.randint(1000, 9999)}"
        rand_suffix = uuid.uuid4().hex[:8].upper()
        gig_id = f"DELIV_{rand_suffix}"

        # Deduct delivery fee and place in Escrow
        student_ref.update({
            'walletBalance': cur_bal - delivery_fee,
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        student_ref.collection('transactions').add({
            'type': 'DELIV_ESCROW_HOLD',
            'amount': -delivery_fee,
            'desc': f'DeLiv Courier Escrow Hold (#{order_id[:6]})',
            'timestamp': firestore.SERVER_TIMESTAMP,
            'order_id': order_id,
            'gig_id': gig_id
        })

        # Create deliv_requests entry
        gig_doc_data = {
            'id': gig_id,
            'orderId': order_id,
            'order_id': order_id,
            'type': 'Food Delivery',
            'status': 'open',
            'stage': 'en_route_pickup',
            'pay': f'KES {delivery_fee:.0f}',
            'deliveryFee': delivery_fee,
            'pickup': vendor_name,
            'vendorName': vendor_name,
            'vendorId': vendor_id,
            'dropoff': dropoff_location,
            'dropoffLocation': dropoff_location,
            'studentUid': student_id,
            'postedBy': student_id,
            'studentName': student_data.get('displayName') or student_data.get('name') or 'Student',
            'studentPhone': student_data.get('phoneNumber') or '',
            'itemsSummary': items_summary,
            'vendorPickupPin': vendor_pickup_pin,
            'studentDeliveryPin': student_delivery_pin,
            'escrow_status': 'HELD',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'timestamp': firestore.SERVER_TIMESTAMP,
        }
        if dropoff_lat is not None and dropoff_lng is not None:
            gig_doc_data['dropoffLat'] = float(dropoff_lat)
            gig_doc_data['dropoffLng'] = float(dropoff_lng)

        db.collection('deliv_requests').document(gig_id).set(gig_doc_data)

        # Update order with courier details
        if order_snap.exists:
            order_ref.update({
                'fulfillmentType': 'deliv_courier',
                'deliv_request_id': gig_id,
                'deliveryFee': delivery_fee,
                'dropoffLocation': dropoff_location,
                'vendorPickupPin': vendor_pickup_pin,
                'studentDeliveryPin': student_delivery_pin,
                'deliveryStatus': 'courier_requested',
                'updatedAt': firestore.SERVER_TIMESTAMP
            })

        return jsonify({
            'status': 'success',
            'message': 'DeLiv courier requested! Nearby riders have been notified.',
            'gig_id': gig_id,
            'vendor_pickup_pin': vendor_pickup_pin,
            'student_delivery_pin': student_delivery_pin,
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500
