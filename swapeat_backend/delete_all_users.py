import os
from dotenv import load_dotenv

load_dotenv()
import app
from firebase_admin import firestore, auth

db = firestore.client()

def delete_all_users():
    # 1. Delete from Firestore users collection
    users_ref = db.collection('users')
    docs = users_ref.stream()
    
    firestore_count = 0
    for doc in docs:
        doc.reference.delete()
        firestore_count += 1
    
    print(f"Deleted {firestore_count} users from Firestore 'users' collection.")
    
    # 2. Delete from Firebase Auth
    auth_count = 0
    try:
        page = auth.list_users()
        while page:
            for user in page.users:
                auth.delete_user(user.uid)
                auth_count += 1
            # Get next page
            page = page.get_next_page()
            
        print(f"Deleted {auth_count} users from Firebase Auth.")
    except Exception as e:
        print(f"Error deleting from auth: {e}")

if __name__ == '__main__':
    delete_all_users()
