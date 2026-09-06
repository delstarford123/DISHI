import requests
from requests.auth import HTTPBasicAuth

consumer_key = "OgkAKD4soo5xGVEegeGPvWS9HK3QuRgZYGQXnKmDxVTxnMDG"
consumer_secret = "LXgsZGYdl6kpunxzGuAw4Fi3JK7FtTLqbCK9JZjI6VDR6e93n5mmW8gFKUORhuQQ"

sandbox_url = "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
r1 = requests.get(sandbox_url, auth=HTTPBasicAuth(consumer_key, consumer_secret))

prod_url = "https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
r2 = requests.get(prod_url, auth=HTTPBasicAuth(consumer_key, consumer_secret))

with open("daraja_result.txt", "w") as f:
    f.write(f"SANDBOX STATUS: {r1.status_code}\n")
    f.write(f"SANDBOX BODY: {r1.text}\n\n")
    f.write(f"PROD STATUS: {r2.status_code}\n")
    f.write(f"PROD BODY: {r2.text}\n")
