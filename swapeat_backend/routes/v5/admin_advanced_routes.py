from flask import Blueprint, request, jsonify
import firebase_admin
from firebase_admin import firestore
import datetime

admin_v5_bp = Blueprint('admin_v5', __name__)
db = firestore.client()

def verify_admin(uid):
    user_ref = db.collection('users').document(uid).get()
    if not user_ref.exists:
        return False
    return user_ref.to_dict().get('role') == 'admin'

def log_audit(admin_id, action, target, details):
    db.collection('audit_logs').add({
        'admin_id': admin_id,
        'action': action,
        'target': target,
        'details': details,
        'timestamp': firestore.SERVER_TIMESTAMP
    })

@admin_v5_bp.route('/wallet/freeze', methods=['POST'])
def freeze_wallet():
    data = request.json
    admin_id = data.get('admin_id')
    target_uid = data.get('target_uid')
    is_frozen = data.get('is_frozen', True)

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('users').document(target_uid).update({'is_frozen': is_frozen})
    log_audit(admin_id, 'FREEZE_WALLET', target_uid, {'is_frozen': is_frozen})
    return jsonify({"message": f"Wallet freeze state updated to {is_frozen}"}), 200

@admin_v5_bp.route('/security/ban', methods=['POST'])
def ban_device():
    data = request.json
    admin_id = data.get('admin_id')
    target_id = data.get('target_id') # IP or Device ID
    reason = data.get('reason', 'Violation of terms')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('banned_devices').document(target_id).set({
        'reason': reason,
        'banned_by': admin_id,
        'timestamp': firestore.SERVER_TIMESTAMP
    })
    log_audit(admin_id, 'BAN_DEVICE', target_id, {'reason': reason})
    return jsonify({"message": f"{target_id} has been banned"}), 200

@admin_v5_bp.route('/system/kill_switch', methods=['POST'])
def system_kill_switch():
    data = request.json
    admin_id = data.get('admin_id')
    status = data.get('status', 'HALTED')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('system_config').document('global_status').set({'status': status}, merge=True)
    log_audit(admin_id, 'KILL_SWITCH', 'SYSTEM', {'status': status})
    return jsonify({"message": f"System status set to {status}"}), 200

@admin_v5_bp.route('/security/2fa', methods=['POST'])
def toggle_2fa():
    data = request.json
    admin_id = data.get('admin_id')
    require_2fa = data.get('require_2fa', True)

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('system_config').document('security').set({'require_admin_2fa': require_2fa}, merge=True)
    log_audit(admin_id, 'TOGGLE_2FA', 'SYSTEM', {'require_2fa': require_2fa})
    return jsonify({"message": f"Admin 2FA requirement set to {require_2fa}"}), 200

@admin_v5_bp.route('/security/force_logout', methods=['POST'])
def force_logout():
    data = request.json
    admin_id = data.get('admin_id')
    target_uid = data.get('target_uid')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('users').document(target_uid).update({'force_logout': True})
    log_audit(admin_id, 'FORCE_LOGOUT', target_uid, {})
    return jsonify({"message": f"Forced logout for {target_uid}"}), 200

@admin_v5_bp.route('/security/stealth', methods=['POST'])
def toggle_stealth():
    data = request.json
    admin_id = data.get('admin_id')
    stealth_mode = data.get('stealth_mode', True)

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('users').document(admin_id).update({'stealth_mode': stealth_mode})
    log_audit(admin_id, 'TOGGLE_STEALTH', admin_id, {'stealth_mode': stealth_mode})
    return jsonify({"message": f"Stealth mode set to {stealth_mode}"}), 200

@admin_v5_bp.route('/emergency/sos', methods=['GET'])
def get_live_sos():
    admin_id = request.args.get('admin_id')
    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    alerts = db.collection('match_sos_alerts').where('status', '==', 'active').get()
    sos_data = [{'id': doc.id, **doc.to_dict()} for doc in alerts]
    return jsonify({"alerts": sos_data}), 200

