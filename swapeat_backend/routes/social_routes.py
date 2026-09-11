from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import datetime

social_bp = Blueprint('social', __name__)

@social_bp.route('/harambee/create', methods=['POST'])
def create_harambee():
    data = request.json
    student_id = data.get('studentId')
    title = data.get('title')
    goal_amount = float(data.get('goalAmount', 0))
    description = data.get('description', '')
    
    if not all([student_id, title, goal_amount > 0, description]):
        return jsonify({"error": "Missing parameters"}), 400

    db = firestore.client()
    campaign_ref = db.collection('harambee_campaigns').document()
    campaign_ref.set({
        'studentId': student_id,
        'title': title,
        'goalAmount': goal_amount,
        'description': description,
        'raised': 0.0,
        'donors': [],
        'status': 'active',
        'createdAt': firestore.SERVER_TIMESTAMP
    })
    
    # Generate Vercel sharing link
    share_link = f"https://dishi.delstarfordworks.co.ke/fund?campaign_id={campaign_ref.id}"
    
    return jsonify({"success": True, "campaignId": campaign_ref.id, "shareLink": share_link})

@social_bp.route('/harambee/donate', methods=['POST'])
def donate_harambee():
    data = request.json
    donor_id = data.get('donorId')
    campaign_id = data.get('campaignId')
    amount = float(data.get('amount', 0))
    donor_name = data.get('donorName', 'Anonymous')
    
    if not all([donor_id, campaign_id, amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    db = firestore.client()
    donor_ref = db.collection('users').document(donor_id)
    campaign_ref = db.collection('harambee_campaigns').document(campaign_id)
    
    commission = 3.0
    total_deduct = amount + commission

    @firestore.transactional
    def process_donation(transaction, d_ref, c_ref):
        donor_doc = d_ref.get(transaction=transaction)
        campaign_doc = c_ref.get(transaction=transaction)
        
        if not donor_doc.exists or not campaign_doc.exists:
            return False, "Donor or Campaign not found"
            
        current_balance = float(donor_doc.to_dict().get('walletBalance', 0))
        if current_balance < total_deduct:
            # Must exactly match the frontend string "Insufficient wallet balance"
            return False, "Insufficient wallet balance"
            
        recipient_id = campaign_doc.to_dict().get('studentId')
        recipient_ref = db.collection('users').document(recipient_id)
        
        # Deduct from donor
        transaction.update(d_ref, {'walletBalance': firestore.Increment(-total_deduct)})
        
        # Credit recipient
        transaction.update(recipient_ref, {'walletBalance': firestore.Increment(amount)})
        
        # System Commission
        admin_ref = db.collection('admin_finances').document('dishi_system_pool')
        transaction.set(admin_ref, {'system_commissions': firestore.Increment(commission)}, merge=True)
        
        # Update Campaign Donors
        donors = list(campaign_doc.to_dict().get('donors', []))
        donors.append({
            'name': donor_name,
            'amount': amount,
            'timestamp': datetime.datetime.utcnow()
        })
        donors.sort(key=lambda x: x['amount'], reverse=True)
        
        transaction.update(c_ref, {
            'raised': firestore.Increment(amount),
            'donors': donors
        })
        
        # Log Ledger
        ledger_ref = db.collection('wallet_ledger').document()
        transaction.set(ledger_ref, {
            'type': 'harambee_donation',
            'from_user': donor_id,
            'to_user': recipient_id,
            'campaign_id': campaign_id,
            'amount': amount,
            'commission': commission,
            'total_deducted': total_deduct,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        return True, "Donation successful!"

    tx = db.transaction()
    success, msg = process_donation(tx, donor_ref, campaign_ref)
    
    if not success:
        return jsonify({"error": msg}), 400
        
    return jsonify({"success": True, "message": msg})

@social_bp.route('/bounty/create', methods=['POST'])
def create_bounty():
    data = request.json
    student_id = data.get('studentId')
    item_name = data.get('itemName')
    bounty_amount = float(data.get('bountyAmount', 0))
    
    if not all([student_id, item_name, bounty_amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    db = firestore.client()
    student_ref = db.collection('users').document(student_id)
    
    if float(student_ref.get().to_dict().get('walletBalance', 0)) < bounty_amount:
        return jsonify({"error": "Insufficient funds to lock bounty"}), 400
        
    batch = db.batch()
    
    batch.update(student_ref, {'walletBalance': firestore.Increment(-bounty_amount)})
    
    bounty_ref = db.collection('bounties').document()
    batch.set(bounty_ref, {
        'studentId': student_id,
        'itemName': item_name,
        'bountyAmount': bounty_amount,
        'status': 'active',
        'createdAt': firestore.SERVER_TIMESTAMP
    })
    
    batch.commit()
    return jsonify({"success": True, "bountyId": bounty_ref.id})

@social_bp.route('/gigs/pay', methods=['POST'])
def pay_gig():
    data = request.json
    client_id = data.get('clientId')
    freelancer_id = data.get('freelancerId')
    amount = float(data.get('amount', 0))
    gig_title = data.get('gigTitle', 'Service')
    
    if not all([client_id, freelancer_id, amount > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    db = firestore.client()
    client_ref = db.collection('users').document(client_id)
    freelancer_ref = db.collection('users').document(freelancer_id)
    
    if float(client_ref.get().to_dict().get('walletBalance', 0)) < amount:
        return jsonify({"error": "Insufficient funds"}), 400
        
    batch = db.batch()
    batch.update(client_ref, {'walletBalance': firestore.Increment(-amount)})
    batch.update(freelancer_ref, {'walletBalance': firestore.Increment(amount)})
    
    tx_ref = db.collection('transactions').document()
    batch.set(tx_ref, {
        'clientId': client_id,
        'freelancerId': freelancer_id,
        'amount': amount,
        'gigTitle': gig_title,
        'type': 'gig_payment',
        'timestamp': firestore.SERVER_TIMESTAMP
    })
    
    batch.commit()
    return jsonify({"success": True, "message": "Payment sent!"})

@social_bp.route('/events/ticket/buy', methods=['POST'])
def buy_ticket():
    data = request.json
    student_id = data.get('studentId')
    event_id = data.get('eventId')
    price = float(data.get('price', 0))
    payment_method = data.get('paymentMethod', 'dishi') # dishi or mpesa
    
    if not all([student_id, event_id, price > 0]):
        return jsonify({"error": "Missing parameters"}), 400

    db = firestore.client()
    
    if payment_method == 'dishi':
        student_ref = db.collection('users').document(student_id)
        if float(student_ref.get().to_dict().get('walletBalance', 0)) < price:
            return jsonify({"error": "Insufficient DISHI funds"}), 400
            
        batch = db.batch()
        batch.update(student_ref, {'walletBalance': firestore.Increment(-price)})
        
        ticket_ref = db.collection('tickets').document()
        batch.set(ticket_ref, {
            'studentId': student_id,
            'eventId': event_id,
            'price': price,
            'status': 'valid',
            'purchasedAt': firestore.SERVER_TIMESTAMP
        })
        batch.commit()
        
        return jsonify({"success": True, "ticketId": ticket_ref.id, "message": "Ticket purchased with DISHI wallet!"})
    elif payment_method == 'mpesa':
        # Trigger STK Push (Assume STK push logic is handled in mpesa_routes, just return pending)
        return jsonify({"success": True, "message": "M-Pesa STK push sent to your phone. Enter PIN to receive ticket."})
    else:
        return jsonify({"error": "Invalid payment method"}), 400
