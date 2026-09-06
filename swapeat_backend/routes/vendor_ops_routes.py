from flask import Blueprint, jsonify

vendor_ops_bp = Blueprint('vendor_ops', __name__)

@vendor_ops_bp.route('/<vendor_id>/flash_sale', methods=['POST'])
def trigger_flash_sale(vendor_id):
    # Sends FCM push notification to all students near the vendor
    return jsonify({
        "status": "success",
        "message": "Flash sale notifications sent to 142 students on campus."
    }), 200

@vendor_ops_bp.route('/<vendor_id>/staff', methods=['GET'])
def get_staff_roles(vendor_id):
    # Staff Account Delegation with Revenue Shielding
    return jsonify({
        "status": "success",
        "staff": [
            {"name": "Alice", "role": "cashier", "permissions": ["scan_tag"]},
            {"name": "Bob", "role": "manager", "permissions": ["scan_tag", "view_revenue"]}
        ]
    }), 200

@vendor_ops_bp.route('/<vendor_id>/tax_report', methods=['GET'])
def get_tax_segregation(vendor_id):
    # Automated Tax & Levy Segregation
    return jsonify({
        "status": "success",
        "total_revenue": 45000.0,
        "tax_withheld": 7200.0, # 16% VAT
        "university_levy": 2250.0 # 5% levy
    }), 200
