from flask import Blueprint, jsonify, request
from firebase_admin import firestore, messaging
import datetime

vendor_sales_bp = Blueprint('vendor_sales', __name__)

@vendor_sales_bp.route('/sales/flash_sale', methods=['POST'])
def create_flash_sale():
    """ Create a flash sale and push notifications to students """
    data = request.json
    vendor_uid = data.get('vendorUid')
    item_name = data.get('itemName')
    discount_msg = data.get('discountMsg') # e.g. "50% off for the next hour!"

    if not all([vendor_uid, item_name, discount_msg]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        
        # 1. Store Flash Sale
        sale_ref = db.collection('flash_sales').document()
        sale_ref.set({
            'vendorUid': vendor_uid,
            'itemName': item_name,
            'discountMsg': discount_msg,
            'isActive': True,
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        # 2. Push notification (Simulated broadly, in reality target nearby/recent students)
        # We can send to a topic like 'campus_deals'
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=f"FLASH SALE: {item_name}",
                    body=discount_msg,
                ),
                    android=messaging.AndroidConfig(priority='high', notification=messaging.AndroidNotification(sound='default')),
                    apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True, sound='default'))),
                topic="campus_deals"
            )
            messaging.send(message)
        except Exception as e:
            print(f"FCM Topic error: {e}")

        return jsonify({"status": "success", "message": "Flash sale broadcasted successfully!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_sales_bp.route('/loyalty/stamp', methods=['POST'])
def add_loyalty_stamp():
    """ Add a stamp to a student's digital punch card """
    data = request.json
    vendor_uid = data.get('vendorUid')
    student_uid = data.get('studentUid')

    if not all([vendor_uid, student_uid]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        loyalty_ref = db.collection('users').document(student_uid).collection('loyalty').document(vendor_uid)

        @firestore.transactional
        def process_stamp(transaction):
            doc = loyalty_ref.get(transaction=transaction)
            current_stamps = doc.to_dict().get('stamps', 0) if doc.exists else 0
            
            new_stamps = current_stamps + 1
            reward_unlocked = False
            
            # Buy 10 get 1 free logic
            if new_stamps >= 10:
                reward_unlocked = True
                new_stamps = 0 # reset
                
            if not doc.exists:
                transaction.set(loyalty_ref, {'vendorUid': vendor_uid, 'stamps': new_stamps})
            else:
                transaction.update(loyalty_ref, {'stamps': new_stamps})
                
            return True, new_stamps, reward_unlocked

        transaction = db.transaction()
        success, stamps, reward = process_stamp(transaction)
        
        if success:
            msg = "Reward Unlocked! Free Meal Earned." if reward else f"Stamp added! Total: {stamps}/10"
            return jsonify({"status": "success", "message": msg, "stamps": stamps, "rewardUnlocked": reward}), 200
        else:
            return jsonify({"error": "Failed to add stamp"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_sales_bp.route('/preorders/queue', methods=['GET'])
def get_preorders():
    """ Get pending pre-paid parent orders (KDS style) """
    vendor_uid = request.args.get('vendorUid')
    if not vendor_uid:
        return jsonify({"error": "Missing vendorUid"}), 400

    try:
        db = firestore.client()
        orders_ref = db.collection('orders')
        query = orders_ref.where('vendorUid', '==', vendor_uid).where('status', '==', 'pending').limit(50)
        
        results = []
        for doc in query.stream():
            data = doc.to_dict()
            data['id'] = doc.id
            results.append(data)
            
        return jsonify({"status": "success", "orders": results}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_sales_bp.route('/preorders/fulfill', methods=['POST'])
def fulfill_preorder():
    """ Mark a pre-order as fulfilled/collected """
    data = request.json
    order_id = data.get('orderId')

    if not order_id:
        return jsonify({"error": "Missing orderId"}), 400

    try:
        db = firestore.client()
        order_ref = db.collection('orders').document(order_id)
        order_ref.update({'status': 'fulfilled', 'fulfilledAt': firestore.SERVER_TIMESTAMP})
        
        return jsonify({"status": "success", "message": "Order fulfilled."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
