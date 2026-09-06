from flask import Blueprint, jsonify, request
import os

marketplace_v2_bp = Blueprint('marketplace_v2', __name__)

@marketplace_v2_bp.route('/items', methods=['GET'])
def get_items():
    try:
        from firebase_admin import firestore
        db = firestore.client()
        items_ref = db.collection('marketplace_items').where('status', '==', 'Available').limit(100).stream()
        
        items = []
        for i in items_ref:
            data = i.to_dict()
            data['id'] = i.id
            items.append(data)
            
        return jsonify({"status": "success", "items": items}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@marketplace_v2_bp.route('/create', methods=['POST'])
def create_item():
    data = request.json or {}
    seller_id = data.get('seller_id')
    title = data.get('title')
    price = data.get('price')
    description = data.get('description', '')
    image_url = data.get('image_url', '')

    if not all([seller_id, title, price]):
        return jsonify({"error": "Missing fields"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()
        item_ref = db.collection('marketplace_items').document()
        item_ref.set({
            'seller_id': seller_id,
            'title': title,
            'price': float(price),
            'description': description,
            'image_url': image_url,
            'status': 'Available',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "item_id": item_ref.id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@marketplace_v2_bp.route('/checkout_cart', methods=['POST'])
def checkout_cart():
    data = request.json or {}
    buyer_id = data.get('buyer_id')
    item_ids = data.get('item_ids', [])
    payment_method = data.get('payment_method', 'vault')
    phone_number = data.get('phone_number')

    if not all([buyer_id, item_ids]):
        return jsonify({"error": "Missing fields"}), 400
        
    if not isinstance(item_ids, list) or len(item_ids) == 0:
        return jsonify({"error": "item_ids must be a non-empty list"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        # 1. Fetch all items and calculate total price
        total_price = 0.0
        items_to_buy = []
        for item_id in item_ids:
            item_doc = db.collection('marketplace_items').document(item_id).get()
            if not item_doc.exists:
                return jsonify({"error": f"Item {item_id} not found"}), 404
            
            item_data = item_doc.to_dict()
            if item_data.get('status') != 'Available':
                return jsonify({"error": f"Item {item_id} is not available"}), 400
            
            price = float(item_data.get('price', 0))
            total_price += price
            items_to_buy.append({
                'ref': item_doc.reference,
                'price': price,
                'seller_id': item_data.get('seller_id')
            })

        platform_commission = 20.0 * len(item_ids) # 20 KES per item
        total_charge = total_price + platform_commission

        if payment_method == 'mpesa':
            if not phone_number:
                return jsonify({"error": "Phone number required for M-Pesa payment"}), 400
                
            from flask import request as flask_request
            import requests
            base_url = flask_request.host_url.rstrip('/')
            
            resp = requests.post(f"{base_url}/api/v1/mpesa/stkpush", json={
                'phone_number': phone_number,
                'amount': total_charge,
                'credit_amount': total_price,
                'user_id': buyer_id, # buyer_id used to identify the payer in STK callback
                'destination': 'walletBalance',
                'metadata': {
                    'action': 'checkout_cart',
                    'item_ids': item_ids,
                    'buyer_id': buyer_id
                }
            }, timeout=15)
            
            if resp.status_code != 200:
                return jsonify({"error": "Failed to initiate M-Pesa payment"}), 400
                
            resp_data = resp.json()
            checkout_id = resp_data.get('CheckoutRequestID')
            
            db.collection('transactions').document().set({
                'type': 'marketplace_escrow_hold_cart',
                'amount': total_charge,
                'commission': platform_commission,
                'buyer_id': buyer_id,
                'item_ids': item_ids,
                'payment_method': 'mpesa',
                'checkout_id': checkout_id,
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            
            return jsonify({"status": "pending", "checkout_id": checkout_id, "message": "M-Pesa payment initiated. Please enter PIN."}), 200

        # Wallet payment
        transaction = db.transaction()
        buyer_ref = db.collection('users').document(buyer_id)

        @firestore.transactional
        def process_checkout(transaction, buyer_ref, items_to_buy, total_charge, buyer_id, payment_method):
            buyer_snap = buyer_ref.get(transaction=transaction)
            
            source_field = 'walletBalance' if payment_method == 'vault' else 'savingsBalance'
            buyer_balance = float(buyer_snap.to_dict().get(source_field, 0))

            if buyer_balance < total_charge:
                raise Exception(f"Insufficient {payment_method} Balance")

            # Deduct combined total from buyer
            transaction.update(buyer_ref, {
                source_field: buyer_balance - total_charge
            })

            # Update each item to 'In Escrow'
            for item in items_to_buy:
                transaction.update(item['ref'], {
                    'status': 'In Escrow',
                    'buyer_id': buyer_id,
                    'escrow_amount': item['price'],
                    'updated_at': firestore.SERVER_TIMESTAMP
                })

        process_checkout(transaction, buyer_ref, items_to_buy, total_charge, buyer_id, payment_method)
        
        db.collection('transactions').document().set({
            'type': 'marketplace_escrow_hold_cart',
            'amount': total_charge,
            'commission': platform_commission,
            'buyer_id': buyer_id,
            'item_ids': item_ids,
            'payment_method': payment_method,
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        return jsonify({"status": "success", "message": f"{len(item_ids)} items purchased. Funds held in Escrow."}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@marketplace_v2_bp.route('/confirm_delivery', methods=['POST'])
def confirm_delivery():
    data = request.json or {}
    buyer_id = data.get('buyer_id')
    item_id = data.get('item_id')

    if not all([buyer_id, item_id]):
        return jsonify({"error": "Missing fields"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()

        item_doc = db.collection('marketplace_items').document(item_id).get()
        if not item_doc.exists:
            return jsonify({"error": "Item not found"}), 404

        item_data = item_doc.to_dict()
        if item_data.get('status') != 'In Escrow':
            return jsonify({"error": "Item is not in Escrow"}), 400

        if item_data.get('buyer_id') != buyer_id:
            return jsonify({"error": "Only the buyer can confirm delivery"}), 403

        seller_id = item_data.get('seller_id')
        price = float(item_data.get('escrow_amount', 0))
        fee_percentage = 0.015
        admin_fee = price * fee_percentage
        seller_payout = price - admin_fee

        transaction = db.transaction()
        seller_ref = db.collection('users').document(seller_id)
        admin_pool_ref = db.collection('admin_finances').document('dishi_rent_pool')
        item_ref = item_doc.reference

        @firestore.transactional
        def process_delivery(transaction, seller_ref, admin_pool_ref, item_ref, payout, fee):
            seller_snap = seller_ref.get(transaction=transaction)
            admin_snap = admin_pool_ref.get(transaction=transaction)
            
            seller_wallet = float(seller_snap.to_dict().get('walletBalance', 0))

            transaction.update(seller_ref, {
                'walletBalance': seller_wallet + payout
            })
            
            if admin_snap.exists:
                admin_data = admin_snap.to_dict()
                transaction.update(admin_pool_ref, {
                    'marketplace_escrow_pool': admin_data.get('marketplace_escrow_pool', 0) + fee,
                    'total_collected': admin_data.get('total_collected', 0) + fee,
                    'updated_at': firestore.SERVER_TIMESTAMP
                })
            else:
                transaction.set(admin_pool_ref, {
                    'marketplace_escrow_pool': fee,
                    'total_collected': fee,
                    'updated_at': firestore.SERVER_TIMESTAMP
                })

            transaction.update(item_ref, {
                'status': 'Sold',
                'updated_at': firestore.SERVER_TIMESTAMP
            })

        process_delivery(transaction, seller_ref, admin_pool_ref, item_ref, seller_payout, admin_fee)

        db.collection('transactions').document().set({
            'type': 'marketplace_escrow_release',
            'amount': seller_payout,
            'fee': admin_fee,
            'seller_id': seller_id,
            'buyer_id': buyer_id,
            'item_id': item_id,
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        return jsonify({"status": "success", "message": "Delivery confirmed. Funds released to seller."}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@marketplace_v2_bp.route('/swipe_exchange/trade', methods=['POST'])
def trade_swipe():
    data = request.json or {}
    student_id = data.get('studentId')
    swipes_to_trade = int(data.get('swipes', 0))
    exchange_rate = 150.0 
    
    if not student_id or swipes_to_trade <= 0:
        return jsonify({"error": "Invalid parameters"}), 400

    try:
        from firebase_admin import firestore
        db = firestore.client()
        student_ref = db.collection('users').document(student_id)
        student_doc = student_ref.get()
        
        if not student_doc.exists:
            return jsonify({"error": "Student not found"}), 404
            
        student_data = student_doc.to_dict()
        current_swipes = student_data.get('mealSwipes', 0)
        
        if current_swipes < swipes_to_trade:
            return jsonify({"error": "Not enough meal swipes"}), 400
            
        wallet_credit = swipes_to_trade * exchange_rate
        
        batch = db.batch()
        batch.update(student_ref, {
            'mealSwipes': firestore.Increment(-swipes_to_trade),
            'walletBalance': firestore.Increment(wallet_credit)
        })
        
        tx_ref = db.collection('transactions').document()
        batch.set(tx_ref, {
            'studentId': student_id,
            'type': 'swipe_exchange',
            'swipesTraded': swipes_to_trade,
            'amountCredited': wallet_credit,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        
        batch.commit()
        
        return jsonify({"status": "success", "creditedAmount": wallet_credit, "message": f"{swipes_to_trade} swipes exchanged for Ksh {wallet_credit}."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
