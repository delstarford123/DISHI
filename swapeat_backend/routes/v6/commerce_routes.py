import os
import hmac
import hashlib
import random
import string
from datetime import datetime
from flask import Blueprint, request, jsonify
from firebase_admin import firestore
from routes.mpesa_routes import resolve_user_ref, _credit_wallet_safely

commerce_v6_bp = Blueprint('commerce_v6', __name__)

# =====================================================================
# PILLAR 1 & 4: CAMPUS COMMERCE, SUPERMARKETS & TECH EQUIPMENT (V6)
# =====================================================================

@commerce_v6_bp.route('/categories', methods=['GET'])
def get_categories():
    """
    Returns the supported commerce categories and their metadata.
    """
    return jsonify({
        "categories": [
            {"id": "food", "name": "Food & Cafeterias", "icon": "🍕", "description": "Hot meals, fast food & campus dining"},
            {"id": "supermarket", "name": "Supermarkets & Groceries", "icon": "🛒", "description": "Snacks, fresh produce, toiletries & dorm supplies"},
            {"id": "electronics", "name": "Electronics & Lab", "icon": "💻", "description": "Laptops, phones, lab coats, calculators & chargers"},
            {"id": "stationery", "name": "Stationery & Books", "icon": "📚", "description": "Printing, notebooks, drafting pens & academic material"},
            {"id": "pharmacy", "name": "Health & Pharmacy", "icon": "💊", "description": "First aid, OTC wellness & hygiene essentials"}
        ]
    }), 200


@commerce_v6_bp.route('/vendors', methods=['GET'])
def list_vendors_by_category():
    """
    Lists vendors filtered by category (food, supermarket, electronics, pharmacy)
    with ratings, location, and operating status.
    """
    category = request.args.get('category', '').strip().lower()
    search = request.args.get('q', '').strip().lower()
    
    db = firestore.client()
    vendors_ref = db.collection('vendors')
    
    query = vendors_ref
    if category and category != 'all':
        query = query.where('vendorType', '==', category)

    docs = query.limit(50).stream()
    results = []
    for doc in docs:
        v = doc.to_dict()
        v['id'] = doc.id
        
        # Text search fallback
        name = (v.get('businessName') or v.get('name') or '').lower()
        if search and search not in name:
            continue
            
        results.append({
            "id": doc.id,
            "businessName": v.get('businessName') or v.get('name') or "Campus Store",
            "vendorType": v.get('vendorType', 'food'),
            "category": v.get('vendorType', 'food'),
            "location": v.get('location', 'Main Campus'),
            "rating": v.get('rating', 4.8),
            "isOpen": v.get('isOpen', True),
            "phone": v.get('phone', ''),
            "logoUrl": v.get('logoUrl') or v.get('bannerUrl') or '',
            "acceptsInstallments": v.get('acceptsInstallments', False),
            "hasWarranty": v.get('hasWarranty', False),
        })

    return jsonify({"vendors": results, "count": len(results)}), 200


@commerce_v6_bp.route('/barcode/<sku>', methods=['GET'])
def lookup_barcode(sku):
    """
    Feature 2: Supermarket SKU & Barcode Scanner.
    Returns product info by EAN-13, UPC, or custom SKU.
    """
    sku_clean = str(sku).strip()
    if not sku_clean:
        return jsonify({"error": "SKU or barcode is required"}), 400

    db = firestore.client()
    
    # Check supermarket_skus collection first
    sku_docs = db.collection('supermarket_skus').where('barcode', '==', sku_clean).limit(1).get()
    if not sku_docs:
        sku_docs = db.collection('supermarket_skus').where('sku', '==', sku_clean).limit(1).get()

    if sku_docs:
        item = sku_docs[0].to_dict()
        item['id'] = sku_docs[0].id
        return jsonify({"item": item, "source": "sku_database"}), 200

    # Fallback to general marketplace_items
    market_docs = db.collection('marketplace_items').where('barcode', '==', sku_clean).limit(1).get()
    if market_docs:
        item = market_docs[0].to_dict()
        item['id'] = market_docs[0].id
        return jsonify({"item": item, "source": "marketplace"}), 200

    return jsonify({"error": f"Item with barcode '{sku_clean}' not found.", "barcode": sku_clean}), 404


