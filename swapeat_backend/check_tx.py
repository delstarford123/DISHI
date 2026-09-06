import os
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
cred = credentials.Certificate('firebase_admin.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Fetch latest mpesa_transactions
print("Fetching last 5 mpesa_transactions:")
docs = db.collection('mpesa_transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(5).get()
for doc in docs:
    data = doc.to_dict()
    print(f"ID: {doc.id}, amount: {data.get('amount')}, destination: {data.get('destination')}, status: {data.get('status')}")

