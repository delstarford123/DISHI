from flask import Blueprint, request, jsonify, current_app

support_bp = Blueprint('support', __name__)


@support_bp.route('/', methods=['POST'])
def send_support_email():
    data = request.json or {}
    subject_text = data.get('subject', '').strip()
    description  = data.get('description', '').strip()
    student_id   = data.get('studentId', 'Unknown')

    if not subject_text or not description:
        return jsonify({"error": "Subject and description are required."}), 400

    admin_email = current_app.config.get('MAIL_USERNAME')
    if not admin_email:
        return jsonify({"error": "Support email not configured on server."}), 503

    try:
        # Lazy import — does not crash startup if flask-mail is misconfigured
        from flask_mail import Message
        from app import mail
        from routes.email_utils import support_ticket_email

        if mail is None:
            return jsonify({"error": "Mail service is not available right now."}), 503

        # Try to look up the student's display name from Firestore
        student_name = student_id
        try:
            from firebase_admin import firestore
            db = firestore.client()
            user_doc = db.collection('users').document(student_id).get()
            if user_doc.exists:
                ud = user_doc.to_dict()
                student_name = ud.get('displayName') or ud.get('name') or ud.get('full_name') or f"{ud.get('first_name', '')} {ud.get('last_name', '')}".strip() or student_id
        except Exception:
            pass  # Fall back to student_id if lookup fails

        email_subject, html_body = support_ticket_email(student_id, student_name, subject_text, description)

        msg = Message(
            subject=email_subject,
            sender=admin_email,
            recipients=[admin_email],
            html=html_body,
            body=(
                f"Support Ticket\n"
                f"Student: {student_name} (ID: {student_id})\n\n"
                f"Subject: {subject_text}\n\n"
                f"Description:\n{description}"
            ),
        )
        mail.send(msg)
        return jsonify({"message": "Support email sent successfully."}), 200

    except Exception as e:
        print(f"Support email error: {e}")
        return jsonify({"error": "Failed to send email. Please try again later."}), 500
