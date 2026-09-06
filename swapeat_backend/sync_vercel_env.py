import os
import subprocess
import json

def push_env_var(key, value):
    print(f"Pushing {key} to Vercel (Production, Preview, Development)...")
    for env in ["production", "preview", "development"]:
        try:
            # First remove it
            subprocess.run(
                f"vercel env rm {key} {env} -y",
                shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            # Then add it
            process = subprocess.Popen(
                ["vercel", "env", "add", key, env],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                shell=True
            )
            stdout, stderr = process.communicate(input=value)
            if process.returncode != 0:
                print(f"  Error pushing {key} to {env}: {stderr.strip()}")
            else:
                print(f"  Successfully set {key} for {env}")
        except Exception as e:
            print(f"  Failed: {e}")

print("--- SYNCING ENVIRONMENT VARIABLES TO VERCEL ---")

# 1. Sync Firebase Key
firebase_key_path = "../ServiceAccountKey.json"
if os.path.exists(firebase_key_path):
    with open(firebase_key_path, "r") as f:
        firebase_json = f.read()
    push_env_var("FIREBASE_SERVICE_ACCOUNT_JSON", firebase_json)
else:
    print(f"ERROR: Could not find {firebase_key_path}")

# 2. Sync .env file
if os.path.exists(".env"):
    with open(".env", "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                if "=" in line:
                    key, val = line.split("=", 1)
                    push_env_var(key, val)
else:
    print("ERROR: Could not find .env file")

if "MAIL_PASSWORD" in os.environ:
    push_env_var("MAIL_PASSWORD", os.environ["MAIL_PASSWORD"])
    
if "MPESA_OPERATOR_ID" in os.environ:
    push_env_var("MPESA_OPERATOR_ID", os.environ["MPESA_OPERATOR_ID"])
    
if "MPESA_OPERATOR_PIN" in os.environ:
    push_env_var("MPESA_OPERATOR_PIN", os.environ["MPESA_OPERATOR_PIN"])

print("--- DONE ---")
print("Run 'vercel --prod' now to apply these variables!")
