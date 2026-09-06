import requests
import json

try:
    response = requests.get("https://dishi.delstarfordworks.co.ke/debug-firebase", timeout=10)
    print("=== FIREBASE DEBUG INFO ===")
    print(json.dumps(response.json(), indent=2))
except Exception as e:
    print(f"Error calling debug route: {e}")
