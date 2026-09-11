import firebase_admin
from firebase_admin import credentials, firestore
import os

try:
    firebase_admin.get_app()
except ValueError:
    # Look for the credentials file
    cred_path = 'swapeat-39f5e-firebase-adminsdk-hbg7q-29215cb86b.json'
    if not os.path.exists(cred_path):
        # try the old one or just search
        cred_path = 'firebase_credentials.json'
    if not os.path.exists(cred_path):
        # find json file in current dir that starts with swapeat
        for f in os.listdir('.'):
            if f.endswith('.json') and 'firebase-adminsdk' in f:
                cred_path = f
                break

    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

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
