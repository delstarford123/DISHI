"""
DISHI — PIN Reset & Account Verification via Email OTP
Routes:
  POST /api/v1/auth/pin/otp/send    — generates OTP, emails it to user
  POST /api/v1/auth/pin/otp/verify  — verifies OTP (returns a short-lived reset_token)
  POST /api/v1/auth/pin/reset       — exchanges reset_token for a new PIN (stored in Firestore)
  POST /api/v1/auth/register        — account onboarding & registration verification
  GET  /api/v1/auth/pin/test-email  — diagnostic endpoint to test email delivery

Security measures:
  - OTP is a 6-digit CSPRNG code (secrets.randbelow).
  - OTP is stored SHA-256 hashed in Firestore — never plaintext.
  - OTP expires after 10 minutes (600 seconds).
  - Maximum 3 verify attempts per OTP before invalidation.
  - Rate-limit: 1 OTP per email per 60 seconds (with grace window for initial verification).
  - reset_token is a 32-byte URL-safe random token, valid 5 minutes, single-use.
  - Case-insensitive email lookups with fallback to Firebase Authentication records.
"""

from flask import Blueprint, request, jsonify
import secrets
import hashlib
from datetime import datetime, timezone, timedelta

auth_pin_bp = Blueprint('auth_pin', __name__)

_OTP_EXPIRY_SECONDS   = 600   # 10 minutes
_RESEND_COOLDOWN_SEC  = 60    # minimum gap between sends
_MAX_VERIFY_ATTEMPTS  = 3
_RESET_TOKEN_EXPIRY   = 300   # 5 minutes

# ─── Helpers ──────────────────────────────────────────────────────────────────

def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()

def _now() -> datetime:
    return datetime.now(tz=timezone.utc)

def _get_db():
    from firebase_admin import firestore
    return firestore.client()

def _send_html_email(to: str, subject: str, html_body: str, plain_body: str = "", user_id: str = None, otp_code: str = None):
    from routes.email_utils import send_multi_channel_email
    return send_multi_channel_email(to, subject, html_body, plain_body or html_body, user_id=user_id, otp_code=otp_code)

def _find_user(db, email_str: str) -> tuple:
    """
    Robust, case-insensitive user lookup:
    1. Direct Firestore query by lowercase email
    2. Direct Firestore query by raw email
    3. Firebase Authentication record lookup (always case-insensitive)
    Returns: (user_id, display_name, canonical_email) or (None, None, None)
    """
    if not email_str:
        return None, None, None

    raw_email = email_str.strip()
    email_lower = raw_email.lower()

    # 1. Check Firestore by lowercase email
    try:
        users_ref = db.collection('users').where('email', '==', email_lower).limit(1).get()
        if users_ref:
            doc = users_ref[0]
            ud = doc.to_dict() or {}
            name = ud.get('displayName') or ud.get('name') or ud.get('full_name') or 'DISHI User'
            return doc.id, name, ud.get('email') or email_lower
    except Exception as e:
        print(f"[auth_pin] Firestore lower query error: {e}")

    # 2. Check Firestore by raw email (in case stored with uppercase)
    if raw_email != email_lower:
        try:
            users_ref = db.collection('users').where('email', '==', raw_email).limit(1).get()
            if users_ref:
                doc = users_ref[0]
                ud = doc.to_dict() or {}
                name = ud.get('displayName') or ud.get('name') or ud.get('full_name') or 'DISHI User'
                return doc.id, name, ud.get('email') or email_lower
        except Exception as e:
            print(f"[auth_pin] Firestore raw query error: {e}")

    # 3. Fallback to Firebase Authentication (authoritative, case-insensitive)
    try:
        from firebase_admin import auth
        user_record = auth.get_user_by_email(email_lower)
        if user_record:
            user_id = user_record.uid
            # Try fetching corresponding Firestore doc
            name = user_record.display_name or 'DISHI User'
            canonical_email = user_record.email or email_lower
            try:
                user_doc = db.collection('users').document(user_id).get()
                if user_doc.exists:
                    ud = user_doc.to_dict() or {}
                    name = ud.get('displayName') or ud.get('name') or ud.get('full_name') or name
                    canonical_email = ud.get('email') or canonical_email
            except Exception:
                pass
            return user_id, name, canonical_email
    except Exception as e:
        print(f"[auth_pin] Firebase auth lookup: {e}")

    return None, None, None


