import re
import time
import random
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
    # Try digits first
    m = re.search(r'(?:ksh|kes|sh|shilingi)?\s*(\d+(?:,\d+)*(?:\.\d+)?)', text, re.IGNORECASE)
    if m:
        try:
            return float(m.group(1).replace(',', ''))
        except ValueError:
            pass
    # Try textual words
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
    
    # Check for each catalog item
    for item_key, item_info in MENU_ITEMS_CATALOG.items():
        found = False
        for alias in item_info['aliases']:
            if alias in low:
                found = True
                # Look for quantity before or after
                qty = 1
                # Check digits: "2 chapati" or "chapati 2"
                digit_match = re.search(rf'(\d+)\s*{re.escape(alias)}|{re.escape(alias)}\s*(\d+)', low)
                if digit_match:
                    num_str = digit_match.group(1) or digit_match.group(2)
                    qty = int(num_str)
                else:
                    # Check swahili/english words: "chapati mbili", "two chapati"
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
    """
    data = request.json or {}
    text = str(data.get('text', '')).strip()
    role = str(data.get('role', 'vendor')).lower()
    user_uid = str(data.get('uid', '')).strip()

    if not text:
        return jsonify({
            "intent": "EMPTY",
            "spoken_response": "Samahani, sijakusikia vizuri. Tafadhali rudia tena."
        }), 400

    low = text.lower()

    # 1. NAVIGATION INTENTS
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

    if any(k in low for k in ['fedha', 'finance', 'pesa yangu', 'usimamizi wa fedha']):
        return jsonify({
            "intent": "NAVIGATE_FINANCE",
            "action": "open_finance",
            "spoken_response": "Inafungua ukurasa wa fedha na malipo.",
            "requires_pin": False
        }), 200

    if any(k in low for k in ['skani', 'scanner', 'scan', 'piga picha', 'pos']):
        return jsonify({
            "intent": "NAVIGATE_SCANNER",
            "action": "open_scanner",
            "spoken_response": "Inafungua skana ya QR na barcodes.",
            "requires_pin": False
        }), 200

    if any(k in low for k in ['nyumbani', 'home', 'dashboard', 'ukurasa wa kwanza']):
        return jsonify({
            "intent": "NAVIGATE_HOME",
            "action": "open_home",
            "spoken_response": "Inarudi kwenye ukurasa mkuu.",
            "requires_pin": False
        }), 200

    # 2. QUERY BALANCE
    if any(k in low for k in ['nimebaki na ngapi', 'balance', 'float', 'salio', 'pesa ngapi']):
        cur_balance = 0.0
        if user_uid:
            try:
                db = firestore.client()
                u_doc = db.collection('users').document(user_uid).get()
                if u_doc.exists:
                    cur_balance = float(u_doc.to_dict().get('walletBalance', 0))
            except Exception:
                pass
        
        spoken = f"Salio lako la float ni Shilingi {cur_balance:,.0f}."
        if cur_balance == 0.0:
            spoken = "Salio lako la float sasa ni shilingi sifuri."

        return jsonify({
            "intent": "QUERY_BALANCE",
            "balance": cur_balance,
            "spoken_response": spoken,
            "requires_pin": False
        }), 200

    # 3. ORDER READY / TICKET ADVANCEMENT (Hands-Busy Kitchen Mode)
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

    # 4. CASH OUT / WITHDRAWAL
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

    # 5. VALIDATE PICKUP PASS / PIN
    if any(k in low for k in ['validate', 'thibitisha', 'verify']):
        pin = extract_ticket_or_pin(text)
        if pin:
            return jsonify({
                "intent": "VALIDATE_PICKUP_PIN",
                "pin": pin,
                "spoken_response": f"Inathibitisha PIN {pin} ya chakula.",
                "requires_pin": False
            }), 200

    # 6. CREATE POS ORDER (Food or Groceries)
    if any(k in low for k in ['weka', 'ongeza', 'rekodi', 'order', 'add', 'bili', 'agiza']):
        parsed_items = parse_order_items(text)
        if parsed_items:
            total_sum = sum(i['total'] for i in parsed_items)
            item_desc = ", ".join([f"{i['quantity']} {i['name']}" for i in parsed_items])
            return jsonify({
                "intent": "CREATE_POS_ORDER",
                "items": parsed_items,
                "total_amount": total_sum,
                "spoken_response": f"Nimeongeza {item_desc}. Jumla ni Shilingi {total_sum:,.0f}.",
                "requires_pin": False
            }), 200

    # 7. WHOLESALE RESTOCK
    if any(k in low for k in ['wholesale', 'jumla', 'stoo', 'distributor', 'restock']):
        return jsonify({
            "intent": "OPEN_WHOLESALE",
            "spoken_response": "Inafungua orodha ya bidhaa za jumla kwa wasambazaji wa chuo.",
            "requires_pin": False
        }), 200

    # Fallback to conversational response
    return jsonify({
        "intent": "GENERAL_QUERY",
        "recognized_text": text,
        "spoken_response": f"Nimepokea: '{text}'. Unaweza kuniambia: 'Weka chapati mbili madondo', 'Fungua jiko', au 'Toa shilingi elfu moja'.",
        "requires_pin": False
    }), 200

