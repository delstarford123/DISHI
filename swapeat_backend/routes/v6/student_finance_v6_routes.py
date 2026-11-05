from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import datetime
from datetime import timedelta
import uuid

# Project rules: Never import heavy packages at module level. Use lazy imports.
# Import safe helpers
from routes.mpesa_routes import resolve_user_ref, _credit_wallet_safely, _send_notification

student_finance_v6_bp = Blueprint('student_finance_v6', __name__)

# =====================================================================
# 1. STUDENT & USER SAVINGS VAULT (CATEGORIES, LOCK-IN, EARLY LIQUIDATION)
# =====================================================================

VALID_VAULT_CATEGORIES = [
    'Emergency Savings',
    'Education & Tuition',
    'Campus Tech & Gear',
    'Semester Living & Groceries',
    'Graduation & Career',
    'Vendor Business Reserve',
    'Family Emergency Pool',
    'General Goal'
]

LOCK_PERIOD_DAYS = {
    'flexible': 0,
    '1_month': 30,
    '3_months': 90,
    '6_months': 180,
    '1_year': 365
}

@student_finance_v6_bp.route('/savings/create', methods=['POST'])
def create_savings_vault():
    """
    Creates a dedicated savings vault category with target, lock period & maturity date.
    """
    data = request.json or {}
    user_id = str(data.get('user_id', '')).strip()
    category = str(data.get('category', 'Emergency Savings')).strip()
    title = str(data.get('title', category)).strip()
    target_amount = float(data.get('target_amount', 1000.0))
    lock_period = str(data.get('lock_period', 'flexible')).strip().lower()
    initial_deposit = float(data.get('initial_deposit', 0.0))

    if not user_id:
        return jsonify({'error': 'user_id is required'}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, user_id)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'User not found'}), 404

    now = datetime.datetime.now(datetime.timezone.utc)
    lock_days = LOCK_PERIOD_DAYS.get(lock_period, 0)
    maturity_date = now + timedelta(days=lock_days) if lock_days > 0 else None

    # Handle custom maturity date if provided
    custom_maturity_str = data.get('custom_maturity_date')
    if custom_maturity_str:
        try:
            maturity_date = datetime.datetime.fromisoformat(custom_maturity_str.replace('Z', '+00:00'))
        except Exception:
            pass

    # Check initial deposit balance
    current_wallet = float(user_doc.to_dict().get('walletBalance', 0.0))
    if initial_deposit > 0:
        if current_wallet < initial_deposit:
            return jsonify({'error': f'Insufficient wallet balance (KES {current_wallet:.2f}) for initial deposit'}), 400
        # Deduct wallet
        user_ref.update({
            'walletBalance': firestore.Increment(-initial_deposit),
            'wallet_balance': firestore.Increment(-initial_deposit),
            'vaultBalance': firestore.Increment(initial_deposit)
        })

    vault_doc = {
        'user_id': real_uid,
        'title': title,
        'category': category,
        'target_amount': target_amount,
        'current_balance': initial_deposit,
        'lock_period': lock_period,
        'maturity_date': maturity_date,
        'is_locked': lock_days > 0,
        'status': 'active',
        'created_at': firestore.SERVER_TIMESTAMP,
        'updated_at': firestore.SERVER_TIMESTAMP
    }

    doc_ref = db.collection('user_savings_vaults').document()
    doc_ref.set(vault_doc)

    return jsonify({
        'success': True,
        'vault_id': doc_ref.id,
        'message': f'Savings Vault "{title}" created successfully.',
        'is_locked': lock_days > 0,
        'maturity_date': maturity_date.isoformat() if maturity_date else None
    }), 201


@student_finance_v6_bp.route('/savings/list/<user_id>', methods=['GET'])
def list_savings_vaults(user_id):
    """
    Lists all category vaults for a student, parent, or vendor.
    """
    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, user_id)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'User not found'}), 404

    now = datetime.datetime.now(datetime.timezone.utc)
    docs = db.collection('user_savings_vaults').where('user_id', '==', real_uid).stream()
    vaults = []
    total_saved = 0.0

    for d in docs:
        v = d.to_dict()
        v['id'] = d.id
        c_bal = float(v.get('current_balance', 0.0))
        total_saved += c_bal

        mat = v.get('maturity_date')
        is_matured = False
        days_left = 0
        if mat:
            mat_dt = mat if isinstance(mat, datetime.datetime) else mat.to_datetime()
            is_matured = now >= mat_dt
            days_left = max(0, (mat_dt - now).days)
            v['maturity_date_iso'] = mat_dt.isoformat()
        else:
            is_matured = True

        v['is_matured'] = is_matured
        v['days_left'] = days_left
        v['progress_percent'] = min(100.0, (c_bal / float(v.get('target_amount', 1.0))) * 100.0) if v.get('target_amount') else 0.0
        vaults.append(v)

    # Check pending early liquidation requests
    req_docs = db.collection('vault_liquidation_requests').where('user_id', '==', real_uid).where('status', '==', 'pending').stream()
    pending_requests = []
    for r in req_docs:
        rd = r.to_dict()
        rd['id'] = r.id
        pending_requests.append(rd)

    return jsonify({
        'success': True,
        'vaults': vaults,
        'total_saved': total_saved,
        'pending_liquidations': pending_requests
    }), 200


@student_finance_v6_bp.route('/savings/deposit', methods=['POST'])
def deposit_to_vault():
    """
    Deposits funds into a specific category savings vault.
    """
    data = request.json or {}
    user_id = str(data.get('user_id', '')).strip()
    vault_id = str(data.get('vault_id', '')).strip()
    amount = float(data.get('amount', 0.0))

    if amount <= 0:
        return jsonify({'error': 'Amount must be greater than zero'}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, user_id)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'User not found'}), 404

    current_wallet = float(user_doc.to_dict().get('walletBalance', 0.0))
    if current_wallet < amount:
        return jsonify({'error': f'Insufficient wallet balance (KES {current_wallet:.2f})'}), 400

    vault_ref = db.collection('user_savings_vaults').document(vault_id)
    vault_snap = vault_ref.get()
    if not vault_snap.exists:
        return jsonify({'error': 'Savings vault not found'}), 404

    # Atomic transfer
    user_ref.update({
        'walletBalance': firestore.Increment(-amount),
        'wallet_balance': firestore.Increment(-amount),
        'vaultBalance': firestore.Increment(amount)
    })
    vault_ref.update({
        'current_balance': firestore.Increment(amount),
        'updated_at': firestore.SERVER_TIMESTAMP
    })

    db.collection('transactions').add({
        'userId': real_uid,
        'title': f'Saved to {vault_snap.to_dict().get("title", "Vault")}',
        'amount': amount,
        'type': 'savings_deposit',
        'vaultId': vault_id,
        'createdAt': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        'success': True,
        'message': f'Successfully saved KES {amount:.2f} into vault.',
        'deposited': amount
    }), 200