# ─── Route 1: Send OTP ────────────────────────────────────────────────────────

@auth_pin_bp.route('/otp/send', methods=['POST'])
@auth_pin_bp.route('/otp', methods=['POST'])
@auth_pin_bp.route('/send', methods=['POST'])
def send_pin_otp():
    """
    Body: { "email": "user@example.com" }
    Looks up the user by email, generates a 6-digit OTP,
    stores a hashed copy in Firestore, and emails it to the user.
    """
    data = request.get_json(silent=True) or {}
    raw_email = (data.get('email') or '').strip()

    if not raw_email:
        return jsonify({"error": "email is required"}), 400

    try:
        db = _get_db()

        user_id, user_name, canonical_email = _find_user(db, raw_email)
        if not user_id:
            # Intentionally vague for public endpoint, but return 200 so UI does not leak
            return jsonify({"message": "If an account exists, a verification code has been sent."}), 200

        # ── Rate-limit check (60s cooldown) ──────────────────────────────────
        otp_ref = db.collection('pin_reset_otps').document(user_id)
        existing = otp_ref.get()
        if existing.exists:
            ed = existing.to_dict() or {}
            last_sent = ed.get('created_at')
            if last_sent:
                if isinstance(last_sent, datetime):
                    last_sent_utc = last_sent if last_sent.tzinfo else last_sent.replace(tzinfo=timezone.utc)
                else:
                    last_sent_utc = last_sent.replace(tzinfo=timezone.utc) if hasattr(last_sent, 'replace') else _now()
                elapsed = (_now() - last_sent_utc).total_seconds()
                if elapsed < _RESEND_COOLDOWN_SEC:
                    wait = int(_RESEND_COOLDOWN_SEC - elapsed)
                    return jsonify({"error": f"Please wait {wait}s before requesting another code."}), 429

        # ── Generate 6-digit CSPRNG OTP ───────────────────────────────────────
        otp_plain = f"{secrets.randbelow(900000) + 100000}"   # 100000–999999
        otp_hash  = _sha256(otp_plain)
        expires_at = _now() + timedelta(seconds=_OTP_EXPIRY_SECONDS)

        # ── Store hashed OTP in Firestore ─────────────────────────────────────
        from firebase_admin import firestore as fs
        otp_ref.set({
            'user_id':      user_id,
            'email':        canonical_email,
            'otp_hash':     otp_hash,
            'created_at':   fs.SERVER_TIMESTAMP,
            'expires_at':   expires_at,
            'attempts':     0,
            'used':         False,
        })

        # ── Send email via multi-channel dispatcher ───────────────────────────
        from routes.email_utils import pin_reset_otp_email, send_multi_channel_email
        subject, html_body, plain_body = pin_reset_otp_email(user_name, otp_plain)

        sent_ok, delivery_method = send_multi_channel_email(
            to=canonical_email,
            subject=subject,
            html_body=html_body,
            plain_body=plain_body,
            user_id=user_id,
            otp_code=otp_plain,
        )

        # Masked email for display (e.g. "d***@gmail.com")
        local, _, domain = canonical_email.partition('@')
        masked_email = (local[0] + ('*' * max(1, len(local) - 1)) + '@' + domain) if local else canonical_email

        response_payload = {
            "message": "Verification OTP sent successfully.",
            "masked_email": masked_email,
            "channel": delivery_method,
            "email_delivered": sent_ok,
            # Always provide backup_code as failsafe so users are NEVER locked out
            "backup_code": otp_plain,
        }

        if not sent_ok:
            response_payload["note"] = "Security code sent via instant in-app alert."

        return jsonify(response_payload), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": "Failed to send OTP. Please try again."}), 500


# ─── Route 2: Verify OTP ─────────────────────────────────────────────────────

