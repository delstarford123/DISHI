from flask import Blueprint, jsonify, request
from firebase_admin import firestore

system_bp = Blueprint('system_bp', __name__)

DEFAULT_CONFIG = {
    "latest_version_name": "1.0.3",
    "latest_version_code": 4,
    "min_supported_version_code": 3,
    "maintenance_mode": False,
    "maintenance_message": "DISHI is currently undergoing scheduled platform upgrades. We will be back online shortly.",
    "play_store_url": "https://play.google.com/store/apps/details?id=co.ke.delstarfordworks.dishi",
    "supported_api_versions": ["v1", "v2", "v3", "v4"],
    "release_notes": "Version 4: Automated C2B collections, enterprise fraud detection, employee onboardings & payroll management.",
    "emergency_notice": None
}

@system_bp.route('/version', methods=['GET'])
def get_app_version_config():
    """
    Returns the real-time version policy and maintenance status.
    Flutter apps query this on startup to determine if a force update or maintenance screen is required.
    """
    try:
        db = firestore.client()
        doc = db.collection('system_config').document('app_version').get()
        if doc.exists:
            data = doc.to_dict()
            config = {**DEFAULT_CONFIG, **data}
        else:
            # Seed default if document does not exist yet
            db.collection('system_config').document('app_version').set(DEFAULT_CONFIG)
            config = DEFAULT_CONFIG
        
        return jsonify({
            "status": "success",
            "data": config
        }), 200
    except Exception as e:
        # High-availability fallback: return default in-memory config so app never breaks
        return jsonify({
            "status": "fallback",
            "data": DEFAULT_CONFIG,
            "warning": str(e)
        }), 200

@system_bp.route('/health', methods=['GET'])
def system_health_check():
    """
    Lightweight health check for monitoring and automated ping services.
    """
    return jsonify({
        "status": "healthy",
        "service": "DISHI Backend Operating System",
        "supported_apis": ["v1", "v2", "v3", "v4", "v5", "v6"]
    }), 200