@student_finance_v6_bp.route('/savings/withdraw', methods=['POST'])
def withdraw_from_vault():
    """
    Withdraws from savings vault back to main wallet if mature or unlocked.
    If locked and pre-mature, instructs user to request early liquidation from Admin.
    """
    data = request.json or {}
    user_id = str(data.get('user_id', '')).strip()
    vault_id = str(data.get('vault_id', '')).strip()
    amount = float(data.get('amount', 0.0))

    if amount <= 0:
        return jsonify({'error': 'Amount must be greater than zero'}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, user_id)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'User not found'}), 404

    vault_ref = db.collection('user_savings_vaults').document(vault_id)
    vault_snap = vault_ref.get()
    if not vault_snap.exists:
        return jsonify({'error': 'Savings vault not found'}), 404

    vault_data = vault_snap.to_dict()
    current_vault_bal = float(vault_data.get('current_balance', 0.0))
    if current_vault_bal < amount:
        return jsonify({'error': f'Insufficient vault funds. Balance is KES {current_vault_bal:.2f}'}), 400

    # Check lock status
    is_locked = vault_data.get('is_locked', False)
    mat = vault_data.get('maturity_date')
    now = datetime.datetime.now(datetime.timezone.utc)

    if is_locked and mat:
        mat_dt = mat if isinstance(mat, datetime.datetime) else mat.to_datetime()
        if now < mat_dt:
            days_left = (mat_dt - now).days
            return jsonify({
                'error': f'Vault is locked for disciplined savings until {mat_dt.strftime("%d %b %Y")} ({days_left} days left). For emergency withdrawal, please submit an Early Liquidation Request to Admin.',
                'can_request_early_liquidation': True,
                'maturity_date': mat_dt.isoformat(),
                'days_left': days_left
            }), 403

    # Mature or flexible withdrawal
    user_ref.update({
        'walletBalance': firestore.Increment(amount),
        'wallet_balance': firestore.Increment(amount),
        'vaultBalance': firestore.Increment(-amount)
    })
    vault_ref.update({
        'current_balance': firestore.Increment(-amount),
        'updated_at': firestore.SERVER_TIMESTAMP
    })

    db.collection('transactions').add({
        'userId': real_uid,
        'title': f'Withdrawal from {vault_data.get("title", "Vault")}',
        'amount': amount,
        'type': 'savings_withdrawal',
        'vaultId': vault_id,
        'createdAt': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        'success': True,
        'message': f'KES {amount:.2f} transferred back to your main wallet.',
        'withdrawn': amount
    }), 200


@student_finance_v6_bp.route('/savings/early_liquidation/request', methods=['POST'])
def request_early_liquidation():
    """
    Submits an emergency early liquidation request to the System Admin for a locked vault.
    """
    data = request.json or {}
    user_id = str(data.get('user_id', '')).strip()
    vault_id = str(data.get('vault_id', '')).strip()
    amount = float(data.get('amount', 0.0))
    reason_category = str(data.get('reason_category', 'Medical Emergency')).strip()
    explanation = str(data.get('explanation', '')).strip()

    if not user_id or not vault_id or amount <= 0:
        return jsonify({'error': 'user_id, vault_id, and positive amount are required'}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, user_id)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'User not found'}), 404

    vault_ref = db.collection('user_savings_vaults').document(vault_id)
    vault_snap = vault_ref.get()
    if not vault_snap.exists:
        return jsonify({'error': 'Vault not found'}), 404

    v_data = vault_snap.to_dict()
    v_bal = float(v_data.get('current_balance', 0.0))
    if v_bal < amount:
        return jsonify({'error': f'Request amount exceeds available vault balance (KES {v_bal:.2f})'}), 400

    user_data = user_doc.to_dict()
    applicant_name = user_data.get('displayName') or user_data.get('name') or 'Student'
    phone = user_data.get('phoneNumber') or ''

    req_doc = {
        'user_id': real_uid,
        'applicant_name': applicant_name,
        'applicant_phone': phone,
        'vault_id': vault_id,
        'vault_title': v_data.get('title', 'Savings Vault'),
        'vault_category': v_data.get('category', 'General'),
        'amount': amount,
        'vault_balance': v_bal,
        'reason_category': reason_category,
        'explanation': explanation,
        'status': 'pending',
        'requested_at': firestore.SERVER_TIMESTAMP
    }

    doc_ref = db.collection('vault_liquidation_requests').document()
    doc_ref.set(req_doc)

    return jsonify({
        'success': True,
        'request_id': doc_ref.id,
        'message': 'Early liquidation request submitted. A system admin will review and liquidate your vault funds to your wallet.'
    }), 201


@student_finance_v6_bp.route('/savings/early_liquidation/admin_list', methods=['GET'])
def admin_list_early_liquidation():
    """
    Admin endpoint to view all pending early liquidation requests across all students.
    """
    db = firestore.client()
    docs = db.collection('vault_liquidation_requests').order_by('requested_at', direction=firestore.Query.DESCENDING).limit(100).stream()
    requests_list = []
    for d in docs:
        item = d.to_dict()
        item['id'] = d.id
        req_dt = item.get('requested_at')
        if req_dt:
            item['requested_at_iso'] = req_dt.isoformat() if hasattr(req_dt, 'isoformat') else str(req_dt)
        requests_list.append(item)

    return jsonify({'success': True, 'requests': requests_list}), 200


