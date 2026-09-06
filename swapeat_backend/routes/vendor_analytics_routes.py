from flask import Blueprint, jsonify

vendor_analytics_bp = Blueprint('vendor_analytics', __name__)

@vendor_analytics_bp.route('/<vendor_id>/inventory_balance', methods=['GET'])
def get_inventory_balance(vendor_id):
    # Mock data for Real-Time Automated Kitchen Inventory Balancing
    mock_data = {
        "status": "success",
        "vendor_id": vendor_id,
        "inventory": [
            {"item": "Ugali Flour", "remaining_kg": 45.5, "status": "adequate"},
            {"item": "Beef", "remaining_kg": 5.2, "status": "low_stock"},
            {"item": "Beans", "remaining_kg": 20.0, "status": "adequate"}
        ],
        "recommendations": [
            "Order more Beef before 2:00 PM peak."
        ]
    }
    return jsonify(mock_data), 200

@vendor_analytics_bp.route('/<vendor_id>/sales_matrix', methods=['GET'])
def get_sales_matrix(vendor_id):
    # Mock data for dynamic happy hour pricing stats
    return jsonify({
        "status": "success",
        "total_revenue_today": 45000.0,
        "peak_hour": "12:00 - 13:00",
        "suggested_happy_hour": "15:00 - 16:00"
    }), 200
