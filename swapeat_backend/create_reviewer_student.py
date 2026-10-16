import firebase_admin
from firebase_admin import credentials, auth, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('../ServiceAccountKey.json')
    firebase_admin.initialize_app(cred)
db = firestore.client()

email = 'reviewer.student@dishi.com'
password = 'ReviewerStudent2026!'
pin = '1234'
name = 'Google Play Reviewer'

try:
    user = auth.get_user_by_email(email)
    print(f"User {email} found. Updating credentials...")
    auth.update_user(user.uid, password=password, display_name=name)
    uid = user.uid
except auth.UserNotFoundError:
    print(f"Creating new test student user {email}...")
    user = auth.create_user(email=email, password=password, display_name=name)
    uid = user.uid

doc_ref = db.collection('users').document(uid)
student_fields = {
    'uid': uid,
    'email': email,
    'displayName': name,
    'name': name,
    'role': 'student',
    'roles': ['student'],
    'pin': pin,
    'walletBalance': 1500.0,
    'vaultBalance': 200.0,
    'okoaBalance': 0.0,
    'diningSwipes': 10,
    'isVerified': True,
    'isOffline': False,
    'campus': 'Main Campus',
    'course': 'Software Engineering',
    'dishiCoins': 350,
    'streakDays': 7,
    'pushNotifications': True,
    'ghostMode': False,
}

doc = doc_ref.get()
if not doc.exists:
    student_fields['createdAt'] = firestore.SERVER_TIMESTAMP
    doc_ref.set(student_fields)
    print("Created Firestore document for reviewer student.")
else:
    doc_ref.set(student_fields, merge=True)
    print("Updated Firestore document for reviewer student.")

print("\n==============================================")
print("GOOGLE PLAY REVIEWER CREDENTIALS READY:")
print(f"Email: {email}")
print(f"Password: {password}")
print(f"Security PIN: {pin}")
print(f"Role: student")
print(f"Pre-loaded Wallet: KES 1,500.00")
print(f"Pre-loaded Dining Swipes: 10")
print("==============================================")
