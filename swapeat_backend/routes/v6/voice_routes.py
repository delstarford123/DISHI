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
    'chapati': {'name': 'Chapati', 'price': 25.0, 'aliases': ['chapo', 'chapati', 'chapatti']},
    'madondo': {'name': 'Bean Stew (Madondo)', 'price': 50.0, 'aliases': ['madondo', 'beans', 'maharagwe', 'dondo']},
    'beef': {'name': 'Beef Stew', 'price': 90.0, 'aliases': ['beef', 'nyama', 'beef stew', 'ng\'ombe']},
    'chicken': {'name': 'Fried Chicken (Quarter)', 'price': 150.0, 'aliases': ['chicken', 'kuku']},
    'rice': {'name': 'Steamed Rice', 'price': 40.0, 'aliases': ['rice', 'wali', 'pishori']},
    'ugali': {'name': 'White Ugali', 'price': 30.0, 'aliases': ['ugali', 'sembe']},
    'sukuma': {'name': 'Sukuma Wiki Greens', 'price': 20.0, 'aliases': ['sukuma', 'greens', 'mboga']},
    'cabbage': {'name': 'Fried Cabbage', 'price': 20.0, 'aliases': ['cabbage', 'kabeji']},
    'tea': {'name': 'Special Milk Tea', 'price': 30.0, 'aliases': ['tea', 'chai']},
    'mandazi': {'name': 'Mandazi', 'price': 15.0, 'aliases': ['mandazi', 'mahamri']},
    'smokie': {'name': 'Smokie Pasua', 'price': 40.0, 'aliases': ['smokie', 'smoke']},
    'egg': {'name': 'Boiled Egg (Mayai Pasua)', 'price': 30.0, 'aliases': ['egg', 'mayai', 'yai']},
    'soda': {'name': 'Soda 300ml', 'price': 50.0, 'aliases': ['soda', 'coke', 'fanta', 'sprite']},
    'bread': {'name': 'Broadways Bread 400g', 'price': 65.0, 'aliases': ['bread', 'mkate']},
    'milk': {'name': 'Fresh Milk 500ml', 'price': 65.0, 'aliases': ['milk', 'maziwa']},
}

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
    Sema na DISHI Conversational Intent & Command Parser.
    Accepts raw spoken text (or transcribed audio) and returns structured action commands.
    Tailored for Student, Vendor, and Parent campus interactions.
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

    # ==========================================
    # GLOBAL: DISMISS / CANCEL VOICE ASSISTANT
    # ==========================================
    if any(k in low for k in ['acha tu', 'funga', 'cancel', 'tulia', 'stop', 'kwaheri', 'bye', 'dismiss']):
        return jsonify({
            "intent": "DISMISS_VOICE",
            "action": "dismiss",
            "spoken_response": "Sawa, nimefunga. Ukinihitaji gusa maikrofoni wakati wowote.",
            "requires_pin": False
        }), 200

    # Fetch User Balance if UID is provided
    cur_balance = 0.0
    user_name = "Comrade"
    if user_uid:
        try:
            db = firestore.client()
            u_doc = db.collection('users').document(user_uid).get()
            if u_doc.exists:
                udata = u_doc.to_dict()
                cur_balance = float(udata.get('walletBalance', 0.0))
                user_name = udata.get('displayName') or udata.get('name') or "Comrade"
        except Exception:
            pass

    # ==========================================
    # STUDENT SPECIFIC VOICE INTENTS
    # ==========================================
    if role == 'student':
        # 1. Budget Burnout & "Nitatoboa?" Intelligence
        if any(k in low for k in ['nitatoboa', 'pesa itanitosha', 'burn rate', 'hesabu ya wiki', 'daily budget', 'nitamaliza wiki', 'hali ya wallet']):
            today_weekday = datetime.datetime.now().weekday()  # 0=Monday, 6=Sunday
            days_left = max(1, 6 - today_weekday)
            daily_allowance = cur_balance / days_left if cur_balance > 0 else 0.0

            if cur_balance <= 50:
                advice = "Comrade, uko pabaya kidogo! Unaweza kutumia Okoa Meal au uombe mzazi allowance ya dharura."
            elif daily_allowance >= 150:
                advice = f"Uko fiti sana! Unaweza kula vizuri na bado uweke akiba ya wikendi."
            else:
                advice = f"Ukila kawaida (chapati na madondo), pesa itakutosha vizuri hadi mwisho wa wiki."

            spoken = f"Salio lako ni Shilingi {cur_balance:,.0f}. Kila siku unaweza kutumia Shilingi {daily_allowance:,.0f} kwa siku {days_left} zilizobaki. {advice}"
            return jsonify({
                "intent": "CHECK_BUDGET",
                "balance": cur_balance,
                "days_left": days_left,
                "daily_allowance": daily_allowance,
                "spoken_response": spoken,
                "requires_pin": False
            }), 200

        # 2. Instant Payment Pass / Dynamic QR Code
        if any(k in low for k in ['pass', 'qr', 'token', 'barcode', 'lipa', 'kuchukua', 'counter', 'nionyeshe qr']):
            return jsonify({
                "intent": "SHOW_STUDENT_QR",
                "action": "open_qr_pass",
                "spoken_response": "Hii hapa QR pass yako ya chakula. Onyesha mpishi au cashier aiskani kwa counter.",
                "requires_pin": False
            }), 200

        # 3. Emergency Okoa Food Rescue
        if any(k in low for k in ['okoa', 'broke', 'njaa', 'sina kakitu', 'sina pesa', 'emergency meal', 'msaada wa chakula']):
            return jsonify({
                "intent": "OKOA_MEAL",
                "action": "open_okoa_food",
                "spoken_response": "Pole sana comrade. Nimekufungulia Okoa Meal upate chakula cha dharura mara moja bila wasiwasi.",
                "requires_pin": False
            }), 200

        # 4. Request Funds from Parent / Sponsor
        if any(k in low for k in ['omba mzazi', 'omba mum', 'omba dad', 'request funds', 'tuma ombi', 'tumia mzazi', 'omba pesa']):
            amt = extract_amount(text) or 300.0
            return jsonify({
                "intent": "REQUEST_PARENT_FUNDS",
                "amount": amt,
                "action": "open_request_funds",
                "spoken_response": f"Nimeandaa ombi la Shilingi {amt:,.0f} kwa mzazi. Angalia maelezo kisha utume.",
                "requires_pin": False
            }), 200

        # 5. Split Bill with Comrades
        if any(k in low for k in ['gawanya', 'split', 'tuchange', 'changamsha', 'bill']):
            amt = extract_amount(text) or 400.0
            people = 2
            digit_people = re.search(r'(?:watu|people|friends|comrades)?\s*(\d+)', low)
            if digit_people and int(digit_people.group(1)) > 1:
                people = int(digit_people.group(1))
            split_share = amt / people

            return jsonify({
                "intent": "SPLIT_BILL",
                "amount": amt,
                "people": people,
                "share_per_person": split_share,
                "action": "open_split_bill",
                "spoken_response": f"Bili ya Shilingi {amt:,.0f} imegawanywa kwa watu {people}. Kila mtu atatoa Shilingi {split_share:,.0f}.",
                "requires_pin": False
            }), 200

        # 6. Campus Gigs & Hustle Finder
        if any(k in low for k in ['gigs', 'kazi', 'hustle', 'vibaruwa', 'delivery', 'earning', 'kutafuta pesa']):
            return jsonify({
                "intent": "CAMPUS_GIGS",
                "action": "open_campus_gigs",
                "spoken_response": "Kuna kazi za chuo, delivery, na tasks zinazopatikana. Zifungue hapa uanze kupata chapaa.",
                "requires_pin": False
            }), 200

        # 7. Timetable & Lecture Schedule
        if any(k in low for k in ['class', 'darasa', 'timetable', 'ratiba', 'kipindi', 'lecture']):
            return jsonify({
                "intent": "CHECK_TIMETABLE",
                "action": "open_timetable",
                "spoken_response": "Inafungua ratiba yako ya masomo na vipindi vya leo.",
                "requires_pin": False
            }), 200

        # 8. Virtual Card (VCC)
        if any(k in low for k in ['vcc', 'kadi', 'card', 'virtual card', 'debit card']):
            return jsonify({
                "intent": "VIRTUAL_CARD",
                "action": "open_virtual_card",
                "spoken_response": "Inafungua kadi yako ya kidijitali (Virtual Card) kwa malipo ya haraka.",
                "requires_pin": False
            }), 200

        # 9. Meal Discovery & Voice Ordering
        if any(k in low for k in ['nataka', 'agiza', 'order', 'chapati', 'madondo', 'kuku', 'chips', 'wali', 'rice', 'ugali', 'beef', 'smokie', 'mayai', 'chakula']):
            parsed_items = parse_order_items(text)
            if parsed_items:
                total_sum = sum(i['total'] for i in parsed_items)
                item_desc = ", ".join([f"{i['quantity']} {i['name']}" for i in parsed_items])
                return jsonify({
                    "intent": "DISCOVER_MEALS",
                    "items": parsed_items,
                    "total_amount": total_sum,
                    "spoken_response": f"Nimepata {item_desc}. Jumla ni Shilingi {total_sum:,.0f}. Inafungua kikapu cha oda yako.",
                    "requires_pin": False
                }), 200

        # 10. Supermarket & Stationery Shop
        if any(k in low for k in ['supermarket', 'groceries', 'duka', 'scanner', 'skani barcode', 'stationary', 'kalamu', 'vitabu']):
            return jsonify({
                "intent": "OPEN_SUPERMARKET",
                "action": "open_supermarket",
                "spoken_response": "Inafungua duka la chuo, vitafunio na skana ya bidhaa.",
                "requires_pin": False
            }), 200

    # ==========================================
    # PARENT SPECIFIC VOICE INTENTS
    # ==========================================
    if role == 'parent':
        if any(k in low for k in ['tuma pesa', 'fund', 'mtumie', 'allowance', 'pesa ya mtoto']):
            amt = extract_amount(text) or 500.0
            return jsonify({
                "intent": "FUND_STUDENT",
                "amount": amt,
                "spoken_response": f"Unakaribia kumtumia mwanafunzi Shilingi {amt:,.0f} kwa vault. Thibitisha muamala.",
                "requires_pin": True
            }), 200

        if any(k in low for k in ['lishe', 'nutrition', 'chakula alichokula', 'health digest']):
            return jsonify({
                "intent": "NAVIGATE_REPORTS",
                "spoken_response": "Inafungua ripoti ya lishe na afya ya mwanafunzi ya siku kumi na nne zilizopita.",
                "requires_pin": False
            }), 200

    # ==========================================
    # VENDOR SPECIFIC VOICE INTENTS
    # ==========================================
    if role == 'vendor':
        if any(k in low for k in ['jiko', 'kitchen', 'kds']):
            return jsonify({
                "intent": "NAVIGATE_KDS",
                "action": "open_kds",
                "spoken_response": "Inafungua skrini ya jiko (Kitchen Display System).",
                "requires_pin": False
            }), 200

        if any(k in low for k in ['ripoti', 'reports', 'report', 'hesabu']):
            return jsonify({
                "intent": "NAVIGATE_REPORTS",
                "action": "open_reports",
                "spoken_response": "Inafungua ripoti za mauzo na hesabu za siku.",
                "requires_pin": False
            }), 200

        if any(k in low for k in ['stoo', 'operations', 'shughuli', 'inventory']):
            return jsonify({
                "intent": "NAVIGATE_OPERATIONS",
                "action": "open_operations",
                "spoken_response": "Inafungua usimamizi wa shughuli na stoo.",
                "requires_pin": False
            }), 200

        if any(k in low for k in ['tayari', 'ready', 'imeshaiva', 'complete']):
            ticket = extract_ticket_or_pin(text)
            if ticket:
                return jsonify({
                    "intent": "ORDER_READY",
                    "ticket": ticket,
                    "action": "advance_order_status",
                    "status": "Ready for Pickup",
                    "spoken_response": f"Tiketi nambari {ticket} imetiwa alama kuwa tayari kwa kuchukuliwa.",
                    "requires_pin": False
                }), 200
            else:
                return jsonify({
                    "intent": "ORDER_READY",
                    "action": "advance_top_order",
                    "status": "Ready for Pickup",
                    "spoken_response": "Agizo la kwanza limewekwa tayari kwa kuchukuliwa.",
                    "requires_pin": False
                }), 200

        if any(k in low for k in ['toa', 'withdraw', 'cash out', 'tuma kwa till', 'hamisha']):
            amount = extract_amount(text)
            if not amount or amount <= 0:
                return jsonify({
                    "intent": "CASH_OUT_PROMPT",
                    "spoken_response": "Ungependa kutoa kiasi gani cha pesa kwa M-Pesa?",
                    "requires_pin": True
                }), 200
            
            challenge = f"{random.randint(10, 99)}"
            return jsonify({
                "intent": "INITIATE_CASH_OUT",
                "amount": amount,
                "requires_pin": True,
                "challenge_code": challenge,
                "spoken_response": f"Unakaribia kutoa Shilingi {amount:,.0f} kwa M-Pesa. Thibitisha kwa Voice PIN yako au sema {challenge}."
            }), 200

        if any(k in low for k in ['validate', 'thibitisha', 'verify']):
            pin = extract_ticket_or_pin(text)
            if pin:
                return jsonify({
                    "intent": "VALIDATE_PICKUP_PIN",
                    "pin": pin,
                    "spoken_response": f"Inathibitisha PIN {pin} ya chakula.",
                    "requires_pin": False
                }), 200

        if any(k in low for k in ['wholesale', 'jumla', 'stoo', 'distributor', 'restock']):
            return jsonify({
                "intent": "OPEN_WHOLESALE",
                "spoken_response": "Inafungua orodha ya bidhaa za jumla kwa wasambazaji wa chuo.",
                "requires_pin": False
            }), 200

    # ==========================================
    # COMMON QUERY BALANCE (ALL ROLES)
    # ==========================================
    if any(k in low for k in ['nimebaki na ngapi', 'balance', 'float', 'salio', 'pesa ngapi', 'angalia salio']):
        spoken = f"Salio lako kwa sasa ni Shilingi {cur_balance:,.0f}."
        if cur_balance == 0.0:
            spoken = "Salio lako kwa sasa ni shilingi sifuri."

        return jsonify({
            "intent": "QUERY_BALANCE",
            "balance": cur_balance,
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # Fallback to general conversational query
    return jsonify({
        "intent": "GENERAL_QUERY",
        "recognized_text": text,
        "spoken_response": f"Nimepokea: '{text}'. Unaweza kuniambia: 'Nionyeshe QR pass', 'Nitatoboa wiki hii?', au 'Weka chapati mbili madondo'.",
        "requires_pin": False
    }), 200
