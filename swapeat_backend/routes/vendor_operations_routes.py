from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import random
from utils.fcm_utils import send_fcm_notification

vendor_operations_bp = Blueprint('vendor_operations', __name__)

@vendor_operations_bp.route('/orders/update_status', methods=['POST'])
def update_order_status():
    data = request.json
    order_id = data.get('order_id')
    status = data.get('status')
    
    if not all([order_id, status]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        order_ref = db.collection('orders').document(order_id)
        order_doc = order_ref.get()
        
        if not order_doc.exists:
            return jsonify({"error": "Order not found"}), 404
            
        order_data = order_doc.to_dict()
        order_ref.update({'status': status})
        
        # Send FCM notification to student
        student_id = order_data.get('student_id')
        if student_id:
            title = "Order Update"
            body = f"Your order from {order_data.get('vendor_name', 'a vendor')} has been {status}."
            send_fcm_notification(student_id, title, body)
            
        return jsonify({"message": f"Order status updated to {status}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_operations_bp.route('/predictive_prep', methods=['GET'])
def predictive_prep():
    """ 
    AI Predictive Prep (Mocked for now)
    Returns suggested prep quantities based on historical data, weather, and day of week.
    """
    vendor_uid = request.args.get('vendorUid')
    if not vendor_uid:
        return jsonify({"error": "Missing vendorUid"}), 400

    # In a real app, query past sales grouped by day of week and weather APIs
    predictions = [
        {"item": "Chapati", "suggested_prep": random.randint(40, 80), "confidence": 0.85, "reason": "High demand on Tuesdays"},
        {"item": "Beef Stew", "suggested_prep": random.randint(20, 50), "confidence": 0.92, "reason": "Cold weather forecast"},
        {"item": "Samosa", "suggested_prep": random.randint(30, 60), "confidence": 0.75, "reason": "Morning snack trend"}
    ]
    
    return jsonify({"status": "success", "predictions": predictions}), 200

@vendor_operations_bp.route('/inventory/stock', methods=['POST'])
def manage_stock():
    """ Log inventory additions or deductions """
    data = request.json
    vendor_uid = data.get('vendorUid')
    item_name = data.get('itemName')
    quantity = float(data.get('quantity', 0))
    action = data.get('action') # 'add' or 'deduct'

    if not all([vendor_uid, item_name, quantity > 0, action]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        inv_ref = db.collection('users').document(vendor_uid).collection('inventory').document(item_name.lower().replace(' ', '_'))
        
        @firestore.transactional
        def update_stock(transaction):
            doc = inv_ref.get(transaction=transaction)
            current_stock = float(doc.to_dict().get('quantity', 0.0)) if doc.exists else 0.0
            
            if action == 'add':
                new_stock = current_stock + quantity
            elif action == 'deduct':
                new_stock = max(0, current_stock - quantity)
            else:
                return False, "Invalid action"
                
            if not doc.exists:
                transaction.set(inv_ref, {'itemName': item_name, 'quantity': new_stock, 'updatedAt': firestore.SERVER_TIMESTAMP})
            else:
                transaction.update(inv_ref, {'quantity': new_stock, 'updatedAt': firestore.SERVER_TIMESTAMP})
                
            return True, f"Stock updated to {new_stock}"

        transaction = db.transaction()
        success, msg = update_stock(transaction)
        
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_operations_bp.route('/inventory/costing', methods=['POST'])
def dynamic_costing():
    """ Calculate profit margin based on recipe ingredients """
    data = request.json
    selling_price = float(data.get('sellingPrice', 0))
    ingredients = data.get('ingredients', []) # List of dicts: {'name': 'Flour', 'cost': 15}

    if selling_price <= 0 or not ingredients:
        return jsonify({"error": "Invalid input"}), 400

    total_cost = sum([float(i.get('cost', 0)) for i in ingredients])
    profit = selling_price - total_cost
    margin = (profit / selling_price) * 100 if selling_price > 0 else 0

    return jsonify({
        "status": "success", 
        "totalCost": total_cost,
        "profit": profit,
        "marginPercentage": round(margin, 2)
    }), 200

@vendor_operations_bp.route('/waste/log', methods=['POST'])
def log_waste():
    """ Log unsold items at end of day """
    data = request.json
    vendor_uid = data.get('vendorUid')
    item_name = data.get('itemName')
    quantity = float(data.get('quantity', 0))

    if not all([vendor_uid, item_name, quantity > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        waste_ref = db.collection('users').document(vendor_uid).collection('waste_logs').document()
        waste_ref.set({
            'itemName': item_name,
            'quantity': quantity,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": "Waste logged successfully."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
