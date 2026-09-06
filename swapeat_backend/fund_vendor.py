import firebase_admin
from firebase_admin import credentials, auth, firestore

# Initialize Firebase
cred = credentials.Certificate('../ServiceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

email = 'lovi@gmail.com'
fund_amount = 50.0

try:
    user = auth.get_user_by_email(email)
    uid = user.uid
    print(f"Found vendor {email} with UID: {uid}")
    
    doc_ref = db.collection('users').document(uid)
    doc_snap = doc_ref.get()
    
    if doc_snap.exists:
        current_earnings = doc_snap.to_dict().get('vendorEarnings', 0)
        new_earnings = current_earnings + fund_amount
        doc_ref.update({'vendorEarnings': new_earnings})
        print(f"Successfully added Ksh {fund_amount} to {email}'s earnings.")
        print(f"Old Balance: Ksh {current_earnings}")
        print(f"New Balance: Ksh {new_earnings}")
    else:
        # Create document if it doesn't exist just in case
        doc_ref.set({
            'email': email,
            'role': 'vendor',
            'isVerified': True,
            'vendorEarnings': fund_amount,
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        print(f"Created new vendor document and funded with Ksh {fund_amount}.")

except auth.UserNotFoundError:
    print(f"Error: User {email} not found in Firebase Authentication.")
except Exception as e:
    print(f"An error occurred: {e}")
