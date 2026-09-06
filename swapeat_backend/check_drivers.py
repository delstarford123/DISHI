import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

firebase_admin.initialize_app()
db = firestore.client()

drivers = db.collection('users').where('isDriver', '==', True).stream()

print("Drivers with isDriver == True:")
count = 0
for d in drivers:
    print(d.id, d.to_dict().get('displayName'), d.to_dict().get('isOnline'))
    count += 1

print(f"Total: {count}")
