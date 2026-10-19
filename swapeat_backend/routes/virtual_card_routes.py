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

        card_response = card_data.copy()
        card_response['createdAt'] = datetime.now().isoformat()

        return jsonify({'message': 'Card generated successfully', 'card': card_response}), 200

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

@card_bp.route('/api/card/online/charge', methods=['POST'])
def online_card_charge():
    """
    Processes online card payments using standard e-commerce card parameters:
    - pan: 16 digit card number
    - cvv: 3 digit code
    - expiry: MM/YY
    - amount: float
    - merchant_name: string (e.g. 'Jumia', 'Coursera', 'Campus Bookstore')
    - category: string
    """
    data = request.get_json() or {}
    raw_pan = data.get('pan', '').strip()
    cvv = data.get('cvv', '').strip()
    expiry = data.get('expiry', '').strip()
    amount = float(data.get('amount', 0))
    merchant_name = data.get('merchant_name', 'Online Merchant')
    category = data.get('category', 'Online Shopping')
    uid = data.get('uid')

    if not raw_pan or not cvv or not expiry or amount <= 0:
        return jsonify({'error': 'Missing or invalid card details', 'code': 'INVALID_PARAMS'}), 400

    clean_pan = raw_pan.replace(" ", "")

    try:
        card_doc = None
        target_uid = uid

        if target_uid:
            doc = db.collection('virtual_cards').document(target_uid).get()
            if doc.exists:
                card_data = doc.to_dict()
                if card_data.get('pan', '').replace(" ", "") == clean_pan:
                    card_doc = doc
        else:
            query = db.collection('virtual_cards').where('pan', '==', raw_pan).limit(1).get()
            if not query and len(clean_pan) == 16:
                spaced_pan = f"{clean_pan[0:4]} {clean_pan[4:8]} {clean_pan[8:12]} {clean_pan[12:16]}"
                query = db.collection('virtual_cards').where('pan', '==', spaced_pan).limit(1).get()
            
            if query:
                card_doc = query[0]
                target_uid = card_doc.id

        if not card_doc or not card_doc.exists:
            return jsonify({'error': 'Card not recognized or invalid number', 'code': 'CARD_NOT_FOUND'}), 404

        card = card_doc.to_dict()

        # 1. Check card status
        if card.get('status') == 'frozen':
            return jsonify({'error': 'Card is frozen. Please unfreeze in DISHI app.', 'code': 'CARD_FROZEN'}), 403

        # 2. Check if online transactions allowed
        if card.get('onlineTransactions') is False:
            return jsonify({'error': 'Online transactions are disabled on this card. Enable in card settings.', 'code': 'ONLINE_DISABLED'}), 403

        # 3. Check CVV
        if str(card.get('cvv')) != str(cvv):
            return jsonify({'error': 'Invalid CVV security code', 'code': 'INVALID_CVV'}), 400

        # 4. Check Expiry
        card_expiry = card.get('expiry', '')
        if card_expiry != expiry:
            return jsonify({'error': 'Card expiry date does not match', 'code': 'INVALID_EXPIRY'}), 400

        # 5. Check daily limit
        daily_limit = float(card.get('dailyLimit', 5000))
        if amount > daily_limit:
            return jsonify({'error': f'Amount KES {amount:.2f} exceeds your daily limit of KES {daily_limit:.2f}', 'code': 'LIMIT_EXCEEDED'}), 400

        # Simulation safeguard: simulation must not deduct student wallet funds
        if data.get('is_simulation') or merchant_name in ['Campus Bookstore', 'Coursera Student Pass', 'Spotify Student Plan', 'Kilimall Tech Gadget']:
            return jsonify({
                'status': 'coming_soon',
                'message': 'Online purchase simulation is coming soon and disabled from deducting student wallet balance.',
                'code': 'SIMULATION_COMING_SOON'
            }), 400

        # 6. Check student wallet balance
        user_ref = db.collection('users').document(target_uid)
        user_doc = user_ref.get()
        if not user_doc.exists:
            return jsonify({'error': 'Student user profile not found', 'code': 'USER_NOT_FOUND'}), 404

        user_data = user_doc.to_dict()
        wallet_balance = float(user_data.get('walletBalance', 0.0))

        if wallet_balance < amount:
            return jsonify({
                'error': f'Insufficient wallet balance (KES {wallet_balance:.2f}). Please top up your DISHI wallet via M-Pesa.',
                'code': 'INSUFFICIENT_FUNDS',
                'balance': wallet_balance,
                'required': amount
            }), 400

        # 7. Deduct from wallet atomically
        new_balance = wallet_balance - amount
        user_ref.update({'walletBalance': new_balance})

        # 8. Record transaction
        txn_id = str(uuid.uuid4())
        txn_data = {
            'id': txn_id,
            'uid': target_uid,
            'amount': amount,
            'merchantId': 'ONLINE_CHECKOUT',
            'merchantName': merchant_name,
            'category': category,
            'type': 'online_purchase',
            'status': 'completed',
            'timestamp': firestore.SERVER_TIMESTAMP,
            'pan_last4': clean_pan[-4:],
            'isOnline': True,
        }
        db.collection('card_transactions').document(txn_id).set(txn_data)

        # 9. Handle Burner Card (Single-Use disposable card)
        is_burner = card.get('status') == 'burner'
        if is_burner:
            db.collection('virtual_cards').document(target_uid).delete()

        # 10. Give 1% Cashback to wallet
        cashback = round(amount * 0.01, 2)
        if cashback > 0:
            user_ref.update({'walletBalance': firestore.Increment(cashback)})
            db.collection('transactions').add({
                'userId': target_uid,
                'type': 'card_cashback',
                'amount': cashback,
                'description': f'1% Online Card Cashback from {merchant_name}',
                'timestamp': firestore.SERVER_TIMESTAMP
            })

        # 11. Send in-app notification
        db.collection('notifications').add({
            'targetUserId': target_uid,
            'title': 'Online Purchase Approved 💳',
            'body': f'KES {amount:.2f} spent at {merchant_name}. (Card ending in {clean_pan[-4:]})',
            'type': 'card_purchase',
            'amount': amount,
            'createdAt': firestore.SERVER_TIMESTAMP,
            'readBy': [],
        })

        return jsonify({
            'status': 'approved',
            'message': 'Online payment authorized successfully',
            'transactionId': txn_id,
            'amount': amount,
            'merchant': merchant_name,
            'newBalance': new_balance,
            'cashbackEarned': cashback,
            'burnerDestroyed': is_burner,
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@card_bp.route('/api/card/online/verify', methods=['POST'])
def online_card_verify():
    """
    Validates card credentials for online pre-auth without charging.
    """
    data = request.get_json() or {}
    raw_pan = data.get('pan', '').strip()
    cvv = data.get('cvv', '').strip()
    expiry = data.get('expiry', '').strip()

    clean_pan = raw_pan.replace(" ", "")
    if len(clean_pan) != 16 or not cvv or not expiry:
        return jsonify({'valid': False, 'error': 'Invalid card format'}), 400

    try:
        query = db.collection('virtual_cards').where('pan', '==', raw_pan).limit(1).get()
        if not query and len(clean_pan) == 16:
            spaced_pan = f"{clean_pan[0:4]} {clean_pan[4:8]} {clean_pan[8:12]} {clean_pan[12:16]}"
            query = db.collection('virtual_cards').where('pan', '==', spaced_pan).limit(1).get()

        if not query:
            return jsonify({'valid': False, 'error': 'Card not found'}), 404

        card = query[0].to_dict()
        if card.get('status') == 'frozen':
            return jsonify({'valid': False, 'error': 'Card is frozen'}), 403

        if card.get('onlineTransactions') is False:
            return jsonify({'valid': False, 'error': 'Online transactions disabled'}), 403

        if str(card.get('cvv')) != str(cvv) or card.get('expiry') != expiry:
            return jsonify({'valid': False, 'error': 'Incorrect CVV or expiry'}), 400

        return jsonify({'valid': True, 'message': 'Card verified successfully', 'status': card.get('status')}), 200
    except Exception as e:
        return jsonify({'valid': False, 'error': str(e)}), 500

