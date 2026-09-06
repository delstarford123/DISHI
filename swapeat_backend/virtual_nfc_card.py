import requests
import json
import time
import hmac
import hashlib

# -------------------------------------------------------------
# 💳 VIRTUAL NFC CARD EMULATOR (Testing Tool)
# -------------------------------------------------------------
# This script emulates the Swapeat Vendor POS App scanning
# a student's NFC card and sending the payload to the backend.
# -------------------------------------------------------------

# Configuration
BACKEND_URL = "https://dishi.delstarfordworks.co.ke/api/v1/transaction/charge"
VENDOR_SECRET = "super-secret-vendor-key"

# The Virtual Card Data
# This MUST match the 'uid' of the student document in your database.
VIRTUAL_CARD_UID = "04:AA:BB:CC:DD:EE"
VENDOR_ID = "VEND-1024"

def generate_hmac_signature(payload_json: str, secret: str) -> str:
    """Mirrors the SecurityEngine.generateHMACPayload() from Flutter"""
    secret_bytes = secret.encode('utf-8')
    payload_bytes = payload_json.encode('utf-8')
    signature = hmac.new(secret_bytes, payload_bytes, hashlib.sha256).hexdigest()
    return signature

def tap_card(amount: float):
    print("="*50)
    print(f"📡 [NFC SCAN] Virtual Card Tapped!")
    print(f"💳 UID: {VIRTUAL_CARD_UID}")
    print(f"💰 Amount to charge: {amount} KSH")
    print("="*50)

    # 1. Build Payload exactly like `nfc_controller.dart`
    tx_id = str(int(time.time() * 1000)) # Millisecond timestamp
    timestamp = time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime())
    
    payload = {
        "uid": VIRTUAL_CARD_UID,
        "amount": amount,
        "vendorId": VENDOR_ID,
        "txId": tx_id,
        "timestamp": timestamp
    }

    # 2. Sign Payload
    payload_json = json.dumps(payload, separators=(',', ':'))
    signature = generate_hmac_signature(payload_json, VENDOR_SECRET)
    
    # Attach signature to the payload object
    payload["signature"] = signature

    # 3. Send to Backend
    print("🚀 Sending transaction to backend...")
    try:
        response = requests.post(
            BACKEND_URL,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=5
        )
        
        # 4. Handle Response
        if response.status_code == 200:
            result = response.json()
            student = result.get('student', {})
            print("\n✅ TRANSACTION SUCCESSFUL")
            print(f"👤 Student: {student.get('name')}")
            print(f"💵 Remaining Balance: {student.get('remainingBalance')} KSH")
            if student.get('usedOkoa'):
                print(f"⚠️ Okoa Food Credit Used!")
        else:
            print("\n❌ TRANSACTION FAILED")
            print(f"Status Code: {response.status_code}")
            try:
                err_data = response.json()
                print(f"Error: {err_data.get('error', 'Unknown Error')}")
                if 'details' in err_data:
                    print(f"Details: {err_data['details']}")
                if 'trace' in err_data:
                    print(f"Trace:\n{err_data['trace']}")
            except:
                print(f"Response: {response.text}")
                
    except requests.exceptions.ConnectionError:
        print("\n❌ CONNECTION ERROR: Ensure your device has internet access and the Vercel backend is live!")

if __name__ == "__main__":
    import sys
    
    # Allow passing amount via command line, default to 50 KSH
    charge_amount = 50.0
    if len(sys.argv) > 1:
        try:
            charge_amount = float(sys.argv[1])
        except ValueError:
            print("Invalid amount provided. Using default 50.0")

    tap_card(charge_amount)
