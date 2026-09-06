import os
import json
import re
import firebase_admin
from firebase_admin import credentials, firestore

try:
    with open('.env.local', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract everything after FIREBASE_SERVICE_ACCOUNT_JSON=" up to the next line that looks like a new env var
    match = re.search(r'FIREBASE_SERVICE_ACCOUNT_JSON="(\{.*?\})"\n[A-Z_]+=', content, re.DOTALL)
    if not match:
        # try without the next env var
        match = re.search(r'FIREBASE_SERVICE_ACCOUNT_JSON="(\{.*?\})"', content, re.DOTALL)
        
    if not match:
        print("Regex failed to find JSON")
        exit(1)
        
    raw_json = match.group(1)
    # The JSON string has raw \r\n and \n in it, we need to handle them carefully.
    # It also has literal \n inside the private key.
    # Let's just pass the raw json string into json.loads after replacing \r\n with spaces (except in private key)
    
    # Actually, a simpler way: the raw_json string has actual unescaped quotes if Vercel dumped it wrong,
    # but looking at the file it seems it's just standard JSON with a few weird newlines.
    
    clean_json = raw_json.replace('\\r\\n', '\\n')
    creds_dict = json.loads(clean_json)
    
    if 'private_key' in creds_dict:
        creds_dict['private_key'] = creds_dict['private_key'].replace('\\n', '\n')
        
    cred = credentials.Certificate(creds_dict)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    print("\n=== LATEST B2C TRANSACTIONS (Personal / Pochi) ===")
    b2c_docs = db.collection('b2c_transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(3).stream()
    for d in b2c_docs:
        data = d.to_dict()
        print(f"ID: {d.id} | Status: {data.get('status')} | ResultCode: {data.get('result_code')}")
        result_node = data.get('Result', {})
        if result_node:
            print(f"Safaricom Error: {result_node.get('ResultDesc')}")
        else:
            print("No Result node found (was it cancelled?)")
        print("-")

    print("\n=== LATEST B2B TRANSACTIONS (Paybill / Till) ===")
    b2b_docs = db.collection('b2b_transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(3).stream()
    for d in b2b_docs:
        data = d.to_dict()
        print(f"ID: {d.id} | Status: {data.get('status')} | ResultCode: {data.get('result_code')}")
        result_node = data.get('Result', {})
        if result_node:
            print(f"Safaricom Error: {result_node.get('ResultDesc')}")
        else:
            print("No Result node found")
        print("-")

except Exception as e:
    print(f"Error occurred: {e}")