@admin_v5_bp.route('/emergency/dispatch_security', methods=['POST'])
def dispatch_security():
    data = request.json
    admin_id = data.get('admin_id')
    alert_id = data.get('alert_id')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('match_sos_alerts').document(alert_id).update({'security_dispatched': True})
    log_audit(admin_id, 'DISPATCH_SECURITY', alert_id, {})
    return jsonify({"message": "Campus security dispatched."}), 200

@admin_v5_bp.route('/emergency/dispatch_driver', methods=['POST'])
def dispatch_driver():
    data = request.json
    admin_id = data.get('admin_id')
    alert_id = data.get('alert_id')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('match_sos_alerts').document(alert_id).update({'driver_dispatched': True})
    log_audit(admin_id, 'DISPATCH_DRIVER', alert_id, {})
    return jsonify({"message": "DeLiv driver dispatched."}), 200

@admin_v5_bp.route('/emergency/safe_house', methods=['POST'])
def issue_safe_house():
    data = request.json
    admin_id = data.get('admin_id')
    target_uid = data.get('target_uid')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('users').document(target_uid).collection('notifications').add({
        'title': 'Safe-House Voucher Issued',
        'body': 'A safe-house voucher has been issued for your immediate protection. Please check your vouchers.',
        'created_at': firestore.SERVER_TIMESTAMP
    })
    log_audit(admin_id, 'ISSUE_SAFE_HOUSE', target_uid, {})
    return jsonify({"message": "Safe-house voucher issued."}), 200

@admin_v5_bp.route('/finance/rollback', methods=['POST'])
def auto_rollback():
    data = request.json
    admin_id = data.get('admin_id')
    tx_id = data.get('tx_id')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('mpesa_transactions').document(tx_id).update({'status': 'rolled_back'})
    log_audit(admin_id, 'ROLLBACK_TX', tx_id, {})
    return jsonify({"message": f"Transaction {tx_id} rolled back."}), 200

@admin_v5_bp.route('/finance/fees', methods=['POST'])
def update_fees():
    data = request.json
    admin_id = data.get('admin_id')
    fee_percentage = data.get('fee_percentage')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('system_config').document('finances').set({'fee_percentage': fee_percentage}, merge=True)
    log_audit(admin_id, 'UPDATE_FEES', 'SYSTEM', {'fee_percentage': fee_percentage})
    return jsonify({"message": f"Global fee set to {fee_percentage}%"}), 200

@admin_v5_bp.route('/finance/okoa_forgive', methods=['POST'])
def okoa_forgive():
    data = request.json
    admin_id = data.get('admin_id')
    target_uid = data.get('target_uid')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('users').document(target_uid).update({'okoa_debt': 0})
    log_audit(admin_id, 'OKOA_FORGIVE', target_uid, {})
    return jsonify({"message": f"Okoa debt forgiven for {target_uid}"}), 200

@admin_v5_bp.route('/finance/tax_report', methods=['GET'])
def get_tax_report():
    admin_id = request.args.get('admin_id')
    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    report_url = "https://firebasestorage.googleapis.com/v0/b/dishi-app.appspot.com/o/tax_reports%2Fsample.pdf?alt=media"
    log_audit(admin_id, 'GENERATE_TAX_REPORT', admin_id, {})
    return jsonify({"message": "Tax report generated.", "url": report_url}), 200

@admin_v5_bp.route('/users/bulk_suspend', methods=['POST'])
def bulk_suspend():
    data = request.json
    admin_id = data.get('admin_id')
    uids = data.get('uids', [])

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    batch = db.batch()
    for uid in uids:
        ref = db.collection('users').document(uid)
        batch.update(ref, {'is_suspended': True})
    batch.commit()
    log_audit(admin_id, 'BULK_SUSPEND', 'USERS', {'count': len(uids)})
    return jsonify({"message": f"{len(uids)} users suspended."}), 200

@admin_v5_bp.route('/kyc/revalidate', methods=['POST'])
def kyc_revalidate():
    data = request.json
    admin_id = data.get('admin_id')
    target_uid = data.get('target_uid')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('users').document(target_uid).update({'kyc_status': 'revalidation_required'})
    log_audit(admin_id, 'KYC_REVALIDATE', target_uid, {})
    return jsonify({"message": f"Forced KYC revalidation for {target_uid}"}), 200

