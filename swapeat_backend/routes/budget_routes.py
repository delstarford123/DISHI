from flask import Blueprint, jsonify, request

budget_bp = Blueprint('budget', __name__)

@budget_bp.route('/<student_id>/drip_feed', methods=['POST'])
def trigger_drip_feed(student_id):
    # Automated Semester Budget Phasing
    # Move funds from "Vault" to "Active Wallet"
    mock_data = {
        "status": "success",
        "student_id": student_id,
        "vault_balance": 18000.0,
        "active_wallet_balance": 2500.0,
        "drip_amount": 1500.0,
        "new_vault_balance": 16500.0,
        "new_active_wallet_balance": 4000.0
    }
    return jsonify(mock_data), 200

@budget_bp.route('/<student_id>/emergency_release', methods=['POST'])
def emergency_release(student_id):
    # Parent overriding the Drip-Feed Vault
    return jsonify({
        "status": "success",
        "message": "Emergency funds released instantly.",
        "amount": 500.0
    }), 200

@budget_bp.route('/<student_id>/low_balance_trigger', methods=['POST'])
def low_balance_trigger(student_id):
    # Triggers M-PESA STK Push to parent if wallet drops below threshold
    # In reality, this is called by the transaction engine if balance < 200
    return jsonify({
        "status": "success",
        "message": "STK Push sent to Parent (0712345678) for Ksh 500."
    }), 200

@budget_bp.route('/<student_id>/eod_rollover', methods=['POST'])
def eod_rollover(student_id):
    # Cron logic: Sweeps unspent daily funds into the Weekend Stash
    data = request.json
    unspent_amount = data.get('unspent_amount', 0)
    return jsonify({
        "status": "success",
        "message": f"Ksh {unspent_amount} rolled over into Weekend Stash.",
        "new_weekend_stash_balance": 450.0 + unspent_amount
    }), 200

@budget_bp.route('/student/<uid>/category_limits', methods=['POST'])
def set_category_limits(uid):
    try:
        from firebase_admin import firestore
        data = request.json
        limits = data.get('limits') # e.g., {"snacks": 200, "meals": 1000}
        
        if not limits:
            return jsonify({"error": "Missing limits"}), 400
            
        db = firestore.client()
        db.collection('users').document(uid).update({
            'categoryLimits': limits
        })
        return jsonify({"status": "success", "message": "Category limits updated."}), 200
    except Exception as e:
        import traceback
        return jsonify({"error": "Server error", "details": str(e)}), 500

@budget_bp.route('/student/<uid>/emergency_fund', methods=['POST'])
def add_emergency_fund(uid):
    try:
        from firebase_admin import firestore
        data = request.json
        amount = float(data.get('amount', 0))
        parent_uid = data.get('parentUid')
        
        if amount <= 0 or not parent_uid:
            return jsonify({"error": "Invalid amount or missing parentUid"}), 400
            
        db = firestore.client()
        # Atomic transfer from parent vault to child's emergencyVaultBalance
        batch = db.batch()
        parent_ref = db.collection('users').document(parent_uid)
        student_ref = db.collection('users').document(uid)
        
        batch.update(parent_ref, {'vaultBalance': firestore.Increment(-amount)})
        batch.update(student_ref, {'emergencyVaultBalance': firestore.Increment(amount)})
        batch.commit()
        
        return jsonify({"status": "success", "message": f"Ksh {amount} locked in emergency fund."}), 200
    except Exception as e:
        return jsonify({"error": "Server error", "details": str(e)}), 500

@budget_bp.route('/student/<uid>/generate_emergency_pin', methods=['POST'])
def generate_emergency_pin(uid):
    try:
        from firebase_admin import firestore
        import random
        import datetime
        
        pin = str(random.randint(1000, 9999))
        # Expiry in 15 minutes
        expires_at = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=15)
        
        db = firestore.client()
        db.collection('users').document(uid).update({
            'emergencyPin': {
                'pin': pin,
                'expiresAt': expires_at
            }
        })
        
        # Here we could integrate Africa's Talking to send an SMS to the child
        # For now, we return it to the parent who can share it, or trigger an FCM
        return jsonify({"status": "success", "message": "PIN generated successfully", "pin": pin}), 200
    except Exception as e:
        return jsonify({"error": "Server error", "details": str(e)}), 500

@budget_bp.route('/student/<uid>/unlock_emergency_fund', methods=['POST'])
def unlock_emergency_fund(uid):
    try:
        from firebase_admin import firestore
        import datetime
        data = request.json
        provided_pin = str(data.get('pin', ''))
        
        db = firestore.client()
        student_ref = db.collection('users').document(uid)
        doc = student_ref.get()
        if not doc.exists:
            return jsonify({"error": "Student not found"}), 404
            
        s_data = doc.to_dict()
        emergency_data = s_data.get('emergencyPin')
        
        if not emergency_data:
            return jsonify({"error": "No emergency PIN set"}), 400
            
        stored_pin = str(emergency_data.get('pin', ''))
        expires_at = emergency_data.get('expiresAt')
        
        if provided_pin != stored_pin:
            return jsonify({"error": "Invalid PIN"}), 403
            
        if isinstance(expires_at, datetime.datetime) and datetime.datetime.now(datetime.timezone.utc) > expires_at.astimezone(datetime.timezone.utc):
            return jsonify({"error": "PIN expired"}), 403
            
        emergency_balance = float(s_data.get('emergencyVaultBalance', 0.0))
        if emergency_balance <= 0:
            return jsonify({"error": "Emergency fund is empty"}), 400
            
        # Unlock funds: move emergencyVaultBalance to walletBalance
        batch = db.batch()
        batch.update(student_ref, {
            'walletBalance': firestore.Increment(emergency_balance),
            'emergencyVaultBalance': 0.0,
            'emergencyPin': firestore.DELETE_FIELD
        })
        batch.commit()
        
        return jsonify({"status": "success", "message": f"Ksh {emergency_balance} released to wallet."}), 200
    except Exception as e:
        import traceback
        return jsonify({"error": "Server error", "details": str(e), "trace": traceback.format_exc()}), 500
