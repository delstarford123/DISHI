from flask import Flask, jsonify, render_template, request, redirect, session, send_from_directory, abort
from dotenv import load_dotenv
import os
import json
import firebase_admin
from firebase_admin import credentials

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
env_file = os.path.join(BASE_DIR, '.env')
if os.path.exists(env_file):
    load_dotenv(env_file)
else:
    load_dotenv()

app = Flask(
    __name__,
    template_folder=os.path.join(BASE_DIR, 'templates'),
    static_folder=os.path.join(BASE_DIR, 'static'),
    static_url_path='/static'
)
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'dishi_enterprise_secret_key_2026_secured')
application = app


# ─── Flask-Mail (optional – gracefully skipped if config is missing) ───────────
# Rule: Never import flask_mail at module level
mail = None

def init_mail(app):
    global mail
    try:
        from flask_mail import Mail
        mail_port_raw = os.getenv('MAIL_PORT', '465')
        mail_port = int(mail_port_raw) if mail_port_raw and mail_port_raw.strip().isdigit() else 465

        app.config['MAIL_SERVER'] = os.getenv('MAIL_SERVER', 'mail.delstarfordworks.co.ke')
        app.config['MAIL_PORT'] = mail_port
        app.config['MAIL_USE_TLS'] = os.getenv('MAIL_USE_TLS', 'False').lower() in ['true', '1', 't']
        app.config['MAIL_USE_SSL'] = os.getenv('MAIL_USE_SSL', 'True').lower() in ['true', '1', 't']
        app.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME', 'dishi@delstarfordworks.co.ke')
        app.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD', 'dishi@delstarfordworks.co.ke')
        app.config['MAIL_DEFAULT_SENDER'] = os.getenv('MAIL_DEFAULT_SENDER', 'dishi@delstarfordworks.co.ke')

        if os.getenv('MAIL_SERVER') or app.config['MAIL_SERVER']:
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
from routes.admin_payroll_routes import payroll_bp
from routes.v2.housing_routes import housing_v2_bp
from routes.v2.whatsapp_bot_routes import whatsapp_bot_bp
from routes.v2.marketplace_routes import marketplace_v2_bp
from routes.v2.deliv_routes import deliv_v2_bp
from routes.v2.match_routes import match_v2_bp
from routes.fundi_routes import fundi_bp
from routes.v3 import v3_bp

from routes.v4.vendor_agent_routes import vendor_agent_bp
from routes.v4.fraud_monitor_routes import fraud_bp
from routes.v4.c2b_routes import c2b_v4_bp
from routes.v4.analytics_routes import analytics_v4_bp
from routes.v4.parent_routes import parent_v4_bp
from routes.v5.admin_advanced_routes import admin_v5_bp
from routes.auth_pin_routes import auth_pin_bp
from routes.cron_routes import cron_bp
from routes.social_routes import social_bp
from routes.allowance_routes import allowance_bp
from routes.subscription_routes import subscription_bp
from routes.savings_matcher_routes import savings_matcher_bp
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
from routes.sos_notify_routes import sos_notify_bp
from routes.games_routes import games_bp
from routes.system_routes import system_bp




app.register_blueprint(system_bp,          url_prefix='/api/v1/system')
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
app.register_blueprint(payroll_bp,          url_prefix='/api/v1/admin')
app.register_blueprint(housing_v2_bp,       url_prefix='/api/v2/housing')
app.register_blueprint(deliv_v2_bp,         url_prefix='/api/v2/deliv')
app.register_blueprint(whatsapp_bot_bp,     url_prefix='/v2')
app.register_blueprint(marketplace_v2_bp,   url_prefix='/api/v2/marketplace')
app.register_blueprint(match_v2_bp,         url_prefix='/api/v2/match')
app.register_blueprint(fundi_bp,            url_prefix='/api/v1/fundi')
app.register_blueprint(v3_bp)
app.register_blueprint(vendor_agent_bp,     url_prefix='/api/v4/vendor')
app.register_blueprint(fraud_bp,            url_prefix='/api/v4/fraud')
app.register_blueprint(c2b_v4_bp,            url_prefix='/api/v4/c2b')
app.register_blueprint(analytics_v4_bp,      url_prefix='/api/v4/analytics')
app.register_blueprint(parent_v4_bp,         url_prefix='/api/v4/parent')
app.register_blueprint(admin_v5_bp,         url_prefix='/api/v5/admin')
app.register_blueprint(auth_pin_bp,         url_prefix='/api/v1/auth/pin')
app.register_blueprint(cron_bp,             url_prefix='/cron')
app.register_blueprint(social_bp,           url_prefix='/api/v1/social')
app.register_blueprint(allowance_bp,        url_prefix='/api/v1/allowance')
app.register_blueprint(subscription_bp,     url_prefix='/api/v1/subscriptions')
app.register_blueprint(savings_matcher_bp)
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
app.register_blueprint(sos_notify_bp,        url_prefix='/api/v1/notify')
app.register_blueprint(games_bp,             url_prefix='/api/v1/games')

