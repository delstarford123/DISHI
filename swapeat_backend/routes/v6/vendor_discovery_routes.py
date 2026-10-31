import math
from flask import Blueprint, request, jsonify
from firebase_admin import firestore

vendor_discovery_v6_bp = Blueprint('vendor_discovery_v6', __name__)

def haversine_km(lat1, lon1, lat2, lon2):
    """Calculates distance between two GPS coordinates in kilometers."""
    try:
        if None in (lat1, lon1, lat2, lon2):
            return float('inf')
        lat1, lon1, lat2, lon2 = float(lat1), float(lon1), float(lat2), float(lon2)
        R = 6371.0  # Earth radius in kilometers
        dLat = math.radians(lat2 - lat1)
        dLon = math.radians(lon2 - lon1)
        a = (math.sin(dLat / 2) ** 2 +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
             math.sin(dLon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c
    except Exception:
        return float('inf')

def format_distance(dist_km):
    """Formats distance for student UI badges: '350 m away' or '2.4 km away'."""
    if math.isinf(dist_km):
        return None
    if dist_km < 1.0:
        return f"{int(dist_km * 1000)} m away"
    return f"{dist_km:.1f} km away"

# Supported Pan-African Country & Campus Region Catalog
AFRICA_REGIONS = [
    {
        "country": "Kenya",
        "code": "KE",
        "currency": "KES",
        "flag": "🇰🇪",
        "counties": [
            {
                "name": "Kakamega",
                "campuses": ["Masinde Muliro University (MMUST)", "Sigalagala National Poly"]
            },
            {
                "name": "Nairobi",
                "campuses": ["University of Nairobi (UoN)", "Strathmore University", "Kenyatta University (KU)", "USIU-Africa"]
            },
            {
                "name": "Kiambu",
                "campuses": ["Jomo Kenyatta University (JKUAT)", "Mount Kenya University (MKU)"]
            },
            {
                "name": "Uasin Gishu",
                "campuses": ["Moi University Main", "Moi University Annex (Eldoret)"]
            },
            {
                "name": "Kisumu",
                "campuses": ["Maseno University", "Great Lakes University", "Kisumu Poly"]
            },
            {
                "name": "Nakuru",
                "campuses": ["Egerton University (Njoro)", "Kabarak University"]
            },
            {
                "name": "Nyeri",
                "campuses": ["Dedan Kimathi University (DeKUT)"]
            },
            {
                "name": "Mombasa",
                "campuses": ["Technical University of Mombasa (TUM)"]
            }
        ]
    },
    {
        "country": "Uganda",
        "code": "UG",
        "currency": "UGX",
        "flag": "🇺🇬",
        "counties": [
            {
                "name": "Kampala",
                "campuses": ["Makerere University", "Kyambogo University", "Kampala International Univ"]
            }
        ]
    },
    {
        "country": "Tanzania",
        "code": "TZ",
        "currency": "TZS",
        "flag": "🇹🇿",
        "counties": [
            {
                "name": "Dar es Salaam",
                "campuses": ["University of Dar es Salaam (UDSM)", "Ardhi University", "IFM"]
            }
        ]
    },
    {
        "country": "Rwanda",
        "code": "RW",
        "currency": "RWF",
        "flag": "🇷🇼",
        "counties": [
            {
                "name": "Kigali",
                "campuses": ["University of Rwanda (UR)", "Carnegie Mellon Univ Africa"]
            }
        ]
    },
    {
        "country": "Nigeria",
        "code": "NG",
        "currency": "NGN",
        "flag": "🇳🇬",
        "counties": [
            {
                "name": "Lagos",
                "campuses": ["University of Lagos (UNILAG)", "Lagos State University (LASU)"]
            },
            {
                "name": "Oyo",
                "campuses": ["University of Ibadan (UI)"]
            }
        ]
    },
    {
        "country": "Ghana",
        "code": "GH",
        "currency": "GHS",
        "flag": "🇬🇭",
        "counties": [
            {
                "name": "Greater Accra",
                "campuses": ["University of Ghana (Legon)", "UPSA"]
            },
            {
                "name": "Ashanti",
                "campuses": ["KNUST Kumasi"]
            }
        ]
    },
    {
        "country": "South Africa",
        "code": "ZA",
        "currency": "ZAR",
        "flag": "🇿🇦",
        "counties": [
            {
                "name": "Western Cape",
                "campuses": ["University of Cape Town (UCT)", "Univ of the Western Cape (UWC)"]
            },
            {
                "name": "Gauteng",
                "campuses": ["University of the Witwatersrand (Wits)", "Univ of Johannesburg (UJ)"]
            }
        ]
    }
]

@vendor_discovery_v6_bp.route('/regions', methods=['GET'])
def get_regions():
    """Returns available Pan-African countries, counties, and university campuses."""
    return jsonify({
        "status": "success",
        "regions": AFRICA_REGIONS
    }), 200

@vendor_discovery_v6_bp.route('/search', methods=['GET'])
def search_vendors():
    """
    Search and discover vendors across Kenya and Africa:
    - Text query: vendor name, food items, cuisine
    - Location: Country, county, campus filter
    - Geolocation: Calculates exact distance to student using GPS coordinates
    """
    query = request.args.get('q', '').strip().lower()
    country = request.args.get('country', 'all').strip()
    county = request.args.get('county', 'all').strip()
    campus = request.args.get('campus', 'all').strip()
    category = request.args.get('category', 'all').strip().lower()
    
    # User coordinates for nearest vendor calculation
    user_lat = request.args.get('lat')
    user_lon = request.args.get('lon') or request.args.get('lng')
    
    max_radius_km_raw = request.args.get('max_distance_km', '50.0')
    try:
        max_radius_km = float(max_radius_km_raw)
    except ValueError:
        max_radius_km = 50.0

    try:
        db = firestore.client()
        # Fetch all users with role 'vendor'
        users_stream = db.collection('users').where('roles', 'array_contains', 'vendor').stream()
        
        vendors_list = []
        for doc in users_stream:
            data = doc.to_dict() or {}
            vid = doc.id
            
            # Profile & display details
            name = data.get('businessName') or data.get('displayName') or data.get('name') or 'Campus Vendor'
            profile_img = data.get('profileImageUrl') or data.get('photoUrl') or data.get('imageUrl')
            banner_img = data.get('bannerImageUrl') or data.get('coverUrl')
            
            # Regional location data
            vendor_country = data.get('country', 'Kenya')
            vendor_county = data.get('county', 'Kakamega')
            vendor_city = data.get('city') or vendor_county
            vendor_campus = data.get('campus', 'MMUST')
            address = data.get('address') or data.get('venueLocation', 'Campus Gate A')
            
            # GPS Coordinates
            lat = data.get('latitude')
            lon = data.get('longitude')
            
            # Operational stats
            is_open = data.get('isOpen', True)
            preorder_enabled = data.get('preorderEnabled', True)
            delivery_enabled = data.get('deliveryEnabled', True)
            rating = float(data.get('rating') or 4.8)
            total_reviews = int(data.get('totalReviews') or data.get('reviewCount') or 24)
            categories = data.get('categories') or ['Hot Meals', 'Fast Food']
            contact_phone = data.get('phoneNumber') or data.get('phone', '')
            dishi_id = data.get('dishiId') or (vid[:7].upper() if len(vid) >= 7 else vid.upper())
            
            # 1. Country filter
            if country != 'all' and vendor_country.lower() != country.lower():
                continue
                
            # 2. County / City filter
            if county != 'all' and vendor_county.lower() != county.lower():
                continue
                
            # 3. Campus filter
            if campus != 'all' and campus.lower() not in vendor_campus.lower():
                continue
                
            # 4. Category filter
            if category != 'all':
                cat_match = any(category in c.lower() for c in categories)
                if not cat_match:
                    continue
                    
            # 5. Text search query match
            if query:
                text_corpus = f"{name} {vendor_campus} {address} {' '.join(categories)} {vendor_county}".lower()
                if query not in text_corpus:
                    continue

            # 6. Distance calculation
            dist_km = float('inf')
            if user_lat is not None and user_lon is not None and lat is not None and lon is not None:
                dist_km = haversine_km(user_lat, user_lon, lat, lon)
                if dist_km > max_radius_km:
                    continue
                    
            vendors_list.append({
                'id': vid,
                'name': name,
                'businessName': name,
                'dishiId': dishi_id,
                'profileImageUrl': profile_img,
                'bannerImageUrl': banner_img,
                'country': vendor_country,
                'county': vendor_county,
                'city': vendor_city,
                'campus': vendor_campus,
                'address': address,
                'latitude': lat,
                'longitude': lon,
                'distanceKm': dist_km if not math.isinf(dist_km) else None,
                'distanceFormatted': format_distance(dist_km),
                'isOpen': is_open,
                'preorderEnabled': preorder_enabled,
                'deliveryEnabled': delivery_enabled,
                'rating': rating,
                'totalReviews': total_reviews,
                'categories': categories,
                'contactPhone': contact_phone
            })
            
        # Sort by distance if user location was provided, otherwise by rating
        if user_lat is not None and user_lon is not None:
            vendors_list.sort(key=lambda x: (x['distanceKm'] if x['distanceKm'] is not None else 999999, -x['rating']))
        else:
            vendors_list.sort(key=lambda x: -x['rating'])
            
        return jsonify({
            "status": "success",
            "count": len(vendors_list),
            "vendors": vendors_list
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_discovery_v6_bp.route('/<vendor_id>/menu', methods=['GET'])
def get_vendor_menu(vendor_id):
    """Fetches full menu catalog for a specific vendor."""
    try:
        db = firestore.client()
        menu_stream = db.collection('vendor_menus').where('vendorId', '==', vendor_id).stream()
        
        items = []
        for doc in menu_stream:
            m = doc.to_dict() or {}
            items.append({
                'id': doc.id,
                'name': m.get('name', 'Menu Item'),
                'description': m.get('description', ''),
                'price': float(m.get('price', 0.0)),
                'imageUrl': m.get('imageUrl'),
                'category': m.get('category', 'Hot Meals'),
                'isAvailable': m.get('isAvailable', True),
                'preorderAllowed': m.get('preorderAllowed', True)
            })
            
        return jsonify({
            "status": "success",
            "vendor_id": vendor_id,
            "count": len(items),
            "menu": items
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
