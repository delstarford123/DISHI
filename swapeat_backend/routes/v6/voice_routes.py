import re
import time
import random
import datetime
from flask import Blueprint, request, jsonify
from firebase_admin import firestore

voice_v6_bp = Blueprint('voice_v6_bp', __name__)

NUMBER_MAP = {
    'moja': 1, 'one': 1,
    'mbili': 2, 'two': 2,
    'tatu': 3, 'three': 3,
    'nne': 4, 'four': 4,
    'tano': 5, 'five': 5,
    'sita': 6, 'six': 6,
    'saba': 7, 'seven': 7,
    'nane': 8, 'eight': 8,
    'tisa': 9, 'nine': 9,
    'kumi': 10, 'ten': 10,
    'kumi na tano': 15, 'fifteen': 15,
    'ishirini': 20, 'twenty': 20,
    'hamsini': 50, 'fifty': 50,
    'mia moja': 100, 'one hundred': 100,
    'mia mbili': 200, 'two hundred': 200,
    'mia tatu': 300, 'three hundred': 300,
    'mia nne': 400, 'four hundred': 400,
    'mia tano': 500, 'five hundred': 500,
    'elfu moja': 1000, 'one thousand': 1000,
    'elfu mbili': 2000, 'two thousand': 2000,
    'elfu tatu': 3000, 'three thousand': 3000,
    'elfu nne': 4000, 'four thousand': 4000,
    'elfu tano': 5000, 'five thousand': 5000,
    'elfu kumi': 10000, 'ten thousand': 10000,
}

MENU_ITEMS_CATALOG = {
    'chapati': {'name': 'Chapati Fupi Soft', 'price': 25.0, 'aliases': ['chapo', 'chapati', 'chapatti']},
    'madondo': {'name': 'Madondo (Yellow Beans)', 'price': 50.0, 'aliases': ['madondo', 'beans', 'maharagwe', 'dondo']},
    'beef': {'name': 'Beef Stew', 'price': 120.0, 'aliases': ['beef', 'nyama', 'beef stew', 'ng\'ombe']},
    'chicken': {'name': 'Fried Chicken (Quarter)', 'price': 150.0, 'aliases': ['chicken', 'kuku']},
    'rice': {'name': 'Steamed Rice', 'price': 40.0, 'aliases': ['rice', 'wali', 'pishori']},
    'ugali': {'name': 'White Ugali', 'price': 30.0, 'aliases': ['ugali', 'sembe']},
    'sukuma': {'name': 'Sukuma Wiki Greens', 'price': 20.0, 'aliases': ['sukuma', 'greens', 'mboga']},
    'cabbage': {'name': 'Fried Cabbage', 'price': 20.0, 'aliases': ['cabbage', 'kabeji']},
    'tea': {'name': 'Special Spiced Tea', 'price': 20.0, 'aliases': ['tea', 'chai']},
    'mandazi': {'name': 'Mandazi', 'price': 15.0, 'aliases': ['mandazi', 'mahamri']},
    'smokie': {'name': 'Smokie Pasua', 'price': 40.0, 'aliases': ['smokie', 'smoke']},
    'egg': {'name': 'Boiled Egg (Mayai Pasua)', 'price': 30.0, 'aliases': ['egg', 'mayai', 'yai']},
    'tilapia': {'name': 'Crispy Tilapia & Ugali', 'price': 250.0, 'aliases': ['tilapia', 'samaki', 'fish']},
    'bread': {'name': 'Broadways Bread 400g', 'price': 65.0, 'aliases': ['bread', 'mkate']},
    'milk': {'name': 'Fresh Milk 500ml', 'price': 60.0, 'aliases': ['milk', 'maziwa']},
}

