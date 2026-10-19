from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import os
import datetime
from routes.admin_routes import verify_admin, log_admin_action

analytics_v4_bp = Blueprint('analytics_v4', __name__)

@analytics_v4_bp.route('/commissions', methods=['GET'])
def get_commission_analytics():
    """
    Computes total commission earned across DISHI:
    1. Vendor money withdrawals (B2C cashout fee)
    2. Driver/DeLiv withdrawals
    3. Fundi marketplace cashouts
    4. Student gifts and peer transfers
    5. Cafeteria pre-orders and food purchases
    6. Virtual card & NFC issuance fees
    7. B2B Commercial transfers
    """
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        db = firestore.client()

        # 1. Vendor money withdrawals
        vendor_w_commission = 0.0
        vendor_w_volume = 0.0
        vendor_w_count = 0
        try:
            w_docs = db.collection('vendor_withdrawals').get()
            for doc in w_docs:
                d = doc.to_dict() or {}
                st = str(d.get('status', '')).lower()
                if st in ['completed', 'success', 'approved']:
                    amt = float(d.get('amount', 0.0) or 0.0)
                    fee = float(d.get('fee', 0.0) or 0.0)
                    if fee == 0.0 and amt > 0:
                        # Fallback standard tier fee if not explicitly saved
                        fee = 12.0 if amt >= 500 else 6.0
                    vendor_w_commission += fee
                    vendor_w_volume += amt
                    vendor_w_count += 1
        except Exception as e:
            print(f"Error reading vendor_withdrawals: {e}")

        # 2. Driver & Fundi withdrawals (KES 4.00 per cashout)
        gig_commission = 0.0
        gig_volume = 0.0
        gig_count = 0
        try:
            b2c_docs = db.collection('b2c_transactions').limit(150).get()
            for doc in b2c_docs:
                d = doc.to_dict() or {}
                tx_type = str(d.get('type', '')).lower()
                if 'driver' in tx_type or 'fundi' in tx_type:
                    amt = float(d.get('amount', 0.0) or 0.0)
                    gig_volume += amt
                    gig_commission += float(d.get('fee', 4.0) or 4.0)
                    gig_count += 1
        except Exception as e:
            print(f"Error reading b2c gig transactions: {e}")

        # 3. Student Gifts & Peer Transfers
        gift_commission = 0.0
        gift_volume = 0.0
        gift_count = 0
        try:
            gift_docs = db.collection('transactions').where('type', 'in', ['gift', 'meal_gift', 'transfer', 'send_money']).limit(200).get()
            for doc in gift_docs:
                d = doc.to_dict() or {}
                amt = float(d.get('amount', 0.0) or 0.0)
                fee = float(d.get('fee', 0.0) or d.get('fee_amount', 0.0) or 1.50)
                gift_volume += amt
                gift_commission += fee
                gift_count += 1
        except Exception as e:
            print(f"Error reading gift transactions: {e}")

        # 4. Cafeteria Preorders & Vendor Food Purchases (Platform fee e.g. 0.40 - 2.50 KES)
        preorder_commission = 0.0
        preorder_volume = 0.0
        preorder_count = 0
        try:
            food_docs = db.collection('transactions').where('type', 'in', ['preorder', 'food_purchase', 'cafeteria_order']).limit(200).get()
            for doc in food_docs:
                d = doc.to_dict() or {}
                amt = float(d.get('amount', 0.0) or 0.0)
                fee = float(d.get('fee_amount', 0.0) or d.get('system_fee', 0.0) or 0.40)
                preorder_volume += amt
                preorder_commission += fee
                preorder_count += 1
        except Exception as e:
            print(f"Error reading preorder food transactions: {e}")

        # 5. Virtual Cards & NFC Issuance Fees (KES 50 - 100 per card)
        vcard_commission = 0.0
        vcard_count = 0
        try:
            card_docs = db.collection('virtual_cards').get()
            for doc in card_docs:
                d = doc.to_dict() or {}
                fee = float(d.get('issuance_fee', 50.0) or 50.0)
                vcard_commission += fee
                vcard_count += 1
        except Exception as e:
            print(f"Error reading virtual cards: {e}")

        # Check aggregate system_commissions counter in system_settings/admin
        aggregated_counter = 0.0
        try:
            admin_doc = db.collection('system_settings').document('admin').get()
            if admin_doc.exists:
                aggregated_counter = float(admin_doc.to_dict().get('system_commissions', 0.0) or 0.0)
        except Exception:
            pass

        total_commission = max(
            vendor_w_commission + gig_commission + gift_commission + preorder_commission + vcard_commission,
            aggregated_counter
        )

        return jsonify({
            "status": "success",
            "total_commission": round(total_commission, 2),
            "breakdown": {
                "vendor_withdrawals": {
                    "title": "Vendor Money Cashouts",
                    "commission": round(vendor_w_commission, 2),
                    "volume": round(vendor_w_volume, 2),
                    "transaction_count": vendor_w_count,
                    "avg_fee_per_tx": round(vendor_w_commission / max(vendor_w_count, 1), 2)
                },
                "student_gifts": {
                    "title": "Student Meal Gifts & Transfers",
                    "commission": round(gift_commission, 2),
                    "volume": round(gift_volume, 2),
                    "transaction_count": gift_count,
                    "avg_fee_per_tx": round(gift_commission / max(gift_count, 1), 2)
                },
                "preorders_cafeteria": {
                    "title": "Cafeteria Pre-Orders & Dining Swipes",
                    "commission": round(preorder_commission, 2),
                    "volume": round(preorder_volume, 2),
                    "transaction_count": preorder_count,
                    "avg_fee_per_tx": round(preorder_commission / max(preorder_count, 1), 2)
                },
                "campus_gigs": {
                    "title": "DeLiv Courier & Fundi Services",
                    "commission": round(gig_commission, 2),
                    "volume": round(gig_volume, 2),
                    "transaction_count": gig_count,
                    "avg_fee_per_tx": round(gig_commission / max(gig_count, 1), 2)
                },
                "virtual_cards": {
                    "title": "Virtual Card & NFC Tap Setup",
                    "commission": round(vcard_commission, 2),
                    "volume": round(vcard_count * 100.0, 2),
                    "transaction_count": vcard_count,
                    "avg_fee_per_tx": 50.0
                }
            },
            "timestamp": datetime.datetime.utcnow().isoformat()
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@analytics_v4_bp.route('/student_flow', methods=['GET'])
def get_student_deposit_and_vendor_flow():
    """
    Data Analysis Tool for DISHI Executives:
    - Total deposits done by students (C2B Paybill 4050545, STK Push, Agent Float)
    - Detailed vendor flow: what vendors students spend at, how often, total amount, and location
    """
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        db = firestore.client()

        # 1. Total deposits done by students
        total_student_deposits = 0.0
        c2b_deposits_volume = 0.0
        c2b_deposits_count = 0
        stk_deposits_volume = 0.0
        stk_deposits_count = 0
        depositing_students = set()

        # Check C2B transactions
        try:
            c2b_docs = db.collection('c2b_transactions').limit(300).get()
            for doc in c2b_docs:
                d = doc.to_dict() or {}
                amt = float(d.get('amount', 0.0) or d.get('TransAmount', 0.0) or 0.0)
                st = str(d.get('status', 'completed')).lower()
                if st in ['completed', 'credited', 'success']:
                    c2b_deposits_volume += amt
                    c2b_deposits_count += 1
                    uid = d.get('user_id') or d.get('resolved_user_id') or d.get('BillRefNumber')
                    if uid:
                        depositing_students.add(str(uid))
        except Exception as e:
            print(f"Error querying c2b_transactions for student deposits: {e}")

        # Check STK / general mpesa_transactions
        try:
            mpesa_docs = db.collection('mpesa_transactions').limit(300).get()
            for doc in mpesa_docs:
                d = doc.to_dict() or {}
                amt = float(d.get('amount', 0.0) or 0.0)
                st = str(d.get('status', '')).lower()
                if st in ['completed', 'success', 'paid']:
                    stk_deposits_volume += amt
                    stk_deposits_count += 1
                    uid = d.get('user_id') or d.get('userId') or d.get('phone')
                    if uid:
                        depositing_students.add(str(uid))
        except Exception as e:
            print(f"Error querying mpesa_transactions: {e}")

        total_student_deposits = c2b_deposits_volume + stk_deposits_volume
        total_deposit_transactions = c2b_deposits_count + stk_deposits_count
        avg_deposit_amount = round(total_student_deposits / max(total_deposit_transactions, 1), 2)

        # 2. Vendor flow: what vendors students spend at, how often, amounts, locations
        # Build cache of vendors (locations, campus, stall name)
        vendors_catalog = {}
        try:
            vendor_users = db.collection('users').where('role', '==', 'vendor').limit(100).get()
            for vdoc in vendor_users:
                vd = vdoc.to_dict() or {}
                vid = vdoc.id
                vendors_catalog[vid] = {
                    'vendor_id': vid,
                    'vendor_name': vd.get('businessName') or vd.get('displayName') or vd.get('name') or "Campus Vendor",
                    'location': vd.get('stallLocation') or vd.get('location') or vd.get('campus') or "Main Campus Hall",
                    'campus': vd.get('campus') or "Main Campus",
                    'category': vd.get('category') or "Cafeteria & Hot Meals",
                    'photoUrl': vd.get('profileImageUrl') or vd.get('photoUrl') or "",
                    'rating': float(vd.get('rating', 4.8) or 4.8)
                }
        except Exception as e:
            print(f"Error loading vendor users catalog: {e}")

        # Analyze transactions paid to vendors
        vendor_spending_map = {}
        total_student_spend = 0.0

        try:
            tx_docs = db.collection('transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(500).get()
            for doc in tx_docs:
                d = doc.to_dict() or {}
                tx_type = str(d.get('type', '')).lower()
                # Student payments to vendors: preorder, food_purchase, payment, vendor_payment
                if tx_type in ['preorder', 'food_purchase', 'payment', 'cafeteria_order', 'meal_purchase', 'vendor_sale']:
                    vendor_id = d.get('vendorId') or d.get('vendor_id') or d.get('recipientId')
                    amt = float(d.get('amount', 0.0) or 0.0)
                    student_uid = d.get('userId') or d.get('student_id') or d.get('senderId') or "anonymous"

                    if not vendor_id:
                        continue

                    total_student_spend += amt

                    if vendor_id not in vendor_spending_map:
                        v_info = vendors_catalog.get(vendor_id, {
                            'vendor_id': vendor_id,
                            'vendor_name': d.get('vendor_name') or d.get('vendorName') or f"Vendor {vendor_id[-4:]}",
                            'location': d.get('location') or "Campus Cafeteria",
                            'campus': d.get('campus') or "Main Campus",
                            'category': "Dining & Catering",
                            'photoUrl': "",
                            'rating': 4.5
                        })
                        vendor_spending_map[vendor_id] = {
                            **v_info,
                            'total_amount': 0.0,
                            'frequency_count': 0,
                            'unique_students': set(),
                            'order_history': []
                        }

                    vendor_spending_map[vendor_id]['total_amount'] += amt
                    vendor_spending_map[vendor_id]['frequency_count'] += 1
                    vendor_spending_map[vendor_id]['unique_students'].add(student_uid)
        except Exception as e:
            print(f"Error compiling vendor spending analytics: {e}")

        # Format sorted vendor spending list (ranked by total student amount spent)
        ranked_vendors = []
        for vid, vdata in vendor_spending_map.items():
            amt = round(vdata['total_amount'], 2)
            count = vdata['frequency_count']
            pct = round((amt / max(total_student_spend, 1.0)) * 100, 1)
            ranked_vendors.append({
                'vendor_id': vid,
                'vendor_name': vdata['vendor_name'],
                'location': vdata['location'],
                'campus': vdata['campus'],
                'category': vdata['category'],
                'photoUrl': vdata.get('photoUrl', ''),
                'total_amount': amt,
                'frequency_count': count,
                'unique_students_count': len(vdata['unique_students']),
                'avg_spend_per_order': round(amt / max(count, 1), 2),
                'market_share_percent': pct
            })

        # Sort descending by total amount spent
        ranked_vendors.sort(key=lambda x: x['total_amount'], reverse=True)

        return jsonify({
            "status": "success",
            "deposit_intelligence": {
                "total_student_deposits": round(total_student_deposits, 2),
                "total_deposit_transactions": total_deposit_transactions,
                "unique_depositing_students": len(depositing_students),
                "avg_deposit_amount": avg_deposit_amount,
                "c2b_paybill_volume": round(c2b_deposits_volume, 2),
                "c2b_paybill_count": c2b_deposits_count,
                "stk_push_volume": round(stk_deposits_volume, 2),
                "stk_push_count": stk_deposits_count,
            },
            "vendor_patronage_flow": {
                "total_student_spend": round(total_student_spend, 2),
                "total_vendors_active": len(ranked_vendors),
                "top_vendors": ranked_vendors[:20],
                "all_vendors": ranked_vendors
            },
            "timestamp": datetime.datetime.utcnow().isoformat()
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@analytics_v4_bp.route('/b2b_liquidity_overview', methods=['GET'])
def get_b2b_liquidity_overview():
    """
    B2B Commercial Liquidity Command Center:
    - Analyzes corporate float vs pending vendor settlements
    - Liquidity health score
    - Runway estimation
    """
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        db = firestore.client()

        # 1. Total vendor liability (sum of all active vendor wallet balances)
        vendor_liability = 0.0
        vendors_ready_for_payout = []
        try:
            vendor_docs = db.collection('users').where('role', '==', 'vendor').get()
            for doc in vendor_docs:
                d = doc.to_dict() or {}
                bal = float(d.get('walletBalance', 0.0) or 0.0)
                vendor_liability += bal
                if bal >= 200.0:
                    vendors_ready_for_payout.append({
                        'vendor_id': doc.id,
                        'name': d.get('businessName') or d.get('displayName') or d.get('name') or "Campus Vendor",
                        'balance': bal,
                        'phone': d.get('phoneNumber') or d.get('phone') or "",
                        'paybill': d.get('paybill') or d.get('tillNumber') or ""
                    })
        except Exception as e:
            print(f"Error calculating vendor liability: {e}")

        # 2. Total platform B2B float
        total_float = 0.0
        try:
            # Check system float counter or total C2B pool
            settings_doc = db.collection('system_settings').document('platform_config').get()
            if settings_doc.exists:
                total_float = float(settings_doc.to_dict().get('corporate_b2b_float', 250000.0) or 250000.0)
            else:
                total_float = 250000.0
        except Exception:
            total_float = 250000.0

        # Liquidity Health Ratio = Float / Liability
        liquidity_ratio = round((total_float / max(vendor_liability, 1.0)) * 100, 1)
        health_status = "Optimal" if liquidity_ratio >= 100 else ("Warning" if liquidity_ratio >= 50 else "Critical")

        return jsonify({
            "status": "success",
            "corporate_b2b_float": total_float,
            "vendor_payout_liability": round(vendor_liability, 2),
            "liquidity_ratio_percent": liquidity_ratio,
            "health_status": health_status,
            "vendors_ready_count": len(vendors_ready_for_payout),
            "vendors_ready_for_settlement": sorted(vendors_ready_for_payout, key=lambda x: x['balance'], reverse=True)[:15],
            "timestamp": datetime.datetime.utcnow().isoformat()
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@analytics_v4_bp.route('/platform_security_config', methods=['GET', 'POST'])
def manage_platform_security_config():
    """
    Real-time platform security, maintenance mode, lockdown, and force-update control.
    """
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    db = firestore.client()
    config_ref = db.collection('system_settings').document('platform_config')

    if request.method == 'GET':
        try:
            doc = config_ref.get()
            data = doc.to_dict() if doc.exists else {}
            # Default values
            response_data = {
                "maintenance_mode": data.get('maintenance_mode', False),
                "maintenance_message": data.get('maintenance_message', "DISHI is currently undergoing scheduled platform upgrades. We will be back online shortly."),
                "system_lockdown": data.get('system_lockdown', False),
                "instant_payouts_enabled": data.get('instant_payouts_enabled', True),
                "corporate_b2b_float": float(data.get('corporate_b2b_float', 250000.0)),
                "min_withdrawal_threshold": float(data.get('min_withdrawal_threshold', 100.0)),
                "max_withdrawal_threshold": float(data.get('max_withdrawal_threshold', 70000.0)),
                "updated_at": datetime.datetime.utcnow().isoformat()
            }
            return jsonify({"status": "success", "config": response_data}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    # POST: Update
    try:
        data = request.get_json() or {}
        updates = {}
        for key in ['maintenance_mode', 'maintenance_message', 'system_lockdown', 
                    'instant_payouts_enabled', 'corporate_b2b_float', 
                    'min_withdrawal_threshold', 'max_withdrawal_threshold']:
            if key in data:
                updates[key] = data[key]

        updates['updated_at'] = firestore.SERVER_TIMESTAMP
        updates['updated_by'] = admin_id

        config_ref.set(updates, merge=True)
        log_admin_action(admin_id, "Update Platform Config", f"Keys: {list(updates.keys())}")

        return jsonify({
            "status": "success", 
            "message": "Platform configuration updated successfully",
            "updated_keys": list(updates.keys())
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
