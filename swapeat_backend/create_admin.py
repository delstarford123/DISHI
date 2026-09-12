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
if not doc_ref.get().exists:
    doc_ref.set({
        'email': email,
        'role': 'admin',
        'isVerified': True,
        'displayName': 'System Admin',
        'createdAt': firestore.SERVER_TIMESTAMP
    })
    print("Created Firestore document for admin.")
else:
    doc_ref.update({'role': 'admin'})
    print("Updated Firestore document role to admin.")

print("\n==============================================")
print("ADMIN LOGIN CREDENTIALS:")
print(f"Email: {email}")
print(f"Password: {password}")
print("==============================================")