def detect_language(text):
    """
    Detects whether the spoken input is primarily English or Kiswahili/Sheng.
    """
    low = text.lower()
    swahili_markers = [
        'nani', 'gani', 'yuko', 'wapi', 'chakula', 'shilingi', 'salio', 'nitatoboa',
        'pesa', 'sasa', 'hapa', 'karibu', 'omba', 'mzazi', 'bili', 'gawanya',
        'vifaa', 'kuna', 'duka', 'stoo', 'jiko', 'cha', 'kwa', 'nawezaje',
        'bob', 'chapo', 'dondo', 'comrade', 'kula', 'tayari', 'toa', 'lipa',
        'fungua', 'habari', 'asante', 'tafadhali', 'mimi', 'ndio', 'hapana'
    ]
    english_markers = [
        'where', 'what', 'which', 'who', 'tell', 'show', 'nearest', 'closest',
        'vendor', 'available', 'electronics', 'food', 'calculator', 'laptop',
        'balance', 'split', 'bill', 'parent', 'help', 'money', 'buy', 'order',
        'how', 'is', 'the', 'open', 'close', 'price', 'cost', 'much', 'can',
        'give', 'find', 'locate', 'recommend'
    ]

    sw_hits = sum(1 for w in swahili_markers if re.search(rf'\b{re.escape(w)}\b', low))
    en_hits = sum(1 for w in english_markers if re.search(rf'\b{re.escape(w)}\b', low))

    return 'en' if en_hits > sw_hits else 'sw'

def extract_amount(text):
    m = re.search(r'(?:ksh|kes|sh|shilingi|bob)?\s*(\d+(?:,\d+)*(?:\.\d+)?)', text, re.IGNORECASE)
    if m:
        try:
            return float(m.group(1).replace(',', ''))
        except ValueError:
            pass
    low = text.lower()
    for phrase, val in sorted(NUMBER_MAP.items(), key=lambda x: -len(x[0])):
        if phrase in low:
            return float(val)
    return None

def extract_ticket_or_pin(text):
    m = re.search(r'(?:order|ticket|tiketi|pin|token|namba|number)?\s*#?([0-9]{3,6})', text, re.IGNORECASE)
    if m:
        return m.group(1)
    return None

def parse_order_items(text):
    items = []
    low = text.lower()
    
    for item_key, item_info in MENU_ITEMS_CATALOG.items():
        for alias in item_info['aliases']:
            if alias in low:
                qty = 1
                digit_match = re.search(rf'(\d+)\s*{re.escape(alias)}|{re.escape(alias)}\s*(\d+)', low)
                if digit_match:
                    num_str = digit_match.group(1) or digit_match.group(2)
                    qty = int(num_str)
                else:
                    for word, val in NUMBER_MAP.items():
                        if f"{word} {alias}" in low or f"{alias} {word}" in low:
                            qty = val
                            break
                items.append({
                    'name': item_info['name'],
                    'quantity': qty,
                    'price': item_info['price'],
                    'total': item_info['price'] * qty
                })
                break
    return items

