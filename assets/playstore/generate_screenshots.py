import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

out_dir = r'C:\Users\Delstaford\swapeat\assets\playstore\screenshots'
os.makedirs(out_dir, exist_ok=True)
font_path = r'C:\Users\Delstaford\swapeat\assets\fonts\Outfit\Outfit-VariableFont_wght.ttf'

font_header = ImageFont.truetype(font_path, 58)
font_sub = ImageFont.truetype(font_path, 32)
font_card_title = ImageFont.truetype(font_path, 34)
font_card_body = ImageFont.truetype(font_path, 26)
font_badge = ImageFont.truetype(font_path, 22)

screens = [
    {
        'num': 1,
        'title': 'Campus Dining, Reimagined',
        'sub': 'Pre-order meals & skip cafeteria queues',
        'badge': 'INSTANT PRE-ORDERS',
        'card_title': 'Tech Cafeteria - Today\'s Special',
        'items': ['Beef Stew & Fragrant Rice - KES 180', 'Swahili Pilau & Kachumbari - KES 220', 'Chapati & Yellow Beans - KES 90'],
        'accent': (5, 213, 170)
    },
    {
        'num': 2,
        'title': 'Instant M-PESA Top-Up',
        'sub': 'Seamless Daraja integration & meal swipes',
        'badge': 'ZERO-FEE STUDENT WALLET',
        'card_title': 'DISHI Student Wallet',
        'items': ['Available Balance: KES 1,500.00', 'Active Meal Swipes: 10 Swipes', 'Last Top-Up: +KES 500 via M-PESA'],
        'accent': (59, 130, 246)
    },
    {
        'num': 3,
        'title': 'Virtual NFC Dining Card',
        'sub': 'Tap or scan QR at any cafeteria terminal',
        'badge': 'CONTACTLESS CHECKOUT',
        'card_title': 'Digital Student ID Card',
        'items': ['Student ID: TU/2026/CS/084', 'Biometric / PIN Secured', 'Offline Meal Validation Active'],
        'accent': (249, 43, 96)
    },
    {
        'num': 4,
        'title': 'Campus Vendor Map & Delivery',
        'sub': 'Live vendor locations & hostel drops',
        'badge': 'CAMPUS NAVIGATION',
        'card_title': 'Nearby Dining Hubs',
        'items': ['Main Mess Dining Hall (120m away)', 'Student Centre Food Court (250m)', 'Green Canteen - Open Now'],
        'accent': (255, 111, 0)
    }
]

logo = Image.open(r'C:\Users\Delstaford\swapeat\assets\img\dishi_logo.png').convert('RGBA')

for s in screens:
    img = Image.new('RGBA', (1080, 1920), (8, 12, 20, 255))
    draw = ImageDraw.Draw(img)
    
    for y in range(1920):
        r = int(8 + 8 * (y / 1920))
        g = int(12 + 12 * (y / 1920))
        b = int(20 + 22 * (y / 1920))
        draw.line([(0, y), (1080, y)], fill=(r, g, b, 255))
        
    glow = Image.new('RGBA', (1080, 1920), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    acc = s['accent']
    gdraw.ellipse([540 - 400, 960 - 400, 540 + 400, 960 + 400], fill=(acc[0], acc[1], acc[2], 26))
    glow = glow.filter(ImageFilter.GaussianBlur(100))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)
    
    b_text = s['badge']
    bbox = font_badge.getbbox(b_text)
    bw = bbox[2] - bbox[0] + 36
    bh = 44
    bx = (1080 - bw) // 2
    by = 130
    draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=22, fill=(20, 28, 45, 230), outline=(acc[0], acc[1], acc[2], 120))
    draw.text((bx + 18, by + 10), b_text, font=font_badge, fill=acc)
    
    t_text = s['title']
    t_box = font_header.getbbox(t_text)
    draw.text(((1080 - (t_box[2] - t_box[0])) // 2, 205), t_text, font=font_header, fill=(255, 255, 255))
    
    s_text = s['sub']
    s_box = font_sub.getbbox(s_text)
    draw.text(((1080 - (s_box[2] - s_box[0])) // 2, 285), s_text, font=font_sub, fill=(148, 163, 184))
    
    fx = 100
    fy = 420
    fw = 880
    fh = 1340
    draw.rounded_rectangle([fx + 10, fy + 15, fx + fw + 10, fy + fh + 15], radius=54, fill=(0, 0, 0, 180))
    draw.rounded_rectangle([fx, fy, fx + fw, fy + fh], radius=50, fill=(15, 22, 38), outline=(acc[0], acc[1], acc[2], 90), width=4)
    draw.rounded_rectangle([fx + 340, fy + 24, fx + 540, fy + 38], radius=7, fill=(35, 45, 65))
    
    draw.text((fx + 50, fy + 80), 'DISHI Campus', font=font_card_title, fill=(255, 255, 255))
    l_small = logo.resize((70, 70), Image.Resampling.LANCZOS)
    img.paste(l_small, (fx + fw - 120, fy + 70), l_small)
    draw = ImageDraw.Draw(img)
    
    draw.rounded_rectangle([fx + 40, fy + 180, fx + fw - 40, fy + 480], radius=28, fill=(22, 32, 53), outline=(acc[0], acc[1], acc[2], 60))
    draw.text((fx + 70, fy + 215), s['card_title'], font=font_card_title, fill=acc)
    
    cy = fy + 290
    for item in s['items']:
        draw.text((fx + 70, cy), f'{item}', font=font_card_body, fill=(220, 230, 245))
        cy += 55
        
    draw.rounded_rectangle([fx + 40, fy + 520, fx + fw - 40, fy + 800], radius=28, fill=(22, 32, 53), outline=(255, 255, 255, 25))
    draw.text((fx + 70, fy + 555), 'Live Campus Status', font=font_card_title, fill=(255, 255, 255))
    draw.text((fx + 70, fy + 625), '•  M-PESA Daraja 2.0 Gateway: Online', font=font_card_body, fill=(5, 213, 170))
    draw.text((fx + 70, fy + 685), '•  Dining Swipes Sync: Instant', font=font_card_body, fill=(220, 230, 245))
    draw.text((fx + 70, fy + 745), '•  Encrypted PIN & Biometric Storage', font=font_card_body, fill=(148, 163, 184))
    
    draw.rounded_rectangle([fx + 50, fy + fh - 140, fx + fw - 50, fy + fh - 50], radius=24, fill=acc)
    btn_text = 'Open DISHI App'
    btn_bbox = font_card_title.getbbox(btn_text)
    draw.text((fx + (fw - (btn_bbox[2] - btn_bbox[0])) // 2, fy + fh - 105), btn_text, font=font_card_title, fill=(8, 12, 20))
    
    n = s['num']
    out_path = os.path.join(out_dir, f'screenshot_{n}.png')
    img = img.convert('RGB')
    img.save(out_path, 'PNG')
    print(f'Saved {out_path}')

print('All 4 Google Play screenshots created successfully!')
