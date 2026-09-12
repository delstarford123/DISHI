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

@cron_bp.route('/harambee-payouts', methods=['POST', 'GET'])
def harambee_payouts():
    auth_header = request.headers.get('Authorization')
    expected_secret = os.getenv('CRON_SECRET', 'swapeat-cron-secret-2024')
    
    if auth_header != f"Bearer {expected_secret}" and request.args.get('secret') != expected_secret:
        return jsonify({"error": "Unauthorized"}), 401

    db = firestore.client()
    now = datetime.now(timezone.utc)
    cutoff_time = now - timedelta(minutes=70)

    from .mpesa_routes import generate_access_token
    import requests

    try:
        # Query for campaigns older than 70 mins with payout_status pending
        campaigns_ref = db.collection('harambee_campaigns')\
            .where('payout_status', '==', 'pending')\
            .stream()

        processed = 0
        for doc in campaigns_ref:
            campaign = doc.to_dict()
            created_at = campaign.get('createdAt')
            
            if not created_at:
                continue
                
            if hasattr(created_at, 'timestamp'):
                created_ts = created_at.timestamp()
            else:
                created_ts = created_at
                
            if created_ts > cutoff_time.timestamp():
                continue # not yet 70 mins old
                
            raised = float(campaign.get('raised', 0))
            if raised <= 0:
                doc.reference.update({'payout_status': 'no_funds'})
                continue

            payout_method = campaign.get('payout_method')
            payout_details = campaign.get('payout_details')
            
            if not payout_method or not payout_details:
                doc.reference.update({'payout_status': 'missing_details'})
                continue
                
            # Prevent duplicate processing
            doc.reference.update({'payout_status': 'processing'})
            
            access_token = generate_access_token()
            if not access_token:
                doc.reference.update({'payout_status': 'failed_auth'})
                continue
            
            headers = {
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            }
            
            env = os.getenv('MPESA_ENV', 'sandbox').lower()
            base_url = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"
            
            success = False
            response_data = None
            
            if payout_method == 'MPESA':
                # Standard B2C Payload
                api_url = f"{base_url}/mpesa/b2c/v3/paymentrequest"
                phone_number = payout_details.strip()
                if phone_number.startswith('0'):
                    phone_number = '254' + phone_number[1:]
                elif phone_number.startswith('+'):
                    phone_number = phone_number[1:]
                    
                payload = {
                    "InitiatorName": os.getenv('DARAJA_INITIATOR_NAME', ''),
                    "SecurityCredential": os.getenv('DARAJA_SECURITY_CREDENTIAL', ''),
                    "CommandID": "BusinessPayment",
                    "Amount": int(raised),
                    "PartyA": os.getenv('MPESA_SHORTCODE', ''),
                    "PartyB": phone_number,
                    "Remarks": f"Harambee Payout for {campaign.get('title', 'Campaign')}",
                    "QueueTimeOutURL": os.getenv('DARAJA_B2C_TIMEOUT_URL', 'https://swapeatbackend.vercel.app/api/v1/mpesa/b2c_timeout'),
                    "ResultURL": os.getenv('DARAJA_B2C_RESULT_URL', 'https://swapeatbackend.vercel.app/api/v1/mpesa/b2c_result'),
                    "Occasion": "Harambee Payout"
                }
                
                try:
                    res = requests.post(api_url, json=payload, headers=headers, timeout=15)
                    response_data = res.json()
                    if res.status_code == 200 and 'ConversationID' in response_data:
                        success = True
                except Exception as e:
                    response_data = {"error": str(e)}
                    
            elif payout_method in ['PAYBILL', 'BUY_GOODS']:
                # Standard B2B Payload
                api_url = f"{base_url}/mpesa/b2b/v1/paymentrequest"
                # Parse Paybill & Account (e.g., "123456 Account123" or just "123456" for Buy Goods)
                parts = payout_details.split()
                party_b = parts[0]
                account_ref = parts[1] if len(parts) > 1 else party_b
                
                command_id = "BusinessPayBill" if payout_method == 'PAYBILL' else "BusinessBuyGoods"
                
                payload = {
                    "Initiator": os.getenv('DARAJA_INITIATOR_NAME', ''),
                    "SecurityCredential": os.getenv('DARAJA_SECURITY_CREDENTIAL', ''),
                    "CommandID": command_id,
                    "SenderIdentifierType": "4",
                    "RecieverIdentifierType": "4",
                    "Amount": int(raised),
                    "PartyA": os.getenv('MPESA_SHORTCODE', ''),
                    "PartyB": party_b,
                    "AccountReference": account_ref[:12],
                    "Remarks": f"Harambee Payout for {campaign.get('title', 'Campaign')}",
                    "QueueTimeOutURL": os.getenv('DARAJA_B2B_TIMEOUT_URL', 'https://swapeatbackend.vercel.app/api/v1/mpesa/b2b_timeout'),
                    "ResultURL": os.getenv('DARAJA_B2B_RESULT_URL', 'https://swapeatbackend.vercel.app/api/v1/mpesa/b2b_result')
                }
                
                try:
                    res = requests.post(api_url, json=payload, headers=headers, timeout=15)
                    response_data = res.json()
                    if res.status_code == 200 and 'ConversationID' in response_data:
                        success = True
                except Exception as e:
                    response_data = {"error": str(e)}
            
            if success:
                doc.reference.update({
                    'payout_status': 'completed',
                    'payout_response': response_data,
                    'payout_time': firestore.SERVER_TIMESTAMP
                })
            else:
                # Fallback to pending or failed based on logic
                doc.reference.update({
                    'payout_status': 'failed',
                    'payout_response': response_data
                })
            processed += 1

        return jsonify({"status": "success", "processed": processed}), 200

    except Exception as e:
        import traceback
        print(f"Error in harambee payouts cron: {traceback.format_exc()}")
        return jsonify({"error": str(e)}), 500
