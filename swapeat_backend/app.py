from flask import Flask, jsonify, render_template, request, redirect
from dotenv import load_dotenv
import os
import json
import firebase_admin
from firebase_admin import credentials

load_dotenv()

app = Flask(__name__)

# ─── Flask-Mail (optional – gracefully skipped if config is missing) ───────────
# Rule: Never import flask_mail at module level
mail = None

def init_mail(app):
    global mail
    try:
        from flask_mail import Mail
        mail_port_raw = os.getenv('MAIL_PORT', '465')
        mail_port = int(mail_port_raw) if mail_port_raw and mail_port_raw.strip().isdigit() else 465

        app.config['MAIL_SERVER'] = os.getenv('MAIL_SERVER', '')
        app.config['MAIL_PORT'] = mail_port
        app.config['MAIL_USE_TLS'] = os.getenv('MAIL_USE_TLS', 'False').lower() in ['true', '1', 't']
        app.config['MAIL_USE_SSL'] = os.getenv('MAIL_USE_SSL', 'True').lower() in ['true', '1', 't']
        app.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME', '')
        app.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD', '')

        if os.getenv('MAIL_SERVER'):
            mail = Mail(app)
    except Exception as e:
        print(f"Flask-Mail not initialised (non-fatal): {e}")

init_mail(app)

# ─── Firebase Admin ─────────────────────────────────────────────────────────────
firebase_init_error = None
try:
    firebase_creds_env = os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON')
    if firebase_creds_env:
        try:
            creds_dict = json.loads(firebase_creds_env)
            # Vercel sometimes escapes newlines in env vars — fix it
            if 'private_key' in creds_dict:
                creds_dict['private_key'] = creds_dict['private_key'].replace('\\n', '\n')
            cred = credentials.Certificate(creds_dict)
        except json.JSONDecodeError:
            raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON is set but is not valid JSON. Ensure you haven't put a file path in this variable.")
    else:
        # Fallback to local file for development
        local_key_parent = os.path.join(os.path.dirname(__file__), '..', 'ServiceAccountKey.json')
        local_key_current = os.path.join(os.path.dirname(__file__), 'ServiceAccountKey.json')
        
        if os.path.exists(local_key_parent):
            cred = credentials.Certificate(local_key_parent)
        elif os.path.exists(local_key_current):
            cred = credentials.Certificate(local_key_current)
        else:
            raise FileNotFoundError(f"Could not find ServiceAccountKey.json in {os.path.abspath(local_key_parent)} or {os.path.abspath(local_key_current)}")

    firebase_admin.initialize_app(cred)
    print("Firebase Admin initialised successfully.")
except Exception as e:
    import traceback
    firebase_init_error = str(e) + "\n" + traceback.format_exc()
    print(f"CRITICAL: Firebase init failed — {e}")

# ─── Register Blueprints ─────────────────────────────────────────────────────────
from routes.transaction_routes import transaction_bp
from routes.security_routes import security_bp
from routes.audit_routes import audit_bp
from routes.vendor_analytics_routes import vendor_analytics_bp
from routes.budget_routes import budget_bp
from routes.vendor_ops_routes import vendor_ops_bp
from routes.ussd_routes import ussd_bp
from routes.mpesa_routes import mpesa_bp
from routes.analytics_routes import analytics_bp
from routes.engagement_routes import engagement_bp
from routes.gamification_routes import gamification_bp
from routes.support_routes import support_bp
from routes.vendor_advanced import vendor_advanced_bp
from routes.invite_routes import invite_bp
from routes.admin_routes import admin_bp
from routes.v2.housing_routes import housing_v2_bp
from routes.v2.whatsapp_bot_routes import whatsapp_bot_bp
from routes.v2.marketplace_routes import marketplace_v2_bp
from routes.v2.deliv_routes import deliv_v2_bp
from routes.v2.match_routes import match_v2_bp
from routes.fundi_routes import fundi_bp
from routes.v3 import v3_bp

