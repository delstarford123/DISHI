from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import traceback
import uuid

fundi_bp = Blueprint('fundi_bp', __name__)

@fundi_bp.route('/pay', methods=['POST'])
def pay_fundi():
    """
    Step 1: Escrow. Deducts money from the Payer's wallet and locks it in Escrow.
    """
    data = request.json
    if not data:
        return jsonify({"error": "No data provided"}), 400

    job_id = data.get('job_id')
    payer_id = data.get('payer_id')
    fundi_id = data.get('fundi_id')
    amount = data.get('amount')
    
    if not all([job_id, payer_id, fundi_id, amount]):
        return jsonify({"error": "Missing required fields"}), 400

    try:
        amount = float(amount)
        if amount <= 0:
            return jsonify({"error": "Amount must be greater than 0"}), 400
    except ValueError:
        return jsonify({"error": "Invalid amount format"}), 400

    db = firestore.client()
    
    try:
        fee = amount * 0.015
        net_amount = amount - fee

        transaction_ref = db.transaction()
        payer_ref = db.collection('users').document(payer_id)
        job_ref = db.collection('fundi_jobs').document(job_id)

        @firestore.transactional
        def process_escrow(transaction):
            payer_doc = payer_ref.get(transaction=transaction)
            
            if not payer_doc.exists:
                raise Exception("Payer not found")

            payer_data = payer_doc.to_dict()
            payer_balance = payer_data.get('walletBalance', 0)

            if payer_balance < amount:
                raise Exception("Insufficient funds")

            # Deduct from payer only. Do NOT credit fundi yet.
            transaction.update(payer_ref, {
                'walletBalance': payer_balance - amount
            })

            # Mark job as In Escrow
            transaction.update(job_ref, {
                'status': 'In Escrow',
                'paid_amount': amount,
                'fee_deducted': fee,
                'net_amount': net_amount,
                'escrow_status': 'HELD'
            })

            # Record escrow out transaction for payer
            tx_id_out = str(uuid.uuid4())
            tx_out_ref = payer_ref.collection('transactions').document(tx_id_out)
            
            transaction.set(tx_out_ref, {
                'type': 'ESCROW_LOCK',
                'amount': amount,
                'desc': 'Fundi Job Escrow Hold',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'job_id': job_id
            })

        process_escrow(transaction_ref)

        return jsonify({
            "status": "success",
            "message": "Funds securely locked in Escrow",
            "escrow_amount": amount
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@fundi_bp.route('/release_escrow', methods=['POST'])
def release_escrow():
    """
    Step 2: Release. Called when Payer confirms job is complete.
    Credits the net amount to the Fundi.
    """
    data = request.json
    job_id = data.get('job_id')
    payer_id = data.get('payer_id')

    if not job_id or not payer_id:
        return jsonify({"error": "Missing job_id or payer_id"}), 400

    db = firestore.client()

    try:
        transaction_ref = db.transaction()
        job_ref = db.collection('fundi_jobs').document(job_id)

        @firestore.transactional
        def process_release(transaction):
            job_doc = job_ref.get(transaction=transaction)
            if not job_doc.exists:
                raise Exception("Job not found")

            job_data = job_doc.to_dict()
            if job_data.get('escrow_status') != 'HELD':
                raise Exception("Funds are not currently in Escrow for this job")
            
            if job_data.get('payer_id') != payer_id:
                raise Exception("Only the payer can release escrow funds")

            fundi_id = job_data.get('fundi_id')
            net_amount = job_data.get('net_amount', 0)
            fee = job_data.get('fee_deducted', 0)

            fundi_ref = db.collection('users').document(fundi_id)
            fundi_doc = fundi_ref.get(transaction=transaction)
            if not fundi_doc.exists:
                raise Exception("Fundi not found")

            fundi_data = fundi_doc.to_dict()
            fundi_balance = fundi_data.get('walletBalance', 0)

            # Credit Fundi
            transaction.update(fundi_ref, {
                'walletBalance': fundi_balance + net_amount
            })

            # Update Job status
            transaction.update(job_ref, {
                'status': 'Completed',
                'escrow_status': 'RELEASED',
                'completed_at': firestore.SERVER_TIMESTAMP
            })

            # Record incoming transaction for Fundi
            tx_id_in = str(uuid.uuid4())
            tx_in_ref = fundi_ref.collection('transactions').document(tx_id_in)
            transaction.set(tx_in_ref, {
                'type': 'ESCROW_RELEASED',
                'amount': net_amount,
                'desc': 'Fundi Job Payment Released',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'job_id': job_id,
                'fee': fee
            })

            # Collect system fee
            system_fee_ref = db.collection('system_revenue').document()
            transaction.set(system_fee_ref, {
                'type': 'FUNDI_FEE',
                'amount': fee,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'job_id': job_id,
                'fundi_id': fundi_id
            })

        process_release(transaction_ref)
        return jsonify({"status": "success", "message": "Funds released to Fundi successfully"}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@fundi_bp.route('/dispute_escrow', methods=['POST'])
def dispute_escrow():
    """
    Step 2 (Alt): Dispute. Locks the funds for admin review.
    """
    data = request.json
    job_id = data.get('job_id')
    payer_id = data.get('payer_id')

    if not job_id or not payer_id:
        return jsonify({"error": "Missing job_id or payer_id"}), 400

    db = firestore.client()

    try:
        transaction_ref = db.transaction()
        job_ref = db.collection('fundi_jobs').document(job_id)

        @firestore.transactional
        def process_dispute(transaction):
            job_doc = job_ref.get(transaction=transaction)
            if not job_doc.exists:
                raise Exception("Job not found")

            job_data = job_doc.to_dict()
            if job_data.get('escrow_status') != 'HELD':
                raise Exception("Funds are not currently in Escrow for this job")
            
            if job_data.get('payer_id') != payer_id:
                raise Exception("Only the payer can dispute")

            # Simply lock the funds
            transaction.update(job_ref, {
                'status': 'Disputed',
                'escrow_status': 'DISPUTED',
                'disputed_at': firestore.SERVER_TIMESTAMP
            })

        process_dispute(transaction_ref)
        return jsonify({"status": "success", "message": "Job disputed. Funds are frozen for admin review."}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@fundi_bp.route('/resolve_dispute', methods=['POST'])
def resolve_dispute():
    """
    Step 3: Admin Dispute Resolution.
    resolution_action: 'refund_payer' or 'pay_fundi'
    """
    data = request.json
    job_id = data.get('job_id')
    admin_id = data.get('admin_id')
    resolution_action = data.get('resolution_action')

    if not all([job_id, admin_id, resolution_action]):
        return jsonify({"error": "Missing required fields"}), 400

    if resolution_action not in ['refund_payer', 'pay_fundi']:
        return jsonify({"error": "Invalid resolution_action"}), 400

    db = firestore.client()

    try:
        transaction_ref = db.transaction()
        job_ref = db.collection('fundi_jobs').document(job_id)

        @firestore.transactional
        def process_resolution(transaction):
            job_doc = job_ref.get(transaction=transaction)
            if not job_doc.exists:
                raise Exception("Job not found")

            job_data = job_doc.to_dict()
            if job_data.get('escrow_status') != 'DISPUTED':
                raise Exception("Job is not currently disputed")

            amount = job_data.get('paid_amount', 0)
            net_amount = job_data.get('net_amount', 0)
            fee = job_data.get('fee_deducted', 0)
            payer_id = job_data.get('payer_id')
            fundi_id = job_data.get('fundi_id')

            if resolution_action == 'refund_payer':
                # Refund Payer
                payer_ref = db.collection('users').document(payer_id)
                payer_doc = payer_ref.get(transaction=transaction)
                payer_balance = payer_doc.to_dict().get('walletBalance', 0)

                transaction.update(payer_ref, {
                    'walletBalance': payer_balance + amount
                })

                transaction.update(job_ref, {
                    'status': 'Resolved - Refunded',
                    'escrow_status': 'REFUNDED',
                    'resolved_at': firestore.SERVER_TIMESTAMP,
                    'resolved_by': admin_id
                })

                tx_id_refund = str(uuid.uuid4())
                tx_refund_ref = payer_ref.collection('transactions').document(tx_id_refund)
                transaction.set(tx_refund_ref, {
                    'type': 'ESCROW_REFUND',
                    'amount': amount,
                    'desc': 'Dispute Resolved: Escrow Refunded',
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'job_id': job_id
                })

            elif resolution_action == 'pay_fundi':
                # Pay Fundi (Net Amount)
                fundi_ref = db.collection('users').document(fundi_id)
                fundi_doc = fundi_ref.get(transaction=transaction)
                fundi_balance = fundi_doc.to_dict().get('walletBalance', 0)

                transaction.update(fundi_ref, {
                    'walletBalance': fundi_balance + net_amount
                })

                transaction.update(job_ref, {
                    'status': 'Resolved - Paid',
                    'escrow_status': 'RELEASED',
                    'resolved_at': firestore.SERVER_TIMESTAMP,
                    'resolved_by': admin_id
                })

                tx_id_in = str(uuid.uuid4())
                tx_in_ref = fundi_ref.collection('transactions').document(tx_id_in)
                transaction.set(tx_in_ref, {
                    'type': 'ESCROW_RELEASED',
                    'amount': net_amount,
                    'desc': 'Dispute Resolved: Escrow Released to Fundi',
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'job_id': job_id,
                    'fee': fee
                })

                system_fee_ref = db.collection('system_revenue').document()
                transaction.set(system_fee_ref, {
                    'type': 'FUNDI_FEE',
                    'amount': fee,
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'job_id': job_id,
                    'fundi_id': fundi_id
                })

        process_resolution(transaction_ref)
        return jsonify({"status": "success", "message": f"Dispute resolved via {resolution_action}"}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@fundi_bp.route('/accept', methods=['POST'])
def accept_fundi_job():
    data = request.json
    if not data:
        return jsonify({"error": "No data provided"}), 400

    job_id = data.get('job_id')
    fundi_id = data.get('fundi_id')
    
    if not job_id or not fundi_id:
        return jsonify({"error": "Missing job_id or fundi_id"}), 400

    db = firestore.client()
    try:
        job_ref = db.collection('fundi_jobs').document(job_id)
        job_doc = job_ref.get()
        if not job_doc.exists:
            return jsonify({"error": "Job not found"}), 404
        
        job_data = job_doc.to_dict()
        if job_data.get('status') != 'Open':
            return jsonify({"error": "Job is no longer open"}), 400
            
        job_ref.update({
            'status': 'In Progress',
            'fundi_id': fundi_id,
            'accepted_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
