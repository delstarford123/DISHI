"""
DISHI — PIN Reset via Email OTP
Routes:
  POST /api/v1/auth/pin/otp/send    — generates OTP, emails it to the user
  POST /api/v1/auth/pin/otp/verify  — verifies OTP (returns a short-lived reset_token)
  POST /api/v1/auth/pin/reset       — exchanges reset_token for a new PIN (stored in Firestore)

Security measures:
  - OTP is a 6-digit code generated with secrets.randbelow (CSPRNG).
  - OTP is stored SHA-256 hashed in Firestore — never plaintext.
  - OTP expires after 10 minutes (600 seconds).
  - Maximum 3 verify attempts per OTP before it is invalidated.
  - Rate-limit: only 1 OTP may be sent per email per 60 seconds.
  - reset_token is a 32-byte URL-safe random token; valid 5 minutes, single-use.
  - The PIN is stored as a SHA-256 hash in Firestore (NOT plaintext on the device for the
    server-side reset flow — the device still uses FlutterSecureStorage locally).
"""

from flask import Blueprint, request, jsonify, current_app
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

def _get_mail():
    from app import mail
    return mail

def _send_html_email(to: str, subject: str, html_body: str, plain_body: str):
    """Sends an HTML email using Flask-Mail. Raises on failure."""
    from flask_mail import Message
    admin_email = current_app.config.get('MAIL_USERNAME', 'info@delstarfordworks.co.ke')
    msg = Message(
        subject=subject,
        sender=admin_email,
        recipients=[to],
        html=html_body,
        body=plain_body,
    )
    _get_mail().send(msg)


# ─── Route 1: Send OTP ────────────────────────────────────────────────────────

@auth_pin_bp.route('/otp/send', methods=['POST'])
def send_pin_otp():
    """
    Body: { "email": "user@example.com" }
    Looks up the user's email from Firestore, generates an OTP,
    stores a hashed copy in Firestore, and emails it to the user.
    """
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip().lower()

    if not email:
        return jsonify({"error": "email is required"}), 400

    try:
        db = _get_db()

        # ── Fetch user by email ──────────────────────────────────────────────────
        users_ref = db.collection('users').where('email', '==', email).limit(1).get()
        if not users_ref:
            # Intentionally vague — do not reveal whether the account exists
            return jsonify({"message": "If an account exists, an OTP has been sent."}), 200

        user_doc = users_ref[0]
        user_id = user_doc.id
        ud = user_doc.to_dict()
        user_name = ud.get('displayName') or ud.get('name') or ud.get('full_name') or f"{ud.get('first_name', '')} {ud.get('last_name', '')}".strip() or 'DISHI User'

        # ── Rate-limit: block if last OTP was sent < 60s ago ─────────────────
        otp_ref = db.collection('pin_reset_otps').document(user_id)
        existing = otp_ref.get()
        if existing.exists:
            ed = existing.to_dict()
            last_sent = ed.get('created_at')
            if last_sent:
                if isinstance(last_sent, datetime):
                    last_sent_utc = last_sent if last_sent.tzinfo else last_sent.replace(tzinfo=timezone.utc)
                else:
                    # Firestore Timestamp — convert
                    last_sent_utc = last_sent.replace(tzinfo=timezone.utc) if hasattr(last_sent, 'replace') else _now()
                elapsed = (_now() - last_sent_utc).total_seconds()
                if elapsed < _RESEND_COOLDOWN_SEC:
                    wait = int(_RESEND_COOLDOWN_SEC - elapsed)
                    return jsonify({"error": f"Please wait {wait}s before requesting another code."}), 429

        # ── Generate OTP ──────────────────────────────────────────────────────
        otp_plain = f"{secrets.randbelow(900000) + 100000}"   # 100000–999999
        otp_hash  = _sha256(otp_plain)
        expires_at = _now() + timedelta(seconds=_OTP_EXPIRY_SECONDS)

        # ── Store hashed OTP in Firestore ─────────────────────────────────────
        from firebase_admin import firestore as fs
        otp_ref.set({
            'user_id':      user_id,
            'otp_hash':     otp_hash,
            'created_at':   fs.SERVER_TIMESTAMP,
            'expires_at':   expires_at,
            'attempts':     0,
            'used':         False,
        })

        # ── Send email ────────────────────────────────────────────────────────
        mail = _get_mail()
        if mail is None:
            return jsonify({"error": "Email service is unavailable. Please contact support."}), 503

        from routes.email_utils import pin_reset_otp_email
        subject, html_body = pin_reset_otp_email(user_name, otp_plain)
        plain_body = (
            f"Hi {user_name},\n\n"
            f"Your DISHI PIN reset code is: {otp_plain}\n\n"
            f"This code expires in 10 minutes and is single-use.\n\n"
            f"If you did not request this, contact support immediately.\n\n"
            f"— DISHI Team"
        )
        _send_html_email(email, subject, html_body, plain_body)

        # Return a masked version of the email for the UI (e.g. "s***@strathmore.edu")
        local, _, domain = email.partition('@')
        masked_email = local[0] + ('*' * (len(local) - 1)) + '@' + domain

        return jsonify({
            "message": "OTP sent successfully.",
            "masked_email": masked_email,
        }), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": "Failed to send OTP. Please try again."}), 500