from routes.v4.vendor_agent_routes import vendor_agent_bp
from routes.v4.fraud_monitor_routes import fraud_bp
from routes.v5.admin_advanced_routes import admin_v5_bp
from routes.auth_pin_routes import auth_pin_bp
from routes.cron_routes import cron_bp
from routes.social_routes import social_bp
from routes.allowance_routes import allowance_bp
from routes.subscription_routes import subscription_bp
from routes.gamification_v2_routes import gamification_v2_bp
from routes.community_routes import community_bp
from routes.vendor_finance_routes import vendor_finance_bp
from routes.vendor_operations_routes import vendor_operations_bp
from routes.vendor_sales_routes import vendor_sales_bp
from routes.vendor_management_routes import vendor_management_bp
from routes.match_core_routes import match_core_bp
from routes.match_interactive_routes import match_interactive_bp
from routes.match_campus_routes import match_campus_bp
from routes.match_premium_routes import match_premium_bp
from routes.events_routes import events_bp
from routes.virtual_card_routes import card_bp
from routes.vibe_routes import vibe_bp
from routes.v6.campus_gigs_routes import campus_gigs_v6_bp




app.register_blueprint(transaction_bp,      url_prefix='/api/v1/transaction')
app.register_blueprint(security_bp,         url_prefix='/api/v1/security')
app.register_blueprint(audit_bp,            url_prefix='/api/v1/audit')
app.register_blueprint(vendor_analytics_bp, url_prefix='/api/v1/vendor')
app.register_blueprint(budget_bp,           url_prefix='/api/v1/budget')
app.register_blueprint(vendor_ops_bp,       url_prefix='/api/v1/vendor_ops')
app.register_blueprint(ussd_bp,             url_prefix='/api/v1/ussd')
app.register_blueprint(mpesa_bp,            url_prefix='/api/v1/mpesa')
app.register_blueprint(analytics_bp,        url_prefix='/api/v1/analytics')
app.register_blueprint(engagement_bp,       url_prefix='/engagement')
app.register_blueprint(gamification_bp,     url_prefix='/gamification')
app.register_blueprint(support_bp,          url_prefix='/api/v1/support')
app.register_blueprint(vendor_advanced_bp,  url_prefix='/api/v1/vendor_advanced')
app.register_blueprint(invite_bp,           url_prefix='/invite')
app.register_blueprint(admin_bp,            url_prefix='/api/v1/admin')
app.register_blueprint(housing_v2_bp,       url_prefix='/api/v2/housing')
app.register_blueprint(deliv_v2_bp,         url_prefix='/api/v2/deliv')
app.register_blueprint(whatsapp_bot_bp,     url_prefix='/v2')
app.register_blueprint(marketplace_v2_bp,   url_prefix='/api/v2/marketplace')
app.register_blueprint(match_v2_bp,         url_prefix='/api/v2/match')
app.register_blueprint(fundi_bp,            url_prefix='/api/v1/fundi')
app.register_blueprint(v3_bp)
app.register_blueprint(vendor_agent_bp,     url_prefix='/api/v4/vendor')
app.register_blueprint(fraud_bp,            url_prefix='/api/v4/fraud')
app.register_blueprint(admin_v5_bp,         url_prefix='/api/v5/admin')
app.register_blueprint(auth_pin_bp,         url_prefix='/api/v1/auth/pin')
app.register_blueprint(cron_bp,             url_prefix='/cron')
app.register_blueprint(social_bp,           url_prefix='/api/v1/social')
app.register_blueprint(allowance_bp,        url_prefix='/api/v1/allowance')
app.register_blueprint(subscription_bp,     url_prefix='/api/v1/subscriptions')
app.register_blueprint(gamification_v2_bp,  url_prefix='/api/v1/gamification_v2')
app.register_blueprint(community_bp,        url_prefix='/api/v1/community')
app.register_blueprint(vendor_finance_bp,   url_prefix='/api/v1/vendor_finance')
app.register_blueprint(vendor_operations_bp,url_prefix='/api/v1/vendor_operations')
app.register_blueprint(vendor_sales_bp,     url_prefix='/api/v1/vendor_sales')
app.register_blueprint(vendor_management_bp,url_prefix='/api/v1/vendor_management')
app.register_blueprint(match_core_bp,       url_prefix='/api/v1/match_core')
app.register_blueprint(match_interactive_bp,url_prefix='/api/v1/match_interactive')
app.register_blueprint(match_campus_bp,     url_prefix='/api/v1/match_campus')
app.register_blueprint(match_premium_bp,    url_prefix='/api/v1/match_premium')
app.register_blueprint(events_bp)
app.register_blueprint(card_bp)
app.register_blueprint(vibe_bp, url_prefix='/api/vibe')
app.register_blueprint(campus_gigs_v6_bp,   url_prefix='/api/v6/campus_gigs')



# ─── Health & Debug routes ──────────────────────────────────────────────────────
@app.route('/health')
def health_check():
    return jsonify({
        "status": "healthy",
        "version": "2.0.0",
        "firebase_ok": firebase_init_error is None,
    }), 200