@commerce_v6_bp.route('/barcode/register', methods=['POST'])
def register_barcode():
    """
    Allows supermarket vendors to register a barcode mapping.
    """
    data = request.json or {}
    barcode = str(data.get('barcode', '')).strip()
    name = str(data.get('name', '')).strip()
    price = float(data.get('price', 0))
    vendor_id = str(data.get('vendor_id', '')).strip()
    stock = int(data.get('stock', 1))

    if not barcode or not name or price <= 0:
        return jsonify({"error": "barcode, name, and valid price required"}), 400

    db = firestore.client()
    doc_ref = db.collection('supermarket_skus').document(barcode)
    doc_ref.set({
        'barcode': barcode,
        'sku': barcode,
        'name': name,
        'price': price,
        'stock': stock,
        'vendor_id': vendor_id,
        'category': data.get('category', 'supermarket'),
        'variants': data.get('variants', []),
        'isAvailable': stock > 0,
        'updated_at': firestore.SERVER_TIMESTAMP
    }, merge=True)

    return jsonify({"success": True, "message": f"Barcode {barcode} registered for '{name}'"}), 200


@commerce_v6_bp.route('/installments/create', methods=['POST'])
def create_equipment_installment():
    """
    Feature 3: Academic Equipment & Tech Installment Locker.
    Laptops, scientific calculators, and lab coats on split layaway with escrow hold.
    """
    data = request.json or {}
    student_uid = (data.get('student_uid') or data.get('studentUid') or '').strip()
    vendor_id = (data.get('vendor_id') or data.get('vendorId') or '').strip()
    item_id = str(data.get('item_id', '')).strip()
    item_name = str(data.get('item_name', 'Tech Equipment')).strip()
    total_price = float(data.get('total_price', 0))
    milestones_count = int(data.get('milestones', 3))

    if not student_uid or not vendor_id or total_price <= 0:
        return jsonify({"error": "student_uid, vendor_id, and total_price are required"}), 400

    milestones_count = max(2, min(6, milestones_count))
    milestone_amount = round(total_price / milestones_count, 2)

    db = firestore.client()
    # Generate unique 6-digit pickup OTP
    pickup_otp = ''.join(random.choices(string.digits, k=6))

    plan_ref = db.collection('equipment_installments').document()
    plan_data = {
        'student_uid': student_uid,
        'vendor_id': vendor_id,
        'item_id': item_id,
        'item_name': item_name,
        'total_price': total_price,
        'milestones_count': milestones_count,
        'milestone_amount': milestone_amount,
        'amount_paid': 0.0,
        'completed_milestones': 0,
        'status': 'active',
        'pickup_otp': pickup_otp,
        'otp_verified': False,
        'created_at': firestore.SERVER_TIMESTAMP,
        'updated_at': firestore.SERVER_TIMESTAMP
    }
    plan_ref.set(plan_data)

    return jsonify({
        "success": True,
        "installment_id": plan_ref.id,
        "item_name": item_name,
        "total_price": total_price,
        "milestone_amount": milestone_amount,
        "milestones_count": milestones_count,
        "message": f"Installment plan created for {item_name}. Pay in {milestones_count} instalments of KES {milestone_amount:,.2f}."
    }), 201


