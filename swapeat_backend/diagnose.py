import os
import sys
import glob

def find_cpanel_domain_root():
    print("=" * 60)
    print("      CPANEL DOMAIN & DOCUMENT ROOT DISCOVERY")
    print("=" * 60)
    
    # 1. Check directories in /home1/farmerma
    print("[1] Top-level folders in /home1/farmerma:")
    try:
        items = os.listdir("/home1/farmerma")
        for item in sorted(items):
            p = os.path.join("/home1/farmerma", item)
            is_d = os.path.isdir(p)
            print(f"    {'[DIR]' if is_d else '[FILE]'} {item}")
    except Exception as e:
        print(f"    Error: {e}")
    print()

    # 2. Check contents of /home1/farmerma/public_html
    print("[2] Folders in /home1/farmerma/public_html:")
    try:
        p_items = os.listdir("/home1/farmerma/public_html")
        for item in sorted(p_items):
            p = os.path.join("/home1/farmerma/public_html", item)
            is_d = os.path.isdir(p)
            print(f"    {'[DIR]' if is_d else '[FILE]'} {item}")
    except Exception as e:
        print(f"    Error: {e}")
    print()

    # 3. Check for cPanel userdata configuration for dishi
    print("[3] Searching for cPanel domain mapping:")
    userdata_patterns = [
        "/var/cpanel/userdata/farmerma/*",
        "/etc/userdatadomains",
        "/home1/farmerma/.cpanel/*"
    ]
    for pat in userdata_patterns:
        for f in glob.glob(pat):
            if "dishi" in f or "delstarford" in f:
                print(f"    Found config: {f}")
                try:
                    with open(f, "r", encoding="utf-8", errors="replace") as cf:
                        for line in cf:
                            if "documentroot" in line.lower() or "dishi" in line.lower():
                                print(f"      {line.strip()}")
                except Exception as e:
                    pass
    print()

    print("=" * 60)

if __name__ == "__main__":
    find_cpanel_domain_root()
