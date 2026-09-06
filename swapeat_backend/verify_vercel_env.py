import subprocess
import os

print("Pulling Vercel env vars...")
try:
    # Run vercel env pull to download the production env vars from vercel
    process = subprocess.Popen(
        "vercel env pull .env.vercel --environment=production --yes",
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = process.communicate()
    print("STDOUT:", stdout)
    print("STDERR:", stderr)
    
    if os.path.exists(".env.vercel"):
        print("\n--- CONTENTS OF VERCEL ENV ---")
        with open(".env.vercel", "r") as f:
            for line in f:
                if "MPESA" in line:
                    print(line.strip())
    else:
        print("Failed to download .env.vercel from Vercel.")
        
except Exception as e:
    print("Error:", e)
