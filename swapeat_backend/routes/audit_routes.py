from flask import Blueprint, request, jsonify
from datetime import datetime
import json

audit_bp = Blueprint('audit', __name__)

# In a real scenario, this would write to a secure, append-only datastore or BigQuery
AUDIT_LOG = []

@audit_bp.route('/log', methods=['POST'])
def log_action():
    data = request.json
    
    action = data.get('action')
    actor_id = data.get('actor_id')
    target_id = data.get('target_id')
    details = data.get('details', {})

    if not all([action, actor_id]):
        return jsonify({"error": "Missing parameters"}), 400

    log_entry = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "action": action,
        "actor_id": actor_id,
        "target_id": target_id,
        "details": details,
        "ip_address": request.remote_addr
    }

    AUDIT_LOG.append(log_entry)
    
    # Example: Immutable ledger append log (simulated)
    # db.collection('audit_trails').add(log_entry)

    return jsonify({"status": "success", "logged": True}), 201

@audit_bp.route('/logs', methods=['GET'])
def get_logs():
    return jsonify({"logs": AUDIT_LOG}), 200
