from flask import Blueprint, jsonify, request
from firebase_admin import firestore
from firebase_admin import auth
import os
from datetime import datetime, timezone, timedelta
from .email_utils import monthly_nutrition_report_email
from .auth_pin_routes import _send_html_email

cron_bp = Blueprint('cron_bp', __name__)

@cron_bp.route('/cleanup-accounts', methods=['POST', 'GET'])
def cleanup_accounts():
    # Basic security using a CRON_SECRET environment variable
    auth_header = request.headers.get('Authorization')
    expected_secret = os.getenv('CRON_SECRET', 'swapeat-cron-secret-2024')
    
    if auth_header != f"Bearer {expected_secret}" and request.args.get('secret') != expected_secret:
        return jsonify({"error": "Unauthorized"}), 401

    db = firestore.client()
    now = datetime.now(timezone.utc)

    try:
        # Query for users pending deletion where scheduled_deletion_date is in the past
        deleted_users_ref = db.collection('deleted_users')\
            .where('status', '==', 'pending_permanent_deletion')\
            .where('scheduled_deletion_date', '<=', now)\
            .stream()

        count = 0
        for doc in deleted_users_ref:
            user_id = doc.id
            
            # 1. Hard Delete from users collection
            db.collection('users').document(user_id).delete()
            
            # 2. Update audit status
            doc.reference.update({
                'status': 'hard_deleted',
                'hard_deleted_at': firestore.SERVER_TIMESTAMP
            })
            
            # 3. Delete from Firebase Auth
            try:
                auth.delete_user(user_id)
            except Exception as auth_e:
                print(f"Auth deletion skipped/failed for {user_id}: {auth_e}")
                
            count += 1
            
        return jsonify({
            "status": "success", 
            "message": f"Successfully hard-deleted {count} accounts."
        }), 200

    except Exception as e:
        print(f"Error during cron cleanup: {e}")
        return jsonify({"error": str(e)}), 500

@cron_bp.route('/nutrition-reports', methods=['POST', 'GET'])
def send_nutrition_reports():
    auth_header = request.headers.get('Authorization')
    expected_secret = os.getenv('CRON_SECRET', 'swapeat-cron-secret-2024')
    
    if auth_header != f"Bearer {expected_secret}" and request.args.get('secret') != expected_secret:
        return jsonify({"error": "Unauthorized"}), 401

    db = firestore.client()
    now = datetime.now(timezone.utc)
    one_month_ago = now - timedelta(days=30)
    month_name = now.strftime('%B %Y')

    try:
        # Get all students with linked parents
        students_ref = db.collection('users').where('isOffline', '==', True).stream()
        
        emails_sent = 0
        for student_doc in students_ref:
            student = student_doc.to_dict()
            parent_uid = student.get('parentUid')
            if not parent_uid: continue
            
            parent_doc = db.collection('users').document(parent_uid).get()
            if not parent_doc.exists: continue
            
            parent_email = parent_doc.to_dict().get('email')
            if not parent_email: continue

            # Query transactions in the last month
            tx_ref = db.collection('transactions')\
                .where('studentId', '==', student_doc.id)\
                .where('timestamp', '>=', one_month_ago)\
                .stream()

            total_items = 0
            carbs = 0
            protein = 0
            sugar = 0

            for tx_doc in tx_ref:
                items = tx_doc.to_dict().get('items', [])
                for item in items:
                    cat = str(item.get('category', '')).lower()
                    qty = item.get('qty', 1)
                    total_items += qty
                    if cat == 'meal':
                        carbs += qty
                        protein += qty
                    elif cat == 'snack' or cat == 'sugar':
                        sugar += qty

            if total_items > 0:
                carbs_pct = int((carbs / total_items) * 100)
                protein_pct = int((protein / total_items) * 100)
                sugar_pct = int((sugar / total_items) * 100)
                
                macros = {'carbs': carbs_pct, 'protein': protein_pct, 'sugar': sugar_pct}
                subject, html_body = monthly_nutrition_report_email(student.get('displayName', 'Student'), month_name, macros)
                
                _send_html_email(parent_email, subject, html_body)
                emails_sent += 1

        return jsonify({
            "status": "success", 
            "message": f"Successfully sent {emails_sent} nutrition reports."
        }), 200

    except Exception as e:
        import traceback
        print(f"Error sending nutrition reports: {traceback.format_exc()}")
        return jsonify({"error": str(e)}), 500