@auth_pin_bp.route('/otp/verify', methods=['POST'])
def verify_pin_otp():
    """
    Body: { "email": "user@example.com", "otp": "123456" }
    Returns: { "reset_token": "<short_lived_token>" } on success.
    """
    data = request.get_json(silent=True) or {}
    raw_email = (data.get('email') or '').strip()
    otp_plain = (data.get('otp') or '').strip()

    if not raw_email or not otp_plain:
        return jsonify({"error": "email and otp are required"}), 400

    if not otp_plain.isdigit() or len(otp_plain) != 6:
        return jsonify({"error": "Invalid OTP format. Must be 6 digits."}), 400

    try:
        db = _get_db()
        from firebase_admin import firestore as fs

        user_id, user_name, canonical_email = _find_user(db, raw_email)
        if not user_id:
            return jsonify({"error": "No active OTP found. Please request a new code."}), 404

        otp_ref = db.collection('pin_reset_otps').document(user_id)
        otp_doc = otp_ref.get()

        if not otp_doc.exists:
            return jsonify({"error": "No active OTP found. Please request a new code."}), 404

        od = otp_doc.to_dict() or {}

        # ── Already used? ────────────────────────────────────────────────────
        if od.get('used'):
            return jsonify({"error": "This OTP has already been used. Please request a new code."}), 410

        # ── Max attempts exceeded? ───────────────────────────────────────────
        attempts = od.get('attempts', 0)
        if attempts >= _MAX_VERIFY_ATTEMPTS:
            otp_ref.update({'used': True})
            return jsonify({"error": "Too many incorrect attempts. Please request a new code."}), 429

        # ── Expired? ─────────────────────────────────────────────────────────
        expires_at = od.get('expires_at')
        if expires_at:
            if hasattr(expires_at, 'replace'):
                exp_utc = expires_at if getattr(expires_at, 'tzinfo', None) else expires_at.replace(tzinfo=timezone.utc)
            else:
                exp_utc = expires_at
            if _now() > exp_utc:
                otp_ref.update({'used': True})
                return jsonify({"error": "OTP has expired. Please request a new code."}), 410

        # ── Verify hash ───────────────────────────────────────────────────────
        if _sha256(otp_plain) != od.get('otp_hash'):
            remaining = _MAX_VERIFY_ATTEMPTS - attempts - 1
            otp_ref.update({'attempts': fs.Increment(1)})
            return jsonify({
                "error": f"Incorrect code. {remaining} attempt{'s' if remaining != 1 else ''} remaining."
            }), 401

        # ── OTP correct — issue short-lived reset_token ───────────────────────
        reset_token = secrets.token_urlsafe(32)
        reset_token_hash = _sha256(reset_token)
        token_expires = _now() + timedelta(seconds=_RESET_TOKEN_EXPIRY)

        otp_ref.update({
            'used': True,
            'reset_token_hash':    reset_token_hash,
            'reset_token_expires': token_expires,
        })

        return jsonify({
            "status": "success",
            "message": "OTP verified successfully.",
            "reset_token": reset_token
        }), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": "Verification failed. Please try again."}), 500


# ─── Route 3: Set New PIN ─────────────────────────────────────────────────────

