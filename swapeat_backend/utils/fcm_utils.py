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

        # Build the message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data if data else {},
            token=fcm_token,
        )

        # Send the message
        response = messaging.send(message)
        print(f"[FCM] Successfully sent message to {user_id}: {response}")
        return True

    except Exception as e:
        print(f"[FCM] Error sending notification to {user_id}: {e}")
        return False
