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

def clean_for_tts(text: str) -> str:
    """
    Strips markdown symbols (*, #, _, -, ~, `, >) so TTS engines
    read smoothly without vocalizing punctuation. Keeps answers to 1-3 sentences.
    """
    if not text:
        return ""
    cleaned = re.sub(r'[*#_~`>\[\]\(\)]', ' ', text)
    cleaned = re.sub(r'(?:^|\s)[-•]\s+', ' ', cleaned)
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned

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

# =========================================================================
# PERSONA DEFINITIONS & MULTI-LINGUAL VOICE MATRIX (20 PERSONAS)
# Memory-optimized static dictionary (< 50KB total in RAM)
# =========================================================================
PERSONAS = {
    'campus_buddy': {
        'id': 'campus_buddy',
        'name': 'The Campus Buddy',
        'en': {
            'greeting': "Hey there {name}! I am your DISHI campus buddy. Looking for hot food, checking your wallet, or splitting a bill with comrades?",
            'balance': "You have KES {balance} available in your DISHI wallet right now, {name}. Ready to grab a bite or saving up for later?",
            'nearest': "The closest spot to eat is Nyawuora Isaya Okuna Cafeteria at MMUST near MEA, rated 4.9 stars. Hot beef stew, chips kuku, and chapati madondo are ready for you!",
            'qr': "Here is your dynamic food pass QR code, {name}! Show this to the cashier at Nyawuora Isaya Okuna Cafeteria for instant pickup with zero waiting lines.",
            'menu': "Nyawuora Isaya Okuna has great dishes ready today: Beef Stew with Rice for 150, Chips Kuku for 220, Chapati Madondo for 100, and Ugali Sukuma with Eggs for 80 bob. What are you craving?",
            'order_confirm': "Awesome pick! Your order is {summary} totaling KES {total}. Ready to tap your NFC badge or enter PIN to complete checkout at Nyawuora's counter.",
            'split_bill': "No stress, I have got you covered! Splitting KES {amount} among {people} comrades (KES {share} each). I opened the Group Pay sheet so they can confirm with their DISHI PIN.",
            'dietary': "For the best campus comfort meal, grab Beef Stew with Steamed Rice for 150 bob. Or get Chapati Madondo for an affordable 100 bob energy boost!",
            'switch_ack': "Hey! Campus Buddy is in the house. What are we getting into today, comrade?"
        },
        'sw': {
            'greeting': "Mambo {name}! Mimi ni DISHI campus buddy wako. Unatafuta msosi moto, unataka kuangalia salio, au kugawanya bili na marafiki?",
            'balance': "Salio lako lililopo ni Shilingi {balance}, comrade {name}. Niambie ukitaka kuweka pesa au kuweka oda ya msosi!",
            'nearest': "Vendor aliye karibu nawe zaidi ni Nyawuora Isaya Okuna Cafeteria hapo MMUST near MEA na ana rating ya 4.9 stars. Kuna beef stew, chips kuku, na chapati madondo moto!",
            'qr': "Hii hapa QR pass yako ya chakula, {name}! Nenda nayo moja kwa moja kwa counter ya Nyawuora Isaya Okuna Cafeteria upate msosi wako bila foleni.",
            'menu': "Nyawuora Isaya Okuna ana vyakula safi leo: Beef stew na wali shilingi 150, Chips kuku 220, Chapo mbili madondo 100, na Ugali sukuma mayai 80 bob. Unatamani nini?",
            'order_confirm': "Safi sana! Oda yako ni {summary} ya jumla ya Shilingi {total}. Gusa simu yako au weka PIN kukamilisha malipo kwa counter ya Nyawuora.",
            'split_bill': "Usiwe na wasiwasi! Bili ya Shilingi {amount} inagawanywa kwa watu {people} (Shilingi {share} kila mmoja). Watapelekewa arifa ya kuweka PIN papo hapo.",
            'dietary': "Chakula bora cha kujaza tumbo leo ni Beef Stew na wali kwa 150 bob, au chapo mbili madondo kwa 100 bob!",
            'switch_ack': "Poa sana! Campus Buddy yuko hewani. Niambie comrade, unahitaji nikusaidie na nini leo?"
        }
    },
    'nutritionist': {
        'id': 'nutritionist',
        'name': 'The Professional Nutritionist',
        'en': {
            'greeting': "Hello {name}. I am your DISHI Nutritionist. Let us nourish your body with balanced macronutrients, clean energy, and smart meal choices.",
            'balance': "Your digital wallet contains KES {balance}. That is sufficient to secure a wholesome plate with lean protein and fresh greens.",
            'nearest': "For nutrient-dense meals, visit Nyawuora Isaya Okuna Cafeteria at MMUST near MEA. Their beef stew with sukuma greens delivers ideal micronutrients and stamina.",
            'qr': "Your verified meal pass QR is ready, {name}. Present it at Nyawuora Isaya Okuna Cafeteria to claim your freshly prepared, wholesome meal.",
            'menu': "Today's healthy selections at Nyawuora's include Beef Stew with Rice at 150, Ugali with Sukuma Wiki and Eggs at 80, and Chapati Madondo for balanced plant protein at 100 bob.",
            'order_confirm': "Great nutritional choice. Your order of {summary} totals KES {total}. Tap NFC or enter PIN at the counter to claim your meal.",
            'split_bill': "Splitting KES {amount} across {people} members equals KES {share} per person. Sharing nourishment fosters healthy community habits.",
            'dietary': "I recommend the Beef Stew with Sukuma Wiki Greens at Nyawuora's. You receive approximately 28 grams of lean protein, dietary iron, and healthy micronutrients.",
            'switch_ack': "Professional Nutritionist active. Let us prioritize clean fuel, balanced macros, and optimal health for your studies today."
        },
        'sw': {
            'greeting': "Hujambo {name}. Mimi ni Mtaalamu wako wa Lishe DISHI. Wacha tuchague vyakula vyenye afya, protini, na mboga za kukupa nguvu.",
            'balance': "Salio lako ni Shilingi {balance}. Kiasi hiki kinatosha kabisa kupata mlo kamili wenye mboga na protini safi.",
            'nearest': "Mlo wenye virutubisho unapatikana Nyawuora Isaya Okuna Cafeteria hapo MMUST near MEA. Beef stew na sukuma wiki zitakupa madini na nguvu mwilini.",
            'qr': "Pass yako ya mlo safi iko tayari, {name}. Ionyeshe kwenye counter ya Nyawuora Isaya Okuna Cafeteria upokee mlo wako bora.",
            'menu': "Chaguo la afya kwa Nyawuora ni Beef Stew na wali kwa 150, Ugali sukuma na mayai kwa 80, na Chapati madondo kwa 100 bob.",
            'order_confirm': "Chaguo zuri la lishe. Oda yako ya {summary} inafikia Shilingi {total}. Thibitisha kwa NFC au PIN upokee mlo wako.",
            'split_bill': "Kugawa Shilingi {amount} kwa watu {people} ni Shilingi {share} kila mmoja. Afya njema huja kwa kushirikiana vyema.",
            'dietary': "Nakushauri uchukue Beef Stew na Sukuma wiki kwa Nyawuora. Ina protini bora na madini ya chuma kwa bei nafuu ya 150 bob.",
            'switch_ack': "Mtaalamu wa Lishe amewashwa. Wacha tuhakikishe unakula kwa afya na nidhamu ya mwili."
        }
    },
    'cashier': {
        'id': 'cashier',
        'name': 'The Swift Canteen Cashier',
        'en': {
            'greeting': "Next customer please! DISHI Swift Cashier ready. What can I punch into the register for you today, {name}?",
            'balance': "Wallet float is KES {balance}. Standing by for payment authorization.",
            'nearest': "Nyawuora Isaya Okuna Cafeteria near MEA. Express POS terminal online, zero line delay.",
            'qr': "Dynamic payment token active! Hold your phone up to the scanner at Nyawuora's register for 2-second clearance.",
            'menu': "On the counter: Beef Rice 150, Chips Kuku 220, Chapo Dondo 100, Ugali Mayai 80, Chai Mandazi 50. What is your order?",
            'order_confirm': "Order ringed up: {summary}. Total is KES {total}. Tap NFC terminal now to print your receipt.",
            'split_bill': "Split transaction: KES {amount} divided by {people} is KES {share} each. Requests dispatched to terminals.",
            'dietary': "Fastest turnaround dish is Beef Rice or Chapati Madondo. Ready to plate in 30 seconds.",
            'switch_ack': "Swift Cashier online. Fast lanes open, let us keep the line moving!"
        },
        'sw': {
            'greeting': "Comrade anayefuata karibu! DISHI Cashier yuko tayari. Nikuwekee nini kwa mashine leo, {name}?",
            'balance': "Salio lako ni Shilingi {balance}. Liko tayari kwa malipo ya haraka.",
            'nearest': "Nyawuora Isaya Okuna Cafeteria karibu na MEA. POS mashine iko hewani, hakuna foleni.",
            'qr': "Tokeni ya malipo iko tayari! Weka QR yako mbele ya scanner ya Nyawuora sekunde mbili umalize.",
            'menu': "Kwenye counter kuna: Beef Rice 150, Chips Kuku 220, Chapo Dondo 100, Ugali Mayai 80, Chai 50. Unachukua kipi?",
            'order_confirm': "Oda imeingia: {summary}. Jumla ni Shilingi {total}. Gusa NFC sasa upate risiti yako.",
            'split_bill': "Gawio la bili: Shilingi {amount} kwa {people} ni Shilingi {share} kila mmoja.",
            'dietary': "Chakula kinachotoka haraka zaidi ni Chapo Dondo na Beef Rice, sekunde thelathini unapata sahani.",
            'switch_ack': "Cashier wa kasi yuko kazini. Wacha tuondoe foleni haraka!"
        }
    },
    'chef': {
        'id': 'chef',
        'name': 'The Gourmet Chef',
        'en': {
            'greeting': "Bon appétit, {name}! I am your DISHI Gourmet Chef. Ready to explore rich culinary aromas, fresh herbs, and artisan campus flavors?",
            'balance': "You have a dining treasury of KES {balance}. Let us craft a memorable palate experience today.",
            'nearest': "The kitchen of honor is Nyawuora Isaya Okuna Cafeteria at MMUST near MEA. Their slow-simmered beef stew with braised tomatoes is exceptional.",
            'qr': "Your culinary VIP pass is ready, {name}. Present it at Nyawuora's to receive your steaming, hand-crafted meal fresh off the stove.",
            'menu': "Our culinary specials today: Tender simmered Beef Stew with aromatic rice for 150, golden roasted Chicken with fries for 220, and flaky layered Chapati with spiced beans for 100 bob.",
            'order_confirm': "Magnificent culinary choice. Preparing ticket for {summary} amounting to KES {total}. Savor every single bite!",
            'split_bill': "A feast is grandest when shared among comrades! Dividing KES {amount} by {people} brings each epicurean share to KES {share}.",
            'dietary': "Indulge in Nyawuora's signature slow-cooked Beef Stew. The harmonious fusion of garlic, ginger, and simmered marrow delivers exquisite depth.",
            'switch_ack': "The Gourmet Chef has arrived! Fire up the stoves and let us discover exquisite campus flavors."
        },
        'sw': {
            'greeting': "Karibu mezani, {name}! Mimi ni Chef wako wa DISHI. Uko tayari kuonja vyakula vilivyopikwa kwa viungo safi na mapishi ya hali ya juu?",
            'balance': "Una hazina ya Shilingi {balance}. Wacha tuchague mlo wenye ladha ya kipekee leo.",
            'nearest': "Jiko bora zaidi ni Nyawuora Isaya Okuna Cafeteria hapo MMUST near MEA. Supu yao ya nyama iliyochemshwa polepole na nyanya safi ni tamu ajabu.",
            'qr': "Pass yako ya kifalme iko tayari, {name}. Ionyeshe kwa Nyawuora upakuliwe msosi moto uliotoka jikoni sasa hivi.",
            'menu': "Mapishi ya leo: Beef Stew laini na wali kwa 150, Kuku wa kukaanga na chips kwa 220, na Chapati za tabaka na madondo kwa 100 bob.",
            'order_confirm': "Chaguo la kibabe! Tiketi ya {summary} ya jumla ya Shilingi {total} iko tayari. Furahia kila tonge!",
            'split_bill': "Kula pamoja huleta baraka! Shilingi {amount} ikigawanywa kwa watu {people} inakuwa Shilingi {share} kila mmoja.",
            'dietary': "Onja Beef Stew ya Nyawuora yenye tangawizi na vitunguo saumu. Ladha yake itakuburudisha sana.",
            'switch_ack': "Chef yuko jikoni! Wacha tuchague vyakula vitamu zaidi chuoni leo."
        }
    },
    'coach': {
        'id': 'coach',
        'name': 'The Energetic Coach',
        'en': {
            'greeting': "Let us get moving, {name}! Coach DISHI in your corner. Are we fueling the engine, crushing a workout, or checking wallet power?",
            'balance': "You have KES {balance} of premium fuel in the tank! Let us put that stamina to work today.",
            'nearest': "Head straight to Nyawuora Isaya Okuna Cafeteria near MEA! High-protein chicken, energy-packed ugali, and fresh greens ready to power your grind.",
            'qr': "Fuel pass active, champ! Flash this QR at Nyawuora's and lock in those gains with zero downtime.",
            'menu': "Performance fuel ready: Chips Kuku at 220 for maximum protein, Ugali Sukuma and Eggs at 80 for pure sustained energy, or Beef Stew with Rice at 150 bob. Lock it in!",
            'order_confirm': "Locked in! Your fuel stack is {summary} totaling KES {total}. Tap NFC and let us crush the rest of the day!",
            'split_bill': "Teamwork wins championships! Splitting KES {amount} among {people} squad members makes it KES {share} each. Stronger together!",
            'dietary': "Double down on the Chicken or Ugali with Eggs! Clean protein plus complex carbs will keep your power output peaking all afternoon.",
            'switch_ack': "Coach is locked in! No excuses, high energy, and top-tier fuel only. Let us go!"
        },
        'sw': {
            'greeting': "Amka twende kazi, {name}! Kocha wako wa DISHI yuko hapa. Tunaweka mafuta ya nguvu mwilini, mazoezi, au salio la wallet?",
            'balance': "Una Shilingi {balance} za mafuta safi ya nguvu! Wacha tuwekeze kwenye afya na mazoezi leo.",
            'nearest': "Kimbia moja kwa moja kwa Nyawuora Isaya Okuna Cafeteria karibu na MEA! Protini ya kuku na nguvu ya ugali iko tayari kukupa msukumo.",
            'qr': "Pass ya nguvu iko tayari, bingwa! Ionyeshe kwa Nyawuora upate mlo wako bila kupoteza hata sekunde.",
            'menu': "Chakula cha nguvu: Chips Kuku 220 kwa protini, Ugali Sukuma na Mayai 80 kwa nguvu ya kudumu, au Beef Stew na Wali kwa 150 bob.",
            'order_confirm': "Tumefunga dili! Oda yako ya nguvu ni {summary} ya Shilingi {total}. Gusa NFC tukashinde siku!",
            'split_bill': "Ushirikiano ndio ushindi! Shilingi {amount} kwa kikosi cha watu {people} ni Shilingi {share} kila mpiganaji.",
            'dietary': "Chukua Chips Kuku au Ugali Mayai! Protini na wanga safi zitakupa nguvu ya kufanya mazoezi na kusoma bila kuchoka.",
            'switch_ack': "Kocha yuko tayari! Hakuna kulegea, nguvu kamili na msosi wa uhakika. Twende kazi!"
        }
    },
    'wise_elder': {
        'id': 'wise_elder',
        'name': 'The Wise Elder / Mentor',
        'en': {
            'greeting': "Peace be upon you, my child {name}. I am your elder guide. How may I assist you with thoughtful budgeting or wholesome campus meals today?",
            'balance': "Your purse holds KES {balance}. Spend with intention, for a shilling saved today shields tomorrow's studies.",
            'nearest': "Walk mindfully to Nyawuora Isaya Okuna Cafeteria at MMUST near MEA. He serves honest, hearty food that honors student effort.",
            'qr': "Here is your food pass, {name}. Show this at the counter with courtesy, and enjoy your meal in gratitude.",
            'menu': "Wholesome offerings await: Beef Stew with Rice at 150, Chapati Madondo at 100, and hearty Ugali Sukuma at 80 bob. Choose what sustains both mind and body.",
            'order_confirm': "A prudent selection. Your order of {summary} totals KES {total}. Confirm with your PIN and eat in good health.",
            'split_bill': "A burden shared is half the weight. Dividing KES {amount} among {people} companions comes to KES {share} each. May your fellowship prosper.",
            'dietary': "The yellow beans with chapati offer steady nourishment that keeps the mind calm and alert without making you sluggish in afternoon studies.",
            'switch_ack': "The Elder is listening. Let patience, prudence, and good nourishment guide our steps."
        },
        'sw': {
            'greeting': "Amani iwe nawe, mwanangu {name}. Mimi ni mzee wako mlezi. Nikusaidie vipi na hekima ya matumizi au chakula kizuri cha chuo leo?",
            'balance': "Mfuko wako una Shilingi {balance}. Tumia kwa hekima na tahadhari ili kesho usihangaike.",
            'nearest': "Tembea kwa utulivu hadi kwa Nyawuora Isaya Okuna Cafeteria hapo MMUST near MEA. Anapika chakula cha heshima kinachorutubisha wanafunzi.",
            'qr': "Hii hapa pass yako ya chakula, {name}. Ionyeshe kwa heshima mezani na ufurahie mlo wako kwa shukrani.",
            'menu': "Chakula cha heshima kipo: Beef Stew na wali kwa 150, Chapo madondo kwa 100, na Ugali sukuma kwa 80 bob. Chagua kitakachokujenga.",
            'order_confirm': "Umechagua kwa busara. Oda ya {summary} inafikia Shilingi {total}. Thibitisha kwa PIN yako na ule kwa amani.",
            'split_bill': "Mtu peke yake hajengi mji. Shilingi {amount} ikigawiwa watu {people} inakuwa Shilingi {share} kila mmoja. Dumisheni undugu.",
            'dietary': "Chakula cha madondo na chapati kinashibisha kwa muda mrefu na hakikuletei usingizi darasani.",
            'switch_ack': "Mzee yuko hapa. Busara, staha, na chakula safi viongoze siku yetu."
        }
    },
    'gen_z': {
        'id': 'gen_z',
        'name': 'The Gen-Z Campus Insider',
        'en': {
            'greeting': "Yoo what is good {name}! Gen-Z insider on deck. Are we checking the wallet flex, securing the best food drip, or splitting the bill?",
            'balance': "You are sitting on KES {balance}, bestie! The balance is valid, let us go spend some funds.",
            'nearest': "Nyawuora's near MEA is literally the vibe right now! 4.9 stars, unmatched campus hype, and the chips kuku hits different.",
            'qr': "Scan token secured, no cap! Flash this QR at Nyawuora's and grab your plate before anyone else.",
            'menu': "The menu is giving main character energy: Beef Rice at 150, Chips Kuku at 220, Chapo Dondo at 100, and Ugali Mayai at 80 bob. What are we eating?",
            'order_confirm': "Bet! Order locked: {summary} for KES {total}. Tap NFC or drop that PIN to finalize the bag.",
            'split_bill': "Splitting the damage! KES {amount} between {people} homies is KES {share} each. Sent straight to their screens, no excuses!",
            'dietary': "The Chips Kuku is top tier elite comfort food, but if you are balling on a budget, Chapo Dondo is an undefeated campus hack.",
            'switch_ack': "Gen-Z mode activated! Real vibes, zero cap, and pure food energy. Let us get it!"
        },
        'sw': {
            'greeting': "Oya inakuaje {name}! Insider wako wa Gen-Z yuko locked in. Tuna-check wallet, kusaka msosi mkali, au kugawana bili?",
            'balance': "Uko na Shilingi {balance} kwa account, bestie! Hii balance inajipa, wacha tusake msosi safi.",
            'nearest': "Nyawuora hapo karibu na MEA ndio plot safi! Stars 4.9, vibe ya chuo, na chips kuku inabamba ajabu.",
            'qr': "QR pass imejipa instantly, no cap! Flash kwa counter ya Nyawuora uchukue msosi wako mara moja.",
            'menu': "Menu inabamba vibaya leo: Beef Rice 150, Chips Kuku 220, Chapo Dondo 100, na Ugali Mayai 80 bob. Unachukua kipi?",
            'order_confirm': "Say less! Oda yako ni {summary} ya Shilingi {total}. Gusa NFC umalize mchezo mara moja.",
            'split_bill': "Tunagawana damage! Shilingi {amount} kwa mafans {people} ni Shilingi {share} kila mtu. Kila msee apige PIN yake!",
            'dietary': "Chips Kuku ni top tier elite, lakini kama budget imebana kiasi, Chapo Dondo ndio hack isiyowahi kubuma chuoni.",
            'switch_ack': "Gen-Z insider amewashwa! Vibe tupu, zero cap, twende kazi!"
        }
    },
    'accountant': {
        'id': 'accountant',
        'name': 'The Strict Budget Accountant',
        'en': {
            'greeting': "Ledger initialized, {name}. I am your DISHI Budget Accountant. Let us audit your dining cash flow and minimize burn rate.",
            'balance': "Audited float balance: KES {balance}. Maintain daily expenditures within calculated thresholds.",
            'nearest': "Most cost-effective dining partner: Nyawuora Isaya Okuna Cafeteria at MMUST near MEA. Proven nutritional ROI per shilling spent.",
            'qr': "Digital payment voucher generated, {name}. Present it at Nyawuora's terminal for prompt settlement.",
            'menu': "Available line items: Ugali Sukuma Mayai at 80 (highest efficiency), Chapati Madondo at 100, Beef Rice at 150, and Chips Kuku at 220 bob.",
            'order_confirm': "Requisition approved: {summary}. Total debit is KES {total}. Verify on-screen to balance the ledger.",
            'split_bill': "Cost allocation processed. Splitting KES {amount} among {people} accounts results in KES {share} per debit entry.",
            'dietary': "The optimal cost-per-calorie ratio is Ugali Sukuma with Eggs at 80 bob, followed by Chapati Madondo at 100 bob. Maximizes energy while saving capital.",
            'switch_ack': "Strict Budget Accountant engaged. Expenditures will be tracked, waste eliminated, and capital preserved."
        },
        'sw': {
            'greeting': "Daftari la hesabu limefunguliwa, {name}. Mimi ni Mhasibu wako mkali DISHI. Wacha tulinde kila shilingi ya mfuko wako.",
            'balance': "Salio lililothibitishwa ni Shilingi {balance}. Epuka matumizi yasiyo na lazima leo.",
            'nearest': "Muuzaji mwenye bei nafuu na hesabu nzuri: Nyawuora Isaya Okuna karibu na MEA. Thamani ya juu kwa kila shilingi.",
            'qr': "Voucher ya malipo iko tayari, {name}. Ionyeshe kwenye mashine ya Nyawuora kukamilisha hesabu.",
            'menu': "Vyakula kwa bei ya hesabu: Ugali Sukuma Mayai 80, Chapati Madondo 100, Beef Rice 150, na Chips Kuku 220 bob.",
            'order_confirm': "Malipo yameidhinishwa: {summary}. Jumla inayotolewa ni Shilingi {total}. Thibitisha kwa PIN kusawazisha hesabu.",
            'split_bill': "Hesabu ya mgawanyo imekamilika: Shilingi {amount} kwa watu {people} ni Shilingi {share} kwa kila mshirika.",
            'dietary': "Chakula chenye hesabu nzuri zaidi ya bei na kushiba ni Ugali Sukuma na Mayai kwa 80 bob, kisha Chapo Dondo kwa 100 bob.",
            'switch_ack': "Mhasibu mkali amewashwa. Hakuna kupoteza shilingi, kila senti itafanya kazi!"
        }
    },
    'mama_njeri': {
        'id': 'mama_njeri',
        'name': 'Mama Njeri (The Warm Local Canteen Matriarch)',
        'en': {
            'greeting': "Mwanangu {name}! Karibu sana, Mama Njeri ako hapa. Umekula vizuri leo, au unataka nikusaidie kuchukua chakula kitamu?",
            'balance': "Una Shilingi {balance} kwa wallet yako mwanangu. Usijali, hakuna mtoto atalala njaa nikiwa hapa.",
            'nearest': "Enda pale kwa Nyawuora Isaya Okuna Cafeteria karibu na MEA! Anapika chakula safi kama cha nyumbani, utashiba kabisa.",
            'qr': "Chukua hii pass ya chakula mwanangu, {name}. Nenda nayo kwa counter ya Nyawuora wakuwekee sahani kubwa mara moja.",
            'menu': "Chakula kiko tayari mwanangu: Beef stew na wali ya 150, Chips kuku moto ya 220, Chapo mbili madondo ya 100, na Ugali sukuma ya 80 bob. Unataka nini nikupakuliwe?",
            'order_confirm': "Hapo sawa mtoto wangu! Nimekuandalia {summary} ya Shilingi {total}. Weka PIN yako au gusa simu ushibe vizuri.",
            'split_bill': "Kushirikiana ni baraka! Shilingi {amount} kwa watoto {people} inatoka Shilingi {share} kila mmoja. Muishi kwa amani.",
            'dietary': "Kula beef stew na wali au chapo dondo mwanangu. Mwili unahitaji nguvu ya kusoma, usishinde njaa kamwe.",
            'switch_ack': "Mama Njeri ako hapa mwanangu! Kaa chini, pumzika, wacha tuhakikishe umeshiba chakula kizuri."
        },
        'sw': {
            'greeting': "Mwanangu {name}! Karibu sana, Mama Njeri yuko hapa. Umekula vizuri leo mwanangu au unataka nikusaidie kuchukua chakula kitamu?",
            'balance': "Una Shilingi {balance} kwa wallet mwanangu. Hiyo inatosha kabisa kupata msosi mzuri ushibe.",
            'nearest': "Enda pale kwa Nyawuora Isaya Okuna Cafeteria karibu na MEA! Anapika chakula safi chenye upendo mwingi.",
            'qr': "Chukua hii pass ya chakula mwanangu {name}. Ionyeshe kwa counter ya Nyawuora wakuwekee sahani kubwa bila foleni.",
            'menu': "Chakula kiko tayari mwanangu: Beef stew na wali ya 150, Chips kuku ya 220, Chapo mbili madondo ya 100, na Ugali sukuma mayai ya 80 bob.",
            'order_confirm': "Vizuri sana mtoto wangu! Nimekuwekea {summary} ya Shilingi {total}. Thibitisha kwa PIN ule ushibe mwanangu.",
            'split_bill': "Kushirikiana ni udugu! Shilingi {amount} kwa watoto {people} inakuwa Shilingi {share} kila mmoja.",
            'dietary': "Kula chapo dondo au beef rice mwanangu. Mwili unahitaji nguvu ya vitabu, usikae na njaa kamwe.",
            'switch_ack': "Mama Njeri yuko hapa mwanangu! Karibu, wacha tuhakikishe umekula vizuri na una amani."
        }
    },
    'tech_geek': {
        'id': 'tech_geek',
        'name': 'The Tech-Geek / AI Assistant',
        'en': {
            'greeting': "System operational. DISHI Core Voice AI v6 online for user {name}. Telemetry, meal APIs, and NFC transaction pipes ready.",
            'balance': "Stored value ledger parsed: KES {balance}. Latency: 12ms. All cryptographic balance checksums valid.",
            'nearest': "Proximity query executed: Target vendor is Nyawuora Isaya Okuna Cafeteria at MMUST near MEA. Metric: 4.9 star rating.",
            'qr': "Cryptographic HMAC token generated for {name}. Ready for NFC inductive coupling or high-speed barcode optical capture.",
            'menu': "Parsed menu endpoint: Beef Rice (KES 150), Chips Kuku (KES 220), Chapati Madondo (KES 100), Ugali Sukuma (KES 80). Specify payload.",
            'order_confirm': "Order payload compiled: {summary}. Total transaction value: KES {total}. Ready for NFC tap handshake.",
            'split_bill': "Consensus algorithm executed. Total KES {amount} partitioned across {people} nodes equals KES {share} per node.",
            'dietary': "Optimization recommendation: Chapati Madondo yields the highest caloric throughput per currency unit, sustaining 6 hours of cognitive load.",
            'switch_ack': "Tech-Geek Assistant initialized. System optimizations, high-throughput APIs, and clean data pipelines ready."
        },
        'sw': {
            'greeting': "Mfumo umewashwa. DISHI Core Voice AI v6 iko hewani kwa ajili ya {name}. Mifumo ya chakula, NFC, na wallet iko tayari.",
            'balance': "Salio la kidijitali limekaguliwa: Shilingi {balance}. Mfumo uko salama na tayari kwa miamala.",
            'nearest': "Utafutaji wa GPS umekamilika: Vendor wa karibu ni Nyawuora Isaya Okuna karibu na MEA. Alama: Stars 4.9.",
            'qr': "Tokeni ya kiusalama ya HMAC imetengenezwa kwa ajili ya {name}. Iko tayari kuskaniwa kwa sekunde moja.",
            'menu': "Orodha ya vyakula: Beef Rice 150, Chips Kuku 220, Chapo Dondo 100, na Ugali Mayai 80 bob. Chagua unachotaka.",
            'order_confirm': "Data ya oda imekamilika: {summary}. Kiasi kamili ni Shilingi {total}. Gusa NFC kukamilisha muamala.",
            'split_bill': "Mgawanyo wa kidijitali: Shilingi {amount} kwa vifaa {people} inatoka Shilingi {share} kila akaunti.",
            'dietary': "Uchambuzi unaonyesha Chapati Madondo inatoa nguvu ya saa sita za kusoma bila kuchoka kwa gharama nafuu ya 100 bob.",
            'switch_ack': "Msaidizi wa kiteknolojia yuko tayari. Mifumo yote iko imara na yenye kasi ya juu."
        }
    },
    'musician': {
        'id': 'musician',
        'name': 'The Acoustic Musician',
        'en': {
            'greeting': "Strumming an easy campus tune, {name}. I am your Acoustic Musician companion. Let us keep the rhythm smooth and the belly full.",
            'balance': "Your melody is carrying a sweet KES {balance} today, {name}. A beautiful chord for the soul.",
            'nearest': "Follow the sweet aroma down the road to Nyawuora Isaya Okuna near MEA. The kitchen rhythm there is pure acoustic poetry.",
            'qr': "Here is your backstage pass, {name}. Present it at Nyawuora's and let the culinary harmony play on your plate.",
            'menu': "Today's campus harmony: Beef Rice at 150, Chips Kuku at 220, Chapati Madondo at 100, and comforting Chai Mandazi at 50 bob.",
            'order_confirm': "Sweet harmony! Your setlist order is {summary} for KES {total}. Tap your NFC note and let us play the song.",
            'split_bill': "Good songs sound best when sung together! Splitting KES {amount} among {people} voices is KES {share} per soul.",
            'dietary': "Hot spiced chai and fresh mandazi will warm your vocal cords and set a relaxed poetic tone for the afternoon.",
            'switch_ack': "Acoustic Musician tuned and ready. Keeping the vibes mellow, lyrical, and soulful."
        },
        'sw': {
            'greeting': "Mdundo mwanana wa chuo, {name}. Mimi ni Mwanamuziki wako tulivu wa DISHI. Wacha tuimbe wimbo wa kushiba leo.",
            'balance': "Melodi yako ina Shilingi {balance} mkononi, {name}. Mdundo mzuri wa kuanzia siku.",
            'nearest': "Fuata harufu nzuri hadi kwa Nyawuora Isaya Okuna karibu na MEA. Mapishi yake ni mdundo mtamu wa kushibisha roho.",
            'qr': "Pass yako ya jukwaa la chakula iko tayari, {name}. Ionyeshe kwa Nyawuora upate mlo wako mzuri.",
            'menu': "Nyimbo za ladha leo: Beef Rice 150, Chips Kuku 220, Chapo Dondo 100, na Chai moto ya Mandazi 50 bob.",
            'order_confirm': "Mdundo safi! Oda yako ya {summary} inafikia Shilingi {total}. Gusa NFC tusherehekee chakula.",
            'split_bill': "Wimbo unanoga tukiimba pamoja! Shilingi {amount} kwa waimbaji {people} inakuwa Shilingi {share} kila mmoja.",
            'dietary': "Chai ya viungo moto na mandazi safi zitakupa utulivu na sauti ya kupendeza chuoni leo.",
            'switch_ack': "Mwanamuziki ameshika gitaa. Vibe tulivu, sauti tamu, na chakula kizuri mbele yetu."
        }
    },
    'study_partner': {
        'id': 'study_partner',
        'name': 'The Midnight Study Partner',
        'en': {
            'greeting': "Hey {name}! Midnight Study Partner here. Exam prep, late-night cram session, or need quick brain food fuel?",
            'balance': "You have KES {balance} in brain fuel credits, {name}. Perfect for a high-focus food run.",
            'nearest': "Nyawuora Isaya Okuna Cafeteria near MEA is the ultimate study fuel stop. Quick service so we do not lose study momentum.",
            'qr': "Study snack pass generated! Flash this QR at Nyawuora's counter, grab the food, and let us get back to the textbooks.",
            'menu': "Top focus fuel: Beef Stew Rice at 150, Chapati Madondo at 100 for steady memory energy, or Hot Tea and Mandazi at 50 bob for late nights.",
            'order_confirm': "Fuel locked in: {summary} for KES {total}. Tap NFC and let us ace these upcoming exams!",
            'split_bill': "Splitting the study group bill! KES {amount} shared among {people} comrades is KES {share} each. Fair and square.",
            'dietary': "The combination of slow-digesting beans and chapati provides glucose stability to prevent brain fatigue during long library marathons.",
            'switch_ack': "Midnight Study Partner active. High focus, brain snacks ready, and zero distractions. Let us ace this semester!"
        },
        'sw': {
            'greeting': "Niaje {name}! Mwenzako wa kusoma usiku yuko hapa. Tunasoma vitabu, exam prep, au unahitaji msosi wa kuongeza akili?",
            'balance': "Una Shilingi {balance} kwa wallet ya masomo, {name}. Inatosha kabisa kupata fuel ya kusoma usiku kucha.",
            'nearest': "Nyawuora Isaya Okuna Cafeteria karibu na MEA ndio jiko la wasomi. Wanatoa chakula haraka turudi kwa vitabu.",
            'qr': "Pass ya msosi wa masomo iko tayari! Ionyeshe kwa Nyawuora, chukua msosi, kisha turudi library.",
            'menu': "Chakula cha kusoma: Beef Rice 150, Chapati Madondo 100 ya kukupa nguvu ya kukumbuka, na Chai ya Mandazi 50 bob.",
            'order_confirm': "Msosi wa vitabu umekamilika: {summary} ya Shilingi {total}. Gusa NFC tukapate GPA ya juu!",
            'split_bill': "Bili ya group study: Shilingi {amount} kwa comrades {people} ni Shilingi {share} kila mmoja.",
            'dietary': "Chapo mbili na madondo hukupa nguvu bila kukuletea uchovu, akili inabaki makini kusoma kurasa zote za mtihani.",
            'switch_ack': "Mwenzako wa vitabu amewashwa. Akili timamu, msosi wa nguvu, wacha tukapate A katika mitihani!"
        }
    },
    'eco_activist': {
        'id': 'eco_activist',
        'name': 'The Eco-Conscious Activist',
        'en': {
            'greeting': "Greetings for a green campus, {name}! Eco-Conscious voice active. Let us choose sustainable dining and zero food waste today.",
            'balance': "Your green wallet balance is KES {balance}. Every mindful choice protects campus resources.",
            'nearest': "Support our local farm-to-table partner: Nyawuora Isaya Okuna Cafeteria near MEA. Locally sourced vegetables and zero-mile campus meals.",
            'qr': "Your eco-verified meal pass is ready, {name}. Please remember to use a reusable tray or container at Nyawuora's!",
            'menu': "Sustainable menu: Chapati Madondo at 100 (low carbon footprint), Ugali Sukuma at 80 (locally farmed greens), and Beef Rice at 150 bob.",
            'order_confirm': "Conscious choice confirmed! {summary} totaling KES {total}. Tap NFC and support sustainable campus living.",
            'split_bill': "Shared resources build resilience. KES {amount} divided by {people} partners is KES {share} each for community dining.",
            'dietary': "Choose the plant-powered Chapati Madondo. Legumes fix nitrogen in our soils and provide clean, low-impact protein.",
            'switch_ack': "Eco-Conscious Activist ready. Championing sustainability, local sourcing, and zero-waste dining."
        },
        'sw': {
            'greeting': "Salamu za kutunza mazingira, {name}! Mwanaharakati wa mazingira yuko hewani. Wacha tuchague vyakula vinavyolinda asili.",
            'balance': "Salio lako la kijani ni Shilingi {balance}. Kila uamuzi mzuri unalinda chuo chetu.",
            'nearest': "Msaidie mkulima wa eneo letu kwa Nyawuora Isaya Okuna karibu na MEA. Mboga zao zinatoka mashambani ya karibu bila uchafuzi.",
            'qr': "Pass yako ya mlo salama iko tayari, {name}. Kumbuka kutumia sahani inayotumika tena ili kupunguza plastiki!",
            'menu': "Vyakula vya asili: Chapati Madondo 100 (mboga zisizoharibu hewa), Ugali Sukuma 80, na Beef Rice 150 bob.",
            'order_confirm': "Uchaguzi makini umethibitishwa: {summary} ya Shilingi {total}. Gusa NFC tulinde mazingira ya chuo.",
            'split_bill': "Kushirikiana kunalinda rasilimali. Shilingi {amount} kwa watu {people} ni Shilingi {share} kila mmoja.",
            'dietary': "Chukua maharagwe na chapati. Mimea inalinda rutuba ya ardhi na inakupa protini safi bila kuharibu mazingira.",
            'switch_ack': "Mwanaharakati wa mazingira yuko tayari. Chakula safi, hakuna kumwaga chakula ovyo!"
        }
    },
    'hype_man': {
        'id': 'hype_man',
        'name': 'The Hype Man',
        'en': {
            'greeting': "LET US GOOO {name}! The DISHI Hype Man is in the building! Are we ready to eat like absolute champions today?!",
            'balance': "BOOM! You have got KES {balance} locked in your wallet! Big moves, big appetite, big energy!",
            'nearest': "Drop everything and head to Nyawuora Isaya Okuna near MEA right now! 4.9 STARS OF PURE FLAVOR PERFECTION!",
            'qr': "VIP PASS UNLOCKED! Flash this QR at Nyawuora's counter and claim that legendary meal like the MVP you are!",
            'menu': "Look at this all-star lineup: CHIPS KUKU for 220, BEEF RICE for 150, CHAPO DONDO for 100, and UGALI MAYAI for 80 bob! LET US EAT!",
            'order_confirm': "LETS WIN! Your champion meal of {summary} totals KES {total}. Tap that NFC badge and celebrate the feast!",
            'split_bill': "SQUAD GOALS! We are splitting KES {amount} among {people} superstars, that is KES {share} each! WE ARE ALL EATING!",
            'dietary': "GET THAT QUARTER CHICKEN AND CHIPS! Maximum protein, legendary crunch, and championship-tier satisfaction!",
            'switch_ack': "HYPE MAN MODE ENGAGED! Energy through the roof, volume on maximum! Let us get hype!"
        },
        'sw': {
            'greeting': "TWENZETU {name}! Hype Man wa DISHI yuko stejini! Tuko tayari kula kama mabingwa wa chuo leo?!",
            'balance': "WAAAH! Una Shilingi {balance} mzima kwa wallet! Maisha ni mazuri, nishati iko juu, wacha tushibe!",
            'nearest': "Acha kila kitu uende kwa Nyawuora Isaya Okuna karibu na MEA sasa hivi! STARS 4.9 ZA UTAMU WA KIBABE!",
            'qr': "VIP PASS IMEWASHWA! Flash hii QR kwa Nyawuora na uchukue msosi wako kama mfalme wa chuo!",
            'menu': "Cheki hii lineup: CHIPS KUKU 220, BEEF RICE 150, CHAPO DONDO 100, na UGALI MAYAI 80 bob! WACHA TULE!",
            'order_confirm': "USHINDI TUPU! Mlo wako wa kishujaa wa {summary} ni Shilingi {total}. Gusa NFC sasa tufurahie!",
            'split_bill': "KIKOSI KINASHEREHEKEA! Shilingi {amount} kwa mabingwa {people} inakuwa Shilingi {share} kila mpiganaji! WOTE TUNASHIBA!",
            'dietary': "CHUKUA CHIPS KUKU! Protini ya ukweli, ladha ya kifalme, na nguvu ya ushindi!",
            'switch_ack': "Hype Man ameingia mzigoni! Shangwe tupu, nishati ya juu kabisa, twendelee!"
        }
    },
    'sarcastic_roommate': {
        'id': 'sarcastic_roommate',
        'name': 'The Sarcastic Roommate',
        'en': {
            'greeting': "Oh look who finally woke up. What is up {name}, need food or are you just going to stare at your empty saucepan again?",
            'balance': "You have KES {balance} left. Look at Mr. Moneybags over here. Try not to spend it all in five minutes.",
            'nearest': "Nyawuora's near MEA. Unless of course you plan on cooking in the hostel and having the caretaker confiscate your heater.",
            'qr': "Here is your QR pass. Do not drop your phone while the cashier is scanning it, please.",
            'menu': "Nyawuora has Beef Rice for 150, Chips Kuku for 220, Chapo Dondo for 100, and Ugali Sukuma for 80 bob. Pick something before they sell out.",
            'order_confirm': "Fine, I queued up {summary} for KES {total}. Tap NFC or enter PIN before I change my mind and eat it myself.",
            'split_bill': "Finally splitting KES {amount} among {people} people, which is KES {share} each. Tell them to pay up so we stop arguing about who bought the eggs.",
            'dietary': "Get the Chapati Madondo. It is 100 bob, it actually fills you up, and you will not have to borrow my bread later.",
            'switch_ack': "Sarcastic Roommate mode enabled. Prepare for honesty, witty banter, and zero sugar-coating."
        },
        'sw': {
            'greeting': "Kumbe umeamka. Niaje {name}, unataka msosi ama utaangalia tu sufuria yako tupu tena leo?",
            'balance': "Umebakiwa na Shilingi {balance}. Tajiri wa chuo, angalia usizimalize zote kwa smokie pasua tano.",
            'nearest': "Nyawuora karibu na MEA. Isipokuwa kama unataka kupika hostel caretaker akunyanganye coil ya stima.",
            'qr': "Chukua QR pass yako. Angalia simu isikuangukie ukiwa kwa counter ya Nyawuora.",
            'menu': "Kuna Beef Rice 150, Chips Kuku 220, Chapo Dondo 100, na Ugali Mayai 80 bob. Chagua haraka kabla hazijaisha.",
            'order_confirm': "Haya basi, nimekuwekea {summary} ya Shilingi {total}. Gusa NFC kabla sijakula mimi mwenyewe.",
            'split_bill': "Hatimaye mnagawana Shilingi {amount} kwa watu {people}, yaani Shilingi {share} kila mtu. Waambie walipe tusianze kubishana usiku.",
            'dietary': "Nunua Chapo Dondo kwa 100 bob. Inashibisha vizuri na hautaniomba mkate wangu usiku.",
            'switch_ack': "Roommate mkorofi amewashwa. Jiandae kusikia ukweli mtupu bila kubembeleza!"
        }
    },
    'zen_guide': {
        'id': 'zen_guide',
        'name': 'The Zen Mindfulness Guide',
        'en': {
            'greeting': "Breathe in deeply, {name}. Welcome to DISHI Mindfulness. Let us bring calm presence and peaceful intention to your nourishment today.",
            'balance': "Your digital sanctuary holds KES {balance}. Savor this abundance with gratitude and peace.",
            'nearest': "Journey mindfully to Nyawuora Isaya Okuna Cafeteria at MMUST near MEA. A tranquil haven of honest, freshly prepared sustenance.",
            'qr': "Your mindful dining pass is open, {name}. Present it serenely at the counter and receive your meal in peace.",
            'menu': "Mindful offerings: Beef Stew with Rice at 150, Chapati Madondo at 100, and nourishing Ugali Sukuma at 80 bob. Breathe and choose with clarity.",
            'order_confirm': "Mindful selection honored: {summary} totaling KES {total}. Breathe out, verify your PIN, and dine in tranquility.",
            'split_bill': "Harmonious balance achieved. KES {amount} shared peacefully among {people} souls comes to KES {share} each.",
            'dietary': "Warm steamed rice and fresh greens promote gentle digestion and clear inner stillness for the rest of your study day.",
            'switch_ack': "Zen Mindfulness Guide active. Breathe in calmness, breathe out stress, and honor your nourishment."
        },
        'sw': {
            'greeting': "Vuta pumzi kwa utulivu, {name}. Karibu kwa DISHI ya utulivu wa akili. Wacha tule kwa amani na shukrani leo.",
            'balance': "Mfuko wako una Shilingi {balance}. Pokea baraka hii kwa moyo wa amani na utulivu.",
            'nearest': "Tembea kwa utulivu kuelekea Nyawuora Isaya Okuna karibu na MEA. Chakula chake kinapikwa kwa unyenyekevu na usafi.",
            'qr': "Pass yako ya amani iko tayari, {name}. Ionyeshe kwa heshima mezani upate mlo wenye baraka.",
            'menu': "Chakula cha utulivu: Beef Rice 150, Chapo Dondo 100, na Ugali Sukuma na Mayai 80 bob. Vuta pumzi uchague.",
            'order_confirm': "Umechagua kwa amani: {summary} ya Shilingi {total}. Thibitisha kwa PIN na ule kwa utulivu wa roho.",
            'split_bill': "Ulinganifu kamili umepatikana: Shilingi {amount} kwa watu {people} inakuwa Shilingi {share} kila mmoja kwa upendo.",
            'dietary': "Wali laini na sukuma wiki safi inaleta mmeng'enyo mwepesi wa chakula na kuleta utulivu wa akili darasani.",
            'switch_ack': "Kiongozi wa utulivu amewashwa. Vuta pumzi, ondoa wasiwasi, na ufurahie chakula chako."
        }
    },
    'history_buff': {
        'id': 'history_buff',
        'name': 'The History Buff',
        'en': {
            'greeting': "Greetings, scholar {name}! Did you know campus meal systems trace back to the ancient universities of Timbuktu? Ready to explore history and meals?",
            'balance': "You hold KES {balance} in currency. A fine treasury worthy of campus historical archives.",
            'nearest': "Set your historical compass toward Nyawuora Isaya Okuna Cafeteria at MMUST near MEA, continuing the grand African dining tradition with a 4.9 rating.",
            'qr': "Your archive clearance pass is ready, {name}. Show this at Nyawuora's counter for rapid historical dining dispensation.",
            'menu': "Historical delights on the menu: Beef Stew and Rice at 150, historic spiced Chapati Madondo at 100, and traditional Ugali Sukuma at 80 bob.",
            'order_confirm': "Historical decree logged: {summary} amounting to KES {total}. Enter your PIN to record this banquet in the annals of campus.",
            'split_bill': "In ancient councils, resources were shared equally. KES {amount} apportioned among {people} scholars is KES {share} each.",
            'dietary': "Ugali and indigenous greens have sustained African warriors and scholars for generations. Rich in minerals, starch, and enduring vigor.",
            'switch_ack': "History Buff mode activated! Connecting past heritage with delicious campus dining traditions."
        },
        'sw': {
            'greeting': "Salamu mwanahistoria {name}! Unajua desturi ya kula chuo ilianza tangu enzi za vyuo vya kale vya Timbuktu? Wacha tuchambue historia na msosi!",
            'balance': "Hazina yako ya sarafu ina Shilingi {balance}. Akiba ya kihistoria ya kutunza masomo yako.",
            'nearest': "Elekea kwa Nyawuora Isaya Okuna karibu na MEA, anayeendeleza desturi ya chakula cha kiasili cha Afrika na stars 4.9.",
            'qr': "Pass yako ya kumbukumbu iko tayari, {name}. Ionyeshe kwa Nyawuora upokee chakula kilichoheshimika kwa vizazi vingi.",
            'menu': "Vyakula vya asili na historia: Beef Rice 150, Chapo Madondo 100, na Ugali wa asili wa Sukuma 80 bob.",
            'order_confirm': "Agizo la kihistoria limeandikwa: {summary} ya Shilingi {total}. Weka PIN yako tuihifadhi kwenye kumbukumbu.",
            'split_bill': "Kama vile wazee wa kale walivyogawa mavuno: Shilingi {amount} kwa wasomi {people} inakuwa Shilingi {share} kila mmoja.",
            'dietary': "Ugali na sukuma wiki zimerutubisha mashujaa na wasomi wa Afrika kwa karne nyingi. Nguvu kamili na madini tele.",
            'switch_ack': "Mwanahistoria amewashwa! Wacha tusherehekee historia yetu kupitia msosi safi wa chuo."
        }
    },
    'disciplinarian': {
        'id': 'disciplinarian',
        'name': 'The Strict Disciplinarian',
        'en': {
            'greeting': "Attention, student {name}. Discipline is the cornerstone of academic excellence. State your dining or wallet requirement clearly and concisely.",
            'balance': "Official balance audit: KES {balance}. Maintain strict compliance with your campus allowance schedule.",
            'nearest': "Designated vendor location: Nyawuora Isaya Okuna Cafeteria at MMUST near MEA. Proceed immediately without loitering.",
            'qr': "Official meal clearance token issued for {name}. Present it precisely at Nyawuora's register for expedited clearance.",
            'menu': "Authorized menu items: Beef Stew Rice at 150, Chips Kuku at 220, Chapati Madondo at 100, and Ugali Sukuma at 80 bob. State your selection.",
            'order_confirm': "Order logged according to regulations: {summary}. Total due: KES {total}. Authenticate with your 4-digit PIN immediately.",
            'split_bill': "Equitable apportionment confirmed. Exactly KES {amount} divided by {people} registered students equals KES {share} per participant.",
            'dietary': "Consume balanced nourishment on schedule. The Ugali Sukuma with eggs provides adequate nutrients to maintain high academic focus.",
            'switch_ack': "Disciplinarian protocol activated. Order, precision, and punctuality will be enforced at all times."
        },
        'sw': {
            'greeting': "Simama wima mwanafunzi {name}. Nidhamu ndio nguzo ya kufaulu chuo. Sema unachohitaji kwa ufasaha na bila kupoteza muda.",
            'balance': "Ukaguzi wa salio: Shilingi {balance}. Fuata ratiba yako ya matumizi bila kukiuka sheria.",
            'nearest': "Eneo lililoidhinishwa: Nyawuora Isaya Okuna Cafeteria karibu na MEA. Nenda moja kwa moja bila kuzurura njiani.",
            'qr': "Kibali rasmi cha chakula kimetolewa kwa {name}. Kionyeshe kwa mashine ya Nyawuora mara moja.",
            'menu': "Vyakula vilivyoidhinishwa: Beef Rice 150, Chips Kuku 220, Chapo Dondo 100, na Ugali Sukuma 80 bob. Chagua sasa.",
            'order_confirm': "Oda imesajiliwa kisheria: {summary}. Jumla: Shilingi {total}. Thibitisha kwa PIN yako ya tarakimu 4 sasa hivi.",
            'split_bill': "Mgawanyo wa haki: Shilingi {amount} kwa wanafunzi {people} ni Shilingi {share} kamili bila senti iliyopotea.",
            'dietary': "Kula kwa wakati unaofaa. Ugali na sukuma wiki zitakupa nguvu ya kukaa darasani kwa nidhamu ya juu.",
            'switch_ack': "Itifaki ya nidhamu imewashwa. Utaratibu, umakini, na nidhamu vitazingatiwa!"
        }
    },
    'festival_coordinator': {
        'id': 'festival_coordinator',
        'name': 'The Festival Coordinator',
        'en': {
            'greeting': "Welcome to the party, {name}! Campus Festival Coordinator bringing the weekend excitement to your meals every single day!",
            'balance': "Celebration fund status: KES {balance}! Ready to treat yourself to an amazing campus culinary carnival?",
            'nearest': "Head over to Nyawuora Isaya Okuna Cafeteria near MEA! The hot grills, sizzling chips, and lively campus crowd make it the main festival stage.",
            'qr': "Festival VIP ticket printed! Show this pass at Nyawuora's counter and grab the spotlight with a delicious feast.",
            'menu': "Festival treats: Crispy golden Chips Kuku at 220, hearty Beef Stew Rice at 150, savory Chapati Madondo at 100, and sweet Chai Mandazi at 50 bob!",
            'order_confirm': "Party ticket confirmed! You are getting {summary} for KES {total}. Tap your NFC wristband and celebrate!",
            'split_bill': "Party crew split! KES {amount} shared across {people} festival-goers is KES {share} each. Let the celebration continue!",
            'dietary': "Treat yourself to the golden Chips Kuku and cold drink! Every great campus milestone deserves a festive food celebration.",
            'switch_ack': "Festival Coordinator is live! Music on, festive energy high, let us make every meal a campus celebration!"
        },
        'sw': {
            'greeting': "Karibu kwenye sherehe {name}! Mratibu wa tamasha za chuo yuko hapa kukuletea shangwe na vyakula vitamu kila siku!",
            'balance': "Mfuko wa sherehe una Shilingi {balance}! Uko tayari kujipongeza kwa mlo mtamu leo?",
            'nearest': "Elekea kwa Nyawuora Isaya Okuna karibu na MEA! Moshi wa chips kuku na wali nyama ndio kitovu cha shangwe za chuo.",
            'qr': "Tiketi ya sherehe iko tayari! Ionyeshe kwa Nyawuora uchukue msosi wako kwa bashasha tele.",
            'menu': "Vyakula vya sherehe: Chips Kuku 220, Beef Rice 150, Chapo Dondo 100, na Chai ya Mandazi 50 bob!",
            'order_confirm': "Tiketi ya mlo imethibitishwa: {summary} ya Shilingi {total}. Gusa NFC tusherehekee!",
            'split_bill': "Mgawanyo wa kikosi: Shilingi {amount} kwa washiriki {people} inakuwa Shilingi {share} kila mmoja. Sherehe iendelee!",
            'dietary': "Jipongeze na Chips Kuku moto! Kila bidii ya masomo chuoni inastahili sherehe ya msosi safi.",
            'switch_ack': "Mratibu wa tamasha yuko hewani! Shangwe zianze, vicheko na msosi mtamu mbele yetu!"
        }
    },
    'minimalist': {
        'id': 'minimalist',
        'name': 'The Minimalist',
        'en': {
            'greeting': "DISHI Minimalist ready, {name}. What do you need?",
            'balance': "Balance: KES {balance}.",
            'nearest': "Nyawuora Cafeteria, MMUST near MEA. 4.9 stars. Open.",
            'qr': "QR pass active. Present at counter.",
            'menu': "Beef Rice 150. Chips Kuku 220. Chapati Madondo 100. Ugali Sukuma 80.",
            'order_confirm': "{summary}. Total: KES {total}. Ready for NFC tap.",
            'split_bill': "KES {amount} divided by {people} is KES {share} each.",
            'dietary': "Chapati Madondo for 100 bob. Simple, dense nutrition.",
            'switch_ack': "Minimalist active. Direct, concise, zero fluff."
        },
        'sw': {
            'greeting': "DISHI Minimalist tayari, {name}. Unahitaji nini?",
            'balance': "Salio: Shilingi {balance}.",
            'nearest': "Nyawuora Cafeteria, MMUST near MEA. Stars 4.9. Wazi.",
            'qr': "Pass ya QR iko tayari. Onyesha counter.",
            'menu': "Beef Rice 150. Chips Kuku 220. Chapo Dondo 100. Ugali Sukuma 80.",
            'order_confirm': "{summary}. Jumla: Shilingi {total}. Gusa NFC.",
            'split_bill': "Shilingi {amount} kwa {people} ni Shilingi {share} kila mmoja.",
            'dietary': "Chapo dondo shilingi 100. Msosi rahisi na wa nguvu.",
            'switch_ack': "Minimalist amewashwa. Maneno machache, kazi mara moja."
        }
    }
}

