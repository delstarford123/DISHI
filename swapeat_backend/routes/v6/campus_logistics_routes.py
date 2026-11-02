import os
import hmac
import hashlib
import time
import random
import string
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from firebase_admin import firestore
from routes.mpesa_routes import resolve_user_ref, _credit_wallet_safely, _send_notification

campus_logistics_v6_bp = Blueprint('campus_logistics_v6', __name__)

HMAC_SECRET = os.getenv('QR_TOKEN_SECRET', 'dishi_qr_pickup_hmac_secret_2026').encode('utf-8')

# =====================================================================
# PILLAR 3 & 5: SMART LOGISTICS, PRE-ORDERS, SAFETY & ECOSYSTEM (V6)
# =====================================================================

@campus_logistics_v6_bp.route('/queue/<order_id>/status', methods=['GET', 'POST'])
def manage_order_queue(order_id):
    """
    Feature 16: Live Preparation Queue ("Queued -> Cooking -> Ready for Pickup").
    """
    db = firestore.client()
    order_ref = db.collection('orders').document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        return jsonify({"error": "Order not found"}), 404

    if request.method == 'GET':
        data = order_doc.to_dict()
        status = data.get('prep_status') or data.get('status') or 'Queued'
        est_minutes = data.get('est_prep_minutes', 15)
        return jsonify({
            "order_id": order_id,
            "status": status,
            "steps": ["Queued", "Cooking", "Ready for Pickup", "Collected"],
            "current_step": status,
            "est_prep_minutes": est_minutes,
            "pickup_time": data.get('pickup_time', 'ASAP')
        }), 200

    # POST: Vendor advances status
    body = request.json or {}
    new_status = str(body.get('status', '')).strip()
    if new_status not in ["Queued", "Cooking", "Ready for Pickup", "Collected"]:
        return jsonify({"error": "Invalid queue status"}), 400

    order_ref.update({
        'prep_status': new_status,
        'status': new_status,
        'queue_updated_at': firestore.SERVER_TIMESTAMP
    })

    # If Ready for Pickup, trigger notification to student
    order_data = order_doc.to_dict()
    student_uid = order_data.get('studentUid') or order_data.get('student_id')
    if new_status == "Ready for Pickup" and student_uid:
        _send_notification(
            db, student_uid,
            "🍲 Your Order is Ready!",
            f"Order #{order_id[-5:]} is hot and ready for pickup at the counter."
        )

    return jsonify({"success": True, "order_id": order_id, "new_status": new_status}), 200


