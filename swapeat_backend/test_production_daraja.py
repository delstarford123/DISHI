import requests
from requests.auth import HTTPBasicAuth

# Your credentials from .env
consumer_key = "OgkAKD4soo5xGVEegeGPvWS9HK3QuRgZYGQXnKmDxVTxnMDG"
consumer_secret = "LXgsZGYdl6kpunxzGuAw4Fi3JK7FtTLqbCK9JZjI6VDR6e93n5mmW8gFKUORhuQQ"

print("==========================================")
print("TESTING DARAJA PRODUCTION CREDENTIALS")
print("==========================================")

prod_url = "https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"

print(f"Connecting to: {prod_url}")
print(f"Using Consumer Key: {consumer_key}")
print(f"Using Consumer Secret: {consumer_secret}\n")

try:
    response = requests.get(prod_url, auth=HTTPBasicAuth(consumer_key, consumer_secret))
    
    print(f"HTTP Status Code: {response.status_code}")
    print(f"Raw Response Text: {response.text}\n")
    
    if response.status_code == 200:
        data = response.json()
        print("✅ SUCCESS: Credentials are valid on Production!")
        print(f"Access Token generated: {data.get('access_token')[:10]}... (truncated)")
    else:
        print("❌ FAILED: Safaricom rejected the credentials on the Production server.")
        print("Possible Reasons:")
        print("  1. The keys are actually Sandbox keys and not yet approved for Go Live.")
        print("  2. The Daraja App has gone live, but Safaricom hasn't fully synced the keys yet (can take 24-48 hours).")
        print("  3. There's a typo in the Consumer Key or Secret.")

except Exception as e:
    print(f"Network Error: {e}")
