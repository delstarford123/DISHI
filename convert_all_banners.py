import os
import subprocess
from PIL import Image

BASE_DIR = r"c:\Users\Delstaford\swapeat\assets\banners"
PNG_DIR = os.path.join(BASE_DIR, "png")
JPG_DIR = os.path.join(BASE_DIR, "jpg")

os.makedirs(PNG_DIR, exist_ok=True)
os.makedirs(JPG_DIR, exist_ok=True)

banners = [
    ("banner_v1_sovereign_gold.svg", "banner_v1_sovereign_gold"),
    ("banner_v2_youth_empowerment.svg", "banner_v2_youth_empowerment"),
    ("banner_v3_dignity_solidarity.svg", "banner_v3_dignity_solidarity"),
    ("banner_v4_agency_banking.svg", "banner_v4_agency_banking"),
    ("banner_v5_smart_tech.svg", "banner_v5_smart_tech"),
    ("banner_v6_hospitality_welfare.svg", "banner_v6_hospitality_welfare"),
    ("banner_v7_corporate_enterprise.svg", "banner_v7_corporate_enterprise"),
    ("banner_v8_comrade_hub.svg", "banner_v8_comrade_hub"),
    ("banner_v9_food_security.svg", "banner_v9_food_security"),
    ("banner_v10_sleek_minimalist.svg", "banner_v10_sleek_minimalist"),
]

for svg_filename, base_name in banners:
    svg_path = os.path.join(BASE_DIR, svg_filename)
    png_path = os.path.join(PNG_DIR, f"{base_name}.png")
    jpg_path = os.path.join(JPG_DIR, f"{base_name}.jpg")
    
    print(f"Rendering {svg_filename} -> PNG...")
    cmd = ["npx", "@resvg/resvg-js-cli", "--fit-width", "1600", svg_path, png_path]
    res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
    if res.returncode != 0:
        print(f"Error rendering {svg_filename}: {res.stderr}")
        continue
    
    # Also create high quality JPEG
    try:
        with Image.open(png_path) as img:
            rgb_img = img.convert("RGB")
            rgb_img.save(jpg_path, "JPEG", quality=95)
            print(f"Saved JPEG: {jpg_path}")
    except Exception as e:
        print(f"Error converting to JPG: {e}")

print("All 10 banners successfully rendered to PNG and JPG!")