@student_finance_v6_bp.route('/savings/early_liquidation/admin_action', methods=['POST'])
def admin_action_early_liquidation():
    """
    Admin endpoint to approve (liquidate) or reject a student's early liquidation request.
    """
    data = request.json or {}
    request_id = str(data.get('request_id', '')).strip()
    action = str(data.get('action', '')).strip().lower() # 'approve' or 'reject'
    admin_notes = str(data.get('admin_notes', '')).strip()

    if action not in ['approve', 'reject']:
        return jsonify({'error': 'Action must be approve or reject'}), 400

    db = firestore.client()
    req_ref = db.collection('vault_liquidation_requests').document(request_id)
    req_snap = req_ref.get()
    if not req_snap.exists:
        return jsonify({'error': 'Liquidation request not found'}), 404

    req_data = req_snap.to_dict()
    if req_data.get('status') != 'pending':
        return jsonify({'error': f'Request is already {req_data.get("status")}'}), 400

    user_id = req_data.get('user_id')
    vault_id = req_data.get('vault_id')
    amount = float(req_data.get('amount', 0.0))

    if action == 'approve':
        vault_ref = db.collection('user_savings_vaults').document(vault_id)
        user_ref = db.collection('users').document(user_id)

        # Liquidate funds: deduct from vault, credit student wallet
        vault_ref.update({
            'current_balance': firestore.Increment(-amount),
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        user_ref.update({
            'walletBalance': firestore.Increment(amount),
            'wallet_balance': firestore.Increment(amount),
            'vaultBalance': firestore.Increment(-amount)
        })

        req_ref.update({
            'status': 'approved',
            'admin_notes': admin_notes or 'Emergency early liquidation approved by admin.',
            'liquidated_at': firestore.SERVER_TIMESTAMP
        })

        db.collection('transactions').add({
            'userId': user_id,
            'title': f'Admin Liquidation: {req_data.get("vault_title", "Savings Vault")}',
            'amount': amount,
            'type': 'early_liquidation_approved',
            'vaultId': vault_id,
            'createdAt': firestore.SERVER_TIMESTAMP
        })

        return jsonify({
            'success': True,
            'message': f'Vault liquidated successfully. KES {amount:.2f} credited to student wallet.'
        }), 200

    else:
        req_ref.update({
            'status': 'rejected',
            'admin_notes': admin_notes or 'Early liquidation rejected by admin.',
            'rejected_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({
            'success': True,
            'message': 'Liquidation request rejected.'
        }), 200


# =====================================================================
# 2. OKOA FOOD BALANCE & AUTO-DEBT SETTLEMENT
# =====================================================================

@student_finance_v6_bp.route('/okoa/status/<student_uid>', methods=['GET'])
def get_okoa_status(student_uid):
    """
    Returns live Okoa Food debt, showing negative balance e.g. -200 KSh.
    """
    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'Student not found'}), 404

    u_data = user_doc.to_dict() or {}
    debt = float(u_data.get('okoa_debt', 0.0) or 0.0)
    has_debt = debt > 0

    return jsonify({
        'success': True,
        'student_uid': real_uid,
        'okoa_debt': debt,
        'display_balance': -debt if has_debt else 0.0,
        'formatted_display': f"-KES {debt:.2f}" if has_debt else "KES 0.00",
        'max_limit': 500.0,
        'has_debt': has_debt,
        'is_eligible': not has_debt,
        'auto_settle_notice': 'Outstanding debt is automatically deducted on your next wallet top-up.' if has_debt else 'Zero Hunger safety net available.'
    }), 200


@student_finance_v6_bp.route('/okoa/settle', methods=['POST'])
def manual_settle_okoa():
    """
    Allows a student to voluntarily settle their Okoa Food debt from existing wallet balance.
    """
    data = request.json or {}
    student_uid = str(data.get('student_uid', '')).strip()

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'Student not found'}), 404

    u_data = user_doc.to_dict()
    debt = float(u_data.get('okoa_debt', 0.0) or 0.0)
    if debt <= 0:
        return jsonify({'error': 'No outstanding Okoa Food debt to settle'}), 400

    wallet = float(u_data.get('walletBalance', 0.0) or 0.0)
    if wallet < debt:
        return jsonify({'error': f'Insufficient wallet balance (KES {wallet:.2f}) to clear debt of KES {debt:.2f}'}), 400

    user_ref.update({
        'walletBalance': firestore.Increment(-debt),
        'wallet_balance': firestore.Increment(-debt),
        'okoa_debt': 0.0,
        'okoaBalance': 0.0
    })

    db.collection('okoa_records').add({
        'student_uid': real_uid,
        'settled_amount': debt,
        'remaining_debt': 0.0,
        'source': 'manual_wallet_settlement',
        'timestamp': firestore.SERVER_TIMESTAMP,
        'status': 'settled'
    })

    db.collection('transactions').add({
        'userId': real_uid,
        'title': 'Okoa Meal Debt Settled',
        'amount': debt,
        'type': 'okoa_repayment',
        'createdAt': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        'success': True,
        'settled_amount': debt,
        'remaining_debt': 0.0,
        'message': f'Okoa Meal debt of KES {debt:.2f} has been fully settled.'
    }), 200


# =====================================================================
# 3. DORM SHARED WALLET & GROUP VAULT (10+ FEATURES)
# =====================================================================

@student_finance_v6_bp.route('/dorm_wallet/lookup_dishi_id', methods=['POST'])
def lookup_roommate_by_dishi_id():
    """
    Feature 1: Roommate Discovery by DISHI ID, phone, or email.
    """
    data = request.json or {}
    identifier = str(data.get('identifier', '')).strip()

    if not identifier:
        return jsonify({'error': 'Please provide DISHI ID, phone, or email'}), 400

    db = firestore.client()
    # Try exact DISHI ID first
    users_coll = db.collection('users')
    query = users_coll.where('dishiId', '==', identifier).limit(1).stream()
    user_match = None

    for q in query:
        user_match = (q.id, q.to_dict())
        break

    if not user_match:
        # Fallback to phone number
        q_phone = users_coll.where('phoneNumber', '==', identifier).limit(1).stream()
        for q in q_phone:
            user_match = (q.id, q.to_dict())
            break

    if not user_match:
        # Fallback to email
        q_email = users_coll.where('email', '==', identifier).limit(1).stream()
        for q in q_email:
            user_match = (q.id, q.to_dict())
            break

    if not user_match:
        # Fallback to direct UID
        direct_doc = users_coll.document(identifier).get()
        if direct_doc.exists:
            user_match = (direct_doc.id, direct_doc.to_dict())

    if not user_match:
        return jsonify({'error': f'No comrade found with ID/phone "{identifier}"'}), 404

    uid, udata = user_match
    return jsonify({
        'success': True,
        'uid': uid,
        'name': udata.get('displayName') or udata.get('name') or 'Comrade',
        'dishi_id': udata.get('dishiId') or uid[:8],
        'campus': udata.get('campus', 'Main Campus'),
        'photo_url': udata.get('profileImageUrl') or ''
    }), 200


@student_finance_v6_bp.route('/dorm_wallet/create', methods=['POST'])
def create_dorm_wallet():
    """
    Feature 2: Creates a shared dorm/group vault with initial captain and target.
    """
    data = request.json or {}
    creator_uid = str(data.get('creator_uid', '')).strip()
    name = str(data.get('name', 'Dorm Essentials Vault')).strip()
    room_number = str(data.get('room_number', 'Room 1')).strip()
    target_amount = float(data.get('target_amount', 3000.0))
    category = str(data.get('category', 'Cooking Gas & Groceries')).strip()

    if not creator_uid:
        return jsonify({'error': 'creator_uid is required'}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, creator_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'User not found'}), 404

    creator_name = user_doc.to_dict().get('displayName') or user_doc.to_dict().get('name') or 'Captain'
    creator_dishi_id = user_doc.to_dict().get('dishiId') or real_uid[:8]

    dorm_doc = {
        'name': name,
        'room_number': room_number,
        'creator_uid': real_uid,
        'creator_name': creator_name,
        'target_amount': target_amount,
        'category': category,
        'balance': 0.0,
        'members': [{
            'uid': real_uid,
            'name': creator_name,
            'dishi_id': creator_dishi_id,
            'role': 'captain',
            'joined_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'total_contributed': 0.0
        }],
        'invites': [],
        'status': 'active',
        'created_at': firestore.SERVER_TIMESTAMP,
        'updated_at': firestore.SERVER_TIMESTAMP
    }

    doc_ref = db.collection('dorm_shared_wallets').document()
    doc_ref.set(dorm_doc)

    return jsonify({
        'success': True,
        'wallet_id': doc_ref.id,
        'name': name,
        'message': f'Dorm Shared Vault "{name}" created successfully!'
    }), 201


