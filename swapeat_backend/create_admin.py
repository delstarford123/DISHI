import firebase_admin
from firebase_admin import credentials, auth, firestore

# Initialize Firebase
cred = credentials.Certificate('../ServiceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

email = 'info@delstarfordworks.co.ke'
password = 'AdminPassword123!'

try:
    # Try to get existing user
    user = auth.get_user_by_email(email)
    print(f"User {email} found. Updating password...")
    auth.update_user(user.uid, password=password)
    uid = user.uid
    print(f"Successfully updated password for {email}.")
except auth.UserNotFoundError:
    print(f"User {email} not found. Creating new admin user...")
    user = auth.create_user(email=email, password=password, display_name="System Admin")
    uid = user.uid
    print(f"Successfully created new admin user {email}.")

# Set admin custom claim for Storage Rules
auth.set_custom_user_claims(uid, {'admin': True})
print("Set admin custom claim for Firebase Auth.")

# Ensure the admin document exists in Firestore to bypass role selection if needed
doc_ref = db.collection('users').document(uid)
admin_fields = {
    'email': email,
    'role': 'admin',          # singular — for legacy checks
    'roles': ['admin'],       # list — for login_view.dart & UserModel routing
    'displayName': 'System Admin',
    'isVerified': True,
    'walletBalance': 0.0,
    'vaultBalance': 0.0,
    'okoaBalance': 0.0,
    'isOffline': False,
}

if not doc_ref.get().exists:
    admin_fields['createdAt'] = firestore.SERVER_TIMESTAMP
    doc_ref.set(admin_fields)
    print("Created Firestore document for admin.")
else:
    doc_ref.update({
        'role': 'admin',
        'roles': ['admin'],
        'displayName': 'System Admin',
        'isVerified': True,
    })
    print("Updated Firestore document with role + roles fields.")

print("\n==============================================")
print("ADMIN LOGIN CREDENTIALS:")
print(f"Email: {email}")
print(f"Password: {password}")
print("==============================================")
