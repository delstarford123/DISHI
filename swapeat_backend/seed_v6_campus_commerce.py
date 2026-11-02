import os
import firebase_admin
from firebase_admin import credentials, firestore

def seed():
    cred_path = 'swapeat_backend/ServiceAccountKey.json' if os.path.exists('swapeat_backend/ServiceAccountKey.json') else 'ServiceAccountKey.json'
    if not os.path.exists(cred_path):
        cred_path = '../ServiceAccountKey.json'
    
    if not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

    db = firestore.client()
    print("Firebase connected. Seeding campus commerce, vendors, food, and electronics...")

    # 1. SEED CAMPUS VENDORS
    vendors = [
        {
            "id": "vendor_cafeteria_main",
            "businessName": "Hall 4 Main Cafeteria",
            "vendorType": "food",
            "category": "food",
            "location": "Student Centre, Ground Floor",
            "venueLocation": "Student Centre Building",
            "campus": "Main Campus",
            "rating": 4.8,
            "totalReviews": 142,
            "isOpen": True,
            "preorderEnabled": True,
            "deliveryEnabled": True,
            "phone": "+254712345678",
            "dishiId": "VND4401",
            "specialties": ["Chapati", "Madondo", "Beef Stew", "Pilau", "Ugali Sukuma", "Chai"],
            "openingHours": "06:30 AM - 09:30 PM",
            "acceptsInstallments": False
        },
        {
            "id": "vendor_tech_hub",
            "businessName": "Campus Tech & Gadgets Hub",
            "vendorType": "electronics",
            "category": "electronics",
            "location": "Engineering Complex, Room 102",
            "venueLocation": "Engineering Block B",
            "campus": "Main Campus",
            "rating": 4.9,
            "totalReviews": 98,
            "isOpen": True,
            "preorderEnabled": True,
            "deliveryEnabled": True,
            "phone": "+254722998877",
            "dishiId": "VND7702",
            "specialties": ["Scientific Calculators", "Laptops", "Flash Drives", "Lab Coats", "Chargers", "Drawing Kits"],
            "openingHours": "08:00 AM - 07:00 PM",
            "acceptsInstallments": True
        },
        {
            "id": "vendor_dishi_supermarket",
            "businessName": "DISHI Express Mini-Supermarket",
            "vendorType": "supermarket",
            "category": "supermarket",
            "location": "Hall 2 Shopping Arcade",
            "venueLocation": "Hostel Zone 2",
            "campus": "Main Campus",
            "rating": 4.8,
            "totalReviews": 210,
            "isOpen": True,
            "preorderEnabled": True,
            "deliveryEnabled": True,
            "phone": "+254733445566",
            "dishiId": "VND2203",
            "specialties": ["Groceries", "Bread", "Milk", "Indomie", "Snacks", "Toiletries"],
            "openingHours": "07:00 AM - 10:30 PM",
            "acceptsInstallments": False
        },
        {
            "id": "vendor_mama_oliech",
            "businessName": "Mama Oliech Campus Kitchen",
            "vendorType": "food",
            "category": "food",
            "location": "Gate B Student Annex",
            "venueLocation": "Gate B Perimeter",
            "campus": "Main Campus",
            "rating": 4.9,
            "totalReviews": 87,
            "isOpen": True,
            "preorderEnabled": True,
            "deliveryEnabled": True,
            "phone": "+254700112233",
            "dishiId": "VND9904",
            "specialties": ["Wet Fry Tilapia", "Ugali", "Kienyeji Greens", "Managu", "Fish Stew"],
            "openingHours": "11:00 AM - 09:00 PM",
            "acceptsInstallments": False
        }
    ]

    for v in vendors:
        db.collection('vendors').document(v['id']).set(v, merge=True)
        # Also ensure user representation for vendor so discovery routes find them
        db.collection('users').document(v['id']).set({
            "uid": v['id'],
            "role": "vendor",
            "roles": ["vendor"],
            "displayName": v['businessName'],
            "businessName": v['businessName'],
            "vendorType": v['vendorType'],
            "venueLocation": v['venueLocation'],
            "location": v['location'],
            "campus": v['campus'],
            "rating": v['rating'],
            "isOpen": v['isOpen'],
            "dishiId": v['dishiId'],
            "phone": v['phone'],
            "walletBalance": 15400.0,
        }, merge=True)

    # 2. SEED CAMPUS FOOD ITEMS (vendor_menus & products)
    food_items = [
        {"id": "food_chapati", "name": "Chapati Fupi Soft", "price": 25.0, "vendorId": "vendor_cafeteria_main", "vendorName": "Hall 4 Main Cafeteria", "category": "food", "inStock": True, "description": "Freshly rolled layered campus chapati", "prepTime": "3 mins"},
        {"id": "food_madondo", "name": "Madondo (Yellow Beans)", "price": 50.0, "vendorId": "vendor_cafeteria_main", "vendorName": "Hall 4 Main Cafeteria", "category": "food", "inStock": True, "description": "Slow-cooked savory yellow beans gravy", "prepTime": "2 mins"},
        {"id": "food_beef_stew", "name": "Beef Stew with Rice/Ugali", "price": 120.0, "vendorId": "vendor_cafeteria_main", "vendorName": "Hall 4 Main Cafeteria", "category": "food", "inStock": True, "description": "Tender beef cubes in rich tomato coriander stew", "prepTime": "5 mins"},
        {"id": "food_pilau", "name": "Swahili Beef Pilau Special", "price": 150.0, "vendorId": "vendor_cafeteria_main", "vendorName": "Hall 4 Main Cafeteria", "category": "food", "inStock": True, "description": "Fragrant basmati rice cooked with whole spices and beef", "prepTime": "5 mins"},
        {"id": "food_ugali_sukuma", "name": "Ugali Sukuma Wiki & Eggs", "price": 60.0, "vendorId": "vendor_cafeteria_main", "vendorName": "Hall 4 Main Cafeteria", "category": "food", "inStock": True, "description": "Fresh ugali served with fried greens and egg", "prepTime": "4 mins"},
        {"id": "food_tilapia", "name": "Deep Fried Tilapia & Ugali", "price": 250.0, "vendorId": "vendor_mama_oliech", "vendorName": "Mama Oliech Campus Kitchen", "category": "food", "inStock": True, "description": "Whole crispy lake Victoria tilapia served with ugali and kachumbari", "prepTime": "12 mins"},
        {"id": "food_chai", "name": "Chai ya Tangawizi (Spiced Tea)", "price": 20.0, "vendorId": "vendor_cafeteria_main", "vendorName": "Hall 4 Main Cafeteria", "category": "food", "inStock": True, "description": "Hot brewed ginger milk tea", "prepTime": "1 min"}
    ]

    for item in food_items:
        db.collection('products').document(item['id']).set(item, merge=True)
        db.collection('vendor_menus').document(item['id']).set(item, merge=True)

    # 3. SEED CAMPUS ELECTRONICS & SUPERMARKET SKUS
    electronics_skus = [
        {
            "barcode": "6901234567891",
            "name": "Casio FX-991EX ClassWiz Scientific Calculator",
            "price": 2400.0,
            "category": "electronics",
            "vendorId": "vendor_tech_hub",
            "vendorName": "Campus Tech & Gadgets Hub",
            "inStock": True,
            "stockQuantity": 35,
            "installmentAvailable": True,
            "monthlyRate": 480.0,
            "description": "552 functions high-resolution display, essential for Engineering, Math & Science comrades",
            "specs": {"brand": "Casio", "model": "FX-991EX", "warranty": "1 Year"}
        },
        {
            "barcode": "6901234567892",
            "name": "Kingston DataTraveler 64GB USB 3.2 Flash Drive",
            "price": 950.0,
            "category": "electronics",
            "vendorId": "vendor_tech_hub",
            "vendorName": "Campus Tech & Gadgets Hub",
            "inStock": True,
            "stockQuantity": 80,
            "installmentAvailable": False,
            "description": "High-speed USB 3.2 Gen 1 metal casing flash drive for assignments and projects",
            "specs": {"capacity": "64GB", "interface": "USB 3.2", "warranty": "2 Years"}
        },
        {
            "barcode": "6901234567893",
            "name": "Heavy Duty 100% Cotton White Lab Coat",
            "price": 1200.0,
            "category": "electronics",
            "vendorId": "vendor_tech_hub",
            "vendorName": "Campus Tech & Gadgets Hub",
            "inStock": True,
            "stockQuantity": 50,
            "installmentAvailable": True,
            "monthlyRate": 300.0,
            "description": "Standard university regulation laboratory protective coat with embroidered pen pockets",
            "specs": {"sizes": ["S", "M", "L", "XL"], "material": "100% Pure Cotton"}
        },
        {
            "barcode": "6901234567894",
            "name": "Baseus 65W GaN Fast Charger Type-C & USB-A",
            "price": 1800.0,
            "category": "electronics",
            "vendorId": "vendor_tech_hub",
            "vendorName": "Campus Tech & Gadgets Hub",
            "inStock": True,
            "stockQuantity": 25,
            "installmentAvailable": True,
            "monthlyRate": 450.0,
            "description": "Dual port fast power adapter charges laptop and phone simultaneously",
            "specs": {"wattage": "65W", "ports": "Type-C + USB-A"}
        },
        {
            "barcode": "6901234567895",
            "name": "Lenovo ThinkPad Core i5 (Refurbished Grade A)",
            "price": 24000.0,
            "category": "electronics",
            "vendorId": "vendor_tech_hub",
            "vendorName": "Campus Tech & Gadgets Hub",
            "inStock": True,
            "stockQuantity": 8,
            "installmentAvailable": True,
            "monthlyRate": 4800.0,
            "description": "Intel Core i5 8th Gen, 8GB RAM, 256GB SSD, 14-inch Full HD display with 6 months warranty",
            "specs": {"cpu": "Core i5-8250U", "ram": "8GB DDR4", "storage": "256GB NVMe SSD"}
        },
        {
            "barcode": "6901234567896",
            "name": "Helix Oxford Mathematical & Drawing Instrument Set",
            "price": 850.0,
            "category": "stationery",
            "vendorId": "vendor_tech_hub",
            "vendorName": "Campus Tech & Gadgets Hub",
            "inStock": True,
            "stockQuantity": 60,
            "installmentAvailable": False,
            "description": "Precision engineering compass, dividers, set squares, ruler and stencil set in tin case",
            "specs": {"pieces": 9, "material": "Die-cast metal"}
        },
        {
            "barcode": "6161100001010",
            "name": "Broadways Sliced White Bread 400g",
            "price": 65.0,
            "category": "supermarket",
            "vendorId": "vendor_dishi_supermarket",
            "vendorName": "DISHI Express Mini-Supermarket",
            "inStock": True,
            "stockQuantity": 40,
            "installmentAvailable": False,
            "description": "Fresh daily baked soft bread",
            "specs": {"weight": "400g"}
        },
        {
            "barcode": "6161100002020",
            "name": "Brookside Fresh Milk 500ml",
            "price": 60.0,
            "category": "supermarket",
            "vendorId": "vendor_dishi_supermarket",
            "vendorName": "DISHI Express Mini-Supermarket",
            "inStock": True,
            "stockQuantity": 50,
            "installmentAvailable": False,
            "description": "Pasteurized whole cow milk pouch",
            "specs": {"volume": "500ml"}
        }
    ]

    for sku in electronics_skus:
        db.collection('supermarket_skus').document(sku['barcode']).set(sku, merge=True)
        db.collection('products').document(sku['barcode']).set(sku, merge=True)

    print("Successfully seeded campus commerce, vendors, menus, and electronics SKUs!")

if __name__ == '__main__':
    seed()

