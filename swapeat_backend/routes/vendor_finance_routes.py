from flask import Blueprint, jsonify, request
from firebase_admin import firestore
import datetime

vendor_finance_bp = Blueprint('vendor_finance', __name__)

@vendor_finance_bp.route('/agent/deposit', methods=['POST'])
def agent_deposit():
    """ 
    Dishi Agent: Vendor takes physical cash, transfers E-float to student.
    Vendor earns 0.5% commission on the transaction.
    """
    data = request.json
    vendor_uid = data.get('vendorUid')
    student_uid = data.get('studentUid')
    amount = float(data.get('amount', 0))

    if not all([vendor_uid, student_uid, amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        vendor_ref = db.collection('users').document(vendor_uid)
        student_ref = db.collection('users').document(student_uid)

        @firestore.transactional
        def process_deposit(transaction):
            v_doc = vendor_ref.get(transaction=transaction)
            s_doc = student_ref.get(transaction=transaction)

            if not v_doc.exists or not s_doc.exists:
                return False, "Vendor or Student not found"

            # Check if vendor has enough float (they need at least the amount minus commission, but safely we check full amount)
            v_balance = float(v_doc.to_dict().get('walletBalance', 0.0))
            if v_balance < amount:
                return False, "Insufficient E-Float"

            commission = amount * 0.005 # 0.5%
            student_receives = amount - commission
            
            # Vendor float deduction: they lose the 'amount' but gain the 'commission' back immediately
            # Effectively: walletBalance - amount + commission = walletBalance - student_receives
            transaction.update(vendor_ref, {'walletBalance': firestore.Increment(-student_receives)})
            
            # Student receives the net amount
            transaction.update(student_ref, {'walletBalance': firestore.Increment(student_receives)})

            # Log transaction
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'vendorUid': vendor_uid,
                'studentUid': student_uid,
                'grossAmount': amount,
                'commission': commission,
                'netAmount': student_receives,
                'type': 'dishi_agent_deposit',
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return True, f"Deposited {student_receives} KSH to student. Earned {commission} KSH commission."

        transaction = db.transaction()
        success, msg = process_deposit(transaction)
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_finance_bp.route('/p2p_transfer', methods=['POST'])
def p2p_transfer():
    """ Peer-to-peer transfer of E-Float between vendors """
    data = request.json
    sender_uid = data.get('senderUid')
    receiver_uid = data.get('receiverUid')
    amount = float(data.get('amount', 0))

    if not all([sender_uid, receiver_uid, amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        sender_ref = db.collection('users').document(sender_uid)
        receiver_ref = db.collection('users').document(receiver_uid)

        @firestore.transactional
        def process_p2p(transaction):
            s_doc = sender_ref.get(transaction=transaction)
            r_doc = receiver_ref.get(transaction=transaction)

            if not s_doc.exists or not r_doc.exists:
                return False, "Sender or Receiver not found"

            if float(s_doc.to_dict().get('walletBalance', 0.0)) < amount:
                return False, "Insufficient E-Float"

            transaction.update(sender_ref, {'walletBalance': firestore.Increment(-amount)})
            transaction.update(receiver_ref, {'walletBalance': firestore.Increment(amount)})

            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'senderUid': sender_uid,
                'receiverUid': receiver_uid,
                'amount': amount,
                'type': 'vendor_p2p_transfer',
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return True, "Transfer successful."

        transaction = db.transaction()
        success, msg = process_p2p(transaction)
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_finance_bp.route('/supplier/pay', methods=['POST'])
def pay_supplier():
    """ Pay supplier using Vendor E-Float """
    data = request.json
    vendor_uid = data.get('vendorUid')
    supplier_id = data.get('supplierId')
    amount = float(data.get('amount', 0))
    invoice_number = data.get('invoiceNumber', '')

    if not all([vendor_uid, supplier_id, amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        vendor_ref = db.collection('users').document(vendor_uid)
        
        # Suppliers could be in a separate collection or users collection
        supplier_ref = db.collection('suppliers').document(supplier_id)

        @firestore.transactional
        def process_supplier_payment(transaction):
            v_doc = vendor_ref.get(transaction=transaction)
            s_doc = supplier_ref.get(transaction=transaction)

            if not v_doc.exists:
                return False, "Vendor not found"
                
            # If supplier doesn't exist, we might just fail, or allow creation. Assuming it exists.
            if not s_doc.exists:
                return False, "Supplier not found"

            if float(v_doc.to_dict().get('walletBalance', 0.0)) < amount:
                return False, "Insufficient E-Float"

            transaction.update(vendor_ref, {'walletBalance': firestore.Increment(-amount)})
            transaction.update(supplier_ref, {'balance': firestore.Increment(amount)})

            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'vendorUid': vendor_uid,
                'supplierId': supplier_id,
                'invoiceNumber': invoice_number,
                'amount': amount,
                'type': 'supplier_payment',
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return True, "Supplier paid successfully."

        transaction = db.transaction()
        success, msg = process_supplier_payment(transaction)
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
