import os
import requests
from flask import Blueprint, request, jsonify, render_template
from firebase_admin import firestore

invite_bp = Blueprint('invite', __name__, template_folder='../templates')

@invite_bp.route('/', methods=['GET'])
def invite_page():
    referrer_id = request.args.get('ref', '')
    return render_template('invite.html', referrer_id=referrer_id)

@invite_bp.route('/register', methods=['POST'])
def register_invite():
    data = request.json or {}
    name = data.get('name', '').strip()
    phone = data.get('phone', '').strip()
    referrer_id = data.get('referrer_id', '').strip()

    if not name or not phone:
        return jsonify({"error": "Name and phone number are required."}), 400

    db = firestore.client()

    # Create a basic user doc for the invited parent
    new_user_ref = db.collection('users').document()
    user_id = new_user_ref.id

    try:
        new_user_ref.set({
            'name': name,
            'phoneNumber': phone,
            'role': 'parent',
            'walletBalance': 0.0,
            'savingsBalance': 0.0,
            'referredBy': referrer_id,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
        
        return jsonify({"status": "success", "message": "User created successfully. You can top up in the app.", "user_id": user_id}), 200

    except Exception as e:
        return jsonify({"error": f"Failed to register: {str(e)}"}), 500
