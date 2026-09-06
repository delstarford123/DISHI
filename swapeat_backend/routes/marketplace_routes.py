from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import datetime

marketplace_bp = Blueprint('marketplace', __name__)

@marketplace_bp.route('/escrow/create', methods=['POST'])
def create_escrow():
    data = request.json
    buyer_id = data.get('buyerId')
    seller_id = data.get('sellerId')
    amount = float(data.get('amount', 0))
    item_desc = data.get('itemDescription', '')
    
    if not all([buyer_id, seller_id, amount > 0, item_desc]):
        return jsonify({"error": "Missing parameters"}), 400

    db = firestore.client()
    buyer_ref = db.collection('users').document(buyer_id)
    buyer_doc = buyer_ref.get()
    
    if not buyer_doc.exists:
        return jsonify({"error": "Buyer not found"}), 404
        
    if float(buyer_doc.to_dict().get('walletBalance', 0)) < amount:
        return jsonify({"error": "Insufficient funds for escrow"}), 400
        
    batch = db.batch()
    
    # Deduct from buyer
    batch.update(buyer_ref, {'walletBalance': firestore.Increment(-amount)})
    
    # Create Escrow record
    escrow_ref = db.collection('escrow_transactions').document()
    batch.set(escrow_ref, {
        'buyerId': buyer_id,
        'sellerId': seller_id,
        'amount': amount,
        'itemDescription': item_desc,
        'status': 'locked',
        'timestamp': firestore.SERVER_TIMESTAMP
    })
    
    batch.commit()
    
    return jsonify({"success": True, "escrowId": escrow_ref.id, "message": "Funds locked in escrow."})

@marketplace_bp.route('/escrow/release', methods=['POST'])
def release_escrow():
    data = request.json
    escrow_id = data.get('escrowId')
    buyer_id = data.get('buyerId')
    
    if not all([escrow_id, buyer_id]):
        return jsonify({"error": "Missing parameters"}), 400

    db = firestore.client()
    escrow_ref = db.collection('escrow_transactions').document(escrow_id)
    escrow_doc = escrow_ref.get()
    
    if not escrow_doc.exists:
        return jsonify({"error": "Escrow not found"}), 404
        
    escrow_data = escrow_doc.to_dict()
    if escrow_data.get('status') != 'locked':
        return jsonify({"error": "Escrow is not locked"}), 400
        
    if escrow_data.get('buyerId') != buyer_id:
        return jsonify({"error": "Only the buyer can release the escrow"}), 403
        
    amount = escrow_data.get('amount')
    seller_id = escrow_data.get('sellerId')
    
    batch = db.batch()
    
    # Add to seller
    seller_ref = db.collection('users').document(seller_id)
    batch.update(seller_ref, {'walletBalance': firestore.Increment(amount)})
    
    # Update Escrow status
    batch.update(escrow_ref, {'status': 'released', 'releasedAt': firestore.SERVER_TIMESTAMP})
    
    batch.commit()
    
    return jsonify({"success": True, "message": "Funds released to seller."})

@marketplace_bp.route('/swipe_exchange/trade', methods=['POST'])
def trade_swipe():
    data = request.json
    student_id = data.get('studentId')
    swipes_to_trade = int(data.get('swipes', 0))
    # E.g. 1 swipe = 150 Ksh
    exchange_rate = 150.0 
    
    if not student_id or swipes_to_trade <= 0:
        return jsonify({"error": "Invalid parameters"}), 400

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
    
    return jsonify({"success": True, "creditedAmount": wallet_credit, "message": f"{swipes_to_trade} swipes exchanged for Ksh {wallet_credit}."})
