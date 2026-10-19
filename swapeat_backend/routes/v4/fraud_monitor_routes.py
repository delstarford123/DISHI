from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime

fraud_bp = Blueprint('fraud_monitor_v4', __name__)

def verify_admin(req):
    auth_header = req.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        token = auth_header.split('Bearer ')[1]
        try:
            from firebase_admin import auth
            decoded = auth.verify_id_token(token)
            return decoded.get('uid')
        except Exception:
            return None
    return None

def _get_user_profile(db, uid, cache):
    """
    Enriches a flagged user/vendor ID with complete profile details and photo.
    Uses in-memory cache to minimize Firestore round-trips.
    """
    if not uid or uid in ['unknown', 'None', '']:
        return {
            'user_id': uid or 'unknown',
            'name': 'Unknown User',
            'email': '',
            'phone': '',
            'photo_url': '',
            'role': 'unknown',
            'wallet_balance': 0.0,
            'campus': '',
            'status': 'active'
        }

    if uid in cache:
        return cache[uid]

    try:
        # 1. Try users collection
        user_doc = db.collection('users').document(uid).get()
        if user_doc.exists:
            u = user_doc.to_dict()
            photo = (
                u.get('photoUrl') or
                u.get('profileImageUrl') or
                u.get('photo_url') or
                u.get('avatar') or
                u.get('image') or
                ''
            )
            profile = {
                'user_id': uid,
                'name': u.get('displayName') or u.get('name') or u.get('fullName') or 'Comrade',
                'email': u.get('email', ''),
                'phone': u.get('phone') or u.get('phoneNumber') or '',
                'photo_url': photo,
                'role': u.get('role', 'student'),
                'wallet_balance': float(u.get('walletBalance') or u.get('wallet_balance') or u.get('balance') or 0.0),
                'campus': u.get('campus') or u.get('university') or '',
                'status': 'suspended' if (u.get('isSuspended') or u.get('status') == 'suspended') else 'active'
            }
            cache[uid] = profile
            return profile

        # 2. Try vendors collection
        vendor_doc = db.collection('vendors').document(uid).get()
        if vendor_doc.exists:
            v = vendor_doc.to_dict()
            photo = (
                v.get('logoUrl') or
                v.get('photoUrl') or
                v.get('profileImageUrl') or
                v.get('image') or
                ''
            )
            profile = {
                'user_id': uid,
                'name': v.get('shopName') or v.get('name') or 'Vendor Shop',
                'email': v.get('email', ''),
                'phone': v.get('phone') or v.get('phoneNumber') or '',
                'photo_url': photo,
                'role': 'vendor',
                'wallet_balance': float(v.get('balance') or v.get('wallet_balance') or 0.0),
                'campus': v.get('campus') or v.get('location', ''),
                'status': 'suspended' if (v.get('isSuspended') or v.get('status') == 'suspended') else 'active'
            }
            cache[uid] = profile
            return profile

    except Exception as e:
        print(f"[FraudMonitor] Error fetching profile for {uid}: {e}")

    fallback = {
        'user_id': uid,
        'name': f"User {uid[:8]}",
        'email': '',
        'phone': '',
        'photo_url': '',
        'role': 'user',
        'wallet_balance': 0.0,
        'campus': '',
        'status': 'active'
    }
    cache[uid] = fallback
    return fallback


