import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

key_path = "C:\\Users\\Delstaford\\swapeat\\ServiceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()

users = db.collection('users').get()
output = []
for user in users:
    data = user.to_dict()
    output.append(f"UID: {user.id}, Balance: {data.get('walletBalance')}, Name: {data.get('name')}")

with open("C:\\Users\\Delstaford\\swapeat\\swapeat_backend\\users_dump.txt", "w") as f:
    f.write("\n".join(output))