@voice_v6_bp.route('/intent', methods=['POST'])
def process_voice_intent():
    """
    Sema na DISHI Bilingual Voice Knowledge Base & Conversational AI.
    Queries live Firestore database collections for nearest vendors, available food,
    and campus electronics, and supports Comrade Bill Splitting PIN notifications.
    """
    data = request.json or {}
    text = str(data.get('text', '')).strip()
    role = str(data.get('role', 'student')).lower()
    user_uid = str(data.get('uid', '')).strip()

    if not text:
        return jsonify({
            "intent": "EMPTY",
            "spoken_response": "Samahani, sijakusikia vizuri. Tafadhali rudia tena."
        }), 400

    low = text.lower()
    lang = detect_language(text)

    # ==========================================
    # GLOBAL: DISMISS / CANCEL VOICE ASSISTANT
    # ==========================================
    if any(k in low for k in ['acha tu', 'funga', 'cancel', 'tulia', 'stop', 'kwaheri', 'bye', 'dismiss', 'close']):
        spoken = "Alright, closing voice assistant. Tap the mic anytime you need me." if lang == 'en' else "Sawa, nimefunga. Ukinihitaji gusa maikrofoni wakati wowote."
        return jsonify({
            "intent": "DISMISS_VOICE",
            "action": "dismiss",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # Fetch User Balance if UID is provided
    cur_balance = 0.0
    user_name = "Comrade"
    db = firestore.client()

    if user_uid:
        try:
            u_doc = db.collection('users').document(user_uid).get()
            if u_doc.exists:
                udata = u_doc.to_dict()
                cur_balance = float(udata.get('walletBalance', 0.0))
                user_name = udata.get('displayName') or udata.get('name') or "Comrade"
        except Exception:
            pass

    # =========================================================================
    # 1. NEAREST VENDOR QUERY (Live Database Fetching: vendors & users)
    # =========================================================================
    if any(k in low for k in [
        'nearest vendor', 'closest vendor', 'where to eat', 'where can i buy',
        'nearest shop', 'nearest canteen', 'closest shop', 'find vendor',
        'vendor gani yuko karibu', 'vendor wa karibu', 'duka la karibu',
        'wapi naweza kula', 'cafeteria ya karibu', 'kuna muuzaji gani karibu'
    ]):
        requested_type = None
        if any(w in low for w in ['electronic', 'tech', 'computer', 'calculator', 'gadget']):
            requested_type = 'electronics'
        elif any(w in low for w in ['supermarket', 'grocery', 'groceries', 'snack', 'bread', 'milk']):
            requested_type = 'supermarket'
        elif any(w in low for w in ['food', 'chakula', 'eat', 'cafeteria', 'lunch', 'dinner']):
            requested_type = 'food'

        matched_vendors = []
        try:
            v_query = db.collection('vendors')
            if requested_type:
                v_query = v_query.where('vendorType', '==', requested_type)
            docs = v_query.limit(10).stream()
            for doc in docs:
                v_data = doc.to_dict()
                v_data['id'] = doc.id
                matched_vendors.append(v_data)
        except Exception:
            pass

        # Fallback to default if empty
        if not matched_vendors:
            matched_vendors = [
                {
                    "id": "vendor_cafeteria_main",
                    "businessName": "Hall 4 Main Cafeteria",
                    "location": "Student Centre, Ground Floor",
                    "rating": 4.8,
                    "isOpen": True,
                    "vendorType": "food",
                    "specialties": ["Chapati", "Madondo", "Beef Stew", "Pilau"]
                },
                {
                    "id": "vendor_tech_hub",
                    "businessName": "Campus Tech & Gadgets Hub",
                    "location": "Engineering Complex, Room 102",
                    "rating": 4.9,
                    "isOpen": True,
                    "vendorType": "electronics",
                    "specialties": ["Calculators", "Laptops", "Lab Coats", "Chargers"]
                }
            ]

        top_v = matched_vendors[0]
        v_name = top_v.get('businessName') or top_v.get('name') or 'Main Cafeteria'
        v_loc = top_v.get('location') or top_v.get('venueLocation') or 'Student Centre'
        v_rating = top_v.get('rating', 4.8)
        specs = ", ".join(top_v.get('specialties', ['Food', 'Essentials'])[:3])

        if lang == 'en':
            spoken = f"The nearest vendor to you is {v_name}, located at {v_loc}. They have a {v_rating} star rating, specializing in {specs}. Would you like to view their menu or store?"
        else:
            spoken = f"Vendor aliye karibu nawe ni {v_name} anayepatikana {v_loc}. Yuko wazi na ana alama ya stars {v_rating}, akiuza hasa {specs}. Ungependa kuona orodha yao?"

        return jsonify({
            "intent": "NEAREST_VENDOR",
            "vendor": top_v,
            "all_vendors": matched_vendors,
            "spoken_response": spoken,
            "action": "open_vendor_card",
            "requires_pin": False
        }), 200

    # =========================================================================
    # 2. AVAILABLE FOOD QUERY (Live Database Fetching: products & vendor_menus)
    # =========================================================================
    if any(k in low for k in [
        'what food is available', 'food available', 'what meals do you have',
        'today\'s menu', 'what can i eat', 'show me food', 'available dishes',
        'kuna chakula gani', 'chakula kinachopatikana', 'vyakula vilivyopo',
        'menu ya leo', 'kuna nini ya kula', 'vyakula gani viko', 'orodha ya chakula'
    ]):
        food_list = []
        try:
            docs = db.collection('products').where('category', '==', 'food').limit(10).stream()
            for d in docs:
                f_data = d.to_dict()
                f_data['id'] = d.id
                food_list.append(f_data)
        except Exception:
            pass

        if not food_list:
            food_list = [
                {"name": "Chapati Fupi Soft", "price": 25.0, "vendorName": "Hall 4 Main Cafeteria"},
                {"name": "Madondo (Yellow Beans)", "price": 50.0, "vendorName": "Hall 4 Main Cafeteria"},
                {"name": "Beef Stew with Rice", "price": 120.0, "vendorName": "Hall 4 Main Cafeteria"},
                {"name": "Swahili Beef Pilau", "price": 150.0, "vendorName": "Hall 4 Main Cafeteria"}
            ]

        # Construct concise spoken list
        top_items_text = ", ".join([f"{item['name']} for {int(item['price'])} bob" for item in food_list[:4]])

        if lang == 'en':
            spoken = f"Available campus meals right now include: {top_items_text}. You can order ahead right from your dashboard to skip the lunch lines!"
        else:
            spoken = f"Vyakula vinavyopatikana sasa ni pamoja na: {top_items_text}. Unaweza kuweka oda sasa hivi ili ukwepe foleni ya chakula!"

        return jsonify({
            "intent": "DISCOVER_MEALS",
            "items": food_list,
            "spoken_response": spoken,
            "action": "open_food_menu",
            "requires_pin": False
        }), 200

    # =========================================================================
    # 3. CAMPUS ELECTRONICS & TECH QUERY (Live Database: supermarket_skus)
    # =========================================================================
    if any(k in low for k in [
        'electronic', 'electronics', 'tech', 'laptop', 'calculator',
        'scientific calculator', 'flash drive', 'lab coat', 'charger',
        'vifaa vya electronics', 'kuna electronics gani', 'vifaa gani vinauzwa',
        'kompyuta', 'kikokotoo', 'vifaa vya lab', 'duka la vifaa', 'chaja'
    ]):
        electronics_list = []
        try:
            docs = db.collection('supermarket_skus').where('category', 'in', ['electronics', 'stationery', 'tech']).limit(10).stream()
            for d in docs:
                e_data = d.to_dict()
                e_data['id'] = d.id
                electronics_list.append(e_data)
        except Exception:
            pass

        if not electronics_list:
            electronics_list = [
                {"name": "Casio FX-991EX Scientific Calculator", "price": 2400.0, "installmentAvailable": True, "monthlyRate": 480.0},
                {"name": "Kingston 64GB USB 3.2 Flash Drive", "price": 950.0, "installmentAvailable": False},
                {"name": "Heavy Duty White Lab Coat", "price": 1200.0, "installmentAvailable": True, "monthlyRate": 300.0},
                {"name": "Baseus 65W GaN Fast Charger", "price": 1800.0, "installmentAvailable": True, "monthlyRate": 450.0},
                {"name": "Lenovo ThinkPad Core i5 Laptop", "price": 24000.0, "installmentAvailable": True, "monthlyRate": 4800.0}
            ]

        if lang == 'en':
            spoken = "Available campus electronics at Campus Tech Hub include Casio FX-991EX Scientific Calculators at KES 2,400, 64GB Flash Drives at KES 950, Cotton Lab Coats at KES 1,200, and ThinkPad Laptops. You can also pay in monthly installments or request parent sponsoring!"
        else:
            spoken = "Vifaa vya electronics vinavyopatikana Campus Tech Hub ni pamoja na Kikokotoo cha kisayansi cha Casio Shilingi 2,400, Flash drive ya 64GB Shilingi 950, Lab Coat Shilingi 1,200, na Laptop za Lenovo. Unaweza kulipa kwa awamu au kuomba ufadhili kutoka kwa mzazi!"

        return jsonify({
            "intent": "CAMPUS_ELECTRONICS",
            "items": electronics_list,
            "spoken_response": spoken,
            "action": "open_tech_store",
            "requires_pin": False
        }), 200

    # =========================================================================
    # 4. COMRADE BILL SPLITTING (Voice Intent -> Opens Sheet & Dispatches Notifications)
    # =========================================================================
    if any(k in low for k in ['gawanya', 'split', 'tuchange', 'changamsha', 'bill split', 'split bill', 'roommate bill']):
        amt = extract_amount(text) or 600.0
        people = 2
        digit_people = re.search(r'(?:watu|people|friends|comrades)?\s*(\d+)', low)
        if digit_people and int(digit_people.group(1)) > 1:
            people = int(digit_people.group(1))
        split_share = round(amt / people, 2)

        if lang == 'en':
            spoken = f"Splitting a bill of KES {amt:,.0f} among {people} comrades (KES {split_share:,.0f} each). Opening the bill split sheet. Once sent, your comrades will receive an instant notification to put their DISHI PIN and approve payment!"
        else:
            spoken = f"Inagawanya bili ya Shilingi {amt:,.0f} kwa marafiki {people} (Shilingi {split_share:,.0f} kila mmoja). Nimefungua fomu ya split bill. Marafiki zako watapokea arifa ya papo hapo kuweka PIN yao ya DISHI na kulipa sehemu yao!"

        return jsonify({
            "intent": "SPLIT_BILL",
            "amount": amt,
            "people": people,
            "share_per_person": split_share,
            "action": "open_split_bill",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # =========================================================================
    # 5. STUDENT SPECIFIC VOICE INTENTS & KNOWLEDGE BASE
    # =========================================================================
    if role == 'student':
        # Budget Burnout & "Nitatoboa?" Intelligence
        if any(k in low for k in ['nitatoboa', 'pesa itanitosha', 'burn rate', 'hesabu ya wiki', 'daily budget', 'nitamaliza wiki', 'will i survive', 'budget check']):
            today_weekday = datetime.datetime.now().weekday()
            days_left = max(1, 6 - today_weekday)
            daily_allowance = cur_balance / days_left if cur_balance > 0 else 0.0

            if lang == 'en':
                if cur_balance <= 50:
                    advice = "You're running very low! Tap Okoa Food Rescue or request an emergency parent top-up."
                elif daily_allowance >= 150:
                    advice = "Your budget is in great shape! You can comfortably enjoy healthy meals."
                else:
                    advice = "With normal meals (chapati & beans), your funds will last until Sunday."
                spoken = f"Your balance is KES {cur_balance:,.0f}. You have a safe daily allowance of KES {daily_allowance:,.0f} across the {days_left} days left. {advice}"
            else:
                if cur_balance <= 50:
                    advice = "Comrade, uko pabaya kidogo! Tumia Okoa Meal au uombe mzazi allowance ya dharura."
                elif daily_allowance >= 150:
                    advice = "Uko fiti sana! Unaweza kula vizuri na bado uweke akiba ya wikendi."
                else:
                    advice = "Ukila kawaida (chapati na madondo), pesa itakutosha vizuri hadi mwisho wa wiki."
                spoken = f"Salio lako ni Shilingi {cur_balance:,.0f}. Kila siku unaweza kutumia Shilingi {daily_allowance:,.0f} kwa siku {days_left} zilizobaki. {advice}"

            return jsonify({
                "intent": "CHECK_BUDGET",
                "balance": cur_balance,
                "days_left": days_left,
                "daily_allowance": daily_allowance,
                "spoken_response": spoken,
                "requires_pin": False
            }), 200

        # Instant Payment Pass / Dynamic QR Code
        if any(k in low for k in ['pass', 'qr', 'token', 'barcode', 'lipa', 'kuchukua', 'counter', 'nionyeshe qr', 'show qr', 'payment pass']):
            spoken = "Here is your dynamic food payment QR code. Show it to the cafeteria cashier to scan." if lang == 'en' else "Hii hapa QR pass yako ya chakula. Onyesha mpishi au cashier aiskani kwa counter."
            return jsonify({
                "intent": "SHOW_STUDENT_QR",
                "action": "open_qr_pass",
                "spoken_response": spoken,
                "requires_pin": False
            }), 200

        # Emergency Okoa Food Rescue
        if any(k in low for k in ['okoa', 'broke', 'njaa', 'sina kakitu', 'sina pesa', 'emergency meal', 'hungry', 'food rescue']):
            spoken = "Hang in there comrade! Opening Okoa Food Rescue so you can get an emergency subsidized meal right now." if lang == 'en' else "Pole sana comrade. Nimekufungulia Okoa Meal upate chakula cha dharura mara moja bila wasiwasi."
            return jsonify({
                "intent": "OKOA_MEAL",
                "action": "open_okoa_food",
                "spoken_response": spoken,
                "requires_pin": False
            }), 200

        # Request Funds from Parent / Sponsor
        if any(k in low for k in ['omba mzazi', 'omba mum', 'omba dad', 'request funds', 'ask parent', 'need allowance', 'omba pesa']):
            amt = extract_amount(text) or 300.0
            spoken = f"Prepared an allowance request for KES {amt:,.0f} to your parent. Tap to review and send." if lang == 'en' else f"Nimeandaa ombi la Shilingi {amt:,.0f} kwa mzazi. Angalia maelezo kisha utume."
            return jsonify({
                "intent": "REQUEST_PARENT_FUNDS",
                "amount": amt,
                "action": "open_request_funds",
                "spoken_response": spoken,
                "requires_pin": False
            }), 200

        # Campus Gigs & Hustle Finder
        if any(k in low for k in ['gigs', 'kazi', 'hustle', 'delivery gigs', 'campus jobs', 'earning', 'kutafuta pesa', 'earn money']):
            spoken = "Campus delivery runner and freelance student gigs are available. Opening the employment hub." if lang == 'en' else "Kuna kazi za chuo, delivery, na tasks zinazopatikana. Zifungue hapa uanze kupata chapaa."
            return jsonify({
                "intent": "CAMPUS_GIGS",
                "action": "open_campus_gigs",
                "spoken_response": spoken,
                "requires_pin": False
            }), 200

        # Timetable & Lecture Schedule
        if any(k in low for k in ['class', 'darasa', 'timetable', 'ratiba', 'kipindi', 'lecture', 'next class', 'schedule']):
            spoken = "Opening your academic timetable and upcoming lectures for today." if lang == 'en' else "Inafungua ratiba yako ya masomo na vipindi vya leo."
            return jsonify({
                "intent": "CHECK_TIMETABLE",
                "action": "open_timetable",
                "spoken_response": spoken,
                "requires_pin": False
            }), 200

        # Virtual Card (VCC)
        if any(k in low for k in ['vcc', 'kadi', 'card', 'virtual card', 'debit card', 'contactless']):
            spoken = "Opening your contactless DISHI Virtual Card for instant payments." if lang == 'en' else "Inafungua kadi yako ya kidijitali (Virtual Card) kwa malipo ya haraka."
            return jsonify({
                "intent": "VIRTUAL_CARD",
                "action": "open_virtual_card",
                "spoken_response": spoken,
                "requires_pin": False
            }), 200

        # Voice Food Ordering
        if any(k in low for k in ['nataka', 'agiza', 'order', 'chapati', 'madondo', 'kuku', 'chips', 'wali', 'rice', 'ugali', 'beef', 'smokie', 'mayai']):
            parsed_items = parse_order_items(text)
            if parsed_items:
                total_sum = sum(i['total'] for i in parsed_items)
                item_desc = ", ".join([f"{i['quantity']} {i['name']}" for i in parsed_items])
                spoken = f"Added {item_desc} to cart. Total is KES {total_sum:,.0f}." if lang == 'en' else f"Nimepata {item_desc}. Jumla ni Shilingi {total_sum:,.0f}. Inafungua oda yako."
                return jsonify({
                    "intent": "DISCOVER_MEALS",
                    "items": parsed_items,
                    "total_amount": total_sum,
                    "spoken_response": spoken,
                    "requires_pin": False
                }), 200

        # Campus Knowledge Base: Peak Lunch Rush Hours
        if any(k in low for k in ['lunch time', 'peak hour', 'rush hour', 'saa ngapi lunch', 'foleni ya chakula']):
            if lang == 'en':
                spoken = "Peak campus lunch rush is between 11:30 AM and 2:00 PM. Order ahead on DISHI to skip the queue lines and pick up at the fast counter!"
            else:
                spoken = "Muda wa foleni kubwa ya chakula cha mchana ni kuanzia saa tano na nusu hadi saa nane (11:30 AM - 2:00 PM). Weka oda mapema kwenye DISHI ukwepe foleni!"
            return jsonify({
                "intent": "KNOWLEDGE_BASE_INFO",
                "topic": "lunch_rush",
                "spoken_response": spoken,
                "requires_pin": False
            }), 200

    # ==========================================
    # PARENT SPECIFIC VOICE INTENTS
    # ==========================================
    if role == 'parent':
        if any(k in low for k in ['tuma pesa', 'fund', 'mtumie', 'allowance', 'send money']):
            amt = extract_amount(text) or 500.0
            spoken = f"You are about to send KES {amt:,.0f} to the student vault. Please confirm the transaction with your PIN." if lang == 'en' else f"Unakaribia kumtumia mwanafunzi Shilingi {amt:,.0f} kwa vault. Thibitisha muamala kwa PIN yako."
            return jsonify({
                "intent": "FUND_STUDENT",
                "amount": amt,
                "spoken_response": spoken,
                "requires_pin": True
            }), 200

    # ==========================================
    # VENDOR SPECIFIC VOICE INTENTS
    # ==========================================
    if role == 'vendor':
        if any(k in low for k in ['jiko', 'kitchen', 'kds']):
            return jsonify({
                "intent": "NAVIGATE_KDS",
                "action": "open_kds",
                "spoken_response": "Opening the Kitchen Display System." if lang == 'en' else "Inafungua skrini ya jiko (Kitchen Display System).",
                "requires_pin": False
            }), 200

        if any(k in low for k in ['ripoti', 'reports', 'report', 'hesabu', 'sales']):
            return jsonify({
                "intent": "NAVIGATE_REPORTS",
                "action": "open_reports",
                "spoken_response": "Opening sales and accounting reports." if lang == 'en' else "Inafungua ripoti za mauzo na hesabu za siku.",
                "requires_pin": False
            }), 200

        if any(k in low for k in ['stoo', 'operations', 'shughuli', 'inventory']):
            return jsonify({
                "intent": "NAVIGATE_OPERATIONS",
                "action": "open_operations",
                "spoken_response": "Opening store inventory and operations." if lang == 'en' else "Inafungua usimamizi wa shughuli na stoo.",
                "requires_pin": False
            }), 200

        if any(k in low for k in ['toa', 'withdraw', 'cash out', 'hamisha']):
            amount = extract_amount(text)
            if not amount or amount <= 0:
                return jsonify({
                    "intent": "CASH_OUT_PROMPT",
                    "spoken_response": "How much float would you like to withdraw to M-Pesa?" if lang == 'en' else "Ungependa kutoa kiasi gani cha pesa kwa M-Pesa?",
                    "requires_pin": True
                }), 200
            
            challenge = f"{random.randint(10, 99)}"
            spoken = f"You are withdrawing KES {amount:,.0f} to M-Pesa. Confirm with your voice PIN or say {challenge}." if lang == 'en' else f"Unakaribia kutoa Shilingi {amount:,.0f} kwa M-Pesa. Thibitisha kwa Voice PIN yako au sema {challenge}."
            return jsonify({
                "intent": "INITIATE_CASH_OUT",
                "amount": amount,
                "requires_pin": True,
                "challenge_code": challenge,
                "spoken_response": spoken
            }), 200

    # ==========================================
    # COMMON: BALANCE QUERY (ALL ROLES)
    # ==========================================
    if any(k in low for k in ['balance', 'float', 'salio', 'pesa ngapi', 'how much do i have', 'check balance']):
        if lang == 'en':
            spoken = f"Your current available balance is KES {cur_balance:,.0f}."
        else:
            spoken = f"Salio lako kwa sasa ni Shilingi {cur_balance:,.0f}."

        return jsonify({
            "intent": "QUERY_BALANCE",
            "balance": cur_balance,
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # ==========================================
    # GENERAL KNOWLEDGE BASE FALLBACK
    # ==========================================
    if lang == 'en':
        spoken = f"I received: '{text}'. You can ask me: 'Where is the nearest vendor?', 'What food is available?', 'Show me campus electronics', or 'Split a bill of 600'."
    else:
        spoken = f"Nimepokea: '{text}'. Unaweza kuniuliza: 'Vendor gani yuko karibu nami?', 'Kuna chakula gani?', 'Kuna electronics gani?', au 'Gawanya bili ya 600'."

    return jsonify({
        "intent": "GENERAL_QUERY",
        "recognized_text": text,
        "language": lang,
        "spoken_response": spoken,
        "requires_pin": False
    }), 200