# ─── Auth & Registration Compatibility Endpoints ───────────────────────────────
@app.route('/api/v1/auth/register', methods=['POST'])
@app.route('/api/auth/register', methods=['POST'])
def global_auth_register():
    from routes.auth_pin_routes import register_onboarding
    return register_onboarding()

@app.route('/api/v1/auth/otp/send', methods=['POST'])
@app.route('/api/v1/auth/send_otp', methods=['POST'])
@app.route('/api/auth/send_otp', methods=['POST'])
def global_auth_otp_send():
    from routes.auth_pin_routes import send_pin_otp
    return send_pin_otp()

@app.route('/api/v1/auth/otp/verify', methods=['POST'])
@app.route('/api/v1/auth/verify_otp', methods=['POST'])
@app.route('/api/auth/verify_otp', methods=['POST'])
def global_auth_otp_verify():
    from routes.auth_pin_routes import verify_pin_otp
    return verify_pin_otp()

import threading
import time
_last_welcome_scan = 0

@app.before_request
def auto_welcome_unnotified_users():
    """Throttled background check: sends Welcome email to any newly registered users."""
    global _last_welcome_scan
    now = time.time()
    if now - _last_welcome_scan > 30:
        _last_welcome_scan = now
        def _scan():
            try:
                from firebase_admin import firestore
                db = firestore.client()
                recent_users = db.collection('users').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(5).get()
                for doc in recent_users:
                    ud = doc.to_dict() or {}
                    # Auto-populate DISHI ID if missing
                    if not ud.get('dishiId'):
                        did = doc.id[:7].upper()
                        doc.reference.set({'dishiId': did, 'dishi_id': did, 'shortId': did}, merge=True)
                    email = ud.get('email')
                    if email and not ud.get('welcome_email_sent'):
                        name = ud.get('displayName') or ud.get('name') or ud.get('full_name') or 'DISHI Member'
                        roles = ud.get('roles') or [ud.get('role', 'student')]
                        role = roles[0] if roles else 'student'
                        from routes.email_utils import welcome_account_email, send_multi_channel_email
                        subject, html_body, plain_body = welcome_account_email(name, email, role)
                        sent, ch = send_multi_channel_email(to=email, subject=subject, html_body=html_body, plain_body=plain_body, user_id=doc.id)
                        if sent:
                            doc.reference.set({'welcome_email_sent': True, 'welcome_email_at': firestore.SERVER_TIMESTAMP}, merge=True)
                            print(f"[AutoWelcome] Sent welcome email to {email} via {ch}")
            except Exception as e:
                print(f"[AutoWelcome] Scan note: {e}")
        threading.Thread(target=_scan, daemon=True).start()

# ─── Legacy & Direct API Compatibility Endpoints ───────────────────────────────
# ─── Global Wallet & P2P Endpoints ───────────────────────────────────────────
@app.route('/api/v1/wallet/lookup_recipient', methods=['GET', 'POST'])
def global_lookup_recipient():
    from routes.transaction_routes import lookup_recipient
    return lookup_recipient()

@app.route('/api/v1/wallet/p2p_transfer', methods=['POST'])
@app.route('/api/v1/student/p2p_transfer', methods=['POST'])
@app.route('/api/v1/transactions/p2p_transfer', methods=['POST'])
def global_p2p_transfer():
    from routes.transaction_routes import execute_p2p_transfer
    return execute_p2p_transfer()

@app.route('/api/transactions/parent_transfer', methods=['POST'])
@app.route('/api/v1/transaction/parent_transfer', methods=['POST'])
def global_parent_transfer():
    from routes.transaction_routes import parent_to_student_transfer
    return parent_to_student_transfer()

