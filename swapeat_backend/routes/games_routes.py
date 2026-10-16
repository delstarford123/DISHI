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

        # Determine scaling factor based on the game
        scale_factors = {
            'scratch_win': 100,
        }
        factor = scale_factors.get(game_id, 10) # default 1 coin per 10 points
        
        coins_earned = score // factor
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



@games_bp.route('/entry', methods=['POST'])
def pay_game_entry():
    """
    Deducts KES 5.0 entry fee from real walletBalance before playing a game round.
    Body: { "game_id": "delivery_dash" }
    """
    uid = get_user_id(request)
    if not uid:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.json or {}
    game_id = data.get('game_id')
    if not game_id:
        return jsonify({"error": "Missing game_id"}), 400

    ENTRY_FEE = 5.0
    user_ref = db.collection('users').document(uid)

    @firestore.transactional
    def _deduct_entry(transaction, u_ref):
        snap = u_ref.get(transaction=transaction)
        if not snap.exists:
            return False, "User not found", 0.0
        u_data = snap.to_dict()
        current_bal = float(u_data.get('walletBalance', 0.0))
        if current_bal < ENTRY_FEE:
            return False, f"Insufficient wallet balance. KES {ENTRY_FEE:.2f} is required to play.", current_bal

        new_bal = current_bal - ENTRY_FEE
        transaction.update(u_ref, {'walletBalance': new_bal})

        # Record arcade entry fee transaction
        tx_ref = db.collection('transactions').document()
        transaction.set(tx_ref, {
            'userId': uid,
            'studentId': uid,
            'type': 'arcade_entry_fee',
            'amount': ENTRY_FEE,
            'gameId': game_id,
            'description': f"Arcade Entry: {game_id.replace('_', ' ').title()}",
            'timestamp': firestore.SERVER_TIMESTAMP,
            'status': 'completed'
        })
        return True, "Entry fee paid successfully", new_bal

    try:
        tx = db.transaction()
        success, msg, remaining = _deduct_entry(tx, user_ref)
        if not success:
            return jsonify({"error": msg, "wallet_balance": remaining}), 400
        return jsonify({
            "message": msg,
            "entry_fee": ENTRY_FEE,
            "remaining_balance": remaining
        }), 200
    except Exception as e:
        print(f"Entry fee error: {e}")
        return jsonify({"error": "Failed to process entry fee"}), 500


@games_bp.route('/unlock', methods=['POST'])
def unlock_game():
    """
    Unlocks a game in the games list using earned Dishi Arcade Coins.
    Coins can ONLY be used for unlocking games and in-app arcade perks.
    Body: { "game_id": "bite_ninja" }
    """
    uid = get_user_id(request)
    if not uid:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.json or {}
    game_id = data.get('game_id')

    GAME_PRICES = {
        'delivery_dash': 0,      # Starter game (Free to unlock)
        'daily_spin': 0,         # Starter game (Free to unlock)
        'dishi_drop': 300,
        'hungry_fresher': 400,
        'bite_ninja': 500,
        'taste_match': 600,
        'vibe_check': 700,
        'campus_quizzer': 800,
        'memory_match': 1000,
        'scratch_win': 1200,
        'dorm_tycoon': 1500,
        'scavenger_hunt': 2000,
    }

    if game_id not in GAME_PRICES:
        return jsonify({"error": f"Invalid game ID: {game_id}"}), 400

    cost = GAME_PRICES[game_id]
    user_ref = db.collection('users').document(uid)

    @firestore.transactional
    def _unlock_tx(transaction, u_ref):
        snap = u_ref.get(transaction=transaction)
        if not snap.exists:
            return False, "User not found", 0
        u_data = snap.to_dict()
        unlocked = list(u_data.get('unlocked_games', ['delivery_dash', 'daily_spin']))
        if game_id in unlocked:
            return True, "Game is already unlocked", u_data.get('dishi_coins', 0)

        coins = int(u_data.get('dishi_coins', 0))
        if coins < cost:
            return False, f"Not enough Arcade Coins. Needs {cost} coins, but you have {coins}.", coins

        unlocked.append(game_id)
        remaining_coins = coins - cost
        transaction.update(u_ref, {
            'dishi_coins': remaining_coins,
            'unlocked_games': unlocked
        })
        return True, f"Unlocked {game_id.replace('_', ' ').title()} successfully!", remaining_coins

    try:
        tx = db.transaction()
        success, msg, remaining_coins = _unlock_tx(tx, user_ref)
        if not success:
            return jsonify({"error": msg}), 400
        return jsonify({
            "message": msg,
            "game_id": game_id,
            "remaining_coins": remaining_coins
        }), 200
    except Exception as e:
        print(f"Unlock game error: {e}")
        return jsonify({"error": "Failed to unlock game"}), 500


@games_bp.route('/redeem', methods=['POST'])
def redeem_store():
    """
    Arcade Store: Coins can ONLY be used for in-app game unlocks and arcade badges.
    Real cash (KES) conversions have been completely removed.
    """
    uid = get_user_id(request)
    if not uid:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.json or {}
    item_id = data.get('item_id')

    # Exclusively in-game perks — NO REAL MONEY CONVERSION
    costs = {
        'game_pass_bronze': 400,
        'game_pass_silver': 800,
        'game_pass_gold': 1500,
        'vip_badge': 2500
    }

    if item_id not in costs:
        return jsonify({"error": "Invalid item. Coins are only usable for in-app games and arcade badges."}), 400

    cost = costs[item_id]

    try:
        user_ref = db.collection('users').document(uid)

        @firestore.transactional
        def _run_redeem(transaction, u_ref, deduct):
            snapshot = u_ref.get(transaction=transaction)
            if not snapshot.exists:
                return False, "User not found"
            current_coins = snapshot.to_dict().get('dishi_coins', 0)
            if current_coins < deduct:
                return False, "Insufficient Arcade Coins balance"
            transaction.update(u_ref, {'dishi_coins': current_coins - deduct})

            if item_id == 'vip_badge':
                transaction.update(u_ref, {'premium_badge': True, 'isVipBadge': True})
            return True, "Success"

        transaction = db.transaction()
        success, message = _run_redeem(transaction, user_ref, cost)

        if not success:
            return jsonify({"error": message}), 400

        return jsonify({"message": "Redemption successful", "item_id": item_id}), 200
    except Exception as e:
        print(f"Redeem error: {e}")
        return jsonify({"error": "Transaction failed"}), 500


