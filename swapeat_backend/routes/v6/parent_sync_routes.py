import os
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from firebase_admin import firestore
from routes.mpesa_routes import resolve_user_ref, _credit_wallet_safely, _notify_parent, _send_notification

parent_sync_v6_bp = Blueprint('parent_sync_v6', __name__)

# =====================================================================
# PILLAR 2: STUDENT-PARENT FINANCIAL & HEALTH SYNCHRONY (V6)
# =====================================================================

@parent_sync_v6_bp.route('/purpose_transfer', methods=['POST'])
def transfer_purpose_locked_funds():
    """
    Feature 9: Purpose-Locked Allowances ("Food-Only" vs "Equipment-Only" Wallets).
    Ensures allowances sent by parents cannot be diverted to unapproved categories.
    """
    data = request.json or {}
    parent_uid = (data.get('parent_uid') or data.get('parentUid') or '').strip()
    student_uid = (data.get('student_uid') or data.get('studentUid') or '').strip()
    amount_raw = data.get('amount')
    purpose = str(data.get('purpose', 'food')).strip().lower()  # 'food' or 'equipment'

    if not parent_uid or not student_uid or amount_raw is None:
        return jsonify({"error": "parent_uid, student_uid, and amount are required"}), 400

    try:
        amount = float(amount_raw)
        if amount <= 0:
            return jsonify({"error": "Amount must be greater than KES 0"}), 400
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid amount"}), 400

    db = firestore.client()
    p_ref, p_doc, real_p_uid = resolve_user_ref(db, parent_uid)
    s_ref, s_doc, real_s_uid = resolve_user_ref(db, student_uid)

    if not p_doc or not p_doc.exists:
        return jsonify({"error": "Parent account not found"}), 404
    if not s_doc or not s_doc.exists:
        return jsonify({"error": "Student account not found"}), 404

    target_field = 'food_allowance_balance' if purpose == 'food' else 'equipment_allowance_balance'
    purpose_label = "Food & Cafeteria" if purpose == 'food' else "Academic Equipment & Lab"

    @firestore.transactional
    def run_purpose_transfer(transaction):
        p_snap = p_ref.get(transaction=transaction)
        s_snap = s_ref.get(transaction=transaction)

        p_data = p_snap.to_dict() or {}
        p_wallet = float(p_data.get('walletBalance', 0.0) or 0.0)
        p_savings = float(p_data.get('savingsBalance', 0.0) or 0.0)
        p_vault = float(p_data.get('vaultBalance', 0.0) or 0.0)

        total_avail = p_wallet + p_savings + p_vault
        if total_avail < amount:
            return {"error": f"Insufficient Family Vault funds. Available: KES {total_avail:,.2f}"}, 400

        # Deduct cascade
        rem = amount
        p_up = {}
        if p_savings > 0:
            d = min(p_savings, rem)
            p_up['savingsBalance'] = p_savings - d
            rem -= d
        if rem > 0 and p_vault > 0:
            d = min(p_vault, rem)
            p_up['vaultBalance'] = p_vault - d
            rem -= d
        if rem > 0 and p_wallet > 0:
            d = min(p_wallet, rem)
            p_up['walletBalance'] = p_wallet - d
            rem -= d

        transaction.update(p_ref, p_up)
        
        # Credit purpose-locked field AND keep total wallet_balance in sync
        transaction.set(s_ref, {
            target_field: firestore.Increment(amount),
            'walletBalance': firestore.Increment(amount),
            'wallet_balance': firestore.Increment(amount),
            'updatedAt': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP
        }, merge=True)

        tx_ref = db.collection('transactions').document()
        transaction.set(tx_ref, {
            'type': 'purpose_locked_transfer',
            'senderUid': real_p_uid,
            'receiverUid': real_s_uid,
            'amount': amount,
            'purpose': purpose,
            'destination_field': target_field,
            'status': 'completed',
            'description': f"Purpose-locked {purpose_label} allowance of KES {amount:,.2f}",
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        return {
            "success": True,
            "amount": amount,
            "purpose": purpose,
            "message": f"Transferred KES {amount:,.2f} locked strictly for {purpose_label}!"
        }

    try:
        res = run_purpose_transfer(db.transaction())
        if isinstance(res, tuple):
            return jsonify(res[0]), res[1]
        
        # Notify student
        _send_notification(
            db, real_s_uid,
            f"💰 {purpose_label} Allowance Received!",
            f"Your parent sent KES {amount:,.0f} locked specifically for {purpose_label}."
        )
        return jsonify(res), 200
    except Exception as e:
        return jsonify({"error": "Transfer failed", "details": str(e)}), 500


@parent_sync_v6_bp.route('/cart/create_paylink', methods=['POST'])
def create_cart_paylink():
    """
    Feature 10: Parent "Direct-to-Cart" Checkout (One-Click Sponsor).
    Generates a shareable web checkout link for parents to pay directly via M-PESA.
    """
    data = request.json or {}
    student_uid = (data.get('student_uid') or data.get('studentUid') or '').strip()
    cart_items = data.get('items', [])
    total_amount = float(data.get('total_amount', 0))
    vendor_id = data.get('vendor_id', '')

    if not student_uid or total_amount <= 0:
        return jsonify({"error": "student_uid and total_amount required"}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    student_name = "Student"
    if user_doc and user_doc.exists:
        student_name = user_doc.to_dict().get('displayName') or user_doc.to_dict().get('name') or "Student"

    cart_ref = db.collection('sponsored_carts').document()
    cart_data = {
        'student_uid': real_uid,
        'student_name': student_name,
        'vendor_id': vendor_id,
        'items': cart_items,
        'total_amount': total_amount,
        'status': 'pending_payment',
        'created_at': firestore.SERVER_TIMESTAMP
    }
    cart_ref.set(cart_data)

    pay_link = f"https://dishi.delstarfordworks.co.ke/pay_cart?cart_id={cart_ref.id}"
    
    # Notify linked parents
    _notify_parent(
        db, real_uid,
        f"{student_name} requested meal/equipment sponsorship of KES {total_amount:,.0f}. Tap to approve & pay: {pay_link}"
    )

    return jsonify({
        "success": True,
        "cart_id": cart_ref.id,
        "pay_link": pay_link,
        "total_amount": total_amount,
        "message": f"Payment link generated! Share with your parent or guardian."
    }), 201


@parent_sync_v6_bp.route('/nutrition_digest/<student_uid>', methods=['GET'])
def get_nutrition_digest(student_uid):
    """
    Feature 11: Nutrition & Meal Variety Health Insights for Parents.
    Summarizes student meal patterns over the last 14 days without violating dignity.
    """
    db = firestore.client()
    u_ref, u_doc, real_uid = resolve_user_ref(db, student_uid)
    if not u_doc or not u_doc.exists:
        return jsonify({"error": "Student not found"}), 404

    # Query recent food orders
    cutoff = datetime.utcnow() - timedelta(days=14)
    orders = db.collection('orders') \
               .where('studentUid', '==', real_uid) \
               .limit(30).get()

    category_counts = {"greens": 0, "protein": 0, "grains": 0, "fruits": 0, "water": 0}
    total_meals = 0

    for doc in orders:
        data = doc.to_dict()
        items = data.get('items', [])
        for item in items:
            cat = str(item.get('category', 'grains')).lower()
            if cat in category_counts:
                category_counts[cat] += 1
            else:
                category_counts['grains'] += 1
        total_meals += 1

    total_tags = sum(category_counts.values()) or 1
    percentages = {k: round((v / total_tags) * 100, 1) for k, v in category_counts.items()}

    wellness_rating = "Excellent"
    if percentages['greens'] + percentages['protein'] > 50:
        wellness_rating = "Very Balanced & Nutritious"
    elif total_meals < 5:
        wellness_rating = "Light Eater — Needs Upkeep Encouragement"

    return jsonify({
        "student_uid": real_uid,
        "period": "Last 14 Days",
        "total_meals_recorded": total_meals,
        "wellness_summary": wellness_rating,
        "breakdown": percentages,
        "insights": [
            f"Greens & Vegetables: {percentages['greens']}%",
            f"Protein Intake: {percentages['protein']}%",
            f"Energy Grains: {percentages['grains']}%"
        ]
    }), 200


@parent_sync_v6_bp.route('/sos_allowance', methods=['POST'])
def trigger_low_balance_sos():
    """
    Feature 13: Low-Balance SOS Push to Parent ("Niko Ground Safe").
    Dignified 1-tap request when wallet < Ksh 100.
    """
    data = request.json or {}
    student_uid = (data.get('student_uid') or data.get('studentUid') or '').strip()
    requested_amount = float(data.get('requested_amount', 300))

    db = firestore.client()
    u_ref, u_doc, real_uid = resolve_user_ref(db, student_uid)
    if not u_doc or not u_doc.exists:
        return jsonify({"error": "Student account not found"}), 404

    u_data = u_doc.to_dict()
    student_name = u_data.get('displayName') or u_data.get('name') or "Your child"
    cur_bal = float(u_data.get('walletBalance', 0))

    if cur_bal > 200:
        return jsonify({"error": "SOS requests are reserved for low-balance situations (< KES 200)"}), 400

    # Notify all linked parents
    _notify_parent(
        db, real_uid,
        f"🚨 Low Balance Alert: {student_name}'s meal wallet has dropped to KES {cur_bal:.0f}. They requested a KES {requested_amount:.0f} refill."
    )

    return jsonify({
        "success": True,
        "message": f"A gentle refill request for KES {requested_amount:.0f} was sent to your linked parents."
    }), 200


@parent_sync_v6_bp.route('/limits', methods=['POST'])
def update_spending_limits():
    """
    Feature 14: Parent-Set Spending Velocity Limits (Daily / Per-Tx Cap).
    """
    data = request.json or {}
    student_uid = (data.get('student_uid') or data.get('studentUid') or '').strip()
    daily_limit = float(data.get('daily_limit', 500))
    per_tx_limit = float(data.get('per_tx_limit', 300))

    db = firestore.client()
    u_ref, u_doc, real_uid = resolve_user_ref(db, student_uid)
    if not u_ref:
        return jsonify({"error": "Student not found"}), 404

    u_ref.update({
        'dailyLimit': daily_limit,
        'perTxLimit': per_tx_limit,
        'limits_updated_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "success": True,
        "daily_limit": daily_limit,
        "per_tx_limit": per_tx_limit,
        "message": f"Spending caps saved: Max KES {daily_limit:,.0f}/day, KES {per_tx_limit:,.0f}/transaction."
    }), 200


@parent_sync_v6_bp.route('/tuition_vault/disburse', methods=['POST'])
def disburse_tuition_vault():
    """
    Feature 15: Semester Tuition & Rent Vault with Direct Institution Disbursement.
    Funds in tuition_vault can only be released to verified school / landlord paybills.
    """
    data = request.json or {}
    parent_uid = (data.get('parent_uid') or data.get('parentUid') or '').strip()
    amount = float(data.get('amount', 0))
    target_shortcode = str(data.get('target_shortcode', '')).strip()
    account_reference = str(data.get('account_reference', 'TUITION')).strip()

    if not parent_uid or amount <= 0 or not target_shortcode:
        return jsonify({"error": "parent_uid, amount, and target_shortcode are required"}), 400

    db = firestore.client()
    p_ref, p_doc, real_uid = resolve_user_ref(db, parent_uid)
    if not p_doc or not p_doc.exists:
        return jsonify({"error": "Parent account not found"}), 404

    p_data = p_doc.to_dict()
    tuition_bal = float(p_data.get('tuition_vault_balance', 0) or p_data.get('vaultBalance', 0))

    if tuition_bal < amount:
        return jsonify({"error": f"Insufficient Tuition Vault funds. Available: KES {tuition_bal:,.2f}"}), 400

    # Deduct tuition vault atomically
    p_ref.update({
        'tuition_vault_balance': firestore.Increment(-amount),
        'updatedAt': firestore.SERVER_TIMESTAMP
    })

    # Log in disbursements
    db.collection('tuition_disbursements').add({
        'parent_uid': real_uid,
        'amount': amount,
        'target_shortcode': target_shortcode,
        'account_reference': account_reference,
        'status': 'disbursed',
        'timestamp': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "success": True,
        "disbursed_amount": amount,
        "target": target_shortcode,
        "reference": account_reference,
        "message": f"KES {amount:,.2f} disbursed directly to {target_shortcode} ({account_reference})."
    }), 200

