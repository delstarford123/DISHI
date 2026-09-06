from flask import Blueprint, jsonify, request

engagement_bp = Blueprint('engagement', __name__)

@engagement_bp.route('/<student_id>/care_package', methods=['POST'])
def send_care_package(student_id):
    # Generates a redemption voucher for a specific vendor item
    data = request.json
    item = data.get('item')
    vendor_id = data.get('vendor_id')
    return jsonify({
        "status": "success",
        "message": f"Care package voucher for {item} sent to student.",
        "voucher_code": "CP-X98V-22M"
    }), 200

@engagement_bp.route('/<student_id>/okoa_cosign', methods=['POST'])
def cosign_okoa(student_id):
    # Parent approval for student micro-credit
    return jsonify({
        "status": "success",
        "message": "Okoa Food micro-credit co-signed."
    }), 200

@engagement_bp.route('/<student_id>/dispute', methods=['POST'])
def submit_dispute(student_id):
    # Routes to SWAPEAT Admin Dashboard
    data = request.json
    reason = data.get('reason')
    tx_id = data.get('tx_id')
    return jsonify({
        "status": "success",
        "message": f"Dispute ticket opened for TX {tx_id}. Admin will review."
    }), 200

@engagement_bp.route('/<student_id>/sign_contract', methods=['POST'])
def sign_contract(student_id):
    # E-Sign Financial Contract
    return jsonify({
        "status": "success",
        "message": "Financial contract digitally signed."
    }), 200

@engagement_bp.route('/<student_id>/pitch_vendors', methods=['POST'])
def pitch_vendors(student_id):
    # Student selects 5 favorite vendors and pitches to parent
    data = request.json
    vendors = data.get('vendors', [])
    return jsonify({
        "status": "success",
        "message": f"Pitch for {len(vendors)} vendors sent to parent for Safe Harbor approval."
    }), 200

@engagement_bp.route('/<student_id>/request_funds', methods=['POST'])
def request_funds(student_id):
    data = request.json
    justification_category = data.get('justification_category')
    amount = data.get('amount')
    vendor_id = data.get('vendor_id')
    # Reframed as a "Pitch" for extra funds
    return jsonify({
        "status": "success",
        "message": f"Pitch for Ksh {amount} sent to parent. Category: {justification_category}"
    }), 200

@engagement_bp.route('/<student_id>/savings_match', methods=['POST'])
def match_savings(student_id):
    # Parent matches student savings
    return jsonify({
        "status": "success",
        "message": "Savings matched successfully."
    }), 200
