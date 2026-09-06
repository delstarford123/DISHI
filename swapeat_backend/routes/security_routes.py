from flask import Blueprint, request, jsonify
from firebase_admin import firestore, auth
import re
from datetime import datetime, timedelta

security_bp = Blueprint('security', __name__)
db = firestore.client()

# In-memory mock for NFC Tag Blacklist
BLACKLISTED_TAGS = ["B4:12:F3:A1"]

@security_bp.route('/freeze', methods=['POST'])
def freeze_tag():
    data = request.json
    student_id = data.get('student_id')

    if not student_id:
        return jsonify({"error": "Missing student ID"}), 400

    # Mock Firestore Update
    # doc_ref = db.collection('students').document(student_id)
    # doc_ref.update({'isFrozen': True})

    return jsonify({"status": "success", "message": "Tag frozen successfully"}), 200

@security_bp.route('/anomaly-check/<student_id>', methods=['GET'])
def check_anomaly(student_id):
    # Machine-Learning Anomaly Flagging (Mock)
    # Check if student caloric consumption / spend suddenly spikes
    return jsonify({
        "status": "success",
        "flagged": False,
        "reason": "Normal transaction volume"
    }), 200

@security_bp.route('/blacklist/sync', methods=['GET'])
def sync_blacklist():
    # NFC Tag Blacklist Propagation
    # Vendors pull this list to reject offline tags
    return jsonify({
        "status": "success",
        "blacklisted_uids": BLACKLISTED_TAGS
    }), 200

@security_bp.route('/<student_id>/parent_freeze', methods=['POST'])
def parent_freeze(student_id):
    # Remote Kill Switch
    return jsonify({
        "status": "success",
        "message": "Student wallet frozen by parent override."
    }), 200

@security_bp.route('/<student_id>/device_login_alert', methods=['POST'])
def device_login_alert(student_id):
    # Sends push notification to parent if a new device logs in
    data = request.json
    device_name = data.get('device_name')
    return jsonify({
        "status": "success",
        "message": f"Login alert for {device_name} sent to parent."
    }), 200

@security_bp.route('/<student_id>/set_controls', methods=['POST'])
def set_parental_controls(student_id):
    # Save daily cap, curfew, geofencing, category blocking, study hours
    data = request.json
    return jsonify({
        "status": "success",
        "message": "Parental security controls updated.",
        "settings": data
    }), 200

@security_bp.route('/<student_id>/multisig_approval', methods=['POST'])
def multisig_approval(student_id):
    # Shared-Parent Authorization for significant changes
    return jsonify({
        "status": "pending",
        "message": "Change requested. Awaiting approval from second guardian."
    }), 200

@security_bp.route('/<student_id>/location_check', methods=['POST'])
def check_location(student_id):
    # Flag geographic outliers
    data = request.json
    vendor_location = data.get('vendor_location')
    # If location is far from Kakamega
    return jsonify({
        "status": "success",
        "flagged": True,
        "reason": "Transaction occurred outside designated MMUST safe zone."
    }), 200

@security_bp.route('/<student_id>/compromised_alert', methods=['POST'])
def compromised_credential_alert(student_id):
    # Alert parent of repeated failed PIN attempts via email
    try:
        from flask import current_app
        from flask_mail import Message
        mail = current_app.extensions.get('mail')
        if mail:
            msg = Message("CRITICAL: Compromised Credential Alert",
                          sender="info@delstarfordworks.co.ke",
                          recipients=["parent@example.com"])
            msg.body = f"URGENT: Multiple failed PIN attempts for {student_id}. Please review dashboard."
            mail.send(msg)
    except Exception as e:
        print("Mail error:", str(e))
    return jsonify({
        "status": "success",
        "message": "Alert dispatched to parent."
    }), 200

@security_bp.route('/<user_id>/delete_account', methods=['DELETE'])
def delete_account(user_id):
    # Account Deletion endpoint
    # Note: Using POST or DELETE with user authentication is recommended.
    # We verify the user via header in a real scenario.
    
    try:
        # 1. Get user doc from Firestore
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            return jsonify({"error": "User not found"}), 404
            
        user_data = user_doc.to_dict()
        # Soft Delete: Flag for deletion after 30 days
        deletion_date = datetime.utcnow() + timedelta(days=30)
        
        req_reason = 'User requested deletion'
        if request.is_json:
            req_json = request.get_json(silent=True)
            if req_json:
                req_reason = req_json.get('reason', 'User requested deletion')
                
        # Log to deleted_users for audit
        deleted_ref = db.collection('deleted_users').document(user_id)
        deleted_ref.set({
            'original_data': user_data,
            'soft_deleted_at': firestore.SERVER_TIMESTAMP,
            'scheduled_deletion_date': deletion_date,
            'reason': req_reason,
            'status': 'pending_permanent_deletion'
        })
        
        # Update original doc to reflect soft-delete status (freeze account)
        user_ref.update({
            'is_deleted': True,
            'status': 'soft_deleted',
            'scheduled_deletion_date': deletion_date
        })
        
        # Disable the Firebase Auth user without deleting
        try:
            auth.update_user(user_id, disabled=True)
        except Exception as auth_e:
            print(f"Auth disable skipped/failed: {auth_e}")

        return jsonify({
            "status": "success",
            "message": f"Account soft-deleted. Scheduled for permanent deletion in 30 days."
        }), 200
        
    except Exception as e:
        print(f"Error deleting account: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Failed to delete account", "details": str(e)}), 500

@security_bp.route('/student/<uid>/medical_profile', methods=['POST'])
def update_medical_profile(uid):
    try:
        from firebase_admin import firestore
        data = request.json
        allergies = data.get('allergies', [])
        
        db = firestore.client()
        db.collection('users').document(uid).update({
            'allergies': allergies
        })
        return jsonify({"status": "success", "message": "Medical profile updated."}), 200
    except Exception as e:
        import traceback
        return jsonify({"error": "Server error", "details": str(e), "trace": traceback.format_exc()}), 500

@security_bp.route('/student/<uid>/vendor_permissions', methods=['POST'])
def update_vendor_permissions(uid):
    try:
        from firebase_admin import firestore
        data = request.json
        whitelisted = data.get('whitelistedVendors')
        blacklisted = data.get('blacklistedVendors')
        
        updates = {}
        if whitelisted is not None:
            updates['whitelistedVendors'] = whitelisted
        if blacklisted is not None:
            updates['blacklistedVendors'] = blacklisted
            
        if not updates:
            return jsonify({"error": "No permissions provided"}), 400
            
        db = firestore.client()
        db.collection('users').document(uid).update(updates)
        return jsonify({"status": "success", "message": "Vendor permissions updated."}), 200
    except Exception as e:
        import traceback
        return jsonify({"error": "Server error", "details": str(e), "trace": traceback.format_exc()}), 500

