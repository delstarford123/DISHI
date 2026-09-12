from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import uuid
import traceback

campus_gigs_v6_bp = Blueprint('campus_gigs_v6', __name__)

@campus_gigs_v6_bp.route('/register', methods=['POST'])
def register_worker():
    data = request.json or {}
    user_id = data.get('user_id')
    category = data.get('category')
    portfolio_images = data.get('portfolio_images', [])
    description = data.get('description', '')
    
    if not user_id or not category:
        return jsonify({"error": "Missing user_id or category"}), 400
        
    try:
        db = firestore.client()
        worker_ref = db.collection('campus_gig_workers').document(user_id)
        
        worker_ref.set({
            'user_id': user_id,
            'category': category,
            'portfolio_images': portfolio_images,
            'description': description,
            'is_available': True,
            'status': 'active',
            'rating': 5.0,
            'completed_gigs': 0,
            'created_at': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
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
    
    if not requester_id or not category or not details:
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        db = firestore.client()
        request_id = str(uuid.uuid4())
        
        db.collection('campus_gig_requests').document(request_id).set({
            'request_id': request_id,
            'requester_id': requester_id,
            'category': category,
            'details': details,
            'price_offer': float(price_offer),
            'status': 'pending',
            'worker_id': None,
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
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
            
            transaction.update(req_ref, {
                'escrow_status': 'HELD',
                'fee_deducted': fee,
                'net_amount': price
            })
            
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

    if not request_id or not requester_id:
        return jsonify({"error": "Missing request_id or requester_id"}), 400

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