@student_finance_v6_bp.route('/dorm_wallet/invite', methods=['POST'])
def invite_to_dorm_wallet():
    """
    Feature 3: Sends an invitation to a roommate via their DISHI ID.
    """
    data = request.json or {}
    wallet_id = str(data.get('wallet_id', '')).strip()
    invited_uid = str(data.get('invited_uid', '')).strip()
    sender_uid = str(data.get('sender_uid', '')).strip()

    db = firestore.client()
    wallet_ref = db.collection('dorm_shared_wallets').document(wallet_id)
    w_snap = wallet_ref.get()
    if not w_snap.exists:
        return jsonify({'error': 'Dorm wallet not found'}), 404

    w_data = w_snap.to_dict()
    # Verify sender is member
    members = w_data.get('members', [])
    if not any(m.get('uid') == sender_uid for m in members):
        return jsonify({'error': 'Only vault members can invite comrades'}), 403

    # Check if already member
    if any(m.get('uid') == invited_uid for m in members):
        return jsonify({'error': 'Comrade is already an active member of this vault'}), 400

    u_ref, u_doc, real_invited_uid = resolve_user_ref(db, invited_uid)
    if not u_doc or not u_doc.exists:
        return jsonify({'error': 'Invited student not found'}), 404

    invited_name = u_doc.to_dict().get('displayName') or u_doc.to_dict().get('name') or 'Comrade'
    invited_dishi_id = u_doc.to_dict().get('dishiId') or real_invited_uid[:8]

    invite_obj = {
        'uid': real_invited_uid,
        'name': invited_name,
        'dishi_id': invited_dishi_id,
        'invited_by': sender_uid,
        'status': 'pending',
        'invited_at': datetime.datetime.now(datetime.timezone.utc).isoformat()
    }

    # Add to invites list
    invites = [inv for inv in w_data.get('invites', []) if inv.get('uid') != real_invited_uid]
    invites.append(invite_obj)

    wallet_ref.update({
        'invites': invites,
        'updated_at': firestore.SERVER_TIMESTAMP
    })

    # Send in-app notification
    try:
        _send_notification(
            real_invited_uid,
            'Dorm Vault Invitation 🏠',
            f'You have been invited to join the "{w_data.get("name")}" shared dorm vault. Open Dorm Wallet to accept.'
        )
    except Exception:
        pass

    return jsonify({
        'success': True,
        'message': f'Invitation sent to {invited_name} (DISHI ID: {invited_dishi_id})'
    }), 200


