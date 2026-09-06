from flask import Blueprint, jsonify
from firebase_admin import firestore
import datetime

fraud_bp = Blueprint('fraud_monitor_v4', __name__)

@fraud_bp.route('/velocity', methods=['GET'])
def get_velocity_monitor():
    """
    Wash Trading Velocity Monitor for Admin Dashboard.
    Calculates the 1:1 Ratio: Genuine Food Sales vs Top-Ups.
    """
    try:
        db = firestore.client()
        today = datetime.datetime.now(datetime.timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        
        # 1. Fetch all transactions for today (O(1) query)
        tx_query = db.collection('transactions').where('timestamp', '>=', today).stream()
        
        # Group transactions by vendor in memory
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
                
        # 2. Process all vendors and calculate risk
        vendors_ref = db.collection('vendors').stream()
        vendor_stats = []

        for v in vendors_ref:
            vendor_id = v.id
            vendor_data = v.to_dict()
            vendor_name = vendor_data.get('shopName', vendor_data.get('name', 'Unknown'))

            stats = vendor_tx_map.get(vendor_id, {'food_sales': 0.0, 'topups': 0.0, 'commissions': 0.0})
            food_sales = stats['food_sales']
            topups_processed = stats['topups']
            commissions_earned = stats['commissions']

            # Ratio logic: Food Sales vs Topups Processed
            ratio = food_sales / topups_processed if topups_processed > 0 else float('inf')
            
            # Risk Score calculation
            risk_score = 0
            if topups_processed > 0 and food_sales == 0:
                risk_score = 95 # Extremely high wash trading risk
            elif topups_processed > food_sales:
                risk_score = 75 # High risk
            elif topups_processed * 0.8 > food_sales:
                risk_score = 50 # Moderate risk
            else:
                risk_score = 10 # Normal

            vendor_stats.append({
                "vendorId": vendor_id,
                "vendorName": vendor_name,
                "foodSalesToday": food_sales,
                "topupsProcessedToday": topups_processed,
                "commissionsEarnedToday": commissions_earned,
                "ratio": round(ratio, 2) if ratio != float('inf') else "N/A",
                "riskScore": risk_score
            })

        # Sort by highest risk score
        vendor_stats.sort(key=lambda x: x['riskScore'], reverse=True)

        return jsonify({"status": "success", "data": vendor_stats}), 200

    except Exception as e:
        import traceback
        return jsonify({"error": str(e), "trace": traceback.format_exc()}), 500
