"""
SOS Notification Routes
-----------------------
POST /api/v1/notify/sos
  - Called by the student Flutter app when SOS is activated or deactivated.
  - Fetches all linked parents for the student.
  - Sends an FCM push notification to each parent's device.
  - Creates / updates the safety_alerts Firestore document.

POST /api/v1/notify/sos/resolve
  - Called when the student deactivates SOS.
  - Updates the safety_alerts document status to 'Resolved'.
"""

from flask import Blueprint, request, jsonify
from firebase_admin import firestore, messaging

sos_notify_bp = Blueprint('sos_notify', __name__)

# ─── Helpers ──────────────────────────────────────────────────────────────────

def _send_fcm(token: str, title: str, body: str, data: dict) -> bool:
    """Send a single FCM message. Returns True on success."""
    try:
        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in data.items()},
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='dishi_sos_alerts',
                    sound='default',
                    priority='max',
                    vibrate_timings_millis=[0, 500, 250, 500],
                    color='#F92B60',
                    icon='ic_sos_alert',
                ),
            ),
            apns=messaging.APNSConfig(
                headers={'apns-priority': '10'},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        badge=1,
                        content_available=True,
                    )
                ),
            ),
            token=token,
        )
        messaging.send(msg)
        return True
    except Exception as e:
        print(f"[SOS] FCM send failed for token {token[:10]}...: {e}")
        return False


# ─── Routes ───────────────────────────────────────────────────────────────────

@sos_notify_bp.route('/sos', methods=['POST'])
def trigger_sos():
    """
    Activate SOS: notify all linked parents via FCM and create safety_alerts doc.

    Expected JSON body:
    {
        "student_uid":   "<uid>",
        "student_name":  "Jane Doe",
        "lat":           -1.2921,
        "lng":           36.8219,
        "alert_id":      "<optional — omit to auto-generate>"
    }
    """
    try:
        data = request.get_json(force=True, silent=True) or {}
        student_uid  = data.get('student_uid', '').strip()
        student_name = data.get('student_name', 'Your Student').strip()
        lat          = data.get('lat')
        lng          = data.get('lng')
        alert_id     = data.get('alert_id', '').strip()

        if not student_uid:
            return jsonify({'error': 'student_uid is required'}), 400

        db = firestore.client()

        # 1. Fetch student doc to get linkedParents
        student_ref  = db.collection('users').document(student_uid)
        student_snap = student_ref.get()
        if not student_snap.exists:
            return jsonify({'error': 'Student not found'}), 404

        student_data = student_snap.to_dict()
        linked_parents: list = student_data.get('linkedParents', [])

        if not linked_parents:
            # Still write the alert — no parents yet registered
            pass

        # 2. Build alert document
        location_str = f"{lat:.5f}, {lng:.5f}" if lat is not None and lng is not None else "Unknown"
        alert_payload = {
            'studentUid':   student_uid,
            'studentName':  student_name,
            'status':       'Unresolved',
            'location':     location_str,
            'lat':          lat,
            'lng':          lng,
            'parentUids':   linked_parents,
            'createdAt':    firestore.SERVER_TIMESTAMP,
            'updatedAt':    firestore.SERVER_TIMESTAMP,
        }

        # 3. Write/update safety_alerts document
        alerts_col = db.collection('safety_alerts')
        if alert_id:
            alert_ref = alerts_col.document(alert_id)
            alert_ref.set(alert_payload, merge=True)
        else:
            alert_ref = alerts_col.add(alert_payload)[1]
            alert_id  = alert_ref.id

        # Also store the active alert_id on the student doc so we can resolve it later
        student_ref.set(
            {'activeSosAlertId': alert_id, 'sosActive': True, 'shareLocationWithParents': True},
            merge=True,
        )

        # 4. Notify each parent
        notification_title = f'🚨 SOS Alert — {student_name}'
        notification_body  = f'{student_name} has triggered an emergency SOS! Location: {location_str}'
        fcm_data = {
            'type':         'sos_alert',
            'student_uid':  student_uid,
            'student_name': student_name,
            'alert_id':     alert_id,
            'lat':          str(lat or ''),
            'lng':          str(lng or ''),
        }

        success_count  = 0
        failure_count  = 0
        stale_tokens   = []

        for parent_uid in linked_parents:
            parent_snap = db.collection('users').document(parent_uid).get()
            if not parent_snap.exists:
                continue
            parent_data = parent_snap.to_dict()

            # Write in-app notification to parent's notifications sub-collection too
            db.collection('notifications').add({
                'targetUserId':  parent_uid,
                'title':         notification_title,
                'body':          notification_body,
                'type':          'sos_alert',
                'alertId':       alert_id,
                'studentUid':    student_uid,
                'studentName':   student_name,
                'readBy':        [],
                'dismissedBy':   [],
                'createdAt':     firestore.SERVER_TIMESTAMP,
            })

            fcm_token = parent_data.get('fcmToken', '').strip()
            if not fcm_token:
                failure_count += 1
                continue

            sent = _send_fcm(fcm_token, notification_title, notification_body, fcm_data)
            if sent:
                success_count += 1
            else:
                failure_count += 1
                stale_tokens.append(parent_uid)

        # Optionally clean stale tokens
        for uid in stale_tokens:
            db.collection('users').document(uid).update({'fcmToken': firestore.DELETE_FIELD})

        return jsonify({
            'success':        True,
            'alert_id':       alert_id,
            'parents_count':  len(linked_parents),
            'fcm_sent':       success_count,
            'fcm_failed':     failure_count,
        }), 200

    except Exception as e:
        import traceback
        print(f"[SOS] trigger_sos error: {e}\n{traceback.format_exc()}")
        return jsonify({'error': str(e)}), 500