@student_finance_v6_bp.route('/dorm_wallet/respond_invite', methods=['POST'])
def respond_dorm_invite():
    """
    Feature 4: Roommate accepts or declines an invitation to the shared vault.
    """
    data = request.json or {}
    wallet_id = str(data.get('wallet_id', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()
    decision = str(data.get('decision', 'accept')).strip().lower() # 'accept' or 'decline'

    db = firestore.client()
    wallet_ref = db.collection('dorm_shared_wallets').document(wallet_id)
    w_snap = wallet_ref.get()
    if not w_snap.exists:
        return jsonify({'error': 'Dorm wallet not found'}), 404

    w_data = w_snap.to_dict()
    invites = w_data.get('invites', [])
    members = w_data.get('members', [])

    matching_invite = next((inv for inv in invites if inv.get('uid') == student_uid and inv.get('status') == 'pending'), None)
    if not matching_invite:
        return jsonify({'error': 'No pending invitation found for this vault'}), 404

    # Remove from pending invites
    updated_invites = [inv for inv in invites if inv.get('uid') != student_uid]

    if decision == 'accept':
        # Add to active members
        members.append({
            'uid': student_uid,
            'name': matching_invite.get('name', 'Comrade'),
            'dishi_id': matching_invite.get('dishi_id', student_uid[:8]),
            'role': 'contributor',
            'joined_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'total_contributed': 0.0
        })
        wallet_ref.update({
            'invites': updated_invites,
            'members': members,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({
            'success': True,
            'message': f'You are now an active member of "{w_data.get("name")}"!'
        }), 200
    else:
        wallet_ref.update({
            'invites': updated_invites,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({
            'success': True,
            'message': 'Invitation declined.'
        }), 200


@student_finance_v6_bp.route('/dorm_wallet/my_wallets/<student_uid>', methods=['GET'])
def get_student_dorm_wallets(student_uid):
    """
    Feature 5: Fetches all dorm wallets the student belongs to plus pending invites.
    """
    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)

    all_wallets = db.collection('dorm_shared_wallets').where('status', '==', 'active').stream()
    my_wallets = []
    pending_invites = []

    for w in all_wallets:
        wd = w.to_dict()
        wd['id'] = w.id
        members = wd.get('members', [])
        invites = wd.get('invites', [])

        if any(m.get('uid') == real_uid for m in members):
            # Calculate target percentage
            bal = float(wd.get('balance', 0.0))
            tgt = float(wd.get('target_amount', 1.0))
            wd['progress_percent'] = min(100.0, (bal / tgt) * 100.0) if tgt > 0 else 0.0
            my_wallets.append(wd)

        matching_inv = next((inv for inv in invites if inv.get('uid') == real_uid and inv.get('status') == 'pending'), None)
        if matching_inv:
            pending_invites.append({
                'wallet_id': w.id,
                'wallet_name': wd.get('name'),
                'room_number': wd.get('room_number'),
                'creator_name': wd.get('creator_name'),
                'target_amount': wd.get('target_amount'),
                'category': wd.get('category'),
                'invited_at': matching_inv.get('invited_at')
            })

    return jsonify({
        'success': True,
        'wallets': my_wallets,
        'pending_invites': pending_invites
    }), 200


@student_finance_v6_bp.route('/dorm_wallet/contribute', methods=['POST'])
def contribute_to_dorm_wallet():
    """
    Feature 6: Member contributes funds from personal wallet into dorm vault.
    """
    data = request.json or {}
    wallet_id = str(data.get('wallet_id', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()
    amount = float(data.get('amount', 0.0))
    note = str(data.get('note', 'Contribution')).strip()

    if amount <= 0:
        return jsonify({'error': 'Amount must be greater than zero'}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'User not found'}), 404

    cur_bal = float(user_doc.to_dict().get('walletBalance', 0.0))
    if cur_bal < amount:
        return jsonify({'error': f'Insufficient wallet balance (KES {cur_bal:.2f})'}), 400

    wallet_ref = db.collection('dorm_shared_wallets').document(wallet_id)
    w_snap = wallet_ref.get()
    if not w_snap.exists:
        return jsonify({'error': 'Dorm wallet not found'}), 404

    w_data = w_snap.to_dict()
    members = w_data.get('members', [])
    m_idx = next((i for i, m in enumerate(members) if m.get('uid') == real_uid), -1)
    if m_idx == -1:
        return jsonify({'error': 'You must be a member of this dorm vault to contribute'}), 403

    # Deduct user, credit dorm
    user_ref.update({
        'walletBalance': firestore.Increment(-amount),
        'wallet_balance': firestore.Increment(-amount)
    })

    # Update member contribution total
    members[m_idx]['total_contributed'] = float(members[m_idx].get('total_contributed', 0.0)) + amount

    wallet_ref.update({
        'balance': firestore.Increment(amount),
        'members': members,
        'updated_at': firestore.SERVER_TIMESTAMP
    })

    # Record ledger
    wallet_ref.collection('ledger').add({
        'contributor_uid': real_uid,
        'contributor_name': members[m_idx].get('name', 'Comrade'),
        'amount': amount,
        'type': 'contribution',
        'note': note,
        'timestamp': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        'success': True,
        'contributed': amount,
        'message': f'Contributed KES {amount:.2f} to {w_data.get("name")}'
    }), 200


@student_finance_v6_bp.route('/dorm_wallet/propose_expense', methods=['POST'])
def propose_dorm_expense():
    """
    Feature 7: Propose a collective purchase (e.g. 13kg Gas cylinder, WiFi voucher, electricity token).
    """
    data = request.json or {}
    wallet_id = str(data.get('wallet_id', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()
    title = str(data.get('title', '')).strip()
    amount = float(data.get('amount', 0.0))
    category = str(data.get('category', 'Gas Refill')).strip()
    vendor_notes = str(data.get('vendor_notes', '')).strip()

    if amount <= 0 or not title:
        return jsonify({'error': 'Title and positive amount required'}), 400

    db = firestore.client()
    wallet_ref = db.collection('dorm_shared_wallets').document(wallet_id)
    w_snap = wallet_ref.get()
    if not w_snap.exists:
        return jsonify({'error': 'Dorm wallet not found'}), 404

    w_data = w_snap.to_dict()
    cur_bal = float(w_data.get('balance', 0.0))
    if cur_bal < amount:
        return jsonify({'error': f'Expense KES {amount:.2f} exceeds vault balance of KES {cur_bal:.2f}'}), 400

    members = w_data.get('members', [])
    m_info = next((m for m in members if m.get('uid') == student_uid), None)
    if not m_info:
        return jsonify({'error': 'Only members can propose expenses'}), 403

    expense_doc = {
        'title': title,
        'amount': amount,
        'category': category,
        'vendor_notes': vendor_notes,
        'proposer_uid': student_uid,
        'proposer_name': m_info.get('name', 'Comrade'),
        'status': 'voting_open', # voting_open, approved, disbursed, rejected
        'votes': {student_uid: True}, # Proposer automatically approves
        'created_at': firestore.SERVER_TIMESTAMP
    }

    doc_ref = wallet_ref.collection('expenses').document()
    doc_ref.set(expense_doc)

    return jsonify({
        'success': True,
        'expense_id': doc_ref.id,
        'message': f'Expense proposal "{title}" created. Roommates can now vote.'
    }), 201


@student_finance_v6_bp.route('/dorm_wallet/vote_expense', methods=['POST'])
def vote_dorm_expense():
    """
    Feature 8: Multi-sig roommate voting on proposed expenses.
    """
    data = request.json or {}
    wallet_id = str(data.get('wallet_id', '')).strip()
    expense_id = str(data.get('expense_id', '')).strip()
    student_uid = str(data.get('student_uid', '')).strip()
    vote = bool(data.get('vote', True))

    db = firestore.client()
    wallet_ref = db.collection('dorm_shared_wallets').document(wallet_id)
    exp_ref = wallet_ref.collection('expenses').document(expense_id)
    exp_snap = exp_ref.get()
    if not exp_snap.exists:
        return jsonify({'error': 'Expense not found'}), 404

    exp_data = exp_snap.to_dict()
    votes = exp_data.get('votes', {})
    votes[student_uid] = vote

    # Check quorum
    w_snap = wallet_ref.get()
    members = w_snap.to_dict().get('members', [])
    total_members = max(1, len(members))
    yes_votes = sum(1 for v in votes.values() if v is True)

    new_status = exp_data.get('status')
    if yes_votes > (total_members // 2):
        new_status = 'approved'

    exp_ref.update({
        'votes': votes,
        'status': new_status,
        'updated_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        'success': True,
        'status': new_status,
        'yes_votes': yes_votes,
        'total_members': total_members,
        'message': 'Vote recorded.'
    }), 200


@student_finance_v6_bp.route('/dorm_wallet/disburse_expense', methods=['POST'])
def disburse_dorm_expense():
    """
    Feature 9: Disburses funds for an approved expense to purchasing student or vendor.
    """
    data = request.json or {}
    wallet_id = str(data.get('wallet_id', '')).strip()
    expense_id = str(data.get('expense_id', '')).strip()
    recipient_uid = str(data.get('recipient_uid', '')).strip()

    db = firestore.client()
    wallet_ref = db.collection('dorm_shared_wallets').document(wallet_id)
    exp_ref = wallet_ref.collection('expenses').document(expense_id)
    exp_snap = exp_ref.get()
    if not exp_snap.exists:
        return jsonify({'error': 'Expense not found'}), 404

    exp_data = exp_snap.to_dict()
    if exp_data.get('status') != 'approved':
        return jsonify({'error': 'Expense has not reached approval quorum'}), 400

    amount = float(exp_data.get('amount', 0.0))
    w_snap = wallet_ref.get()
    w_data = w_snap.to_dict()
    cur_bal = float(w_data.get('balance', 0.0))

    if cur_bal < amount:
        return jsonify({'error': 'Insufficient funds in dorm vault'}), 400

    # Credit recipient
    target_uid = recipient_uid or exp_data.get('proposer_uid')
    u_ref = db.collection('users').document(target_uid)
    u_ref.update({
        'walletBalance': firestore.Increment(amount),
        'wallet_balance': firestore.Increment(amount)
    })

    # Deduct dorm vault
    wallet_ref.update({
        'balance': firestore.Increment(-amount),
        'updated_at': firestore.SERVER_TIMESTAMP
    })
    exp_ref.update({
        'status': 'disbursed',
        'disbursed_to': target_uid,
        'disbursed_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        'success': True,
        'disbursed_amount': amount,
        'message': f'KES {amount:.2f} disbursed for "{exp_data.get("title")}".'
    }), 200


@student_finance_v6_bp.route('/dorm_wallet/refund_all', methods=['POST'])
def refund_all_dorm_wallet():
    """
    Feature 10: Vault dissolution / equal refund back to all member personal wallets.
    """
    data = request.json or {}
    wallet_id = str(data.get('wallet_id', '')).strip()
    captain_uid = str(data.get('captain_uid', '')).strip()

    db = firestore.client()
    wallet_ref = db.collection('dorm_shared_wallets').document(wallet_id)
    w_snap = wallet_ref.get()
    if not w_snap.exists:
        return jsonify({'error': 'Dorm wallet not found'}), 404

    w_data = w_snap.to_dict()
    if w_data.get('creator_uid') != captain_uid:
        return jsonify({'error': 'Only the vault captain can dissolve and refund the vault'}), 403

    cur_bal = float(w_data.get('balance', 0.0))
    members = w_data.get('members', [])
    if not members:
        return jsonify({'error': 'No members in vault'}), 400

    if cur_bal > 0:
        split_per_member = cur_bal / len(members)
        for m in members:
            m_uid = m.get('uid')
            if m_uid:
                db.collection('users').document(m_uid).update({
                    'walletBalance': firestore.Increment(split_per_member),
                    'wallet_balance': firestore.Increment(split_per_member)
                })

    wallet_ref.update({
        'balance': 0.0,
        'status': 'closed',
        'closed_at': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        'success': True,
        'refunded_total': cur_bal,
        'message': 'Vault dissolved. Remaining balance refunded proportionally to all members.'
    }), 200


# =====================================================================
# 4. STUDENT MICRO-LOANS (FOOD & STUDY SUPPORT, 100 - 500 KSH)
# =====================================================================

LOAN_TIERS = {
    100: {'weeks': 1, 'base_interest_pct': 0.0, 'min_repaid': 0, 'purpose': 'Emergency Cafeteria Meal Token'},
    200: {'weeks': 2, 'base_interest_pct': 1.5, 'min_repaid': 0, 'purpose': 'Meal & Printing / Exam Materials'},
    300: {'weeks': 3, 'base_interest_pct': 3.0, 'min_repaid': 1, 'purpose': 'Course Textbooks & Lab Supplies'},
    400: {'weeks': 4, 'base_interest_pct': 4.5, 'min_repaid': 2, 'purpose': 'Study Modules & Revision Packs'},
    500: {'weeks': 5, 'base_interest_pct': 6.0, 'min_repaid': 3, 'purpose': 'Essential Food Basket & Academic Project Kit'}
}

OVERDUE_PENALTY_PCT = 2.0 # 2% additional interest when repayment period elapses

def get_student_credit_track_record(db, real_uid, user_data):
    """
    Evaluates student creditworthiness, track record, and security protocols.
    Prevents taking loans more than once before paying.
    Requires proven transaction activity and graduated tier progression.
    """
    now = datetime.datetime.now(datetime.timezone.utc)

    # 1. Active or Overdue Loans check (Prevents multiple concurrent loans)
    active_loans_query = db.collection('student_loans') \
        .where('student_uid', '==', real_uid) \
        .where('status', 'in', ['active', 'overdue']) \
        .limit(1).stream()
    active_loan = None
    for doc in active_loans_query:
        active_loan = doc.to_dict()
        active_loan['id'] = doc.id
        break

    # 2. Loan repayment history (count of successfully settled loans)
    settled_loans_query = db.collection('student_loans') \
        .where('student_uid', '==', real_uid) \
        .where('status', '==', 'settled') \
        .stream()
    repaid_count = sum(1 for _ in settled_loans_query)

    # 3. OKOA Food debt check (Cross-debt restriction)
    okoa_debt = float(user_data.get('okoa_debt', 0.0) or 0.0)

    # 4. Campus transaction track record
    tx_query = db.collection('transactions').where('userId', '==', real_uid).limit(10).stream()
    tx_count = sum(1 for _ in tx_query)
    if tx_count < 3:
        order_query = db.collection('orders').where('userId', '==', real_uid).limit(5).stream()
        tx_count += sum(1 for _ in order_query)

    # 5. Account age check
    account_age_hours = 72
    created_at = user_data.get('createdAt') or user_data.get('created_at')
    if created_at:
        try:
            created_dt = created_at if isinstance(created_at, datetime.datetime) else created_at.to_datetime()
            account_age_hours = max(0, int((now - created_dt).total_seconds() / 3600))
        except Exception:
            account_age_hours = 72

    # 6. Unlocked tiers calculation based on disciplined track record ("know how to use them")
    unlocked_tiers = []
    has_basic_track_record = (tx_count >= 2) or (account_age_hours >= 48 and bool(user_data.get('phoneNumber') or user_data.get('phone')))

    if has_basic_track_record:
        unlocked_tiers.append(100)
        unlocked_tiers.append(200)
        if repaid_count >= 1:
            unlocked_tiers.append(300)
        if repaid_count >= 2:
            unlocked_tiers.append(400)
        if repaid_count >= 3:
            unlocked_tiers.append(500)
    elif tx_count >= 1:
        unlocked_tiers.append(100)

    # 7. DISHI Campus Credit Score (300 - 850)
    score = 450
    score += min(150, tx_count * 25)
    score += min(250, repaid_count * 75)
    if active_loan and active_loan.get('status') == 'overdue':
        score -= 200
    if okoa_debt > 0:
        score -= 50
    score = max(300, min(850, score))

    if score >= 750:
        tier_title = 'Gold Scholar (Elite)'
    elif score >= 650:
        tier_title = 'Silver Comrade (Trusted)'
    elif score >= 500:
        tier_title = 'Bronze Comrade (Active)'
    else:
        tier_title = 'Novice Comrade (Building Record)'

    is_eligible = (active_loan is None) and (okoa_debt <= 0) and (len(unlocked_tiers) > 0)

    ineligibility_reasons = []
    if active_loan:
        ineligibility_reasons.append(f'Active loan of KES {active_loan.get("amount", 0):.0f} must be settled first.')
    if okoa_debt > 0:
        ineligibility_reasons.append(f'Outstanding Okoa Food debt of KES {okoa_debt:.2f} must be cleared.')
    if not has_basic_track_record and tx_count == 0:
        ineligibility_reasons.append('Complete at least 2 campus transactions to establish credit history.')

    return {
        'is_eligible': is_eligible,
        'has_active_loan': active_loan is not None,
        'active_loan': active_loan,
        'okoa_debt': okoa_debt,
        'has_okoa_debt': okoa_debt > 0,
        'transactions_count': tx_count,
        'repaid_loans_count': repaid_count,
        'account_age_hours': account_age_hours,
        'credit_score': score,
        'credit_rating': tier_title,
        'unlocked_tiers': unlocked_tiers,
        'max_borrow_limit': max(unlocked_tiers) if unlocked_tiers else 0,
        'rejection_reasons': ineligibility_reasons
    }

@student_finance_v6_bp.route('/loans/eligibility/<student_uid>', methods=['GET'])
def get_student_loan_eligibility(student_uid):
    """
    Returns live credit track record, tier permissions, and security eligibility for loans.
    """
    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'Student not found'}), 404

    user_data = user_doc.to_dict() or {}
    record = get_student_credit_track_record(db, real_uid, user_data)
    record['student_uid'] = real_uid
    record['success'] = True
    return jsonify(record), 200

@student_finance_v6_bp.route('/loans/apply', methods=['POST'])
def apply_student_loan():
    """
    Applies for a micro-loan (KES 100 - 500) with strict security protocols & track record validation.
    """
    data = request.json or {}
    student_uid = str(data.get('student_uid', '')).strip()
    amount = int(data.get('amount', 100))
    purpose = str(data.get('purpose', 'Food & Study Support')).strip()

    if amount not in LOAN_TIERS:
        return jsonify({'error': 'Loan amount must be one of: 100, 200, 300, 400, or 500 KES'}), 400

    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'Student not found'}), 404

    user_data = user_doc.to_dict() or {}
    track_record = get_student_credit_track_record(db, real_uid, user_data)

    # 1. Security Protocol: Prevent taking loans more than once before paying
    if track_record['has_active_loan']:
        active_amt = track_record['active_loan'].get('amount', 0)
        return jsonify({
            'error': f'Security Block: You already have an unsettled loan of KES {active_amt:.0f}. DISHI policy strictly forbids multiple concurrent loans. Repay your current loan to unlock new credit.'
        }), 400

    # 2. Security Protocol: Cross-debt check (OKOA Food)
    if track_record['has_okoa_debt']:
        return jsonify({
            'error': f'Security Block: Outstanding Okoa Food debt of KES {track_record["okoa_debt"]:.2f} detected. Please top up and clear your emergency food credit before applying for a cash loan.'
        }), 400

    # 3. Security Protocol: Track record and progressive tier unlocking ("know how to use them")
    if amount not in track_record['unlocked_tiers']:
        req_repaid = LOAN_TIERS[amount]['min_repaid']
        if track_record['transactions_count'] < 2:
            return jsonify({
                'error': 'Track Record Required: Complete at least 2 campus transactions (meals, orders, top-ups) to establish your credit record before borrowing.'
            }), 400
        return jsonify({
            'error': f'Tier Locked: Borrowing KES {amount} requires a proven track record of at least {req_repaid} successfully settled loan(s). You have settled {track_record["repaid_loans_count"]} loan(s). Start with KES 100 or 200 and repay on time to unlock higher tiers.'
        }), 400

    tier = LOAN_TIERS[amount]
    weeks = tier['weeks']
    base_pct = tier['base_interest_pct']
    base_fee = amount * (base_pct / 100.0)
    total_due = amount + base_fee

    now = datetime.datetime.now(datetime.timezone.utc)
    due_date = now + timedelta(weeks=weeks)

    student_name = user_data.get('displayName') or user_data.get('name') or 'Student'
    parent_uid = user_data.get('parentUid')

    loan_doc = {
        'student_uid': real_uid,
        'student_name': student_name,
        'parent_uid': parent_uid,
        'amount': float(amount),
        'base_interest_pct': base_pct,
        'base_fee': base_fee,
        'overdue_penalty_pct': OVERDUE_PENALTY_PCT,
        'total_due': total_due,
        'purpose': purpose,
        'status': 'active',
        'borrowed_at': firestore.SERVER_TIMESTAMP,
        'due_date': due_date,
        'parent_settlement_requested': False
    }

    doc_ref = db.collection('student_loans').document()
    doc_ref.set(loan_doc)

    # Disburse directly to student's wallet balance
    user_ref.update({
        'walletBalance': firestore.Increment(amount),
        'wallet_balance': firestore.Increment(amount)
    })

    db.collection('transactions').add({
        'userId': real_uid,
        'title': f'Micro-Loan Disbursed: KES {amount}',
        'description': f'{purpose} (Repayment due {due_date.strftime("%d %b %Y")})',
        'amount': float(amount),
        'type': 'loan_disbursement',
        'loanId': doc_ref.id,
        'createdAt': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        'success': True,
        'loan_id': doc_ref.id,
        'amount_disbursed': amount,
        'total_due': total_due,
        'due_date': due_date.isoformat(),
        'message': f'KES {amount} disbursed to your wallet. Due in {weeks} week(s).'
    }), 201


@student_finance_v6_bp.route('/loans/active/<student_uid>', methods=['GET'])
def get_active_student_loan(student_uid):
    """
    Returns active loan details with live overdue penalty calculation.
    """
    db = firestore.client()
    user_ref, user_doc, real_uid = resolve_user_ref(db, student_uid)
    if not user_doc or not user_doc.exists:
        return jsonify({'error': 'Student not found'}), 404

    active_query = db.collection('student_loans').where('student_uid', '==', real_uid).where('status', 'in', ['active', 'overdue']).limit(1).stream()
    loan = None
    for q in active_query:
        loan = q.to_dict()
        loan['id'] = q.id
        break

    if not loan:
        return jsonify({'success': True, 'has_active_loan': False}), 200

    now = datetime.datetime.now(datetime.timezone.utc)
    due_dt = loan.get('due_date')
    if due_dt and not isinstance(due_dt, datetime.datetime):
        due_dt = due_dt.to_datetime()

    amount = float(loan.get('amount', 0.0))
    base_fee = float(loan.get('base_fee', 0.0))
    is_overdue = False
    penalty_fee = 0.0
    days_left = 0

    if due_dt:
        if now > due_dt:
            is_overdue = True
            penalty_fee = amount * (OVERDUE_PENALTY_PCT / 100.0)
            # Update status in db if wasn't marked overdue
            if loan.get('status') != 'overdue':
                db.collection('student_loans').document(loan['id']).update({'status': 'overdue'})
                loan['status'] = 'overdue'
        else:
            days_left = max(0, (due_dt - now).days)

    current_total_due = amount + base_fee + penalty_fee
    loan['is_overdue'] = is_overdue
    loan['penalty_fee'] = penalty_fee
    loan['current_total_due'] = current_total_due
    loan['days_left'] = days_left
    loan['due_date_iso'] = due_dt.isoformat() if due_dt else None

    return jsonify({
        'success': True,
        'has_active_loan': True,
        'loan': loan
    }), 200


@student_finance_v6_bp.route('/loans/repay/student', methods=['POST'])
def student_repay_loan():
    """
    Student repays the active loan directly from their wallet balance.
    """
    data = request.json or {}
    loan_id = str(data.get('loan_id', '')).strip()

    db = firestore.client()
    loan_ref = db.collection('student_loans').document(loan_id)
    l_snap = loan_ref.get()
    if not l_snap.exists:
        return jsonify({'error': 'Loan not found'}), 404

    loan_data = l_snap.to_dict()
    if loan_data.get('status') == 'settled':
        return jsonify({'error': 'Loan is already settled'}), 400

    student_uid = loan_data.get('student_uid')
    u_ref = db.collection('users').document(student_uid)
    u_snap = u_ref.get()
    if not u_snap.exists:
        return jsonify({'error': 'Student not found'}), 404

    amount = float(loan_data.get('amount', 0.0))
    base_fee = float(loan_data.get('base_fee', 0.0))
    due_dt = loan_data.get('due_date')
    if due_dt and not isinstance(due_dt, datetime.datetime):
        due_dt = due_dt.to_datetime()

    now = datetime.datetime.now(datetime.timezone.utc)
    penalty_fee = amount * 0.02 if (due_dt and now > due_dt) else 0.0
    total_to_pay = amount + base_fee + penalty_fee

    current_wallet = float(u_snap.to_dict().get('walletBalance', 0.0))
    if current_wallet < total_to_pay:
        return jsonify({'error': f'Insufficient wallet balance (KES {current_wallet:.2f}) to pay KES {total_to_pay:.2f}'}), 400

    u_ref.update({
        'walletBalance': firestore.Increment(-total_to_pay),
        'wallet_balance': firestore.Increment(-total_to_pay),
        'repaid_loans_count': firestore.Increment(1)
    })

    loan_ref.update({
        'status': 'settled',
        'settled_amount': total_to_pay,
        'settled_by': 'student',
        'settled_at': firestore.SERVER_TIMESTAMP
    })

    db.collection('transactions').add({
        'userId': student_uid,
        'title': 'Student Loan Repayment',
        'amount': total_to_pay,
        'type': 'loan_settlement',
        'loanId': loan_id,
        'createdAt': firestore.SERVER_TIMESTAMP
    })

    return jsonify({
        'success': True,
        'repaid_amount': total_to_pay,
        'message': f'Loan of KES {total_to_pay:.2f} settled in full. Thank you!'
    }), 200


@student_finance_v6_bp.route('/loans/request_parent', methods=['POST'])
def request_parent_pay_loan():
    """
    Student sends an emergency assistance request for the parent to settle the loan.
    """
    data = request.json or {}
    loan_id = str(data.get('loan_id', '')).strip()

    db = firestore.client()
    loan_ref = db.collection('student_loans').document(loan_id)
    l_snap = loan_ref.get()
    if not l_snap.exists:
        return jsonify({'error': 'Loan not found'}), 404

    loan_data = l_snap.to_dict()
    student_uid = loan_data.get('student_uid')
    u_snap = db.collection('users').document(student_uid).get()
    parent_uid = loan_data.get('parent_uid') or (u_snap.to_dict().get('parentUid') if u_snap.exists else None)

    if not parent_uid:
        return jsonify({'error': 'No linked parent found for your account. Please link a parent first.'}), 400

    loan_ref.update({
        'parent_uid': parent_uid,
        'parent_settlement_requested': True,
        'parent_requested_at': firestore.SERVER_TIMESTAMP
    })

    # Send parent notification
    try:
        student_name = loan_data.get('student_name', 'Your student')
        _send_notification(
            parent_uid,
            'Student Loan Assistance Request 🎓',
            f'{student_name} requested assistance paying their KES {loan_data.get("amount", 0):.0f} study/food loan. Tap to review & settle.'
        )
    except Exception:
        pass

    return jsonify({
        'success': True,
        'message': 'Assistance request sent to parent. They can settle it directly from their Parent Dashboard.'
    }), 200


@student_finance_v6_bp.route('/loans/repay/parent', methods=['POST'])
def parent_repay_student_loan():
    """
    Parent settles the student's active loan from Parent family vault or wallet.
    """
    data = request.json or {}
    loan_id = str(data.get('loan_id', '')).strip()
    parent_uid = str(data.get('parent_uid', '')).strip()

    db = firestore.client()
    loan_ref = db.collection('student_loans').document(loan_id)
    l_snap = loan_ref.get()
    if not l_snap.exists:
        return jsonify({'error': 'Loan not found'}), 404

    loan_data = l_snap.to_dict()
    if loan_data.get('status') == 'settled':
        return jsonify({'error': 'Loan is already settled'}), 400

    amount = float(loan_data.get('amount', 0.0))
    base_fee = float(loan_data.get('base_fee', 0.0))
    due_dt = loan_data.get('due_date')
    if due_dt and not isinstance(due_dt, datetime.datetime):
        due_dt = due_dt.to_datetime()

    now = datetime.datetime.now(datetime.timezone.utc)
    penalty_fee = amount * 0.02 if (due_dt and now > due_dt) else 0.0
    total_to_pay = amount + base_fee + penalty_fee

    p_ref = db.collection('users').document(parent_uid)
    p_snap = p_ref.get()
    if not p_snap.exists:
        return jsonify({'error': 'Parent not found'}), 404

    p_data = p_snap.to_dict()
    p_wallet = float(p_data.get('walletBalance', 0.0) or 0.0)
    p_vault = float(p_data.get('vaultBalance', 0.0) or p_data.get('savingsBalance', 0.0) or 0.0)
    total_p_avail = p_wallet + p_vault

    if total_p_avail < total_to_pay:
        return jsonify({'error': f'Insufficient parent funds (KES {total_p_avail:.2f}) to settle KES {total_to_pay:.2f}'}), 400

    # Deduct from parent
    if p_wallet >= total_to_pay:
        p_ref.update({
            'walletBalance': firestore.Increment(-total_to_pay),
            'wallet_balance': firestore.Increment(-total_to_pay)
        })
    else:
        rem = total_to_pay - p_wallet
        p_ref.update({
            'walletBalance': 0.0,
            'wallet_balance': 0.0,
            'vaultBalance': firestore.Increment(-rem)
        })

    loan_ref.update({
        'status': 'settled',
        'settled_amount': total_to_pay,
        'settled_by': 'parent',
        'settled_by_uid': parent_uid,
        'settled_at': firestore.SERVER_TIMESTAMP
    })

    student_uid = loan_data.get('student_uid')
    try:
        db.collection('users').document(student_uid).update({
            'repaid_loans_count': firestore.Increment(1)
        })
    except Exception:
        pass
    # Notify student
    try:
        _send_notification(
            student_uid,
            'Loan Cleared by Parent! 🎉',
            f'Your parent has settled your KES {total_to_pay:.2f} study loan in full.'
        )
    except Exception:
        pass

    return jsonify({
        'success': True,
        'repaid_amount': total_to_pay,
        'message': f'Student loan of KES {total_to_pay:.2f} successfully cleared.'
    }), 200
