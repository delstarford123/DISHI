import os

def append_to_match_routes():
    # Assuming match_routes.py is in swapeat_backend/routes/v2/
    target_file = r"c:\Users\Delstaford\swapeat\swapeat_backend\routes\v2\match_routes.py"
    
    routes_code = """

# ==========================================
# SUPPORT TICKETS (Cross-Dashboard)
# ==========================================
@match_bp.route('/support/create_ticket', methods=['POST'])
def create_support_ticket():
    try:
        from firebase_admin import messaging
        data = request.json
        user_id = data.get('user_id')
        user_role = data.get('user_role')
        message = data.get('message')

        if not all([user_id, user_role, message]):
            return jsonify({'error': 'Missing required fields'}), 400

        ticket_ref = db.collection('support_tickets').document()
        ticket_ref.set({
            'user_id': user_id,
            'user_role': user_role,
            'message': message,
            'status': 'open',
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        # Send FCM to admins
        try:
            admin_msg = messaging.Message(
                notification=messaging.Notification(
                    title=f"New Support Ticket ({user_role.capitalize()})",
                    body=f"{message[:50]}..."
                ),
                topic='admin_alerts'
            )
            messaging.send(admin_msg)
        except Exception as e:
            print(f"Error sending admin FCM: {e}")

        return jsonify({'message': 'Ticket created successfully', 'ticket_id': ticket_ref.id}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
"""

    try:
        with open(target_file, "a") as f:
            f.write(routes_code)
        print("Support routes successfully appended to match_routes.py")
    except Exception as e:
        print(f"Failed to append routes: {e}")

if __name__ == "__main__":
    append_to_match_routes()
