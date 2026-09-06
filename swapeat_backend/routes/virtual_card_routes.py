from flask import Blueprint, request, jsonify
from firebase_admin import firestore
from datetime import datetime
import random
import uuid

card_bp = Blueprint('card_bp', __name__)
db = firestore.client()

@card_bp.route('/api/card/generate', methods=['POST'])
def generate_card():
    data = request.get_json()
    uid = data.get('uid')
    if not uid:
        return jsonify({'error': 'UID required'}), 400

    try:
        # Check if card already exists
        card_ref = db.collection('virtual_cards').document(uid)
        doc = card_ref.get()
        if doc.exists:
            return jsonify({'message': 'Card already exists', 'card': doc.to_dict()}), 200

        # Generate standard 16 digit PAN starting with 4512 (Visa-style)
        pan = f"4512 {random.randint(1000, 9999)} {random.randint(1000, 9999)} {random.randint(1000, 9999)}"
        # Expiry 4 years from now
        now = datetime.now()
        expiry_month = f"{now.month:02d}"
        expiry_year = str((now.year + 4) % 100)
        expiry = f"{expiry_month}/{expiry_year}"
        cvv = f"{random.randint(100, 999)}"

        card_data = {
            'pan': pan,
            'expiry': expiry,
            'cvv': cvv,  # In production, this should be encrypted
            'uid': uid,
            'status': 'active', # active, frozen, burner
            'dailyLimit': 5000,
            'createdAt': firestore.SERVER_TIMESTAMP,
            'pin': None
        }
        
        card_ref.set(card_data)
        
        # Cleanup old dummy data from users collection if exists
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()
        if user_doc.exists and 'virtualCard' in user_doc.to_dict():
            user_ref.update({'virtualCard': firestore.DELETE_FIELD})

        return jsonify({'message': 'Card generated successfully', 'card': card_data}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@card_bp.route('/api/card/update_status', methods=['POST'])
def update_status():
    data = request.get_json()
    uid = data.get('uid')
    status = data.get('status')
    
    if not uid or not status:
        return jsonify({'error': 'Missing parameters'}), 400
        
    try:
        db.collection('virtual_cards').document(uid).update({'status': status})
        return jsonify({'message': f'Card status updated to {status}'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@card_bp.route('/api/card/update_limit', methods=['POST'])
def update_limit():
    data = request.get_json()
    uid = data.get('uid')
    limit = data.get('limit')
    
    if not uid or limit is None:
        return jsonify({'error': 'Missing parameters'}), 400
        
    try:
        db.collection('virtual_cards').document(uid).update({'dailyLimit': float(limit)})
        return jsonify({'message': 'Limit updated successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@card_bp.route('/api/card/pay', methods=['POST'])
def local_merchant_pay():
    data = request.get_json()
    uid = data.get('uid')
    amount = float(data.get('amount', 0))
    merchant_id = data.get('merchantId')
    merchant_name = data.get('merchantName', 'Local Merchant')
    category = data.get('category', 'General')
    
    if not uid or amount <= 0:
        return jsonify({'error': 'Invalid payment details'}), 400
        
    try:
        card_ref = db.collection('virtual_cards').document(uid)
        user_ref = db.collection('users').document(uid)
        
        card = card_ref.get().to_dict()
        user = user_ref.get().to_dict()
        
        if not card or card.get('status') == 'frozen':
            return jsonify({'error': 'Card is frozen or invalid'}), 400
            
        wallet_balance = user.get('walletBalance', 0)
        
        if wallet_balance < amount:
            return jsonify({'error': 'Insufficient wallet balance', 'requires_mpesa_overdraft': True}), 400
            
        # Check limit
        daily_limit = card.get('dailyLimit', 5000)
        # Simplified limit check (in production, sum up today's txns)
        if amount > daily_limit:
            return jsonify({'error': 'Amount exceeds daily card limit'}), 400
            
        # Deduct
        new_balance = wallet_balance - amount
        user_ref.update({'walletBalance': new_balance})
        
        # Log Transaction
        txn_id = str(uuid.uuid4())
        txn_data = {
            'id': txn_id,
            'uid': uid,
            'amount': amount,
            'merchantId': merchant_id,
            'merchantName': merchant_name,
            'category': category,
            'type': 'card_swipe',
            'status': 'completed',
            'timestamp': firestore.SERVER_TIMESTAMP,
            'pan_last4': card['pan'][-4:]
        }
        db.collection('card_transactions').document(txn_id).set(txn_data)
        
        # Check Burner status
        if card.get('status') == 'burner':
            card_ref.delete()
            return jsonify({'message': 'Payment successful. Burner card destroyed.', 'newBalance': new_balance}), 200

        # Cashback logic (1% on local vendors)
        if merchant_id:
            cashback = amount * 0.01
            if cashback > 0:
                user_ref.update({'walletBalance': new_balance + cashback})
                db.collection('transactions').add({
                    'userId': uid,
                    'type': 'cashback',
                    'amount': cashback,
                    'description': f'1% Cashback from {merchant_name}',
                    'timestamp': firestore.SERVER_TIMESTAMP
                })

        return jsonify({'message': 'Payment successful', 'newBalance': new_balance}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
