from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime
import random

vendor_management_bp = Blueprint('vendor_management', __name__)

@vendor_management_bp.route('/staff/clock_in', methods=['POST'])
def clock_in():
    """ Securely clock in a staff member using PIN """
    data = request.json
    vendor_uid = data.get('vendorUid')
    staff_pin = data.get('pin')

    if not all([vendor_uid, staff_pin]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        # In a real app, verify PIN against a staff subcollection
        # For now, mock a successful clock in if PIN is 4 digits
        if len(str(staff_pin)) != 4:
            return jsonify({"error": "Invalid PIN format"}), 400
            
        shift_ref = db.collection('users').document(vendor_uid).collection('shifts').document()
        shift_ref.set({
            'staffPin': staff_pin,
            'clockInTime': firestore.SERVER_TIMESTAMP,
            'status': 'active'
        })
        return jsonify({"status": "success", "message": "Clocked in successfully.", "shiftId": shift_ref.id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_management_bp.route('/staff/clock_out', methods=['POST'])
def clock_out():
    """ Clock out a staff member """
    data = request.json
    vendor_uid = data.get('vendorUid')
    shift_id = data.get('shiftId')

    if not all([vendor_uid, shift_id]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        # Mocking shift sales calculation for MVP
        shift_sales = 4500.00
        shift_deposits = 1200.00

        shift_ref = db.collection('users').document(vendor_uid).collection('shifts').document(shift_id)
        shift_ref.update({
            'clockOutTime': firestore.SERVER_TIMESTAMP,
            'status': 'completed',
            'shiftSales': shift_sales,
            'shiftDeposits': shift_deposits
        })
        return jsonify({
            "status": "success", 
            "message": "Clocked out successfully.",
            "shiftSales": shift_sales,
            "shiftDeposits": shift_deposits
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_management_bp.route('/market_insights', methods=['GET'])
def get_market_insights():
    """ Return anonymous average pricing on campus """
    vendor_uid = request.args.get('vendorUid')
    
    # Mocking data for insights
    insights = [
        {"item": "Beef Stew", "yourPrice": 180, "marketAvg": 165, "competitiveness": "High (Consider lowering)"},
        {"item": "Chapati", "yourPrice": 20, "marketAvg": 25, "competitiveness": "Excellent (Value)"},
        {"item": "Pilau", "yourPrice": 150, "marketAvg": 150, "competitiveness": "Average"}
    ]
    return jsonify({"status": "success", "insights": insights}), 200

@vendor_management_bp.route('/vault/upload', methods=['POST'])
def upload_vault_doc():
    """ Store health certificate references """
    data = request.json
    vendor_uid = data.get('vendorUid')
    doc_type = data.get('docType') # e.g. "Food Handling License"
    doc_url = data.get('docUrl') # URL from Firebase Storage

    if not all([vendor_uid, doc_type, doc_url]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        vault_ref = db.collection('users').document(vendor_uid).collection('vault').document()
        vault_ref.set({
            'docType': doc_type,
            'docUrl': doc_url,
            'uploadedAt': firestore.SERVER_TIMESTAMP,
            'status': 'verified'
        })
        return jsonify({"status": "success", "message": "Document secured in vault."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_management_bp.route('/staff/add', methods=['POST'])
def add_staff():
    """ Add a staff member with a specific role """
    data = request.json
    vendor_uid = data.get('vendorUid')
    staff_name = data.get('name')
    staff_role = data.get('role')
    staff_pin = data.get('pin')

    if not all([vendor_uid, staff_name, staff_role, staff_pin]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        staff_ref = db.collection('users').document(vendor_uid).collection('staff').document()
        staff_ref.set({
            'name': staff_name,
            'role': staff_role,
            'pin': staff_pin,
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": f"{staff_name} added as {staff_role}."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_management_bp.route('/maintenance/log', methods=['POST'])
def log_maintenance():
    """ Log equipment maintenance or repair requests """
    data = request.json
    vendor_uid = data.get('vendorUid')
    equipment_name = data.get('equipmentName')
    issue_desc = data.get('issueDescription')
    needs_repair = data.get('needsRepair', False)

    if not all([vendor_uid, equipment_name, issue_desc]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        maint_ref = db.collection('users').document(vendor_uid).collection('maintenance_logs').document()
        maint_ref.set({
            'equipmentName': equipment_name,
            'issueDescription': issue_desc,
            'needsRepair': needs_repair,
            'status': 'pending_repair' if needs_repair else 'logged',
            'loggedAt': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": f"Maintenance log for {equipment_name} recorded."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_management_bp.route('/branches/add', methods=['POST'])
def add_branch():
    """ Add a new shop branch """
    data = request.json
    vendor_uid = data.get('vendorUid')
    branch_name = data.get('branchName')
    location = data.get('location')

    if not all([vendor_uid, branch_name, location]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        branch_ref = db.collection('users').document(vendor_uid).collection('branches').document()
        branch_ref.set({
            'branchName': branch_name,
            'location': location,
            'status': 'active',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": f"Branch {branch_name} added successfully."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