@sos_notify_bp.route('/sos/resolve', methods=['POST'])
def resolve_sos():
    """
    Deactivate SOS: mark the alert as Resolved and notify parents.

    Expected JSON body:
    {
        "student_uid":  "<uid>",
        "student_name": "Jane Doe",
        "alert_id":     "<optional — will auto-lookup activeSosAlertId if omitted>"
    }
    """
    try:
        data = request.get_json(force=True, silent=True) or {}
        student_uid  = data.get('student_uid', '').strip()
        student_name = data.get('student_name', 'Your Student').strip()
        alert_id     = data.get('alert_id', '').strip()

        if not student_uid:
            return jsonify({'error': 'student_uid is required'}), 400

        db = firestore.client()

        # Look up alert_id if not provided
        if not alert_id:
            student_snap = db.collection('users').document(student_uid).get()
            if student_snap.exists:
                alert_id = student_snap.to_dict().get('activeSosAlertId', '')

        # Update the alert document
        if alert_id:
            db.collection('safety_alerts').document(alert_id).set(
                {
                    'status':    'Resolved',
                    'resolvedAt': firestore.SERVER_TIMESTAMP,
                    'updatedAt':  firestore.SERVER_TIMESTAMP,
                },
                merge=True,
            )

        # Clear the student's sosActive flag
        db.collection('users').document(student_uid).set(
            {'sosActive': False, 'activeSosAlertId': firestore.DELETE_FIELD},
            merge=True,
        )

        # Notify parents that the SOS has been resolved
        student_snap = db.collection('users').document(student_uid).get()
        linked_parents = student_snap.to_dict().get('linkedParents', []) if student_snap.exists else []

        resolution_title = f'✅ SOS Resolved — {student_name}'
        resolution_body  = f'{student_name} has deactivated the SOS. All clear!'
        fcm_data = {
            'type':         'sos_resolved',
            'student_uid':  student_uid,
            'student_name': student_name,
            'alert_id':     alert_id,
        }

        for parent_uid in linked_parents:
            parent_snap = db.collection('users').document(parent_uid).get()
            if not parent_snap.exists:
                continue
            parent_data  = parent_snap.to_dict()

            # In-app notification
            db.collection('notifications').add({
                'targetUserId': parent_uid,
                'title':        resolution_title,
                'body':         resolution_body,
                'type':         'sos_resolved',
                'alertId':      alert_id,
                'studentUid':   student_uid,
                'studentName':  student_name,
                'readBy':       [],
                'dismissedBy':  [],
                'createdAt':    firestore.SERVER_TIMESTAMP,
            })

            fcm_token = parent_data.get('fcmToken', '').strip()
            if fcm_token:
                _send_fcm(fcm_token, resolution_title, resolution_body, fcm_data)

        return jsonify({'success': True, 'alert_id': alert_id}), 200

    except Exception as e:
        import traceback
        print(f"[SOS] resolve_sos error: {e}\n{traceback.format_exc()}")
        return jsonify({'error': str(e)}), 500
