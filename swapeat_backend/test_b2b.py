import os
import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

# Load the environment variables from .env
load_dotenv('.env')

def generate_access_token():
    consumer_key = os.getenv('MPESA_CONSUMER_KEY')
    consumer_secret = os.getenv('MPESA_CONSUMER_SECRET')
    env_mpesa = os.getenv('MPESA_ENV', 'sandbox').lower()
    
    safaricom_url = "https://api.safaricom.co.ke" if env_mpesa == 'production' else "https://sandbox.safaricom.co.ke"
    api_URL = f"{safaricom_url}/oauth/v1/generate?grant_type=client_credentials"

    try:
        r = requests.get(api_URL, auth=HTTPBasicAuth(consumer_key, consumer_secret), timeout=15)
        r.raise_for_status()
        return r.json().get('access_token')
    except Exception as e:
        print("Failed to get Access Token:", str(e))
        return None

def test_b2b_withdrawal():
    print("--- Starting Daraja B2B Test ---")
    access_token = generate_access_token()
    if not access_token:
        print("Error: Could not get access token. Check your Consumer Key & Secret.")
        return

    print("Access Token Generated Successfully!")

    # Gather credentials
    initiator_name = os.getenv('DARAJA_INITIATOR_NAME', 'Delstarford Api')
    security_credential = os.getenv("SECURITY_CREDENTIAL")
    shortcode = os.getenv('MPESA_SHORTCODE', os.getenv('MPESA_BUSINESS_SHORT_CODE', '4050545'))
    env_mpesa = os.getenv('MPESA_ENV', 'sandbox').lower()
    safaricom_url = "https://api.safaricom.co.ke" if env_mpesa == 'production' else "https://sandbox.safaricom.co.ke"

    # Please change target_till to a valid BuyGoods Till number you want to test!
    target_till = input("Enter target Buy Goods Till Number (e.g. 123456): ").strip()
    if not target_till:
        print("You must enter a till number to test.")
        return

    amount = "10" # Sending Ksh 10 for test
    command_id = "BusinessBuyGoods"

    payload = {
        "Initiator": initiator_name,
        "InitiatorName": initiator_name,
        "SecurityCredential": security_credential,
        "CommandID": command_id,
        "SenderIdentifierType": "4",
        "RecieverIdentifierType": "4",
        "Amount": amount,
        "PartyA": shortcode,
        "PartyB": target_till,
        "AccountReference": "DISHI",
        "Remarks": "Test B2B Withdrawal",
        "QueueTimeOutURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2b_timeout",
        "ResultURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2b_result",
    }

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    url = f"{safaricom_url}/mpesa/b2b/v1/paymentrequest"
    
    print(f"\nSending {command_id} of Ksh {amount} from {shortcode} to {target_till}...")
    print(f"Endpoint: {url}")
    print(f"Initiator: {initiator_name}")
    print(f"SecurityCredential starts with: {security_credential[:15]}...")
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=15)
        print("\n--- RESPONSE FROM SAFARICOM ---")
        print("Status Code:", response.status_code)
        print("Response JSON:", response.text)
        
        if response.status_code == 200:
            print("\nSUCCESS: Daraja accepted the payload! The transaction should process asynchronously.")
        else:
            print("\nERROR: Daraja rejected the payload! Read the error message above.")
            
    except Exception as e:
        print(f"\nRequest failed: {e}")

if __name__ == "__main__":
    test_b2b_withdrawal()