# ─────────────────────────────────────────────────────────────────────────────
# 1. Enriched Fraud & Wash Trading Flags (Details, Images, Profile)
# ─────────────────────────────────────────────────────────────────────────────
@fraud_bp.route('/flags', methods=['GET'])
def get_all_fraud_flags():
    """
    Returns enriched Fraud and Wash Trading flags with full user images,
    profile details, and transaction forensics for the Admin Dashboard.
    """
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        db = firestore.client()
        cache = {}
        flags = []
        seen_keys = set()

        # ── Source A: Explicit Wash Trading & Fraud Flags from Firestore ─────
        try:
            fraud_docs = db.collection('fraud_flags').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(50).get()
            for d in fraud_docs:
                f_data = d.to_dict()
                student_id = f_data.get('studentId') or f_data.get('user_id') or ''
                vendor_id = f_data.get('vendorId') or f_data.get('vendor_id') or ''
                primary_uid = student_id or vendor_id or d.id

                profile = _get_user_profile(db, primary_uid, cache)
                vendor_profile = _get_user_profile(db, vendor_id, cache) if vendor_id else None

                ts = f_data.get('timestamp')
                ts_str = ts.isoformat() if hasattr(ts, 'isoformat') else str(ts or '')

                reason_code = f_data.get('reason', 'cooldown_violation')
                if reason_code == 'cooldown_violation':
                    reason_title = "Wash Trading Cooldown Violation"
                    risk_score = 95
                    severity = "critical"
                    desc = f_data.get('description') or (
                        f"{profile['name']} purchased food within 30 minutes of a top-up at "
                        f"{vendor_profile['name'] if vendor_profile else 'the same vendor'} to farm agent commissions."
                    )
                else:
                    reason_title = f_data.get('reason', 'Suspicious Activity').replace('_', ' ').title()
                    risk_score = int(f_data.get('risk_score', 80))
                    severity = "high" if risk_score >= 70 else "medium"
                    desc = f_data.get('description', 'Suspicious transaction pattern detected.')

                key = f"doc_{d.id}"
                seen_keys.add(key)

                flags.append({
                    'id': d.id,
                    'flag_id': d.id,
                    'user_id': primary_uid,
                    'name': profile['name'],
                    'email': profile['email'],
                    'phone': profile['phone'],
                    'photo_url': profile['photo_url'],
                    'role': profile['role'],
                    'campus': profile['campus'],
                    'wallet_balance': profile['wallet_balance'],
                    'status': profile['status'],
                    'risk_score': risk_score,
                    'severity': severity,
                    'category': 'wash_trading',
                    'reason': reason_title,
                    'description': desc,
                    'tx_id': f_data.get('txId', ''),
                    'timestamp': ts_str,
                    'recent_tx_count': f_data.get('tx_count', 1),
                    'vendor_id': vendor_id,
                    'vendor_name': vendor_profile['name'] if vendor_profile else None,
                    'vendor_photo_url': vendor_profile['photo_url'] if vendor_profile else None,
                })
        except Exception as e:
            print(f"[FraudMonitor] Error reading fraud_flags collection: {e}")

        # ── Source B: Wash Trading Ratio Violations (Genuine Food Sales vs Topups) ──
        try:
            today = datetime.datetime.now(datetime.timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
            tx_today = db.collection('transactions').where('timestamp', '>=', today).stream()

            vendor_tx_map = {}
            for tx in tx_today:
                t = tx.to_dict()
                vid = t.get('vendorId') or t.get('vendor_id')
                if not vid:
                    continue
                if vid not in vendor_tx_map:
                    vendor_tx_map[vid] = {'food_sales': 0.0, 'topups': 0.0, 'count': 0}
                amt = float(t.get('amount', 0.0))
                if t.get('type') == 'vendor_agent_topup':
                    vendor_tx_map[vid]['topups'] += amt
                else:
                    vendor_tx_map[vid]['food_sales'] += amt
                vendor_tx_map[vid]['count'] += 1

            for vid, stats in vendor_tx_map.items():
                food = stats['food_sales']
                topups = stats['topups']
                if topups > 0 and (food == 0 or topups > food):
                    # Flag this vendor for wash trading
                    v_profile = _get_user_profile(db, vid, cache)
                    ratio_str = f"{(food / topups):.2f}" if topups > 0 else "0.00"
                    key = f"wash_ratio_{vid}"
                    if key in seen_keys:
                        continue
                    seen_keys.add(key)

                    risk = 95 if food == 0 else 75
                    flags.append({
                        'id': f"wash_{vid}",
                        'flag_id': f"wash_{vid}",
                        'user_id': vid,
                        'name': v_profile['name'],
                        'email': v_profile['email'],
                        'phone': v_profile['phone'],
                        'photo_url': v_profile['photo_url'],
                        'role': 'vendor',
                        'campus': v_profile['campus'],
                        'wallet_balance': v_profile['wallet_balance'],
                        'status': v_profile['status'],
                        'risk_score': risk,
                        'severity': 'critical' if risk >= 90 else 'high',
                        'category': 'wash_trading',
                        'reason': '1:1 Wash Trading Ratio Breached',
                        'description': f"Vendor processed KES {topups:,.0f} in agent top-ups but only KES {food:,.0f} in genuine food sales (Ratio {ratio_str}:1).",
                        'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                        'recent_tx_count': stats['count'],
                        'metrics': {
                            'food_sales': food,
                            'topups_processed': topups,
                            'ratio': ratio_str
                        }
                    })
        except Exception as e:
            print(f"[FraudMonitor] Error calculating wash trading ratio: {e}")

        # ── Source C: High Frequency Velocity Bursts from Recent Transactions ──
        try:
            recent_txs = db.collection('transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(100).get()
            user_tx_counts = {}
            for t in recent_txs:
                td = t.to_dict()
                u = td.get('user_id') or td.get('student_id') or td.get('vendor_id') or ''
                if u and u != 'unknown':
                    user_tx_counts[u] = user_tx_counts.get(u, 0) + 1

            for u, count in user_tx_counts.items():
                if count >= 4:
                    key = f"velocity_{u}"
                    if key in seen_keys:
                        continue
                    seen_keys.add(key)

                    u_profile = _get_user_profile(db, u, cache)
                    flags.append({
                        'id': f"vel_{u}",
                        'flag_id': f"vel_{u}",
                        'user_id': u,
                        'name': u_profile['name'],
                        'email': u_profile['email'],
                        'phone': u_profile['phone'],
                        'photo_url': u_profile['photo_url'],
                        'role': u_profile['role'],
                        'campus': u_profile['campus'],
                        'wallet_balance': u_profile['wallet_balance'],
                        'status': u_profile['status'],
                        'risk_score': min(90, 50 + (count * 5)),
                        'severity': 'high' if count >= 6 else 'medium',
                        'category': 'velocity_spike',
                        'reason': 'High Transaction Velocity Spike',
                        'description': f"Observed abnormal transaction velocity: {count} transactions recorded in the recent cycle.",
                        'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                        'recent_tx_count': count
                    })
        except Exception as e:
            print(f"[FraudMonitor] Error checking velocity: {e}")

        # Sort highest risk score first
        flags.sort(key=lambda x: x.get('risk_score', 0), reverse=True)

        return jsonify({'flags': flags, 'count': len(flags)}), 200

    except Exception as e:
        import traceback
        return jsonify({'error': str(e), 'trace': traceback.format_exc()}), 500


# ─────────────────────────────────────────────────────────────────────────────
# 2. Legacy /velocity Endpoint (Preserved and Enriched with Profiles)
# ─────────────────────────────────────────────────────────────────────────────
@fraud_bp.route('/velocity', methods=['GET'])
def get_velocity_monitor():
    """
    Wash Trading Velocity Monitor for Admin Dashboard.
    Calculates the 1:1 Ratio: Genuine Food Sales vs Top-Ups.
    """
    try:
        db = firestore.client()
        today = datetime.datetime.now(datetime.timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        
        tx_query = db.collection('transactions').where('timestamp', '>=', today).stream()
        
        vendor_tx_map = {}
        for tx in tx_query:
            t_data = tx.to_dict()
            v_id = t_data.get('vendorId')
            if not v_id:
                continue
                
            if v_id not in vendor_tx_map:
                vendor_tx_map[v_id] = {'food_sales': 0.0, 'topups': 0.0, 'commissions': 0.0}
                
            amt = float(t_data.get('amount', 0.0))
            if t_data.get('type', 'sale') == 'vendor_agent_topup':
                vendor_tx_map[v_id]['topups'] += amt
                vendor_tx_map[v_id]['commissions'] += float(t_data.get('commissionEarned', 0.0))
            else:
                vendor_tx_map[v_id]['food_sales'] += amt
                
        vendors_ref = db.collection('vendors').stream()
        vendor_stats = []

        for v in vendors_ref:
            vendor_id = v.id
            vendor_data = v.to_dict()
            vendor_name = vendor_data.get('shopName', vendor_data.get('name', 'Unknown'))
            vendor_photo = vendor_data.get('logoUrl') or vendor_data.get('photoUrl') or vendor_data.get('image') or ''

            stats = vendor_tx_map.get(vendor_id, {'food_sales': 0.0, 'topups': 0.0, 'commissions': 0.0})
            food_sales = stats['food_sales']
            topups_processed = stats['topups']
            commissions_earned = stats['commissions']

            ratio = food_sales / topups_processed if topups_processed > 0 else float('inf')
            
            risk_score = 0
            if topups_processed > 0 and food_sales == 0:
                risk_score = 95
            elif topups_processed > food_sales:
                risk_score = 75
            elif topups_processed * 0.8 > food_sales:
                risk_score = 50
            else:
                risk_score = 10

            vendor_stats.append({
                "vendorId": vendor_id,
                "vendorName": vendor_name,
                "photo_url": vendor_photo,
                "foodSalesToday": food_sales,
                "topupsProcessedToday": topups_processed,
                "commissionsEarnedToday": commissions_earned,
                "ratio": round(ratio, 2) if ratio != float('inf') else "N/A",
                "riskScore": risk_score
            })

        vendor_stats.sort(key=lambda x: x['riskScore'], reverse=True)
        return jsonify({"status": "success", "data": vendor_stats}), 200

    except Exception as e:
        import traceback
        return jsonify({"error": str(e), "trace": traceback.format_exc()}), 500


# ─────────────────────────────────────────────────────────────────────────────
# 3. Dismiss Fraud Flag Endpoint
# ─────────────────────────────────────────────────────────────────────────────
@fraud_bp.route('/flags/<flag_id>', methods=['DELETE', 'POST'])
def dismiss_flag(flag_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        db = firestore.client()
        # If document exists in fraud_flags, delete or mark as dismissed
        doc_ref = db.collection('fraud_flags').document(flag_id)
        if doc_ref.get().exists:
            doc_ref.delete()

        # Log admin audit
        db.collection('admin_action_logs').add({
            'admin_id': admin_id,
            'action': 'dismiss_fraud_flag',
            'details': {'flag_id': flag_id},
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        return jsonify({'message': f'Flag {flag_id} dismissed successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