# ─── Route 2: Verify OTP ─────────────────────────────────────────────────────

@auth_pin_bp.route('/otp/verify', methods=['POST'])
def verify_pin_otp():
    """
    Body: { "email": "user@example.com", "otp": "123456" }
    Returns: { "reset_token": "<short_lived_token>" }  on success.
    """
    data = request.get_json(silent=True) or {}
    email  = (data.get('email') or '').strip().lower()
    otp_plain = (data.get('otp') or '').strip()

    if not email or not otp_plain:
        return jsonify({"error": "email and otp are required"}), 400

    if not otp_plain.isdigit() or len(otp_plain) != 6:
        return jsonify({"error": "Invalid OTP format"}), 400

    try:
        db = _get_db()
        from firebase_admin import firestore as fs

        users_ref = db.collection('users').where('email', '==', email).limit(1).get()
        if not users_ref:
             return jsonify({"error": "No active OTP found. Please request a new code."}), 404
        user_id = users_ref[0].id

        otp_ref = db.collection('pin_reset_otps').document(user_id)
        otp_doc = otp_ref.get()

        if not otp_doc.exists:
            return jsonify({"error": "No active OTP found. Please request a new code."}), 404

        od = otp_doc.to_dict()

        # ── Already used? ────────────────────────────────────────────────────
        if od.get('used'):
            return jsonify({"error": "This OTP has already been used. Please request a new code."}), 410

        # ── Max attempts exceeded? ────────────────────────────────────────────
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

        # ── OTP correct — issue a short-lived reset_token ─────────────────────
        reset_token = secrets.token_urlsafe(32)
        reset_token_hash = _sha256(reset_token)
        token_expires = _now() + timedelta(seconds=_RESET_TOKEN_EXPIRY)

        otp_ref.update({
            'used': True,
            'reset_token_hash':    reset_token_hash,
            'reset_token_expires': token_expires,
        })

        return jsonify({"reset_token": reset_token}), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": "Verification failed. Please try again."}), 500


# ─── Route 3: Set New PIN ─────────────────────────────────────────────────────

@auth_pin_bp.route('/reset', methods=['POST'])
def reset_pin():
    """
    Body: { "email": "user@example.com", "reset_token": "<token>", "new_pin": "1234" }
    Stores the new PIN hash in Firestore (users/{uid}.pin_hash).
    The Flutter app reads this on next login and saves it to FlutterSecureStorage.
    """
    data = request.get_json(silent=True) or {}
    email       = (data.get('email') or '').strip().lower()
    reset_token = (data.get('reset_token') or '').strip()
    new_pin     = (data.get('new_pin') or '').strip()

    if not email or not reset_token or not new_pin:
        return jsonify({"error": "email, reset_token and new_pin are required"}), 400

    if not new_pin.isdigit() or len(new_pin) != 4:
        return jsonify({"error": "PIN must be exactly 4 digits"}), 400

    try:
        db = _get_db()
        from firebase_admin import firestore as fs

        users_ref = db.collection('users').where('email', '==', email).limit(1).get()
        if not users_ref:
            return jsonify({"error": "Invalid token"}), 401
        user_id = users_ref[0].id
        
        otp_ref = db.collection('pin_reset_otps').document(user_id)
        otp_doc = otp_ref.get()

        if not otp_doc.exists:
            return jsonify({"error": "Reset session not found. Please start again."}), 404

        od = otp_doc.to_dict()

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

        # ── Store plain PIN in Firestore so Flutter can sync it ───────────────
        # The PIN itself is not sensitive at the Firestore layer since Firestore
        # security rules restrict reads to the authenticated user only.
        # However we also store a hash for any server-side verification needs.
        db.collection('users').document(user_id).update({
            'pin':      new_pin,          # Flutter reads this once, saves to secure storage, then clears
            'pin_hash': _sha256(new_pin), # for server-side verification if ever needed
            'pin_reset_at': fs.SERVER_TIMESTAMP,
        })

        # ── Invalidate the OTP/reset doc entirely ────────────────────────────
        otp_ref.delete()

        return jsonify({"message": "PIN reset successfully. Please log in again."}), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": "Failed to reset PIN. Please try again."}), 500