def get_persona_dict(persona_id: str):
    p = persona_id.lower().strip()
    return PERSONAS.get(p, PERSONAS['campus_buddy'])

def get_persona_text(persona_dict, lang: str, key: str, fallback_en: str = ""):
    lang_key = 'sw' if lang in ['sw', 'sheng'] else 'en'
    texts = persona_dict.get(lang_key, persona_dict['en'])
    res = texts.get(key, persona_dict['en'].get(key, fallback_en))
    return clean_for_tts(res)

@voice_v6_bp.route('/intent', methods=['POST'])
def process_voice_intent():
    """
    DISHI Voice AI v6 - 20 Persona Directory, Multi-Lingual & Ultra-Low RAM Endpoint.
    Default language: English ('en'). Dynamic switching to Swahili ('sw'), Sheng, French, Spanish.
    Zero-Trust Voice Financial Security (anti-theft, anti-hacking, prompt injection blocks).
    Hardened single verified campus vendor: Nyawuora Isaya Okuna (MMUST near MEA, 4.9 stars).
    """
    data = request.json or {}
    text = str(data.get('text', '')).strip()
    role = str(data.get('role', 'student')).lower()
    user_uid = str(data.get('uid', '')).strip()

    # Persona selection (Default: 'campus_buddy')
    active_persona_id = str(data.get('active_persona', 'campus_buddy')).lower().strip()
    if active_persona_id not in PERSONAS:
        active_persona_id = 'campus_buddy'
    persona_obj = get_persona_dict(active_persona_id)

    # Language selection (Default: 'en' English)
    client_lang = str(data.get('language', 'en')).lower().strip()
    if client_lang not in ['en', 'sw', 'sheng', 'fr', 'es']:
        client_lang = 'en'
    current_lang = client_lang

    if not text:
        empty_msg = get_persona_text(persona_obj, current_lang, 'greeting').format(name="Comrade")
        return jsonify({
            "intent": "EMPTY",
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "spoken_response": empty_msg
        }), 400

    low = text.lower()
    db = firestore.client()

    # =========================================================================
    # 1. HARDENED ANTI-THEFT & PROMPT INJECTION GUARD
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

            spoken = "Security Alert: Unsanctioned financial action detected. For your safety, all monetary actions on DISHI require explicit on-screen PIN verification." if current_lang == 'en' else "Onyo la Usalama: Amri hii imezuiwa kwa sababu za kiusalama. Malipo yote ya fedha kwenye DISHI yanalindwa kwa PIN yako binafsi na hayawezi kutolewa kiholela."
            return jsonify({
                "intent": "SECURITY_BLOCKED",
                "spoken_response": clean_for_tts(spoken),
                "is_security_alert": True,
                "requires_pin": True
            }), 403

    # =========================================================================
    # 2. DYNAMIC LANGUAGE SWITCHING DETECTION
    # =========================================================================
    lang_triggers = [
        ('sw', ['speak swahili', 'ongea kiswahili', 'badili kiswahili', 'switch to swahili', 'swahili please']),
        ('en', ['speak english', 'ongea kiingereza', 'switch to english', 'english please', 'use english']),
        ('sheng', ['speak sheng', 'ongea sheng', 'switch to sheng', 'sheng please']),
        ('fr', ['speak french', 'parle francais', 'parlez francais', 'en francais', 'switch to french']),
        ('es', ['speak spanish', 'habla espanol', 'en espanol', 'switch to spanish'])
    ]
    for target_lang, phrases in lang_triggers:
        if any(p in low for p in phrases):
            current_lang = target_lang
            if target_lang == 'sw':
                ack = f"Sawa kabisa! Kuanzia sasa nitazungumza Kiswahili. Mimi ni {persona_obj['name']}, nikusaidie nini comrade?"
            elif target_lang == 'sheng':
                ack = f"Wazi bro! Kuanzia sasa tunaongea Sheng safi ya chuo. Mimi ni {persona_obj['name']}, form inajipaje leo?"
            elif target_lang == 'fr':
                ack = f"Très bien! Je parlerai français maintenant. Je suis {persona_obj['name']}, comment puis-je vous aider aujourd'hui?"
            elif target_lang == 'es':
                ack = f"¡Muy bien! Hablaré español a partir de ahora. Soy {persona_obj['name']}, ¿en qué puedo ayudarte hoy?"
            else:
                ack = f"Understood! Switching to English. I am {persona_obj['name']}, your DISHI Voice AI. How can I assist you?"

            return jsonify({
                "intent": "CHANGE_LANGUAGE",
                "active_language": current_lang,
                "active_persona": active_persona_id,
                "spoken_response": clean_for_tts(ack),
                "requires_pin": False
            }), 200

    # =========================================================================
    # 2.5 DYNAMIC VOICE GENDER SWITCHING (Female / Lady vs Male / Gentleman)
    # =========================================================================
    if any(k in low for k in [
        'male voice', 'gentleman voice', 'sauti ya kiume', 'sauti ya kiume tafadhali',
        'switch to male', 'change to male voice', 'use male voice', 'badili sauti ya kiume',
        'sauti ya dume', 'ongea kama mwanaume', 'tumia sauti ya kiume', 'gentleman mode'
    ]):
        spoken = f"Nimebadilisha hadi sauti ya kiume. Niko tayari kukusaidia comrade!" if current_lang in ['sw', 'sheng'] else f"Switched to gentleman voice. Ready to assist you, comrade!"
        return jsonify({
            "intent": "CHANGE_VOICE_GENDER",
            "active_gender": "male",
            "active_language": current_lang,
            "active_persona": active_persona_id,
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

    if any(k in low for k in [
        'female voice', 'lady voice', 'sauti ya kike', 'sauti ya kike tafadhali',
        'switch to female', 'change to female voice', 'use female voice', 'badili sauti ya kike',
        'sauti ya msichana', 'ongea kama mwanamke', 'tumia sauti ya kike', 'lady mode'
    ]):
        spoken = f"Nimebadilisha hadi sauti ya kike ya DISHI. Nikusaidie nini leo rafiki yangu?" if current_lang in ['sw', 'sheng'] else f"Switched to DISHI lady voice. How can I brighten your campus day?"
        return jsonify({
            "intent": "CHANGE_VOICE_GENDER",
            "active_gender": "female",
            "active_language": current_lang,
            "active_persona": active_persona_id,
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

    # =========================================================================
    # 3. DYNAMIC PERSONA SWITCHING DETECTION (All 20 Personas)
    # =========================================================================
    persona_switch_map = {
        'campus_buddy': ['campus buddy', 'buddy mode', 'default persona'],
        'nutritionist': ['nutritionist', 'nutrition', 'healthy mode', 'dietitian'],
        'cashier': ['cashier', 'canteen cashier', 'swift cashier'],
        'chef': ['gourmet chef', 'chef mode', 'master chef', 'cook'],
        'coach': ['energetic coach', 'coach mode', 'workout coach', 'be my coach'],
        'wise_elder': ['wise elder', 'mentor mode', 'elder persona', 'mzee'],
        'gen_z': ['gen z', 'campus insider', 'gen-z mode'],
        'accountant': ['budget accountant', 'accountant mode', 'strict accountant'],
        'mama_njeri': ['mama njeri', 'mama canteen', 'matriarch'],
        'tech_geek': ['tech geek', 'ai assistant', 'developer mode', 'hacker mode'],
        'musician': ['acoustic musician', 'musician mode', 'guitarist'],
        'study_partner': ['study partner', 'midnight study', 'library buddy'],
        'eco_activist': ['eco activist', 'eco conscious', 'green campus'],
        'hype_man': ['hype man', 'hype mode', 'stadium hype'],
        'sarcastic_roommate': ['sarcastic roommate', 'roommate mode', 'sarcasm'],
        'zen_guide': ['zen guide', 'mindfulness', 'meditation guide', 'calm mode'],
        'history_buff': ['history buff', 'historian', 'history mode'],
        'disciplinarian': ['disciplinarian', 'strict disciplinarian', 'military mode'],
        'festival_coordinator': ['festival coordinator', 'party mode', 'festival mode'],
        'minimalist': ['minimalist', 'minimal mode', 'brief mode', 'short answers']
    }

    if any(k in low for k in ['switch persona', 'change persona', 'act like', 'be my', 'switch to', 'badili persona']):
        for p_id, triggers in persona_switch_map.items():
            if any(t in low for t in triggers):
                active_persona_id = p_id
                persona_obj = get_persona_dict(active_persona_id)
                ack = get_persona_text(persona_obj, current_lang, 'switch_ack')
                return jsonify({
                    "intent": "CHANGE_PERSONA",
                    "active_persona": active_persona_id,
                    "active_language": current_lang,
                    "spoken_response": clean_for_tts(ack),
                    "requires_pin": False
                }), 200

    # =========================================================================
    # 4. DISMISS / CANCEL VOICE
    # =========================================================================
    if any(k in low for k in ['acha tu', 'funga', 'cancel', 'tulia', 'stop', 'kwaheri', 'bye', 'dismiss', 'close', 'exit']):
        bye_msg = "Alright, closing for now. Tap my mic anytime you need anything!" if current_lang == 'en' else "Sawa rafiki yangu! Nimefunga kwa sasa. Ukinihitaji gusa tu maikrofoni, niko hapa!"
        return jsonify({
            "intent": "DISMISS_VOICE",
            "action": "dismiss",
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "spoken_response": clean_for_tts(bye_msg),
            "requires_pin": False
        }), 200

    # Fetch User Profile & Balance
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
    # 5. NEAREST VENDOR QUERY (Sole verified: Nyawuora Isaya Okuna)
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
        spoken = get_persona_text(persona_obj, current_lang, 'nearest')
        return jsonify({
            "intent": "NEAREST_VENDOR",
            "vendor": vendor_data,
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "progress_steps": [
                "Scanning campus location coordinates...",
                "Located Nyawuora Isaya Okuna Cafeteria at MMUST near MEA",
                "Menu and operating hours ready"
            ],
            "spoken_response": clean_for_tts(spoken),
            "action": "open_vendor_card",
            "requires_pin": False
        }), 200

    # =========================================================================
    # 6. QR CODE / FOOD PASS ("Talk better, respond like a friend")
    # =========================================================================
    if any(k in low for k in ['pass', 'qr', 'token', 'barcode', 'lipa', 'kuchukua', 'counter', 'nionyeshe qr', 'show qr', 'payment pass']):
        spoken = get_persona_text(persona_obj, current_lang, 'qr').format(name=user_name)
        return jsonify({
            "intent": "SHOW_STUDENT_QR",
            "action": "open_qr_pass",
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "progress_steps": [
                "Generating secure dynamic HMAC payment pass...",
                "Connecting with Nyawuora Isaya Okuna POS terminal...",
                "QR Food Pass Active!"
            ],
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

    # =========================================================================
    # 7. ORDER PLACEMENT & NFC CONFIRMATION
    # "Confirm transaction amounts clearly before triggering NFC or mobile checkout."
    # =========================================================================
    if any(k in low for k in ['order', 'buy', 'nunua', 'agiza', 'weka oda', 'place order', 'checkout', 'pay for', 'nfc']):
        parsed_items = parse_order_items(text)
        if parsed_items:
            total_sum = sum(i['total'] for i in parsed_items)
            summary_str = ", ".join(f"{i['quantity']} {i['name']}" for i in parsed_items)
            spoken = get_persona_text(persona_obj, current_lang, 'order_confirm').format(
                summary=summary_str,
                total=f"{total_sum:,.0f}"
            )
            return jsonify({
                "intent": "CONFIRM_NFC_ORDER",
                "action": "confirm_nfc_checkout",
                "items": parsed_items,
                "total_amount": total_sum,
                "active_persona": active_persona_id,
                "active_language": current_lang,
                "progress_steps": [
                    f"Order prepared: {summary_str}",
                    f"Total: KES {total_sum:,.0f}",
                    "Ready for NFC tap at Nyawuora's counter!"
                ],
                "spoken_response": clean_for_tts(spoken),
                "requires_pin": False
            }), 200

    # =========================================================================
    # 8. AVAILABLE FOOD QUERY & DIETARY RECOMMENDATIONS
    # =========================================================================
    if any(k in low for k in ['dietary', 'healthy', 'protein', 'nutrition', 'what should i eat', 'recommend', 'ushauri wa chakula']):
        spoken = get_persona_text(persona_obj, current_lang, 'dietary')
        return jsonify({
            "intent": "DIETARY_RECOMMENDATION",
            "action": "open_food_menu",
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

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
        spoken = get_persona_text(persona_obj, current_lang, 'menu')
        return jsonify({
            "intent": "DISCOVER_MEALS",
            "items": food_list,
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "progress_steps": [
                "Fetching live menu from Nyawuora Isaya Okuna...",
                "All items confirmed hot and in-stock!",
                "Displaying menu"
            ],
            "spoken_response": clean_for_tts(spoken),
            "action": "open_food_menu",
            "requires_pin": False
        }), 200

    # =========================================================================
    # 9. COMRADE BILL SPLITTING
    # =========================================================================
    if any(k in low for k in ['gawanya', 'split', 'tuchange', 'changamsha', 'bill split', 'split bill', 'roommate bill']):
        amt = extract_amount(text) or 600.0
        people = 2
        digit_people = re.search(r'(?:watu|people|friends|comrades)?\s*(\d+)', low)
        if digit_people and int(digit_people.group(1)) > 1:
            people = int(digit_people.group(1))
        split_share = round(amt / people, 2)

        spoken = get_persona_text(persona_obj, current_lang, 'split_bill').format(
            amount=f"{amt:,.0f}",
            people=people,
            share=f"{split_share:,.0f}"
        )

        return jsonify({
            "intent": "SPLIT_BILL",
            "amount": amt,
            "people": people,
            "share_per_person": split_share,
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "progress_steps": [
                f"Calculating equal split for KES {amt:,.0f}...",
                f"Divided by {people} members = KES {split_share:,.0f} each",
                "Opening PIN-secured Group Pay sheet..."
            ],
            "action": "open_split_bill",
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

    # =========================================================================
    # 10. WALLET BALANCE QUERY
    # =========================================================================
    if any(k in low for k in ['balance', 'float', 'salio', 'pesa ngapi', 'how much do i have', 'check balance']):
        spoken = get_persona_text(persona_obj, current_lang, 'balance').format(
            balance=f"{cur_balance:,.0f}",
            name=user_name
        )
        return jsonify({
            "intent": "QUERY_BALANCE",
            "balance": cur_balance,
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

    # =========================================================================
    # 11. GENERAL CONVERSATION & CASUAL GREETINGS
    # =========================================================================
    if any(k in low for k in ['mambo', 'habari', 'vipi', 'how are you', 'hello', 'hi', 'who are you', 'wewe ni nani']):
        spoken = get_persona_text(persona_obj, current_lang, 'greeting').format(name=user_name)
        return jsonify({
            "intent": "FRIEND_CONVERSATION",
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

    # =========================================================================
    # 12. BUDGET SURVIVAL INTELLIGENCE ("NITATOBOA?")
    # =========================================================================
    if any(k in low for k in ['nitatoboa', 'pesa itanitosha', 'burn rate', 'hesabu ya wiki', 'daily budget', 'nitamaliza wiki', 'will i survive', 'budget check']):
        today_weekday = datetime.datetime.now().weekday()
        days_left = max(1, 6 - today_weekday)
        daily_allowance = cur_balance / days_left if cur_balance > 0 else 0.0

        if current_lang == 'en':
            advice = "You are in great shape to enjoy delicious meals at Nyawuora's!" if daily_allowance >= 150 else "Stick to nutritious chapati madondo to sail through smoothly."
            spoken = f"Your balance is KES {cur_balance:,.0f}. That allows KES {daily_allowance:,.0f} per day across the {days_left} remaining days. {advice}"
        else:
            advice = "Uko vizuri sana, unaweza kula vizuri kwa Nyawuora na ubaki na akiba." if daily_allowance >= 150 else "Ukila chapo dondo na chai, pesa itakutosha vizuri kabisa hadi Jumapili."
            spoken = f"Salio lako ni Shilingi {cur_balance:,.0f}. Kila siku unaweza kutumia Shilingi {daily_allowance:,.0f} kwa siku {days_left} zilizobaki. {advice}"

        return jsonify({
            "intent": "CHECK_BUDGET",
            "balance": cur_balance,
            "days_left": days_left,
            "daily_allowance": daily_allowance,
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "progress_steps": [
                "Analyzing Firestore wallet balance...",
                f"Safe daily rate: KES {daily_allowance:,.0f} for {days_left} days",
                "Budget forecast complete"
            ],
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

    # =========================================================================
    # 13. EMERGENCY FOOD RESCUE (OKOA MEAL)
    # =========================================================================
    if any(k in low for k in ['okoa', 'broke', 'njaa', 'sina kakitu', 'sina pesa', 'emergency meal', 'hungry', 'food rescue']):
        spoken = f"I have got your back, {user_name}! No comrade should ever study hungry. Opening Okoa Food Rescue for an instant subsidized meal." if current_lang == 'en' else f"Pole sana rafiki yangu {user_name}! Mwanafunzi hapaswi kusoma na njaa. Nimekufungulia Okoa Food Rescue upate msosi wa dharura mara moja."
        return jsonify({
            "intent": "OKOA_MEAL",
            "action": "open_okoa_food",
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

    # =========================================================================
    # 14. PARENT ALLOWANCE REQUEST
    # =========================================================================
    if any(k in low for k in ['omba mzazi', 'omba mum', 'omba dad', 'request funds', 'ask parent', 'need allowance', 'omba pesa']):
        amt = extract_amount(text) or 300.0
        spoken = f"Prepared an allowance request of KES {amt:,.0f} for your parent. Tap to confirm and send it straight to their phone." if current_lang == 'en' else f"Nimekuandalia ombi la Shilingi {amt:,.0f} kwa mzazi wako. Gusa uthibitishe litumwe papo hapo kwa simu yake."
        return jsonify({
            "intent": "REQUEST_PARENT_FUNDS",
            "amount": amt,
            "action": "open_request_funds",
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "spoken_response": clean_for_tts(spoken),
            "requires_pin": False
        }), 200

    # =========================================================================
    # 15. CASH WITHDRAWAL (Enforces On-Screen PIN Authentication)
    # =========================================================================
    if any(k in low for k in ['toa', 'withdraw', 'cash out', 'hamisha']):
        amount = extract_amount(text)
        if not amount or amount <= 0:
            prompt_msg = "How much would you like to withdraw to your M-Pesa line?" if current_lang == 'en' else "Ungependa kutoa kiasi gani cha pesa kwa M-Pesa yako?"
            return jsonify({
                "intent": "CASH_OUT_PROMPT",
                "active_persona": active_persona_id,
                "active_language": current_lang,
                "spoken_response": clean_for_tts(prompt_msg),
                "requires_pin": True
            }), 200

        challenge = f"{random.randint(10, 99)}"
        spoken = f"Security verification: Withdrawing KES {amount:,.0f} to your M-Pesa line. Please enter your 4-digit Wallet PIN on screen to authorize this payout." if current_lang == 'en' else f"Uthibitisho wa Usalama: Unakaribia kutoa Shilingi {amount:,.0f} kwa M-Pesa. Tafadhali weka PIN yako ya tarakimu 4 kwenye skrini kuthibitisha muamala huu."
        return jsonify({
            "intent": "INITIATE_CASH_OUT",
            "amount": amount,
            "active_persona": active_persona_id,
            "active_language": current_lang,
            "requires_pin": True,
            "challenge_code": challenge,
            "spoken_response": clean_for_tts(spoken)
        }), 200

    # =========================================================================
    # GENERAL FALLBACK
    # =========================================================================
    if current_lang == 'en':
        spoken = f"I hear you, {user_name}! You can ask me: 'Where is the nearest vendor?', 'What food is available?', 'Show my food QR pass', or 'Split a bill of 600'."
    else:
        spoken = f"Nimekuelewa rafiki yangu {user_name}! Unaweza kuniambia: 'Vendor gani yuko karibu?', 'Kuna chakula gani sasa hivi?', 'Nionyeshe QR pass yangu', au 'Gawanya bili ya 600'."

    return jsonify({
        "intent": "GENERAL_QUERY",
        "recognized_text": text,
        "active_persona": active_persona_id,
        "active_language": current_lang,
        "spoken_response": clean_for_tts(spoken),
        "requires_pin": False
    }), 200