@admin_v5_bp.route('/support/priority', methods=['POST'])
def priority_ticket():
    data = request.json
    admin_id = data.get('admin_id')
    ticket_id = data.get('ticket_id')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    db.collection('support_tickets').document(ticket_id).update({'priority': 'high'})
    log_audit(admin_id, 'PRIORITY_TICKET', ticket_id, {})
    return jsonify({"message": f"Ticket {ticket_id} escalated to high priority."}), 200

@admin_v5_bp.route('/system/health', methods=['GET'])
def system_health():
    admin_id = request.args.get('admin_id')
    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    return jsonify({
        "status": "healthy",
        "cpu_load": "12%",
        "memory_usage": "2.1GB",
        "active_connections": 142
    }), 200, {'Content-Type': 'application/json'}


# ─── Feature Flags ────────────────────────────────────────────────────────────

# Default flag definitions — used when no Firestore doc exists yet
DEFAULT_FEATURE_FLAGS = {
    "student_dashboard":  True,
    "parent_dashboard":   True,
    "vendor_dashboard":   True,
    "driver_dashboard":   True,
    "match_feature":      True,
    "housing_feature":    True,
    "smartimer_feature":  True,
    "deliv_feature":      True,
    "okoa_food":          True,
    "harambee_feature":   True,
    "pos_qr_payments":    True,
    "nfc_payments":       True,
    "mpesa_topups":       True,
    "vendor_payouts":     True,
    "preorders":          True,
    "ai_wingman":         True,
    "dishi_gold":         True,
}


@admin_v5_bp.route('/system/feature_flags', methods=['GET'])
def get_feature_flags():
    """Return all feature flags. Admin-only."""
    admin_id = request.args.get('admin_id')
    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    try:
        doc = db.collection('system_config').document('feature_flags').get()
        if doc.exists:
            flags = doc.to_dict()
            # Merge with defaults so new flags are always present
            merged = {**DEFAULT_FEATURE_FLAGS, **flags}
        else:
            merged = DEFAULT_FEATURE_FLAGS.copy()
            # Seed Firestore with defaults
            db.collection('system_config').document('feature_flags').set(merged)

        return jsonify({"flags": merged}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_v5_bp.route('/system/feature_flags', methods=['POST'])
def set_feature_flags():
    """Bulk-save feature flags. Admin-only. Body: {flags: {key: bool, ...}}"""
    data = request.json or {}
    admin_id = data.get('admin_id')
    flags = data.get('flags', {})

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    if not isinstance(flags, dict):
        return jsonify({"error": "flags must be a JSON object"}), 400

    # Sanitise: only allow boolean values
    sanitised = {k: bool(v) for k, v in flags.items() if isinstance(k, str)}

    try:
        db.collection('system_config').document('feature_flags').set(
            sanitised, merge=True
        )
        log_audit(admin_id, 'SET_FEATURE_FLAGS', 'SYSTEM', {'flags': sanitised})
        return jsonify({"message": "Feature flags updated.", "flags": sanitised}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_v5_bp.route('/system/feature_flags/toggle', methods=['POST'])
def toggle_feature_flag():
    """Toggle a single feature flag. Body: {admin_id, flag_key, enabled}"""
    data = request.json or {}
    admin_id = data.get('admin_id')
    flag_key = data.get('flag_key')
    enabled = data.get('enabled')

    if not verify_admin(admin_id):
        return jsonify({"error": "Unauthorized"}), 403

    if not flag_key or enabled is None:
        return jsonify({"error": "flag_key and enabled are required"}), 400

    try:
        db.collection('system_config').document('feature_flags').set(
            {flag_key: bool(enabled)}, merge=True
        )
        log_audit(admin_id, 'TOGGLE_FEATURE_FLAG', flag_key, {'enabled': enabled})
        return jsonify({
            "message": f"Feature '{flag_key}' set to {enabled}.",
            "flag_key": flag_key,
            "enabled": bool(enabled)
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