@commerce_v6_bp.route('/installments/<plan_id>/pay_milestone', methods=['POST'])
def pay_equipment_milestone(plan_id):
    """
    Pays the next milestone for an active equipment installment plan.
    Deducts atomically from student wallet and holds in escrow.
    """
    db = firestore.client()
    plan_ref = db.collection('equipment_installments').document(plan_id)
    plan_doc = plan_ref.get()

    if not plan_doc.exists:
        return jsonify({"error": "Installment plan not found"}), 404

    plan = plan_doc.to_dict()
    if plan.get('status') == 'completed':
        return jsonify({"error": "Plan already fully paid and ready for pickup"}), 400

    student_uid = plan.get('student_uid')
    remaining = plan.get('total_price', 0) - plan.get('amount_paid', 0)
    milestone_amt = min(remaining, plan.get('milestone_amount', 0))

    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({"error": "Student account not found"}), 404

    current_balance = float(user_doc.to_dict().get('walletBalance', 0))
    if current_balance < milestone_amt:
        return jsonify({
            "error": f"Insufficient wallet balance. You need KES {milestone_amt:,.2f}, available: KES {current_balance:,.2f}"
        }), 400

    # Deduct atomically
    _credit_wallet_safely(db, user_ref, real_uid, -milestone_amt, destination='walletBalance')

    new_amount_paid = plan.get('amount_paid', 0) + milestone_amt
    new_completed = plan.get('completed_milestones', 0) + 1
    is_fully_paid = new_amount_paid >= plan.get('total_price', 0)

    update_fields = {
        'amount_paid': new_amount_paid,
        'completed_milestones': new_completed,
        'updated_at': firestore.SERVER_TIMESTAMP
    }
    if is_fully_paid:
        update_fields['status'] = 'ready_for_pickup'

    plan_ref.update(update_fields)

    # Log in transactions
    db.collection('transactions').add({
        'type': 'installment_payment',
        'studentId': real_uid,
        'user_id': real_uid,
        'amount': milestone_amt,
        'plan_id': plan_id,
        'item_name': plan.get('item_name'),
        'description': f"Installment payment {new_completed}/{plan.get('milestones_count')} for {plan.get('item_name')}",
        'status': 'completed',
        'timestamp': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "success": True,
        "amount_paid": milestone_amt,
        "total_paid": new_amount_paid,
        "remaining": max(0, plan.get('total_price', 0) - new_amount_paid),
        "is_ready_for_pickup": is_fully_paid,
        "pickup_otp": plan.get('pickup_otp') if is_fully_paid else None,
        "message": "Fully funded! Present your OTP to the vendor for pickup." if is_fully_paid else f"Payment successful. {new_completed}/{plan.get('milestones_count')} milestones completed."
    }), 200


@commerce_v6_bp.route('/installments/<plan_id>/verify_pickup', methods=['POST'])
def verify_installment_pickup(plan_id):
    """
    Vendor verifies student OTP at the counter and receives escrow payout.
    """
    data = request.json or {}
    otp = str(data.get('otp', '')).strip()
    vendor_id = str(data.get('vendor_id', '')).strip()

    db = firestore.client()
    plan_ref = db.collection('equipment_installments').document(plan_id)
    plan_doc = plan_ref.get()

    if not plan_doc.exists:
        return jsonify({"error": "Plan not found"}), 404

    plan = plan_doc.to_dict()
    if plan.get('status') != 'ready_for_pickup':
        return jsonify({"error": "Plan is not fully paid yet"}), 400

    if plan.get('pickup_otp') != otp:
        return jsonify({"error": "Invalid Pickup OTP code"}), 403

    # Mark completed
    plan_ref.update({
        'status': 'collected',
        'otp_verified': True,
        'collected_at': firestore.SERVER_TIMESTAMP
    })

    # Credit vendor escrow
    v_ref, v_doc, real_v_uid = resolve_user_ref(db, plan.get('vendor_id'))
    if v_ref:
        _credit_wallet_safely(db, v_ref, real_v_uid, plan.get('total_price'), destination='walletBalance')

    return jsonify({
        "success": True,
        "message": f"OTP verified! KES {plan.get('total_price'):,.2f} released to vendor wallet. Item handed to student."
    }), 200


