import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Test cPanel UAPI / JSON API on port 2083
url = "https://mail.delstarfordworks.co.ke:2083/execute/Email/list_pops"
username = "dishi@delstarfordworks.co.ke"
password = "dishi@delstarfordworks.co.ke"

print("Testing cPanel UAPI on port 2083...")
try:
    res = requests.get(url, auth=(username, password), verify=False, timeout=10)
    print(f"Status Code: {res.status_code}")
    print(f"Response: {res.text[:300]}")
except Exception as e:
    print(f"cPanel API error: {e}")

# Test webmail login
url_webmail = "https://mail.delstarfordworks.co.ke:2096/login"
print("\nTesting Webmail on port 2096...")
try:
    res2 = requests.post(url_webmail, data={'user': username, 'pass': password}, verify=False, timeout=10)
    print(f"Webmail Status: {res2.status_code}")
    print(f"Webmail Response: {res2.text[:300]}")
except Exception as e:
    print(f"Webmail error: {e}")
