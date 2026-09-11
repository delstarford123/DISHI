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

@vendor_operations_bp.route('/vendor_offline_scan_deduction', methods=['POST'])
def vendor_offline_scan_deduction():
    """ 
    Deducts cash from a parent's wallet when a vendor scans an offline student's QR code.
    Verifies vendor whitelisting, nutritional locks, and balance before deducting.
    """
    data = request.json
    vendor_id = data.get('vendor_id')
    student_id = data.get('student_id')
    amount = float(data.get('amount', 0))
    items = data.get('items', []) # e.g. [{"name": "Soda", "price": 50, "flags": ["High Sugar"]}]

    if not all([vendor_id, student_id, amount > 0]):
        return jsonify({"error": "Missing vendor_id, student_id, or valid amount"}), 400

    try:
        db = firestore.client()
        student_ref = db.collection('users').document(student_id)
        vendor_ref = db.collection('users').document(vendor_id)
        
        student_doc = student_ref.get()
        if not student_doc.exists:
            return jsonify({"error": "Student QR invalid or not found."}), 404
            
        student_data = student_doc.to_dict()
        if not student_data.get('isOffline', False):
            # Only offline students are supported by this specific POS endpoint
            return jsonify({"error": "This QR is for an online user. They must pay via their own app."}), 400
            
        # 1. Vendor Restrictions Check
        blocked_vendors = student_data.get('blockedVendors', [])
        if vendor_id in blocked_vendors:
            return jsonify({"error": "Parent has blocked purchases from this vendor."}), 403
            
        # 2. Nutritional Locks Check
        restricted_flags = student_data.get('nutritionalLocks', [])
        for item in items:
            item_flags = item.get('flags', [])
            for flag in item_flags:
                if flag in restricted_flags:
                    return jsonify({"error": f"Purchase blocked by parent: Item '{item.get('name')}' contains restricted '{flag}'"}), 403

        # Identify Parent
        linked_parents = student_data.get('linkedParents', [])
        if not linked_parents:
            return jsonify({"error": "Offline student has no linked parent to bill."}), 400
        parent_id = linked_parents[0]
        parent_ref = db.collection('users').document(parent_id)
        
        @firestore.transactional
        def process_offline_deduction(transaction):
            parent_doc = parent_ref.get(transaction=transaction)
            if not parent_doc.exists:
                return False, "Parent account not found."
                
            parent_wallet = float(parent_doc.to_dict().get('wallet_balance', 0.0))
            if parent_wallet < amount:
                return False, "Parent vault has insufficient funds."
                
            vendor_doc = vendor_ref.get(transaction=transaction)
            vendor_wallet = float(vendor_doc.to_dict().get('wallet_balance', 0.0)) if vendor_doc.exists else 0.0
            
            # Deduct from Parent, Add to Vendor
            transaction.update(parent_ref, {'wallet_balance': parent_wallet - amount})
            transaction.update(vendor_ref, {'wallet_balance': vendor_wallet + amount})
            
            # Create transaction record
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'id': tx_ref.id,
                'student_id': student_id, # Link to offline profile
                'parent_id': parent_id,
                'vendor_id': vendor_id,
                'amount': amount,
                'type': 'offline_qr_payment',
                'status': 'completed',
                'items': items,
                'timestamp': firestore.SERVER_TIMESTAMP,
            })
            
            return True, tx_ref.id
            
        transaction = db.transaction()
        success, result = process_offline_deduction(transaction)
        
        if success:
            # Send notification to parent
            send_fcm_notification(
                parent_id, 
                "Offline Child Purchase", 
                f"{student_data.get('name', 'Your child')} spent Ksh {amount} via QR scan."
            )
            return jsonify({"status": "success", "transaction_id": result, "message": "Deduction successful"}), 200
        else:
            return jsonify({"error": result}), 400

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

            
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