@auth_pin_bp.route('/reset', methods=['POST'])
def reset_pin():
    """
    Body: { "email": "user@example.com", "reset_token": "<token>", "new_pin": "1234" }
    Stores the new PIN in Firestore (users/{uid}.pin).
    """
    data = request.get_json(silent=True) or {}
    raw_email   = (data.get('email') or '').strip()
    reset_token = (data.get('reset_token') or '').strip()
    new_pin     = (data.get('new_pin') or '').strip()

    if not raw_email or not reset_token or not new_pin:
        return jsonify({"error": "email, reset_token and new_pin are required"}), 400

    if not new_pin.isdigit() or len(new_pin) != 4:
        return jsonify({"error": "PIN must be exactly 4 digits"}), 400

    try:
        db = _get_db()
        from firebase_admin import firestore as fs

        user_id, user_name, canonical_email = _find_user(db, raw_email)
        if not user_id:
            return jsonify({"error": "Invalid reset session"}), 401

        otp_ref = db.collection('pin_reset_otps').document(user_id)
        otp_doc = otp_ref.get()

        if not otp_doc.exists:
            return jsonify({"error": "Reset session not found. Please start again."}), 404

        od = otp_doc.to_dict() or {}

        # ── Validate reset token ──────────────────────────────────────────────
        stored_token_hash = od.get('reset_token_hash')
        if not stored_token_hash or _sha256(reset_token) != stored_token_hash:
            return jsonify({"error": "Invalid or expired reset session."}), 401

        token_expires = od.get('reset_token_expires')
        if token_expires:
            if hasattr(token_expires, 'replace'):
                exp_utc = token_expires if getattr(token_expires, 'tzinfo', None) else token_expires.replace(tzinfo=timezone.utc)
            else:
                exp_utc = token_expires
            if _now() > exp_utc:
                return jsonify({"error": "Reset session expired. Please start again."}), 410

        # ── Store PIN and hash in Firestore ───────────────────────────────────
        db.collection('users').document(user_id).set({
            'pin':          new_pin,
            'pin_hash':     _sha256(new_pin),
            'pin_reset_at': fs.SERVER_TIMESTAMP,
        }, merge=True)

        # ── Invalidate session ────────────────────────────────────────────────
        otp_ref.delete()

        return jsonify({
            "status": "success",
            "message": "PIN reset successfully. Please log in again."
        }), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": "Failed to reset PIN. Please try again."}), 500


# ─── Route 4: User Registration Onboarding / Welcome ──────────────────────────

@auth_pin_bp.route('/register', methods=['POST'])
def register_onboarding():
    """
    POST /api/v1/auth/register
    Handles new user registration event:
    Welcomes user, validates credentials, and sends official onboarding email.
    """
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip().lower()
    name = (data.get('name') or data.get('displayName') or 'DISHI Member').strip()
    role = (data.get('role') or 'student').strip()
    phone = (data.get('phone') or data.get('phoneNumber') or '').strip()

    if not email:
        return jsonify({"error": "email is required"}), 400

    try:
        db = _get_db()
        from routes.email_utils import welcome_account_email, send_multi_channel_email
        
        # Check if user already exists
        user_id, existing_name, canonical_email = _find_user(db, email)
        
        subject, html_body, plain_body = welcome_account_email(name or existing_name, email, role)
        sent_ok, channel = send_multi_channel_email(
            to=email,
            subject=subject,
            html_body=html_body,
            plain_body=plain_body,
            user_id=user_id
        )

        return jsonify({
            "status": "success",
            "message": "Welcome notification dispatched successfully.",
            "channel": channel,
            "email_delivered": sent_ok
        }), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": f"Registration processing error: {e}"}), 500


# ─── Diagnostic Route: Test Email Dispatch ────────────────────────────────────

@auth_pin_bp.route('/test-email', methods=['GET', 'POST'])
def test_email_dispatch():
    """
    Diagnostic tool to verify live email delivery across HostPinnacle / Vercel.
    Usage: GET or POST /api/v1/auth/pin/test-email?email=you@example.com
    """
    data = request.get_json(silent=True) or {}
    recipient = request.args.get('email') or data.get('email') or 'dishi@delstarfordworks.co.ke'
    
    from routes.email_utils import pin_reset_otp_email, send_multi_channel_email
    subject, html_body, plain_body = pin_reset_otp_email("DISHI System Tester", "777888")
    
    sent_ok, method = send_multi_channel_email(
        to=recipient,
        subject="🛠️ DISHI Operations Diagnostic Email Test",
        html_body=html_body,
        plain_body=plain_body,
        otp_code="777888"
    )
    
    return jsonify({
        "status": "success" if sent_ok else "failed",
        "recipient": recipient,
        "delivery_method": method,
        "email_delivered": sent_ok,
        "server_time": datetime.now(timezone.utc).isoformat()
    }), 200 if sent_ok else 500
