from flask import Blueprint, render_template_string
from firebase_admin import firestore

events_bp = Blueprint('events', __name__)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    
    <!-- Open Graph tags for WhatsApp / Social Media Rich Previews -->
    <meta property="og:title" content="{{ title }}">
    <meta property="og:description" content="{{ description }}">
    <meta property="og:image" content="{{ image_url }}">
    <meta property="og:url" content="{{ request_url }}">
    <meta property="og:type" content="website">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="{{ title }}">
    <meta name="twitter:description" content="{{ description }}">
    <meta name="twitter:image" content="{{ image_url }}">

    <title>{{ title }} - DISHI Campus Event</title>
    
    <style>
        body {
            background-color: #0C101B;
            color: white;
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
        }
        h1 { color: #00FFC2; }
        .btn {
            display: inline-block;
            margin-top: 20px;
            padding: 15px 30px;
            background-color: #00FFC2;
            color: #000;
            text-decoration: none;
            font-weight: bold;
            border-radius: 8px;
            font-size: 18px;
        }
    </style>

    <script>
        // Attempt to open the app automatically via deep link
        window.onload = function() {
            var deepLink = "dishi://event/{{ event_id }}";
            window.location.href = deepLink;
        }
    </script>
</head>
<body>
    <h1>{{ title }}</h1>
    <p>Opening event in DISHI App...</p>
    <p>If the app does not open automatically, click the button below:</p>
    <a href="dishi://event/{{ event_id }}" class="btn">Open in DISHI</a>
</body>
</html>
"""

@events_bp.route('/e/<event_id>')
def view_event(event_id):
    try:
        db = firestore.client()
        doc_ref = db.collection('events').document(event_id)
        doc = doc_ref.get()
        if not doc.exists:
            return "Event not found.", 404
        
        event_data = doc.to_dict()
        
        # Increment views for analytics
        try:
            doc_ref.update({'views': firestore.Increment(1)})
        except Exception:
            pass
            
        from flask import request
        
        title = event_data.get('title', 'DISHI Campus Event')
        desc = f"{event_data.get('date', '')} @ {event_data.get('time', '')} | KES {event_data.get('price', 0)}"
        image_url = event_data.get('imageUrl', 'https://dishi.delstarfordworks.co.ke/static/dishi_logo.png')
        
        return render_template_string(
            HTML_TEMPLATE, 
            event_id=event_id, 
            title=title, 
            description=desc, 
            image_url=image_url,
            request_url=request.url
        )
    except Exception as e:
        return str(e), 500
