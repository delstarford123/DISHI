import os
from flask import Blueprint, request, jsonify
from firebase_admin import firestore
from datetime import datetime, timedelta
import random

games_bp = Blueprint('games_bp', __name__)
db = firestore.client()

def get_user_id(req):
    auth_header = req.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None
    token = auth_header.split(' ')[1]
    return token

@games_bp.route('/score', methods=['POST'])
def submit_score():
    uid = get_user_id(request)
    if not uid:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.json
    game_id = data.get('game_id')
    score = data.get('score', 0)

    if not game_id:
        return jsonify({"error": "Missing game_id"}), 400

    try:
        if score < 0 or score > 100000:
            return jsonify({"error": "Suspicious score detected"}), 400

        db.collection('game_leaderboards').add({
            'uid': uid,
            'game_id': game_id,
            'score': score,
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        user_stats_ref = db.collection('user_game_stats').document(uid)
        user_stats_doc = user_stats_ref.get()
        if user_stats_doc.exists:
            current_best = user_stats_doc.to_dict().get(f'best_{game_id}', 0)
            if score > current_best:
                user_stats_ref.update({f'best_{game_id}': score})
        else:
            user_stats_ref.set({f'best_{game_id}': score})

        coins_earned = score // 100
        if coins_earned > 0:
            user_ref = db.collection('users').document(uid)
            user_ref.set({'dishi_coins': firestore.Increment(coins_earned)}, merge=True)

        return jsonify({"message": "Score submitted", "coins_earned": coins_earned}), 200

    except Exception as e:
        print(f"Submit score error: {e}")
        return jsonify({"error": "Internal server error"}), 500

@games_bp.route('/spin', methods=['POST'])
def daily_spin():
    uid = get_user_id(request)
    if not uid:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        user_stats_ref = db.collection('user_game_stats').document(uid)
        doc = user_stats_ref.get()
        
        now = datetime.utcnow()
        if doc.exists:
            last_spin = doc.to_dict().get('last_spin')
            if last_spin:
                last_spin_dt = last_spin.replace(tzinfo=None)
                if now - last_spin_dt < timedelta(hours=24):
                    return jsonify({"error": "You must wait 24 hours between spins!"}), 429

        rewards = [
            {"label": "50 Dishi Coins", "value": 50, "type": "coins"},
            {"label": "Free Peer Delivery", "value": 1, "type": "delivery"},
            {"label": "Try Again Tomorrow", "value": 0, "type": "none"},
            {"label": "100 Dishi Coins", "value": 100, "type": "coins"},
            {"label": "10% Vendor Discount", "value": 10, "type": "discount"},
            {"label": "Try Again Tomorrow", "value": 0, "type": "none"},
        ]
        
        won_reward = random.choice(rewards)

        user_stats_ref.set({'last_spin': now}, merge=True)

        if won_reward['type'] == 'coins':
            db.collection('users').document(uid).set({'dishi_coins': firestore.Increment(won_reward['value'])}, merge=True)
        elif won_reward['type'] == 'delivery':
            user_stats_ref.set({'free_deliveries': firestore.Increment(1)}, merge=True)
        
        return jsonify({"message": "Spin successful", "reward": won_reward}), 200

    except Exception as e:
        print(f"Daily spin error: {e}")
        return jsonify({"error": "Internal server error"}), 500

@firestore.transactional
def process_redemption(transaction, user_ref, cost, item_id):
    snapshot = user_ref.get(transaction=transaction)
    if not snapshot.exists:
        return False, "User not found"
        
    current_coins = snapshot.to_dict().get('dishi_coins', 0)
    if current_coins < cost:
        return False, "Insufficient Dishi Coins"
        
    transaction.update(user_ref, {
        'dishi_coins': current_coins - cost
    })
    
    # Process reward delivery
    if item_id == 'free_delivery':
        user_stats_ref = db.collection('user_game_stats').document(user_ref.id)
        transaction.set(user_stats_ref, {'free_deliveries': firestore.Increment(1)}, merge=True)
    elif item_id == 'discount_10':
        pass # Client handles the promo code UI, we just deduct
    elif item_id == 'vip_badge':
        transaction.update(user_ref, {'premium_badge': True})
        
    return True, "Success"

@games_bp.route('/redeem', methods=['POST'])
def redeem_store():
    uid = get_user_id(request)
    if not uid:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.json
    item_id = data.get('item_id')
    
    costs = {
        'free_delivery': 500,
        'discount_10': 1000,
        'vip_badge': 2500
    }
    
    if item_id not in costs:
        return jsonify({"error": "Invalid item"}), 400
        
    cost = costs[item_id]
    
    try:
        user_ref = db.collection('users').document(uid)
        transaction = db.transaction()
        success, message = process_redemption(transaction, user_ref, cost, item_id)
        
        if not success:
            return jsonify({"error": message}), 400
            
        return jsonify({"message": "Redemption successful", "item_id": item_id}), 200
    except Exception as e:
        print(f"Redeem error: {e}")
        return jsonify({"error": "Transaction failed"}), 500