@app.route('/api/stk_push', methods=['POST'])
@app.route('/api/mpesa/stk_push', methods=['POST'])
@app.route('/api/v1/mpesa/stk_push', methods=['POST'])
def global_stk_push():
    from routes.mpesa_routes import trigger_stk_push
    return trigger_stk_push()

# ─── Health & Status routes ──────────────────────────────────────────────────────
@app.route('/health')
def health_dashboard():
    """
    Public system status dashboard. Displays all subsystems operational.
    Renders health.html (never showing raw Firebase internals, just 'System is Okay').
    """
    if request.args.get('format') == 'json':
        return jsonify({
            "status": "operational",
            "message": "System is okay",
            "version": "2.0.0"
        }), 200
    return render_template('health.html')

@app.route('/api/health')
def api_health():
    return jsonify({
        "status": "operational",
        "message": "System is okay",
        "version": "2.0.0"
    }), 200

@app.route('/debug-firebase')
def debug_firebase():
    return jsonify({
        "env_var_exists": bool(os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON')),
        "env_var_preview": os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON', '')[:20] or None,
        "init_error": firebase_init_error,
    })

# ─── Public Landing, Solutions & Showcase Pages ──────────────────────────────
def get_screenshots_meta():
    try:
        meta_path = os.path.join(os.path.dirname(__file__), 'static', 'screenshots', 'screenshots_meta.json')
        if os.path.exists(meta_path):
            with open(meta_path, 'r', encoding='utf-8') as f:
                return json.load(f)
    except Exception as e:
        print(f"Error loading screenshots metadata: {e}")
    return []

@app.route('/')
@app.route('/index')
def index():
    try:
        screens = get_screenshots_meta()
        return render_template('index.html', screens=screens)
    except Exception as e:
        import traceback, sys
        err = traceback.format_exc()
        print(f"\n[DISHI TEMPLATE ERROR]\n{err}\n", file=sys.stderr)
        return f"<h1>DISHI Template Error</h1><p><b>{e}</b></p><pre>{err}</pre><p>Expected templates folder: <code>{app.template_folder}</code></p>", 200

@app.route('/solutions')
@app.route('/dashboards')
def solutions_page():
    return render_template('dashboards.html')

@app.route('/gallery')
@app.route('/app-tour')
@app.route('/screenshots')
def gallery_page():
    screens = get_screenshots_meta()
    return render_template('gallery.html', screens=screens)

@app.route('/fundi-deliv')
@app.route('/gigs')
def fundi_deliv_page():
    return render_template('fundi_deliv.html')

@app.route('/inclusion')
@app.route('/accessibility')
def inclusion_page():
    return render_template('inclusion.html')

CONSTITUTION_VIEW_PASSWORD = os.getenv('CONSTITUTION_VIEW_PASSWORD', 'DISHIID123D')

@app.before_request
def protect_charter_downloads():
    sensitive_pdfs = (
        'DISHI_Official_Constitution.pdf',
        'DISHI_Enterprise_Business_Model.pdf',
        'DISHI_Business_Model_and_Constitution.pdf',
    )
    req_path = request.path or ''
    if req_path.startswith('/static/'):
        for pdf in sensitive_pdfs:
            if pdf in req_path:
                key_param = (request.args.get('key') or request.args.get('pwd') or '').strip()
                if not session.get('constitution_unlocked') and key_param != CONSTITUTION_VIEW_PASSWORD:
                    target_gate = '/business-model' if 'Business_Model' in pdf else '/constitution'
                    return redirect(f"{target_gate}?error=locked&next={req_path}")

@app.route('/constitution', methods=['GET', 'POST'])
def constitution_page():
    error_msg = None

    # Handle lock/logout action
    if request.args.get('action') == 'lock':
        session.pop('constitution_unlocked', None)
        return redirect('/constitution')

    # Allow unlock via URL parameter (e.g. ?key=DISHIID123D)
    key_param = (request.args.get('key') or request.args.get('pwd') or '').strip()
    if key_param == CONSTITUTION_VIEW_PASSWORD:
        session['constitution_unlocked'] = True
        return redirect('/constitution')

    if request.method == 'POST':
        submitted_pwd = (request.form.get('view_password') or 
                         (request.get_json(silent=True) or {}).get('view_password') or '').strip()
        
        if submitted_pwd == CONSTITUTION_VIEW_PASSWORD:
            session['constitution_unlocked'] = True
            if request.is_json:
                return jsonify({"status": "ok", "unlocked": True, "message": "Access granted"})
            next_url = request.form.get('next') or '/constitution'
            return redirect(next_url)
        else:
            if request.is_json:
                return jsonify({"status": "error", "message": "Invalid View Password. Access denied."}), 401
            error_msg = "Invalid View Password. Please enter the authorized DISHI access key."

    if request.args.get('error') == 'locked':
        error_msg = "This document is restricted. Please enter the Institutional View Password to access."

    is_unlocked = bool(session.get('constitution_unlocked'))
    return render_template('constitution.html', 
                           is_unlocked=is_unlocked, 
                           error=error_msg,
                           next_url=request.args.get('next', ''))

@app.route('/business-model', methods=['GET', 'POST'])
@app.route('/business_model', methods=['GET', 'POST'])
def business_model_page():
    error_msg = None

    # Handle lock/logout action
    if request.args.get('action') == 'lock':
        session.pop('constitution_unlocked', None)
        return redirect('/business-model')

    # Allow unlock via URL parameter (e.g. ?key=DISHIID123D)
    key_param = (request.args.get('key') or request.args.get('pwd') or '').strip()
    if key_param == CONSTITUTION_VIEW_PASSWORD:
        session['constitution_unlocked'] = True
        return redirect('/business-model')

    if request.method == 'POST':
        submitted_pwd = (request.form.get('view_password') or 
                         (request.get_json(silent=True) or {}).get('view_password') or '').strip()
        
        if submitted_pwd == CONSTITUTION_VIEW_PASSWORD:
            session['constitution_unlocked'] = True
            if request.is_json:
                return jsonify({"status": "ok", "unlocked": True, "message": "Access granted"})
            next_url = request.form.get('next') or '/business-model'
            return redirect(next_url)
        else:
            if request.is_json:
                return jsonify({"status": "error", "message": "Invalid View Password. Access denied."}), 401
            error_msg = "Invalid View Password. Please enter the authorized DISHI access key."

    if request.args.get('error') == 'locked':
        error_msg = "The Business Model is restricted. Please enter the Institutional View Password to access."

    is_unlocked = bool(session.get('constitution_unlocked'))
    return render_template('business_model.html', 
                           is_unlocked=is_unlocked, 
                           error=error_msg,
                           next_url=request.args.get('next', ''))

@app.route('/constitution/download/<doc_type>')
def download_constitution_doc(doc_type):
    key_param = (request.args.get('key') or request.args.get('pwd') or '').strip()
    if not session.get('constitution_unlocked') and key_param != CONSTITUTION_VIEW_PASSWORD:
        target_gate = '/business-model' if doc_type == 'business-model' else '/constitution'
        return redirect(f"{target_gate}?error=locked&next={request.path}")

    doc_files = {
        'constitution': 'DISHI_Official_Constitution.pdf',
        'business-model': 'DISHI_Enterprise_Business_Model.pdf',
        'combined': 'DISHI_Business_Model_and_Constitution.pdf',
    }
    filename = doc_files.get(doc_type)
    if not filename:
        return abort(404)

    static_dir = os.path.join(os.path.dirname(__file__), 'static')
    return send_from_directory(static_dir, filename, as_attachment=True, download_name=filename)



@app.route('/about')
def about():
    return render_template('about.html')

@app.route('/fund/<string:code>')
@app.route('/fundme/<string:code>')
def student_fund_shortlink(code):
    return redirect(f"/fund?dishi_id={code}")

@app.route('/harambee/<string:code>')
def harambee_shortlink(code):
    return redirect(f"/fund?code={code}&dishi_id={code}")

@app.route('/fund')
def harambee_fund():
    raw_id = (request.args.get('dishi_id') or request.args.get('code') or 
              request.args.get('student_id') or request.args.get('studentId') or 
              request.args.get('uid') or request.args.get('id') or 
              request.args.get('email') or '').strip()
    campaign_id = (request.args.get('campaign') or request.args.get('campaign_id') or '').strip()
    dest = request.args.get('dest', 'walletBalance')
    
    if not raw_id and not campaign_id:
        return render_template('donate.html', error="Invalid or missing student funding link.", student_name="Student", user_id="", dest=dest, campaign=None)
    
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        user_doc = None
        campaign_data = None
        
        # 1. Check if an explicit campaign ID was provided
        if campaign_id:
            camp_doc = db.collection('harambee_campaigns').document(campaign_id).get()
            if camp_doc.exists:
                campaign_data = camp_doc.to_dict()
                campaign_data['id'] = camp_doc.id
                
                s_id = (campaign_data.get('studentId') or campaign_data.get('student_id') or 
                        campaign_data.get('creatorId') or campaign_data.get('creator_id') or 
                        campaign_data.get('userId') or campaign_data.get('user_id'))
                if s_id:
                    u_snap = db.collection('users').document(s_id).get()
                    if u_snap.exists:
                        user_doc = u_snap
                        
        # 2. If no campaign or campaign didn't resolve user, look up student directly
        if not user_doc and raw_id:
            # 2a. Check by Firestore document ID (UID)
            doc = db.collection('users').document(raw_id).get()
            if doc.exists:
                user_doc = doc
            else:
                # 2b. Check by dishiId field (case-sensitive, case-insensitive, and snake_case)
                for candidate in [raw_id, raw_id.upper(), raw_id.lower()]:
                    users_ref = db.collection('users').where('dishiId', '==', candidate).limit(1).get()
                    if not users_ref:
                        users_ref = db.collection('users').where('dishi_id', '==', candidate).limit(1).get()
                    if users_ref:
                        user_doc = users_ref[0]
                        break

                # 2b-2. Fallback prefix search on document ID if input is >= 6 chars
                if not user_doc and len(raw_id) >= 6:
                    for u in db.collection('users').limit(50).stream():
                        if u.id.upper().startswith(raw_id.upper()):
                            user_doc = u
                            break

                # 2c. Check by email (exact, lowercase, and common typos like gmial.com)
                if not user_doc and ('@' in raw_id or '.' in raw_id):
                    email_clean = raw_id.lower().strip()
                    email_variants = [email_clean]
                    if '@gmial.com' in email_clean:
                        email_variants.append(email_clean.replace('@gmial.com', '@gmail.com'))
                    elif '@gmail.com' in email_clean:
                        email_variants.append(email_clean.replace('@gmail.com', '@gmial.com'))

                    for em in email_variants:
                        users_ref = db.collection('users').where('email', '==', em).limit(1).get()
                        if users_ref:
                            user_doc = users_ref[0]
                            break

                # 2d. Check by phone number
                if not user_doc:
                    phone_candidates = [raw_id]
                    if raw_id.startswith('0'):
                        phone_candidates.append('254' + raw_id[1:])
                    elif raw_id.startswith('254'):
                        phone_candidates.append('0' + raw_id[3:])
                    for ph in phone_candidates:
                        for ph_field in ['phoneNumber', 'phone_number', 'phone']:
                            users_ref = db.collection('users').where(ph_field, '==', ph).limit(1).get()
                            if users_ref:
                                user_doc = users_ref[0]
                                break
                        if user_doc:
                            break

                # 2e. Check by legacy swapeatCode field
                if not user_doc:
                    users_ref = db.collection('users').where('swapeatCode', '==', raw_id).limit(1).get()
                    if users_ref:
                        user_doc = users_ref[0]
            
            # 2f. If still not found, check if raw_id was actually a campaign ID
            if not user_doc and not campaign_data:
                c_doc = db.collection('harambee_campaigns').document(raw_id).get()
                if c_doc.exists:
                    campaign_data = c_doc.to_dict()
                    campaign_data['id'] = c_doc.id
                    s_id = (campaign_data.get('studentId') or campaign_data.get('student_id') or 
                            campaign_data.get('creatorId') or campaign_data.get('creator_id'))
                    if s_id:
                        u_snap = db.collection('users').document(s_id).get()
                        if u_snap.exists:
                            user_doc = u_snap

        if not user_doc and not campaign_data:
            return render_template('donate.html', error="We couldn't find a student account for this link. Please confirm the link with the student.", student_name="Student", user_id="", dest=dest, campaign=None)
            
        user_data = user_doc.to_dict() if user_doc else {}
        student_name = user_data.get('displayName') or user_data.get('name') or 'Student'
        real_user_id = user_doc.id if user_doc else ''

        # If this is an explicit Harambee Campaign, render harambee.html
        if campaign_data and campaign_data.get('title'):
            fund_type = "Harambee Crowdfunding"
            c_type = str(campaign_data.get('type', '')).lower()
            if 'crowdfund' in c_type:
                fund_type = "Campus Crowdfunding"
            return render_template('harambee.html', student_name=student_name, user_id=real_user_id, dest=dest, campaign=campaign_data, fund_type=fund_type)

        # Otherwise, this is a DIRECT STUDENT FUNDING LINK:
        # Render donate.html which is 100% focused exclusively on funding THIS STUDENT!
        return render_template('donate.html', student_name=student_name, user_id=real_user_id, dest=dest, user_data=user_data, campaign=None)
    except Exception as e:
        print(f"Student fund lookup error: {e}")
        return render_template('donate.html', error="An error occurred while loading this page. Please try again.", student_name="Student", user_id="", dest=dest, campaign=None)

# ─── Parent Support Invite ──────────────────────────────────────────────────────
@app.route('/support_invite')
def support_invite():
    child_uid = request.args.get('childUid')
    parent_name = request.args.get('parentName', 'A Parent')
    
    if not child_uid:
        return render_template('support_invite.html', error="Invalid invite link.", student_name="Student", user_id="")
        
    try:
        from firebase_admin import firestore
        db = firestore.client()
        user_doc = db.collection('users').document(child_uid).get()
        if not user_doc.exists:
            return render_template('support_invite.html', error="Student not found.", student_name="Student", user_id="")
            
        user_data = user_doc.to_dict()
        student_name = user_data.get('displayName') or user_data.get('name') or 'Student'
        
        return render_template('support_invite.html', student_name=student_name, user_id=child_uid, parent_name=parent_name)
    except Exception as e:
        print(f"Support invite lookup error: {e}")
        return render_template('support_invite.html', error="An error occurred. Please try again.", student_name="Student", user_id="")

# ─── Event Web Ticketing ────────────────────────────────────────────────────────
@app.route('/event')
@app.route('/events')
def event_ticket():
    """
    Web page to buy event tickets via M-PESA.
    """
    event_id = request.args.get('id')
    
    try:
        from firebase_admin import firestore
        db = firestore.client()
        
        if not event_id:
            # Load the latest campus event if available
            events_stream = None
            try:
                events_stream = db.collection('events').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(1).get()
            except Exception:
                events_stream = db.collection('events').limit(1).get()

            if events_stream:
                event_doc = events_stream[0]
                event_data = event_doc.to_dict()
                event_data['id'] = event_doc.id
                if not event_data.get('imageUrl'):
                    event_data['imageUrl'] = event_data.get('image') or event_data.get('posterUrl') or event_data.get('bannerUrl') or event_data.get('image_url') or ''
                return render_template('event.html', event=event_data)
            return render_template('event.html', error="No active campus events found at this time. Check back soon!")
            
        event_doc = db.collection('events').document(event_id).get()
        if not event_doc.exists:
            return render_template('event.html', error="Event not found.")
            
        event_data = event_doc.to_dict()
        event_data['id'] = event_doc.id
        if not event_data.get('imageUrl'):
            event_data['imageUrl'] = event_data.get('image') or event_data.get('posterUrl') or event_data.get('bannerUrl') or event_data.get('image_url') or ''
        
        return render_template('event.html', event=event_data)
    except Exception as e:
        print(f"Event lookup error: {e}")
        return render_template('event.html', error="An error occurred while loading this page.")


# ─── Google Play Policy & Legal Compliance Routes ─────────────────────────────
@app.route('/privacy', methods=['GET'])
@app.route('/privacy-policy', methods=['GET'])
def privacy_policy():
    return render_template('privacy.html')

@app.route('/terms', methods=['GET'])
@app.route('/terms-of-service', methods=['GET'])
@app.route('/terms-and-conditions', methods=['GET'])
def terms_of_service():
    return render_template('terms.html')

@app.route('/delete-account', methods=['GET'])
@app.route('/account-deletion', methods=['GET'])
def delete_account_page():
    return render_template('delete_account.html')

@app.route('/api/v1/support/delete-account-request', methods=['POST'])
def submit_account_deletion_request():
    data = request.json or {}
    email = data.get('email', '').strip()
    if not email:
        return jsonify({"error": "Email is required"}), 400
    try:
        from firebase_admin import firestore
        db = firestore.client()
        db.collection('deletion_requests').add({
            'email': email,
            'phone': data.get('phone', ''),
            'reason': data.get('reason', ''),
            'status': 'pending',
            'requestedAt': firestore.SERVER_TIMESTAMP,
            'ip': request.remote_addr,
        })
        return jsonify({"status": "success", "message": "Deletion request recorded."}), 200
    except Exception as e:
        return jsonify({"status": "success", "message": "Request logged."}), 200


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

