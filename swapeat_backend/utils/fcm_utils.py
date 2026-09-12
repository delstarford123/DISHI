import firebase_admin
from firebase_admin import messaging
from firebase_admin import firestore

def send_fcm_notification(user_id: str, title: str, body: str, data: dict = None):
    """
    Retrieves the user's fcmToken from Firestore and sends a push notification via Firebase Admin SDK.
    """
    try:
        db = firestore.client()
        user_doc = db.collection('users').document(user_id).get()
        
        if not user_doc.exists:
            print(f"[FCM] User {user_id} not found.")
            return False

        user_data = user_doc.to_dict()
        fcm_token = user_data.get('fcmToken')

        if not fcm_token:
            print(f"[FCM] User {user_id} does not have an fcmToken registered.")
            return False

        # Prepare data payload (must be strings)
        stringified_data = {k: str(v) for k, v in data.items()} if data else {}

        # Build the message with high-priority Android & APNS config for offline wake-up
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=stringified_data,
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                ttl=86400, # 24 hours offline TTL
                notification=messaging.AndroidNotification(sound='default')
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(content_available=True, sound='default')
                )
            )
        )

        # Send the message
        response = messaging.send(message)
        print(f"[FCM] Successfully sent message to {user_id}: {response}")
        return True

    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"[FCM] Error sending notification to {user_id}: {e}")
        return False