@commerce_v6_bp.route('/flash_deals', methods=['GET'])
def get_flash_deals():
    """
    Feature 6: Happy Hour / Okoa Surplus evening markdowns (30-50% off).
    """
    db = firestore.client()
    now_hour = datetime.utcnow().hour + 3  # East Africa Time (UTC+3)
    
    # Query items marked with isFlashDeal or discountHours
    deals = []
    docs = db.collection('marketplace_items').where('isFlashDeal', '==', True).limit(25).stream()
    for d in docs:
        item = d.to_dict()
        item['id'] = d.id
        deals.append(item)

    return jsonify({
        "current_eat_hour": now_hour,
        "is_happy_hour": (now_hour >= 18 or now_hour <= 7),
        "deals": deals,
        "count": len(deals)
    }), 200


@commerce_v6_bp.route('/pool/create', methods=['POST'])
def create_pool_cart():
    """
    Feature 7: Chama Cart & Dorm Group Pooling.
    Roommates split wholesale bulk orders (e.g. 25kg rice, cartons of Indomie).
    """
    data = request.json or {}
    creator_uid = str(data.get('creator_uid', '')).strip()
    title = str(data.get('title', 'Dorm Bulk Cart')).strip()
    target_amount = float(data.get('target_amount', 0))
    members = data.get('members', [])  # list of UIDs or phone numbers

    if not creator_uid or target_amount <= 0:
        return jsonify({"error": "creator_uid and target_amount required"}), 400

    db = firestore.client()
    pool_ref = db.collection('chama_carts').document()
    pool_data = {
        'creator_uid': creator_uid,
        'title': title,
        'target_amount': target_amount,
        'total_contributed': 0.0,
        'contributors': [],
        'items': data.get('items', []),
        'status': 'open',
        'deep_link': f"dishi://cart/pool/{pool_ref.id}",
        'created_at': firestore.SERVER_TIMESTAMP,
        'updated_at': firestore.SERVER_TIMESTAMP
    }
    pool_ref.set(pool_data)

    return jsonify({
        "success": True,
        "pool_id": pool_ref.id,
        "deep_link": pool_data['deep_link'],
        "title": title,
        "target_amount": target_amount,
        "message": f"Chama Cart created! Share link with roommates to pool KES {target_amount:,.2f}."
    }), 201


