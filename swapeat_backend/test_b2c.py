import os
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# 1. Generate Access Token
consumer_key = os.getenv('MPESA_CONSUMER_KEY')
consumer_secret = os.getenv('MPESA_CONSUMER_SECRET')
env = os.getenv('MPESA_ENV', 'sandbox').lower()
base_url = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"

api_url = f"{base_url}/oauth/v1/generate?grant_type=client_credentials"
response = requests.get(api_url, auth=(consumer_key, consumer_secret))

if response.status_code == 200:
    access_token = response.json().get('access_token')
    print("Access token generated successfully.")
else:
    print(f"Failed to get access token: {response.text}")
    exit(1)

# 2. Make B2C Request
operator_id = os.getenv('MPESA_OPERATOR_ID', 'OI')
shortcode = os.getenv('MPESA_SHORTCODE', '4050545')
security_credential = os.getenv("SECURITY_CREDENTIAL")

phone_number = "254707605751"
amount = "2"

headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json"
}

payload = {
    "InitiatorName": operator_id,
    "SecurityCredential": security_credential,
    "CommandID": "BusinessPayment",
    "Amount": amount,
    "PartyA": shortcode,
    "PartyB": phone_number,
    "Remarks": "DISHI Test Withdrawal",
    "QueueTimeOutURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2c_timeout",
    "ResultURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2c_result",
    "Occasion": "WithdrawalTest"
}

b2c_url = f"{base_url}/mpesa/b2c/v1/paymentrequest"

print("Sending B2C Request to Daraja...")
b2c_response = requests.post(b2c_url, json=payload, headers=headers)

print(f"B2C Response [{b2c_response.status_code}]: {b2c_response.text}")
