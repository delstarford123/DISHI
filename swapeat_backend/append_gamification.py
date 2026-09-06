import os

filepath = r"c:\Users\Delstaford\swapeat\swapeat_backend\routes\v2\match_routes.py"
with open(filepath, "a", encoding="utf-8") as f:
    f.write('''

# ── PHASE 10: GAMIFICATION & STREAKS ──────────────────────────

@match_v2_bp.route('/gamification/log_activity', methods=['POST'])
def log_activity():
    """
    Logs user activity (login, match, swipe) and updates their Comrade Score & Streaks.
    Awards free delivery vouchers for 7-day streaks.
    """
    data = request.json or {}
    user_id = data.get('user_id')
    activity_type = data.get('activity_type', 'login') # login, swipe, match, message
    
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400
        
    try:
        db = firestore.client()
        user_ref = db.collection('match_profiles').document(user_id)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            return jsonify({"error": "User profile not found"}), 404
            
        profile_data = user_doc.to_dict()
        
        # Calculate score points
        points_map = {'login': 10, 'swipe': 2, 'match': 50, 'message': 5}
        points_earned = points_map.get(activity_type, 0)
        
        current_score = profile_data.get('comrade_score', 0)
        current_streak = profile_data.get('comrade_streak_days', 0)
        last_active = profile_data.get('last_active_date')
        
        now = datetime.utcnow()
        today_str = now.strftime('%Y-%m-%d')
        yesterday_str = (now - __import__('datetime').timedelta(days=1)).strftime('%Y-%m-%d')
        
        reward_issued = False
        reward_msg = ""
        
        if last_active == today_str:
            # Already logged in today, just add points
            new_score = current_score + points_earned
            new_streak = current_streak
        elif last_active == yesterday_str:
            # Maintained streak!
            new_streak = current_streak + 1
            new_score = current_score + points_earned + 20 # Streak bonus
            
            # 7-Day Vendor Bribe!
            if new_streak % 7 == 0:
                reward_issued = True
                reward_msg = "🔥 7-Day Comrade Streak! You earned a Free Delivery Voucher!"
                # Mint a voucher in their wallet
                db.collection('users').document(user_id).collection('vouchers').add({
                    'type': 'free_delivery',
                    'title': 'Comrade 7-Day Streak Reward',
                    'discount_ksh': 50,
                    'is_used': False,
                    'created_at': firestore.SERVER_TIMESTAMP,
                    'expires_at': now + __import__('datetime').timedelta(days=7)
                })
        else:
            # Streak broken
            new_streak = 1
            new_score = current_score + points_earned
            
        update_data = {
            'comrade_score': new_score,
            'comrade_streak_days': new_streak,
            'last_active_date': today_str,
            'updated_at': firestore.SERVER_TIMESTAMP
        }
        
        user_ref.update(update_data)
        
        return jsonify({
            "status": "success",
            "comrade_score": new_score,
            "streak_days": new_streak,
            "points_earned": points_earned,
            "reward_issued": reward_issued,
            "reward_msg": reward_msg
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
''')
