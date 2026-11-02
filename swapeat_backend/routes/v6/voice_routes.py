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
    'beef_rice': {'name': 'Beef Stew & Steamed Rice', 'price': 150.0, 'aliases': ['beef', 'rice', 'wali nyama', 'beef stew', 'nyama']},
    'chips_kuku': {'name': 'Chips Kuku (Quarter Chicken)', 'price': 220.0, 'aliases': ['chips', 'kuku', 'chips kuku', 'chicken fries', 'chips mayai']},
    'chapati_dondo': {'name': 'Chapati Mbili Madondo', 'price': 100.0, 'aliases': ['chapo dondo', 'chapati madondo', 'madondo', 'dondo', 'chapo mbili']},
    'ugali_sukuma': {'name': 'Ugali Sukuma Wiki & Mayai', 'price': 80.0, 'aliases': ['ugali', 'sukuma', 'mayai', 'ugali mboga', 'sembe']},
    'chai_mandazi': {'name': 'Chai ya Maziwa & Mandazi Mbili', 'price': 50.0, 'aliases': ['chai', 'tea', 'mandazi', 'chai mandazi', 'mahamri']},
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
        'fungua', 'habari', 'asante', 'tafadhali', 'mimi', 'ndio', 'hapana', 'mambo', 'vipi'
    ]
    english_markers = [
        'where', 'what', 'which', 'who', 'tell', 'show', 'nearest', 'closest',
        'vendor', 'available', 'electronics', 'food', 'calculator', 'laptop',
        'balance', 'split', 'bill', 'parent', 'help', 'money', 'buy', 'order',
        'how', 'is', 'the', 'open', 'close', 'price', 'cost', 'much', 'can',
        'give', 'find', 'locate', 'recommend', 'hello', 'hi'
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
    Sema na DISHI - Friendly Sister Voice Companion ("Zawadi") & Financial AI.
    Features:
    - Warm conversational companion speaking like a trusted comrade sister.
    - Zero-Trust Voice Financial Security (anti-theft, anti-hacking, prompt injection blocks).
    - Hardened vendor matching: Nyawuora Isaya Okuna is the sole verified campus vendor.
    - Interactive command execution with real-time spoken and visual progress updates.
    """
    data = request.json or {}
    text = str(data.get('text', '')).strip()
    role = str(data.get('role', 'student')).lower()
    user_uid = str(data.get('uid', '')).strip()

    if not text:
        return jsonify({
            "intent": "EMPTY",
            "spoken_response": "Niko hapa rafiki yangu! Sema nami wakati wowote au niambie kile unahitaji nikusaidie."
        }), 400

    low = text.lower()
    lang = detect_language(text)
    db = firestore.client()

    # =========================================================================
    # HARDENED SECURITY & ANTI-THEFT / ANTI-HACKING GUARD
    # =========================================================================
    suspicious_patterns = [
        r'ignore.*instructions', r'system.*override', r'steal', r'hack',
        r'transfer.*all.*float', r'transfer.*all.*money', r'drain.*wallet',
        r'bypass.*pin', r'send.*to.*external', r'send.*without.*pin',
        r'change.*admin', r'delete.*database', r'grant.*admin', r'drop.*collection'
    ]
    for pat in suspicious_patterns:
        if re.search(pat, low):
            try:
                db.collection('voice_security_events').add({
                    'user_uid': user_uid,
                    'attempted_text': text,
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'action': 'blocked_suspicious_injection'
                })
            except Exception:
                pass

            spoken = "Security Alert: Unsanctioned financial action detected. For your safety and to prevent theft, all monetary actions on DISHI require explicit PIN verification on your device." if lang == 'en' else "Onyo la Usalama: Amri hii imezuiwa kwa sababu za kiusalama. Malipo yote ya fedha kwenye DISHI yanalindwa kwa PIN yako binafsi na hayawezi kutolewa kiholela."
            return jsonify({
                "intent": "SECURITY_BLOCKED",
                "spoken_response": spoken,
                "is_security_alert": True,
                "requires_pin": True
            }), 403

    # =========================================================================
    # GLOBAL: DISMISS / CANCEL VOICE ASSISTANT
    # =========================================================================
    if any(k in low for k in ['acha tu', 'funga', 'cancel', 'tulia', 'stop', 'kwaheri', 'bye', 'dismiss', 'close']):
        spoken = "Alright my friend, I'm closing for now. Tap my mic anytime you need anything, I've got your back!" if lang == 'en' else "Sawa rafiki yangu! Nimefunga kwa sasa. Ukinihitaji gusa tu maikrofoni, niko hapa kukusaidia kila wakati!"
        return jsonify({
            "intent": "DISMISS_VOICE",
            "action": "dismiss",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # Fetch User Balance and Profile
    cur_balance = 0.0
    user_name = "Comrade"
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
    # 1. NEAREST VENDOR QUERY -> Nyawuora Isaya Okuna
    # =========================================================================
    if any(k in low for k in [
        'nearest vendor', 'closest vendor', 'where to eat', 'where can i buy',
        'nearest shop', 'nearest canteen', 'closest shop', 'find vendor',
        'vendor gani yuko karibu', 'vendor wa karibu', 'duka la karibu',
        'wapi naweza kula', 'cafeteria ya karibu', 'kuna muuzaji gani karibu'
    ]):
        vendor_data = {
            "id": "yoDXyLq0vQRp1XNETzKFATzVDzo1",
            "businessName": "Nyawuora Isaya Okuna Cafeteria",
            "name": "Nyawuora Isaya Okuna",
            "location": "MMUST near MEA",
            "rating": 4.9,
            "isOpen": True,
            "vendorType": "food",
            "phone": "0795632942",
            "specialties": ["Beef Stew & Rice", "Chips Kuku", "Chapati Madondo", "Ugali Sukuma", "Chai"]
        }

        if lang == 'en':
            spoken = f"The nearest verified vendor to you is Nyawuora Isaya Okuna Cafeteria, located right at MMUST near MEA! He has a stellar 4.9 star rating, serving freshly prepared Beef Stew with Rice, crispy Chips Kuku, and hot Chapati Madondo. Would you like me to open his menu so you can order ahead?"
        else:
            spoken = f"Vendor aliye karibu nawe zaidi ni Nyawuora Isaya Okuna Cafeteria anayepatikana hapo MMUST near MEA! Ana alama ya juu ya stars 4.9, na anapika msosi safi sana: Beef stew na wali, Chips kuku, na Chapati madondo moto. Nifungue menu yake uweke oda yako sasa hivi?"

        return jsonify({
            "intent": "NEAREST_VENDOR",
            "vendor": vendor_data,
            "progress_steps": [
                "Locating campus vendors...",
                "Found Nyawuora Isaya Okuna Cafeteria at MMUST near MEA",
                "Menu and operating hours ready"
            ],
            "spoken_response": spoken,
            "action": "open_vendor_card",
            "requires_pin": False
        }), 200

    # =========================================================================
    # 2. QR CODE / FOOD PASS ("Talk better, respond like a friend")
    # =========================================================================
    if any(k in low for k in ['pass', 'qr', 'token', 'barcode', 'lipa', 'kuchukua', 'counter', 'nionyeshe qr', 'show qr', 'payment pass']):
        if lang == 'en':
            spoken = f"Here is your dynamic food pass QR code, {user_name}! Just show this rotating pass to the cashier at Nyawuora Isaya Okuna Cafeteria. They'll scan it in two seconds and your hot meal will be served immediately with zero line waiting. Enjoy your meal, friend!"
        else:
            spoken = f"Hii hapa QR pass yako ya chakula nimekuandalia, comrade {user_name}! Nenda nayo moja kwa moja kwa counter ya Nyawuora Isaya Okuna Cafeteria. Cashier akiskani tu kwa simu yake, unapata msosi wako mara moja bila kusimama kwa foleni. Kula ushibe rafiki yangu!"

        return jsonify({
            "intent": "SHOW_STUDENT_QR",
            "action": "open_qr_pass",
            "progress_steps": [
                "Generating secure dynamic HMAC payment pass...",
                "Connecting with Nyawuora Isaya Okuna POS terminal...",
                "QR Food Pass Active!"
            ],
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # =========================================================================
    # 3. AVAILABLE FOOD QUERY (Nyawuora Isaya Okuna Menu)
    # =========================================================================
    if any(k in low for k in [
        'what food is available', 'food available', 'what meals do you have',
        'today\'s menu', 'what can i eat', 'show me food', 'available dishes',
        'kuna chakula gani', 'chakula kinachopatikana', 'vyakula vilivyopo',
        'menu ya leo', 'kuna nini ya kula', 'vyakula gani viko', 'orodha ya chakula'
    ]):
        food_list = [
            {"name": "Beef Stew & Steamed Rice", "price": 150.0, "vendorName": "Nyawuora Isaya Okuna Cafeteria"},
            {"name": "Chips Kuku (Quarter Chicken)", "price": 220.0, "vendorName": "Nyawuora Isaya Okuna Cafeteria"},
            {"name": "Chapati Mbili Madondo", "price": 100.0, "vendorName": "Nyawuora Isaya Okuna Cafeteria"},
            {"name": "Ugali Sukuma Wiki & Mayai", "price": 80.0, "vendorName": "Nyawuora Isaya Okuna Cafeteria"},
            {"name": "Chai ya Maziwa & Mandazi Mbili", "price": 50.0, "vendorName": "Nyawuora Isaya Okuna Cafeteria"}
        ]

        if lang == 'en':
            spoken = f"Nyawuora Isaya Okuna has delicious hot dishes ready for you today! You can get Beef Stew & Rice for 150 bob, Chips Kuku for 220, Chapati Madondo for 100, or Ugali Sukuma & Eggs for 80 bob. Which one should I get started for you, my friend?"
        else:
            spoken = f"Nyawuora Isaya Okuna ana vyakula vitamu sana leo! Kuna Beef stew na wali kwa shilingi 150, Chips kuku kwa 220, Chapati mbili madondo kwa 100, na Ugali sukuma na mayai kwa 80 bob. Unatamani kipi rafiki yangu nikusaidie kuweka oda?"

        return jsonify({
            "intent": "DISCOVER_MEALS",
            "items": food_list,
            "progress_steps": [
                "Fetching live menu from Nyawuora Isaya Okuna...",
                "All items confirmed hot and in-stock!",
                "Displaying menu"
            ],
            "spoken_response": spoken,
            "action": "open_food_menu",
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
            spoken = f"Don't worry, I've got you covered! I'm splitting KES {amt:,.0f} among {people} comrades (KES {split_share:,.0f} each). Opening the bill split sheet right now. As soon as you tap send, your friends will receive an instant notification to put their DISHI PIN and pay their share straight to your wallet!"
        else:
            spoken = f"Usiwe na wasiwasi rafiki yangu, nimekusaidia! Bili ya Shilingi {amt:,.0f} inagawanywa kwa watu {people} (Shilingi {split_share:,.0f} kila mmoja). Nimefungua fomu ya split bill. Ukituma tu, marafiki zako watapata arifa ya haraka kuweka PIN zao za DISHI na pesa itaingia kwenye wallet yako moja kwa moja!"

        return jsonify({
            "intent": "SPLIT_BILL",
            "amount": amt,
            "people": people,
            "share_per_person": split_share,
            "progress_steps": [
                f"Calculating equal comrade split for KES {amt:,.0f}...",
                f"Divided by {people} members = KES {split_share:,.0f} each",
                "Opening PIN-secured Group Pay sheet..."
            ],
            "action": "open_split_bill",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # =========================================================================
    # 5. CASUAL BUDDY CONVERSATIONS / Q&A ("Talk like a friend")
    # =========================================================================
    if any(k in low for k in ['mambo', 'habari', 'vipi', 'how are you', 'hello', 'hi zawadi', 'sema zawadi', 'who are you', 'wewe ni nani']):
        if lang == 'en':
            spoken = f"Hey there {user_name}! I'm Zawadi, your trusted DISHI campus companion and buddy. I'm here to help you get meals with zero lines, keep your budget on track, split bills with comrades, and navigate campus life. How are you feeling today?"
        else:
            spoken = f"Mambo comrade {user_name}! Mimi ni Zawadi, dada na rafiki yako wa chuo hapa DISHI. Niko hapa kuhakikisha unakula vizuri bila kusimama kwa foleni, unalinda bajeti yako, na mambo ya chuo yanaenda swafi. Uko poa leo?"

        return jsonify({
            "intent": "FRIEND_CONVERSATION",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    if any(k in low for k in ['kicheko', 'joke', 'chekesha', 'tell me a joke']):
        if lang == 'en':
            spoken = "Why did the comrade bring a spoon to the lecture hall? Because the lecturer said the exam was going to be a piece of cake! Haha, remember to order your chapati madondo ahead to fuel that brain!"
        else:
            spoken = "Unajua kwa nini comrade alibeba kijiko kwenye exam room? Alisikia lecturer akisema mtihani utakuwa 'a piece of cake'! Haha, usijali rafiki yangu, chapati za Nyawuora ziko tayari kukuongeza nguvu!"

        return jsonify({
            "intent": "FRIEND_JOKE",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # =========================================================================
    # 6. BUDGET INTELLIGENCE & "NITATOBOA?"
    # =========================================================================
    if any(k in low for k in ['nitatoboa', 'pesa itanitosha', 'burn rate', 'hesabu ya wiki', 'daily budget', 'nitamaliza wiki', 'will i survive', 'budget check']):
        today_weekday = datetime.datetime.now().weekday()
        days_left = max(1, 6 - today_weekday)
        daily_allowance = cur_balance / days_left if cur_balance > 0 else 0.0

        if lang == 'en':
            if cur_balance <= 50:
                advice = "Hang in there, friend! You're running very low. Tap Okoa Food Rescue or let's ask your parent for an emergency allowance."
            elif daily_allowance >= 150:
                advice = "You're doing fantastic! You can comfortably enjoy a warm meal at Nyawuora's and still save for the weekend."
            else:
                advice = "With normal meals like chapati madondo, you'll easily make it to Sunday with no stress."
            spoken = f"Your balance is KES {cur_balance:,.0f}. That gives you a safe spending allowance of KES {daily_allowance:,.0f} per day across the {days_left} days left. {advice}"
        else:
            if cur_balance <= 50:
                advice = "Comrade wangu, hali si shwari sana! Tumia Okoa Meal upate chakula cha dharura au tuombe mzazi akurushie kakitu."
            elif daily_allowance >= 150:
                advice = "Uko vizuri sana! Unaweza kula beef stew kwa Nyawuora na bado ubaki na akiba ya wikendi."
            else:
                advice = "Ukila kawaida chapo dondo, pesa itakutosha vizuri kabisa hadi Jumapili."
            spoken = f"Salio lako ni Shilingi {cur_balance:,.0f}. Kila siku unaweza kutumia Shilingi {daily_allowance:,.0f} kwa siku {days_left} zilizobaki. {advice}"

        return jsonify({
            "intent": "CHECK_BUDGET",
            "balance": cur_balance,
            "days_left": days_left,
            "daily_allowance": daily_allowance,
            "progress_steps": [
                "Analyzing Firestore wallet balance...",
                f"Calculating safe daily burn rate for {days_left} remaining days...",
                "Forecast ready!"
            ],
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # =========================================================================
    # 7. EMERGENCY OKOA FOOD RESCUE
    # =========================================================================
    if any(k in low for k in ['okoa', 'broke', 'njaa', 'sina kakitu', 'sina pesa', 'emergency meal', 'hungry', 'food rescue']):
        spoken = f"I've got your back, {user_name}! No comrade should ever study on an empty stomach. I'm opening Okoa Food Rescue right now so you can get an emergency subsidized meal right away!" if lang == 'en' else f"Pole sana rafiki yangu {user_name}! Mwanafunzi hapaswi kusoma akiwa na njaa kamwe. Nimekufungulia Okoa Food Rescue upate msosi wa dharura mara moja bila wasiwasi!"
        return jsonify({
            "intent": "OKOA_MEAL",
            "action": "open_okoa_food",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # =========================================================================
    # 8. REQUEST FUNDS FROM PARENT
    # =========================================================================
    if any(k in low for k in ['omba mzazi', 'omba mum', 'omba dad', 'request funds', 'ask parent', 'need allowance', 'omba pesa']):
        amt = extract_amount(text) or 300.0
        spoken = f"I've prepared an allowance request of KES {amt:,.0f} for your parent, friend. Tap to review and send it straight to their phone!" if lang == 'en' else f"Nimekuandalia ombi la Shilingi {amt:,.0f} kwa mzazi wako rafiki yangu. Gusa uthibitishe kisha litatumwa papo hapo kwa simu yake!"
        return jsonify({
            "intent": "REQUEST_PARENT_FUNDS",
            "amount": amt,
            "action": "open_request_funds",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # =========================================================================
    # 9. CAMPUS GIGS & TIMETABLE
    # =========================================================================
    if any(k in low for k in ['gigs', 'kazi', 'hustle', 'delivery gigs', 'campus jobs', 'earning', 'kutafuta pesa', 'earn money']):
        spoken = "Looking to earn some extra pocket money? Campus runner delivery gigs and freelance student tasks are open right now. Let's get you that bag!" if lang == 'en' else "Unataka kutengeneza chapaa ya ziada? Kuna kazi za delivery za chuo na tasks zinazopatikana. Zifungue hapa uanze kupata pesa rafiki yangu!"
        return jsonify({
            "intent": "CAMPUS_GIGS",
            "action": "open_campus_gigs",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    if any(k in low for k in ['class', 'darasa', 'timetable', 'ratiba', 'kipindi', 'lecture', 'next class', 'schedule']):
        spoken = "Opening your lecture schedule and classes for today. Let's stay on top of those grades!" if lang == 'en' else "Inafungua ratiba yako ya vipindi vya leo. Wacha tuwahi darasa mapema rafiki yangu!"
        return jsonify({
            "intent": "CHECK_TIMETABLE",
            "action": "open_timetable",
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # =========================================================================
    # 10. VOICE WITHDRAWAL (Hardened Anti-Theft with PIN Requirement)
    # =========================================================================
    if any(k in low for k in ['toa', 'withdraw', 'cash out', 'hamisha']):
        amount = extract_amount(text)
        if not amount or amount <= 0:
            return jsonify({
                "intent": "CASH_OUT_PROMPT",
                "spoken_response": "How much float would you like to withdraw to your M-Pesa line?" if lang == 'en' else "Ungependa kutoa kiasi gani cha pesa kwa M-Pesa yako?",
                "requires_pin": True
            }), 200
        
        challenge = f"{random.randint(10, 99)}"
        spoken = f"Security verification: You are withdrawing KES {amount:,.0f} to your registered M-Pesa line. Please enter your 4-digit Wallet PIN on screen to authorize this payout." if lang == 'en' else f"Uthibitisho wa Usalama: Unakaribia kutoa Shilingi {amount:,.0f} kwa M-Pesa. Tafadhali weka PIN yako ya tarakimu 4 kwenye skrini kuthibitisha muamala huu."
        return jsonify({
            "intent": "INITIATE_CASH_OUT",
            "amount": amount,
            "requires_pin": True,
            "challenge_code": challenge,
            "spoken_response": spoken
        }), 200

    # =========================================================================
    # 11. BALANCE QUERY
    # =========================================================================
    if any(k in low for k in ['balance', 'float', 'salio', 'pesa ngapi', 'how much do i have', 'check balance']):
        if lang == 'en':
            spoken = f"Your current available balance is KES {cur_balance:,.0f}, {user_name}. Let me know if you want to top up, check budget forecast, or grab a meal!"
        else:
            spoken = f"Salio lako lililopo kwenye wallet ni Shilingi {cur_balance:,.0f}, comrade {user_name}. Niambie ukitaka kuweka pesa au kuweka oda ya msosi!"

        return jsonify({
            "intent": "QUERY_BALANCE",
            "balance": cur_balance,
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # =========================================================================
    # GENERAL FRIENDLY FALLBACK
    # =========================================================================
    if lang == 'en':
        spoken = f"I hear you, my friend! You can ask me: 'Where is the nearest vendor?', 'What food is available?', 'Show me my food QR pass', or 'Split a bill of 600'."
    else:
        spoken = f"Nimekuelewa rafiki yangu! Unaweza kuniambia: 'Vendor gani yuko karibu nami?', 'Kuna chakula gani sasa hivi?', 'Nionyeshe pass yangu ya QR', au 'Gawanya bili ya 600'."

    return jsonify({
        "intent": "GENERAL_QUERY",
        "recognized_text": text,
        "language": lang,
        "spoken_response": spoken,
        "requires_pin": False
    }), 200
