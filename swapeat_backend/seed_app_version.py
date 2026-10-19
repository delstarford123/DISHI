import os
import firebase_admin
from firebase_admin import credentials, firestore

def seed_version_config():
    if not firebase_admin._apps:
        cred_path = os.path.join(os.path.dirname(__file__), '..', 'ServiceAccountKey.json')
        if not os.path.exists(cred_path):
            cred_path = os.path.join(os.path.dirname(__file__), 'ServiceAccountKey.json')
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        else:
            firebase_admin.initialize_app()
    
    db = firestore.client()
    config = {
        "latest_version_name": "1.0.3",
        "latest_version_code": 4,
        "min_supported_version_code": 3,
        "force_update": False,
        "maintenance_mode": False,
        "maintenance_message": "DISHI is currently upgrading campus servers for a smoother dining experience. We will be back online shortly.",
        "play_store_url": "https://play.google.com/store/apps/details?id=co.ke.delstarfordworks.dishi",
        "supported_api_versions": ["v1", "v2", "v3", "v4", "v5", "v6"],
        "release_notes": "Version 4: Enterprise departments management, enriched fraud & wash trading intelligence with user profiles, automated staff appointment onboarding with official app links, and professional C2B Paybill 4050545 collections engine.",
        "updated_at": firestore.SERVER_TIMESTAMP
    }
    
    db.collection('system_config').document('app_version').set(config, merge=True)
    print("Successfully seeded system_config/app_version:", config)

if __name__ == '__main__':
    seed_version_config()