@commerce_v6_bp.route('/pool/<pool_id>/contribute', methods=['POST'])
def contribute_to_pool(pool_id):
    """
    Contributes a member's share directly from their DISHI wallet to the Chama cart.
    """
    data = request.json or {}
    contributor_uid = str(data.get('user_id') or data.get('contributor_uid', '')).strip()
    amount = float(data.get('amount', 0))

    if not contributor_uid or amount <= 0:
        return jsonify({"error": "user_id and valid amount required"}), 400

    db = firestore.client()
    pool_ref = db.collection('chama_carts').document(pool_id)
    pool_doc = pool_ref.get()

    if not pool_doc.exists:
        return jsonify({"error": "Chama cart not found"}), 404

    pool = pool_doc.to_dict()
    if pool.get('status') == 'funded':
        return jsonify({"error": "This cart is already fully funded!"}), 400

    user_ref, user_doc, real_uid = resolve_user_ref(db, contributor_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({"error": "User account not found"}), 404

    cur_bal = float(user_doc.to_dict().get('walletBalance', 0))
    if cur_bal < amount:
        return jsonify({"error": f"Insufficient wallet balance. Available: KES {cur_bal:,.2f}"}), 400

    # Deduct from member
    _credit_wallet_safely(db, user_ref, real_uid, -amount, destination='walletBalance')

    new_total = pool.get('total_contributed', 0) + amount
    contributors = list(pool.get('contributors', []))
    u_data = user_doc.to_dict()
    member_name = u_data.get('displayName') or u_data.get('name') or 'Roommate'

    contributors.append({
        'user_id': real_uid,
        'name': member_name,
        'amount': amount,
        'timestamp': datetime.utcnow()
    })

    is_funded = new_total >= pool.get('target_amount', 0)
    pool_ref.update({
        'total_contributed': new_total,
        'contributors': contributors,
        'status': 'funded' if is_funded else 'open',
        'updated_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        "success": True,
        "amount_contributed": amount,
        "total_contributed": new_total,
        "target_amount": pool.get('target_amount'),
        "is_funded": is_funded,
        "message": "Cart is 100% funded! Order is ready to dispatch." if is_funded else f"Contributed KES {amount:,.2f}. KES {max(0, pool.get('target_amount') - new_total):,.2f} remaining."
    }), 200


@commerce_v6_bp.route('/warranty/<order_id>/verify', methods=['POST'])
def verify_electronics_warranty(order_id):
    """
    Feature 8: Verified Campus Electronics 14-Day Warranty & Swap Protection.
    Confirms product condition or initiates return/swap.
    """
    data = request.json or {}
    student_uid = str(data.get('student_uid', '')).strip()
    status = str(data.get('status', 'accepted')).strip().lower()  # 'accepted' or 'disputed'
    reason = str(data.get('reason', '')).strip()

    db = firestore.client()
    order_ref = db.collection('orders').document(order_id)
    order_doc = order_ref.get()

    if not order_doc.exists:
        return jsonify({"error": "Order not found"}), 404

    order = order_doc.to_dict()
    if order.get('studentUid') != student_uid and order.get('student_id') != student_uid:
        return jsonify({"error": "Unauthorized"}), 403

    if status == 'accepted':
        order_ref.update({
            'warranty_status': 'verified_accepted',
            'escrow_released': True,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        # Release vendor payout
        vendor_id = order.get('vendorUid') or order.get('vendor_id')
        v_ref, v_doc, v_uid = resolve_user_ref(db, vendor_id)
        if v_ref:
            payout = float(order.get('totalAmount') or order.get('amount') or 0)
            _credit_wallet_safely(db, v_ref, v_uid, payout, destination='walletBalance')
            
        return jsonify({"success": True, "message": "Warranty verified. Escrow funds released to vendor."}), 200

    else:
        # File dispute
        db.collection('disputes').add({
            'order_id': order_id,
            'student_id': student_uid,
            'vendor_id': order.get('vendorUid') or order.get('vendor_id'),
            'type': 'electronics_warranty',
            'reason': reason,
            'status': 'open',
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        order_ref.update({'warranty_status': 'disputed', 'updated_at': firestore.SERVER_TIMESTAMP})
        return jsonify({"success": True, "message": "Dispute filed under DISHI 14-Day Guarantee. Funds paused in escrow."}), 200


@commerce_v6_bp.route('/wholesale/catalog', methods=['GET'])
def get_wholesale_catalog():
    """
    Feature 26: Direct Distributor Wholesale Ordering for campus shops & mini-supermarkets.
    """
    catalog = [
        {"id": "w1", "name": "Premium White Rice (25kg Bag)", "category": "grains", "wholesale_price": 3200, "retail_estimate": 4000, "supplier": "Mwea Millers Hub", "min_order": 1},
        {"id": "w2", "name": "Cooking Oil Pure Gold (20 Litre Jerrycan)", "category": "oil", "wholesale_price": 4650, "retail_estimate": 5500, "supplier": "Coast Edible Oils", "min_order": 1},
        {"id": "w3", "name": "Instant Noodles (Box of 40 Packs)", "category": "snacks", "wholesale_price": 1400, "retail_estimate": 2000, "supplier": "IndoCampus Depot", "min_order": 2},
        {"id": "w4", "name": "Long Life UHT Milk 500ml (Carton of 12)", "category": "dairy", "wholesale_price": 720, "retail_estimate": 960, "supplier": "Brookside Wholesale", "min_order": 2},
        {"id": "w5", "name": "Engineering Drafting Compasses (Pack of 10)", "category": "stationery", "wholesale_price": 2800, "retail_estimate": 4500, "supplier": "Oxford Stationery Supplies", "min_order": 1}
    ]
    return jsonify({"catalog": catalog, "count": len(catalog)}), 200

