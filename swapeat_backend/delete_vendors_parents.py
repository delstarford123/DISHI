import os
from dotenv import load_dotenv

load_dotenv()
import app
from firebase_admin import firestore

db = firestore.client()

def delete_users():
    users_ref = db.collection('users')
    docs = users_ref.stream()
    
    deleted_count = 0
    for doc in docs:
        data = doc.to_dict()
        roles = data.get('roles', [])
        
        if isinstance(roles, list) and ('vendor' in roles or 'parent' in roles):
            print(f"Deleting user {doc.id} with roles {roles}")
            doc.reference.delete()
            deleted_count += 1
            
    print(f"Finished deleting {deleted_count} users.")

if __name__ == '__main__':
    delete_users()
