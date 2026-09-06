import requests
import base64
import os
from datetime import datetime

# Load credentials
consumer_key = "OgkAKD4soo5xGVEegeGPvWS9HK3QuRgZYGQXnKmDxVTxnMDG"
consumer_secret = "LXgsZGYdl6kpunxzGuAw4Fi3JK7FtTLqbCK9JZjI6VDR6e93n5mmW8gFKUORhuQQ"
business_short_code = "4050545"
passkey = "f2d5541751a9649a49971680017613ecec69eb7bd886bda8bfb5d07c5d1c2d1f"
phone_number = "254711388658" # Default Safaricom test number, replace if needed

print("1. Generating token...")
auth_url = "https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
r_auth = requests.get(auth_url, auth=(consumer_key, consumer_secret))
access_token = r_auth.json().get("access_token")

print("2. Generating password...")
timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
password_str = business_short_code + passkey + timestamp
password = base64.b64encode(password_str.encode('utf-8')).decode('utf-8')

print("3. Sending STK Push...")
stk_url = "https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest"
headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json"
}
payload = {
    "BusinessShortCode": business_short_code,
    "Password": password,
    "Timestamp": timestamp,
    "TransactionType": "CustomerPayBillOnline",
    "Amount": "1",
    "PartyA": phone_number,
    "PartyB": business_short_code,
    "PhoneNumber": phone_number,
    "CallBackURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/callback",
    "AccountReference": "DISHI",
    "TransactionDesc": "DISHI Top-Up"
}

r_stk = requests.post(stk_url, json=payload, headers=headers)
print(f"Status Code: {r_stk.status_code}")
print(f"Response: {r_stk.text}")
