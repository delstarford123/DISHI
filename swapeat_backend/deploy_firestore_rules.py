import os
import json
import requests
from google.oauth2 import service_account
from google.auth.transport.requests import Request

# Find files relative to script directory or current directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(BASE_DIR, '..'))

def find_file(filename):
    for path in [
        os.path.join(ROOT_DIR, filename),
        os.path.join(BASE_DIR, filename),
        os.path.join(os.getcwd(), filename),
    ]:
        if os.path.exists(path):
            return path
    raise FileNotFoundError(f"Cannot find {filename}")

KEY_FILE = find_file('ServiceAccountKey.json')
RULES_FILE = find_file('firestore.rules')

SCOPES = [
    'https://www.googleapis.com/auth/firebase',
    'https://www.googleapis.com/auth/cloud-platform'
]

def deploy():
    print(f"Using Service Account: {KEY_FILE}")
    print(f"Using Rules File: {RULES_FILE}")
    
    creds = service_account.Credentials.from_service_account_file(KEY_FILE, scopes=SCOPES)
    creds.refresh(Request())
    token = creds.token
    print("Authenticated successfully.")

    with open(RULES_FILE, 'r', encoding='utf-8') as f:
        rules_content = f.read()

    project_id = 'swapeat-39f5e'
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }

    # Step 1: Create Ruleset
    print("Creating new ruleset on Firebase Rules API...")
    ruleset_url = f'https://firebaserules.googleapis.com/v1/projects/{project_id}/rulesets'
    payload = {
        'source': {
            'files': [
                {
                    'name': 'firestore.rules',
                    'content': rules_content
                }
            ]
        }
    }
    res = requests.post(ruleset_url, headers=headers, json=payload)
    if res.status_code not in (200, 201):
        print(f"Error creating ruleset: {res.status_code} {res.text}")
        return False

    ruleset_data = res.json()
    ruleset_name = ruleset_data.get('name')
    print(f"Ruleset created successfully: {ruleset_name}")

    # Step 2: Release the ruleset for cloud.firestore
    print("Updating release 'cloud.firestore'...")
    release_name = f'projects/{project_id}/releases/cloud.firestore'
    release_url = f'https://firebaserules.googleapis.com/v1/{release_name}'
    
    release_payload = {
        'release': {
            'name': release_name,
            'rulesetName': ruleset_name
        }
    }
    patch_res = requests.patch(release_url, headers=headers, json=release_payload)
    if patch_res.status_code in (200, 201):
        print(f"SUCCESS! Release updated successfully:")
        print(json.dumps(patch_res.json(), indent=2))
        return True
    
    print(f"PATCH status: {patch_res.status_code} {patch_res.text}")
    return False

if __name__ == '__main__':
    deploy()
