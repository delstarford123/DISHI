import socket

domains = ["delstarfordworks.co.ke", "mail.delstarfordworks.co.ke"]
for d in domains:
    try:
        ip = socket.gethostbyname(d)
        print(f"DNS Resolution: {d} -> {ip}")
    except Exception as e:
        print(f"DNS Resolution FAILED for {d}: {e}")

# Test common ports
target_host = "mail.delstarfordworks.co.ke"
ports = [25, 465, 587, 2525, 80, 443, 2082, 2083, 2095, 2096]
print(f"\nChecking port connectivity on {target_host}...")
for p in ports:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(4)
    try:
        s.connect((target_host, p))
        print(f"Port {p}: OPEN / REACHABLE!")
        s.close()
    except Exception as e:
        print(f"Port {p}: CLOSED/TIMEOUT ({type(e).__name__})")
