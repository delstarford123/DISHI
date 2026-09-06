import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import os

key_path = "C:\\Users\\Delstaford\\swapeat\\ServiceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()

TEST_UID = '04:AA:BB:CC:DD:EE'

doc_ref = db.collection('users').document(TEST_UID)
doc = doc_ref.get()

if doc.exists:
    data = doc.to_dict()
    print(f"Name: {data.get('name')}")
    print(f"UID: {data.get('uid')}")
    print(f"Remaining Balance: {data.get('walletBalance')} KSH")
else:
    print("User not found!")
