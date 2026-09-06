import firebase_admin, os
from firebase_admin import credentials, firestore

cred = credentials.Certificate('swapeat-7ff8a-firebase-adminsdk-fbsvc-d38df8fcd8.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

print("--- B2B ---")
docs = db.collection('b2b_transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(3).stream()
for d in docs:
    print(d.id, d.to_dict())

print("\n--- Vendor Withdrawals ---")
docs2 = db.collection('vendor_withdrawals').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(3).stream()
for d in docs2:
    print(d.id, d.to_dict())
