from flask import Blueprint, render_template_string, request
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
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background-color: #0C101B;
            color: white;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 40px 20px;
        }
        .card {
            background: #131A2A;
            border-radius: 16px;
            padding: 40px 32px;
            max-width: 480px;
            width: 100%;
            text-align: center;
            box-shadow: 0 8px 40px rgba(0,255,194,0.08);
            border: 1px solid rgba(0,255,194,0.15);
        }
        .logo { font-size: 13px; letter-spacing: 4px; color: #05D5AA; margin-bottom: 24px; opacity: 0.7; }
        h1 { color: #00FFC2; font-size: 26px; font-weight: 700; margin-bottom: 12px; }
        .meta { color: #8B9BB4; font-size: 14px; line-height: 1.7; margin-bottom: 28px; }
        .spinner {
            width: 36px; height: 36px;
            border: 3px solid rgba(0,255,194,0.2);
            border-top-color: #00FFC2;
            border-radius: 50%;
            animation: spin 0.9s linear infinite;
            margin: 0 auto 20px;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .status { font-size: 13px; color: #05D5AA; margin-bottom: 28px; letter-spacing: 1px; }
        .btn {
            display: inline-block;
            padding: 14px 36px;
            background: linear-gradient(135deg, #05D5AA, #00FFC2);
            color: #000;
            text-decoration: none;
            font-weight: 700;
            border-radius: 10px;
            font-size: 16px;
            letter-spacing: 0.5px;
            transition: opacity 0.2s;
        }
        .btn:hover { opacity: 0.85; }
        .footer { margin-top: 28px; font-size: 11px; color: #3a4055; letter-spacing: 1px; }
    </style>

    <script>
        // Attempt to open the app automatically via deep link after a short delay
        setTimeout(function() {
            window.location.href = "dishi://event/{{ event_id }}";
        }, 800);
    </script>
</head>
<body>
    <div class="card">
        <div class="logo">D I S H I</div>
        <h1>{{ title }}</h1>
        <div class="meta">{{ description }}</div>
        <div class="spinner"></div>
        <div class="status">Opening in DISHI App...</div>
        <a href="dishi://event/{{ event_id }}" class="btn">Open in DISHI</a>
        <div class="footer">from Delstarford Works</div>
    </div>
</body>
</html>
"""

@events_bp.route('/e/<event_id>')
def view_event(event_id):
    """Public event deep-link page — renders a preview and auto-opens the app."""
    try:
        db = firestore.client()
        doc_ref = db.collection('events').document(event_id)
        doc = doc_ref.get()

        if not doc.exists:
            return (
                "<html><body style='background:#0C101B;color:white;text-align:center;padding:60px'>"
                "<h2 style='color:#F92B60'>Event Not Found</h2>"
                "<p>This event may have been removed or the link is incorrect.</p>"
                "</body></html>",
                404,
            )

        event_data = doc.to_dict()

        # Increment views for analytics — non-fatal
        try:
            doc_ref.update({'views': firestore.Increment(1)})
        except Exception:
            pass

        title = event_data.get('title', 'DISHI Campus Event')
        date_str = event_data.get('date', '')
        time_str = event_data.get('time', '')
        price = event_data.get('price', 0)
        venue = event_data.get('venue', event_data.get('location', ''))

        # Build description with available fields
        parts = []
        if date_str:
            parts.append(date_str)
        if time_str:
            parts.append(f'@ {time_str}')
        if venue:
            parts.append(f'📍 {venue}')
        if price is not None:
            parts.append(f'KES {price}' if price else 'Free')
        desc = '  |  '.join(parts) if parts else 'View details in the DISHI app.'

        image_url = event_data.get(
            'imageUrl',
            event_data.get('image_url', 'https://dishi.delstarfordworks.co.ke/static/dishi_logo.png'),
        )

        return render_template_string(
            HTML_TEMPLATE,
            event_id=event_id,
            title=title,
            description=desc,
            image_url=image_url,
            request_url=request.url,
        )

    except Exception as e:
        # Return a user-friendly error, not a raw Python traceback
        return (
            "<html><body style='background:#0C101B;color:white;text-align:center;padding:60px'>"
            f"<h2 style='color:#F92B60'>Something went wrong</h2>"
            f"<p>Could not load the event. Please try again later.</p>"
            "</body></html>",
            500,
        )
