import os
from dotenv import load_dotenv

# load .env first
load_dotenv()

# importing app automatically initializes firebase from app.py
import app
from firebase_admin import firestore

db = firestore.client()

def clean_roles():
    users_ref = db.collection('users')
    docs = users_ref.stream()
    
    updated_count = 0
    for doc in docs:
        data = doc.to_dict()
        roles = data.get('roles', [])
        
        # Ensure mutually exclusive roles, prioritize student.
        if isinstance(roles, list) and len(roles) > 1:
            if 'student' in roles:
                new_roles = ['student']
            elif 'parent' in roles:
                new_roles = ['parent']
            elif 'vendor' in roles:
                new_roles = ['vendor']
            else:
                new_roles = [roles[0]] # Just pick the first one
                
            print(f"Updating user {doc.id} from {roles} to {new_roles}")
            doc.reference.update({'roles': new_roles})
            updated_count += 1
            
    print(f"Finished updating {updated_count} users.")

if __name__ == '__main__':
    clean_roles()
