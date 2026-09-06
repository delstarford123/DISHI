import firebase_admin
from firebase_admin import credentials, firestore
import os

# Initialize Firebase Admin using the existing service account key
cred = credentials.Certificate("../ServiceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

# Our Virtual NFC Card UID
TEST_UID = "04:AA:BB:CC:DD:EE"

# Define the test student data
student_data = {
    "displayName": "Test Student (Virtual Card)",
    "swapeatCode": "SWP-TEST-001",
    "walletBalance": 200.0,
    "isFrozen": False,
    "okoaFoodEligible": True,
    "email": "teststudent@swapeat.com"
}

# Add or update the user document matching the UID
doc_ref = db.collection('users').document(TEST_UID)
doc_ref.set(student_data)

print(f"Successfully created test student in Firestore!")
print(f"UID: {TEST_UID}")
print(f"Wallet Balance: 200 KSH")