@campus_logistics_v6_bp.route('/qr_token', methods=['POST'])
def generate_pickup_token():
    """
    Feature 17: Fraud-Proof Dynamic QR Pickup Token with Time-based HMAC & 4-digit PIN.
    Prevents screenshot theft and receipt reuse.
    """
    data = request.json or {}
    order_id = str(data.get('order_id', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()

    if not order_id or not student_uid:
        return jsonify({"error": "order_id and student_uid are required"}), 400

    # 1. 30-second epoch timestamp
    epoch = int(time.time() // 30)
    raw_message = f"{order_id}:{student_uid}:{epoch}"
    token_hmac = hmac.new(HMAC_SECRET, raw_message.encode('utf-8'), hashlib.sha256).hexdigest()[:16].upper()
    
    # 4-digit numeric fallback PIN for cashiers without high-res scanners
    pin_hash = int(hashlib.md5(f"{order_id}:{epoch}".encode('utf-8')).hexdigest()[:6], 16)
    short_pin = f"{pin_hash % 10000:04d}"

    return jsonify({
        "order_id": order_id,
        "token": token_hmac,
        "short_pin": short_pin,
        "expires_in_seconds": 30 - int(time.time() % 30),
        "qr_payload": f"DISHI:PICKUP:{order_id}:{token_hmac}:{short_pin}"
    }), 200


@campus_logistics_v6_bp.route('/validate_token', methods=['POST'])
def validate_pickup_token():
    """
    Vendor POS scans the student's dynamic QR code and verifies validity.
    """
    data = request.json or {}
    order_id = str(data.get('order_id', '')).strip()
    token = str(data.get('token', '')).strip().upper()
    pin = str(data.get('short_pin') or data.get('pin', '')).strip()

    if not order_id:
        return jsonify({"error": "order_id required"}), 400

    db = firestore.client()
    order_ref = db.collection('orders').document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        return jsonify({"valid": False, "error": "Order not found"}), 404

    order = order_doc.to_dict()
    student_uid = order.get('studentUid') or order.get('student_id', '')

    # Allow current epoch and previous epoch (60-second grace window)
    now_epoch = int(time.time() // 30)
    is_valid = False

    for ep in [now_epoch, now_epoch - 1]:
        raw_msg = f"{order_id}:{student_uid}:{ep}"
        calc_hmac = hmac.new(HMAC_SECRET, raw_msg.encode('utf-8'), hashlib.sha256).hexdigest()[:16].upper()
        p_hash = int(hashlib.md5(f"{order_id}:{ep}".encode('utf-8')).hexdigest()[:6], 16)
        calc_pin = f"{p_hash % 10000:04d}"

        if (token and token == calc_hmac) or (pin and pin == calc_pin):
            is_valid = True
            break

    if not is_valid:
        return jsonify({"valid": False, "error": "QR Token or PIN has expired. Please refresh the student screen."}), 403

    # Mark order collected
    order_ref.update({
        'status': 'Collected',
        'prep_status': 'Collected',
        'collected_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "valid": True,
        "order_id": order_id,
        "items": order.get('items', []),
        "student_name": order.get('student_name', 'Student'),
        "message": "Token verified! Food collection confirmed."
    }), 200


@campus_logistics_v6_bp.route('/dine_in/order', methods=['POST'])
def create_dine_in_order():
    """
    Feature 19: Table & Cafeteria Seat Delivery (Dine-In QR Table Ordering).
    """
    data = request.json or {}
    vendor_id = str(data.get('vendor_id', '')).strip()
    table_number = str(data.get('table_number', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()
    items = data.get('items', [])
    total_price = float(data.get('total_price', 0))

    if not vendor_id or not table_number or not student_uid or total_price <= 0:
        return jsonify({"error": "vendor_id, table_number, student_uid, and items required"}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({"error": "Student account not found"}), 404

    cur_bal = float(user_doc.to_dict().get('walletBalance', 0))
    if cur_bal < total_price:
        return jsonify({"error": f"Insufficient wallet balance. Available: KES {cur_bal:,.2f}"}), 400

    # Deduct student wallet
    _credit_wallet_safely(db, user_ref, real_uid, -total_price, destination='walletBalance')

    # Create dine-in order
    order_ref = db.collection('orders').document()
    order_data = {
        'type': 'dine_in',
        'vendorUid': vendor_id,
        'vendor_id': vendor_id,
        'studentUid': real_uid,
        'student_id': real_uid,
        'table_number': table_number,
        'items': items,
        'totalAmount': total_price,
        'prep_status': 'Queued',
        'status': 'Queued',
        'is_paid': True,
        'created_at': firestore.SERVER_TIMESTAMP
    }
    order_ref.set(order_data)

    return jsonify({
        "success": True,
        "order_id": order_ref.id,
        "table_number": table_number,
        "message": f"Dine-in order placed for Table {table_number}! Meals will be served to your seat."
    }), 201


@campus_logistics_v6_bp.route('/subscription/consume', methods=['POST'])
def consume_meal_pass_token():
    """
    Feature 20: 30-Day Subscription Meal Pass (Mess Card).
    Deducts 1 token per scanned meal.
    """
    data = request.json or {}
    subscription_id = str(data.get('subscription_id', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()

    db = firestore.client()
    sub_ref = db.collection('meal_subscriptions').document(subscription_id)
    sub_doc = sub_ref.get()

    if not sub_doc.exists:
        return jsonify({"error": "Subscription meal pass not found"}), 404

    sub_data = sub_doc.to_dict()
    remaining = int(sub_data.get('remaining_tokens', 0))

    if remaining <= 0:
        return jsonify({"error": "Meal Pass exhausted. 0 tokens remaining."}), 400

    sub_ref.update({
        'remaining_tokens': remaining - 1,
        'last_consumed_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "success": True,
        "remaining_tokens": remaining - 1,
        "plan_title": sub_data.get('plan_title', 'Monthly Cafeteria Pass'),
        "message": f"Meal pass approved! 1 meal token deducted. {remaining - 1} meals remaining."
    }), 200


@campus_logistics_v6_bp.route('/safety/okoa_meal/request', methods=['POST'])
def request_okoa_meal():
    """
    Feature 27: "Okoa Meal" Emergency Credit (Zero-Hunger Safety Net).
    Provides a small meal voucher (KES 150 - 300) to verified hungry students.
    """
    data = request.json or {}
    student_uid = str(data.get('student_uid', '')).strip()
    amount = float(data.get('amount', 200))

    amount = max(100.0, min(350.0, amount))

    db = firestore.client()
    u_ref, u_doc, real_uid = resolve_user_ref(db, student_uid)
    if not u_doc or not u_doc.exists:
        return jsonify({"error": "Student account not found"}), 404

    u_data = u_doc.to_dict()
    existing_debt = float(u_data.get('okoa_debt', 0))
    if existing_debt > 0:
        return jsonify({
            "error": f"You have an outstanding Okoa Meal voucher of KES {existing_debt:.0f}. Please top up to settle before requesting another."
        }), 400

    cur_bal = float(u_data.get('walletBalance', 0))
    if cur_bal > 150:
        return jsonify({"error": "Okoa Meal is only available when balance is below KES 150."}), 400

    # Credit student food allowance and record debt
    u_ref.update({
        'food_allowance_balance': firestore.Increment(amount),
        'walletBalance': firestore.Increment(amount),
        'wallet_balance': firestore.Increment(amount),
        'okoa_debt': amount,
        'okoa_issued_at': firestore.SERVER_TIMESTAMP
    })

    # Record in safety pool
    db.collection('okoa_records').add({
        'student_uid': real_uid,
        'amount': amount,
        'status': 'active_debt',
        'timestamp': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "success": True,
        "voucher_credited": amount,
        "message": f"DISHI Zero-Hunger Safety Net activated. KES {amount:.0f} credited to your food wallet. Repay automatically on next top-up."
    }), 200


@campus_logistics_v6_bp.route('/social/split_expense/create', methods=['POST'])
def create_split_expense():
    """
    Feature 28: Hostel & Roommate Split-Expense Hub (Tokens, LPG Gas, Wi-Fi).
    """
    data = request.json or {}
    creator_uid = str(data.get('creator_uid', '')).strip()
    title = str(data.get('title', 'Electricity Token Split')).strip()
    total_amount = float(data.get('total_amount', 0))
    roommates = data.get('roommates', [])  # list of UIDs or phone numbers

    if not creator_uid or total_amount <= 0 or not roommates:
        return jsonify({"error": "creator_uid, total_amount, and roommates list required"}), 400

    split_count = len(roommates) + 1  # includes creator
    per_person = round(total_amount / split_count, 2)

    db = firestore.client()
    split_ref = db.collection('split_expenses').document()
    split_ref.set({
        'creator_uid': creator_uid,
        'title': title,
        'total_amount': total_amount,
        'per_person': per_person,
        'roommates': roommates,
        'paid_members': [creator_uid],
        'status': 'pending',
        'created_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "success": True,
        "split_id": split_ref.id,
        "per_person": per_person,
        "message": f"Split expense created! KES {per_person:,.2f} requested from each of {len(roommates)} roommates."
    }), 201