@app.route('/debug-firebase')
def debug_firebase():
    return jsonify({
        "env_var_exists": bool(os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON')),
        "env_var_preview": os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON', '')[:20] or None,
        "init_error": firebase_init_error,
    })

# ─── Pitch Page / About ─────────────────────────────────────────────────────────
@app.route('/about')
def about():
    return render_template('about.html')

@app.route('/harambee/<string:code>')
def harambee_shortlink(code):
    return redirect(f"/fund?campaign={code}&dishi_id={code}")

@app.route('/fund')
def harambee_fund():
    dishi_id = request.args.get('dishi_id')
    campaign_id = request.args.get('campaign')
    dest = request.args.get('dest', 'walletBalance')
    
    if not dishi_id and not campaign_id:
        return render_template('harambee.html', error="Invalid or missing link.", student_name="Student", user_id="", dest=dest)
    
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        user_doc = None
        campaign_data = None
        
        if campaign_id:
            camp_doc = db.collection('harambee_campaigns').document(campaign_id).get()
            if camp_doc.exists:
                campaign_data = camp_doc.to_dict()
                campaign_data['id'] = camp_doc.id
                
                student_id = campaign_data.get('studentId')
                if student_id:
                    user_doc = db.collection('users').document(student_id).get()
                    if not user_doc.exists:
                        user_doc = None
                        
        if not user_doc and dishi_id:
            # First check by document ID directly
            doc = db.collection('users').document(dishi_id).get()
            if doc.exists:
                user_doc = doc
            else:
                # Fallback to dishiId
                users_ref = db.collection('users').where('dishiId', '==', dishi_id).limit(1).get()
                if not users_ref:
                    # Fallback to legacy swapeatCode
                    users_ref = db.collection('users').where('swapeatCode', '==', dishi_id).limit(1).get()
                
                if users_ref:
                    user_doc = users_ref[0]
            
        if not user_doc:
            return render_template('harambee.html', error="We couldn't find a student or campaign for this link.", student_name="Student", user_id="", dest=dest)
            
        user_data = user_doc.to_dict()
        student_name = user_data.get('displayName') or user_data.get('name') or 'Student'
        real_user_id = user_doc.id
        
        return render_template('harambee.html', student_name=student_name, user_id=real_user_id, dest=dest, campaign=campaign_data)
    except Exception as e:
        print(f"Harambee lookup error: {e}")
        return render_template('harambee.html', error="An error occurred while loading this page. Please try again.", student_name="Student", user_id="", dest=dest)

# ─── Event Web Ticketing ────────────────────────────────────────────────────────
@app.route('/event')
def event_ticket():
    """
    Web page to buy event tickets via M-PESA.
    """
    event_id = request.args.get('id')
    
    if not event_id:
        return render_template('event.html', error="Invalid Event Link.")
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        event_doc = db.collection('events').document(event_id).get()
        if not event_doc.exists:
            return render_template('event.html', error="Event not found.")
            
        event_data = event_doc.to_dict()
        event_data['id'] = event_doc.id
        
        return render_template('event.html', event=event_data)
    except Exception as e:
        print(f"Event lookup error: {e}")
        return render_template('event.html', error="An error occurred while loading this page.")

# ─── System Announcements ───────────────────────────────────────────────────────
@app.route('/api/v1/system/announce', methods=['POST'])
def system_announce():
    data = request.json or {}
    title = data.get('title', 'System Announcement')
    body = data.get('body', '')
    
    if not body:
        return jsonify({"error": "Announcement body is required"}), 400
        
    auth = request.headers.get('Authorization', '')
    admin_token = os.getenv('ADMIN_SECRET', 'swapeat-admin-2024')
    if auth != f"Bearer {admin_token}":
        return jsonify({"error": "Unauthorized"}), 401
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        users = db.collection('users').stream()
        
        batch = db.batch()
        count = 0
        
        for user in users:
            notif_ref = user.reference.collection('notifications').document()
            batch.set(notif_ref, {
                'title': title,
                'body': body,
                'type': 'system',
                'isRead': False,
                'createdAt': firestore.SERVER_TIMESTAMP,
            })
            count += 1
            if count % 400 == 0:
                batch.commit()
                batch = db.batch()
                
        if count % 400 != 0:
            batch.commit()
            
        return jsonify({"status": "success", "message": f"Announcement sent to {count} users"}), 200
    except Exception as e:
        return jsonify({"error": f"Failed to send announcement: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
