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

            # 0.5% commission only (no extra money for vendor)
            commission = round(amount * 0.005, 2)
            student_receives = max(0.0, amount - commission)
            
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

@vendor_finance_bp.route('/okoa_dishi/issue', methods=['POST'])
def issue_okoa_dishi():
    """ Issue Okoa Dishi (micro-credit) to a trusted student """
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
        def process_credit(transaction):
            v_doc = vendor_ref.get(transaction=transaction)
            s_doc = student_ref.get(transaction=transaction)

            if not v_doc.exists or not s_doc.exists:
                return False, "Vendor or Student not found"

            # Check if vendor has enough float to extend credit
            if float(v_doc.to_dict().get('walletBalance', 0.0)) < amount:
                return False, "Insufficient E-Float to issue credit"

            # Deduct from vendor, add to student's debt (or just wallet balance if that's how we model debt)
            transaction.update(vendor_ref, {'walletBalance': firestore.Increment(-amount)})
            
            # For simplicity, we create a negative wallet balance record or a specific debt record
            # Here we just increment their wallet balance with the loan so they can spend it, but also record the debt
            transaction.update(student_ref, {
                'walletBalance': firestore.Increment(amount),
                'okoaDebt': firestore.Increment(amount)
            })

            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'vendorUid': vendor_uid,
                'studentUid': student_uid,
                'amount': amount,
                'type': 'okoa_dishi_credit',
                'status': 'unpaid',
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return True, f"Issued {amount} KSH credit to student."

        transaction = db.transaction()
        success, msg = process_credit(transaction)
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_finance_bp.route('/escrow/request', methods=['POST'])
def request_escrow():
    """ Vendor requests a bulk catering payment to be held in escrow """
    data = request.json
    vendor_uid = data.get('vendorUid')
    parent_phone = data.get('parentPhone')
    amount = float(data.get('amount', 0))
    event_name = data.get('eventName', 'Bulk Catering')

    if not all([vendor_uid, parent_phone, amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        escrow_ref = db.collection('escrows').document()
        escrow_ref.set({
            'vendorUid': vendor_uid,
            'parentPhone': parent_phone,
            'amount': amount,
            'eventName': event_name,
            'status': 'pending', # 'pending', 'funded', 'released'
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"status": "success", "message": f"Escrow request of KSH {amount} sent to {parent_phone}!"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_finance_bp.route('/tax_export', methods=['GET'])
def tax_export():
    """ Generate a simulated tax/revenue CSV or JSON summary for KRA compliance """
    vendor_uid = request.args.get('vendorUid')
    if not vendor_uid:
        return jsonify({"error": "Missing vendorUid"}), 400

    try:
        db = firestore.client()
        # In a real app, query transactions collection for the given vendor over the last month
        # For this prototype, we will return a mocked summary object
        
        # Log this generation for audit purposes
        audit_ref = db.collection('tax_reports_metadata').document()
        audit_ref.set({
            'vendorUid': vendor_uid,
            'generatedAt': firestore.SERVER_TIMESTAMP,
            'status': 'success'
        })
        
        summary = {
            "vendorUid": vendor_uid,
            "period": "Current Month",
            "grossRevenue": 150000.00,
            "vatCollected": 24000.00,
            "kraPin": "P000000000Z",
            "transactionsCount": 432
        }
        
        return jsonify({"status": "success", "data": summary, "message": "Tax report generated successfully."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_finance_bp.route('/refund', methods=['POST'])
def refund_transaction():
    """ Automated Vendor Refunds (Finance) - Refund a transaction to student wallet """
    data = request.json
    vendor_uid = data.get('vendorUid')
    student_uid = data.get('studentUid')
    amount = float(data.get('amount', 0))
    reason = data.get('reason', 'Customer requested refund')

    if not all([vendor_uid, student_uid, amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        db = firestore.client()
        vendor_ref = db.collection('users').document(vendor_uid)
        student_ref = db.collection('users').document(student_uid)

        @firestore.transactional
        def process_refund(transaction):
            v_doc = vendor_ref.get(transaction=transaction)
            s_doc = student_ref.get(transaction=transaction)

            if not v_doc.exists or not s_doc.exists:
                return False, "Vendor or Student not found"

            # Check if vendor has enough float to refund
            if float(v_doc.to_dict().get('walletBalance', 0.0)) < amount:
                return False, "Insufficient E-Float for refund"

            # Deduct from vendor, return to student
            transaction.update(vendor_ref, {'walletBalance': firestore.Increment(-amount)})
            transaction.update(student_ref, {'walletBalance': firestore.Increment(amount)})

            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'vendorUid': vendor_uid,
                'studentUid': student_uid,
                'amount': amount,
                'type': 'vendor_refund',
                'reason': reason,
                'timestamp': firestore.SERVER_TIMESTAMP
            })
            return True, f"Refunded {amount} KSH to student."

        transaction = db.transaction()
        success, msg = process_refund(transaction)
        if success:
            return jsonify({"status": "success", "message": msg}), 200
        else:
            return jsonify({"error": msg}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@vendor_finance_bp.route('/advanced_export', methods=['GET'])
def advanced_export():
    """ Advanced Reporting (Finance) - Export detailed sales, refunds, escrows, and top-ups """
    vendor_uid = request.args.get('vendorUid')
    format_type = request.args.get('format', 'csv')

    if not vendor_uid:
        return jsonify({"error": "Missing vendorUid"}), 400

    try:
        # In a real app, query multiple collections, aggregate data, and format as CSV or JSON
        summary = {
            "vendorUid": vendor_uid,
            "reportType": "Advanced Financial Analysis",
            "dateGenerated": datetime.datetime.now().isoformat(),
            "metrics": {
                "totalSales": 320000.50,
                "totalRefunds": 4500.00,
                "escrowHeld": 15000.00,
                "loyaltyPointsIssued": 3200,
                "topSellingItem": "Beef Stew",
            }
        }
        
        return jsonify({"status": "success", "data": summary, "message": f"Advanced {format_type.upper()} report generated."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
