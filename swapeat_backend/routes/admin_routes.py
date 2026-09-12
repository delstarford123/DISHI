from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import os

admin_bp = Blueprint('admin', __name__)

def log_admin_action(admin_id, action_type, details):
    try:
        db = firestore.client()
        db.collection('admin_action_logs').add({
            'admin_id': admin_id,
            'action': action_type,
            'details': details,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
    except Exception as e:
        print(f"Failed to log admin action: {e}")

def verify_admin(req):
    auth_header = req.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        token = auth_header.split('Bearer ')[1]
        try:
            from firebase_admin import auth
            decoded = auth.verify_id_token(token)
            uid = decoded['uid']
            db = firestore.client()
            user_doc = db.collection('users').document(uid).get()
            if user_doc.exists and user_doc.to_dict().get('role') == 'admin':
                return uid
        except Exception as e:
            print(f"Admin auth error: {e}")
            
    # Fallback for scripts/cron
    admin_token = os.getenv('ADMIN_SECRET', 'swapeat-admin-2024')
    if auth_header == f"Bearer {admin_token}":
        return "SUPERADMIN_SCRIPT"
    return None

@admin_bp.route('/deliv/drivers', methods=['GET'])
def get_all_drivers():
    try:
        db = firestore.client()
        docs = db.collection('deliv_drivers').order_by('created_at', direction=firestore.Query.DESCENDING).get()
        drivers = [doc.to_dict() for doc in docs]
        # Serialize datetime
        for d in drivers:
            if 'created_at' in d and hasattr(d['created_at'], 'isoformat'):
                d['created_at'] = d['created_at'].isoformat()
            else:
                d['created_at'] = str(d.get('created_at'))
        return jsonify({"status": "success", "drivers": drivers}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/match/reports', methods=['GET'])
def get_match_reports():
    try:
        db = firestore.client()
        docs = db.collection('match_incident_reports').order_by('timestamp', direction=firestore.Query.DESCENDING).get()
        reports = [doc.to_dict() for doc in docs]
        for r in reports:
            if 'timestamp' in r and hasattr(r['timestamp'], 'isoformat'):
                r['timestamp'] = r['timestamp'].isoformat()
            else:
                r['timestamp'] = str(r.get('timestamp'))
        return jsonify({"status": "success", "reports": reports}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/match/unban', methods=['POST'])
def unban_match_user():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
    data = request.json or {}
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({"error": "Missing user_id"}), 400
        
    try:
        db = firestore.client()
        db.collection('match_profiles').document(user_id).update({'is_active': True})
        return jsonify({"status": "success", "message": "User unbanned"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
         
@admin_bp.route('/payout', methods=['POST'])
def process_payout():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
        
    data = request.json or {}
    vendor_id = data.get('vendorId')
    amount = data.get('amount')
    
    if not vendor_id or amount is None:
        return jsonify({"error": "Missing vendorId or amount"}), 400
        
    try:
        db = firestore.client()
        vendor_ref = db.collection('users').document(vendor_id)
        
        @firestore.transactional
        def update_in_transaction(transaction, v_ref):
            snapshot = v_ref.get(transaction=transaction)
            if not snapshot.exists:
                raise Exception("Vendor not found")
                
            current_earnings = snapshot.get('vendorEarnings') or 0
            if current_earnings < amount:
                raise Exception("Insufficient vendor earnings")
                
            transaction.update(v_ref, {
                'vendorEarnings': current_earnings - amount
            })
            
            # Log transaction
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'vendorId': vendor_id,
                'amount': -amount,
                'type': 'Admin Payout',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'completed',
                'destination': 'mpesa_b2c' # Tagged for potential Daraja B2C integration
            })

        transaction = db.transaction()
        update_in_transaction(transaction, vendor_ref)
        
        # NOTE: Real M-PESA B2C API call would go here using Daraja credentials.
        
        return jsonify({"status": "success", "message": "Payout processed successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/refund', methods=['POST'])
def process_refund():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
        
    data = request.json or {}
    tx_id = data.get('txId')
    
    if not tx_id:
        return jsonify({"error": "Missing txId"}), 400
        
    try:
        db = firestore.client()
        tx_ref = db.collection('transactions').document(tx_id)
        
        @firestore.transactional
        def refund_in_transaction(transaction, t_ref):
            snapshot = t_ref.get(transaction=transaction)
            if not snapshot.exists:
                raise Exception("Transaction not found")
                
            tx_data = snapshot.to_dict()
            if tx_data.get('status') == 'refunded':
                raise Exception("Transaction is already refunded")
                
            amount = tx_data.get('amount', 0)
            user_id = tx_data.get('user_id') or tx_data.get('studentId') or tx_data.get('uid')
            vendor_id = tx_data.get('vendor_id') or tx_data.get('vendorId')
            
            if not user_id or not vendor_id:
                raise Exception("Transaction missing user or vendor identifiers")
                
            student_ref = db.collection('users').document(user_id)
            vendor_ref = db.collection('users').document(vendor_id)
            
            # Reversing the flow: Add to student, deduct from vendor
            transaction.update(student_ref, {'walletBalance': firestore.Increment(amount)})
            transaction.update(vendor_ref, {'walletBalance': firestore.Increment(-amount)})
            
            # Mark original as refunded
            transaction.update(t_ref, {'status': 'refunded'})
            
            # Log the refund action
            refund_tx_ref = db.collection('transactions').document()
            transaction.set(refund_tx_ref, {
                'originalTxId': tx_id,
                'user_id': user_id,
                'vendorId': vendor_id,
                'amount': amount,
                'type': 'Refund',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'completed'
            })
            
        transaction = db.transaction()
        refund_in_transaction(transaction, tx_ref)
        
        return jsonify({"status": "success", "message": f"Transaction {tx_id} refunded"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/adjust_wallet', methods=['POST'])
def adjust_wallet():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
        
    data = request.json or {}
    user_id = data.get('userId')
    amount = data.get('amount')
    
    if not user_id or amount is None:
        return jsonify({"error": "Missing userId or amount"}), 400
        
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        
        @firestore.transactional
        def adjust_in_transaction(transaction, u_ref):
            snapshot = u_ref.get(transaction=transaction)
            if not snapshot.exists:
                raise Exception("User not found")
                
            transaction.update(u_ref, {'walletBalance': firestore.Increment(amount)})
            
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'user_id': user_id,
                'amount': amount,
                'type': 'Admin Adjustment',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'completed',
                'destination': 'wallet'
            })
            
        transaction = db.transaction()
        adjust_in_transaction(transaction, user_ref)
        
        return jsonify({"status": "success", "message": f"Wallet adjusted by {amount}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/link_nfc', methods=['POST'])
def link_nfc():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
        
    data = request.json or {}
    user_id = data.get('userId')
    nfc_uid = data.get('nfcUid')
    
    if not user_id or not nfc_uid:
        return jsonify({"error": "Missing userId or nfcUid"}), 400
        
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        user_ref.set({'nfcUid': nfc_uid}, merge=True)
        return jsonify({"status": "success", "message": "NFC Linked successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@admin_bp.route('/users/<user_id>/suspend', methods=['POST'])
def suspend_user(user_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        from firebase_admin import auth
        data = request.json or {}
        reason = data.get('reason', 'Violation of terms')
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        if not user_ref.get().exists:
            return jsonify({'error': 'User not found'}), 404
            
        try:
            auth.update_user(user_id, disabled=True)
            auth.revoke_refresh_tokens(user_id)
        except Exception as e:
            print(f"Error disabling auth for {user_id}: {e}")

        user_ref.update({
            'status': 'suspended',
            'suspension_reason': reason,
            'suspended_at': firestore.SERVER_TIMESTAMP
        })
        log_admin_action(admin_id, 'suspend_user', {'target_user_id': user_id, 'reason': reason})
        return jsonify({'message': f'User suspended successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/users/<user_id>/delete', methods=['DELETE'])
def delete_user(user_id):
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
    try:
        from firebase_admin import auth
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        if not user_ref.get().exists:
            return jsonify({'error': 'User not found'}), 404
        try:
            auth.delete_user(user_id)
        except Exception as e:
            print(f"Error deleting from auth: {e}")
        user_ref.delete()
        return jsonify({'message': f'User deleted successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/users/<user_id>/impersonate', methods=['POST'])
def impersonate_user(user_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        from firebase_admin import auth
        custom_token = auth.create_custom_token(user_id)
        token_str = custom_token.decode('utf-8') if isinstance(custom_token, bytes) else custom_token
        log_admin_action(admin_id, 'ghost_login', {'target_user_id': user_id})
        return jsonify({'token': token_str}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/disputes/<dispute_id>/resolve', methods=['POST'])
def resolve_dispute(dispute_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        action = data.get('action') # 'refund_student' or 'release_to_vendor'
        db = firestore.client()
        
        dispute_ref = db.collection('disputes').document(dispute_id)
        dispute_doc = dispute_ref.get()
        if not dispute_doc.exists:
            return jsonify({'error': 'Dispute not found'}), 404
            
        dispute_data = dispute_doc.to_dict()
        if dispute_data.get('status') == 'resolved':
            return jsonify({'error': 'Dispute already resolved'}), 400
            
        student_id = dispute_data.get('student_id')
        vendor_id = dispute_data.get('vendor_id')
        amount = dispute_data.get('amount', 0)
        
        @firestore.transactional
        def resolve_in_transaction(transaction, disp_ref):
            student_ref = db.collection('users').document(student_id)
            vendor_ref = db.collection('users').document(vendor_id)
            
            if action == 'refund_student':
                transaction.update(student_ref, {'walletBalance': firestore.Increment(amount)})
                tx_ref = db.collection('transactions').document()
                transaction.set(tx_ref, {
                    'student_id': student_id,
                    'vendor_id': vendor_id,
                    'amount': amount,
                    'type': 'Dispute Refund',
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'status': 'completed',
                    'dispute_id': dispute_id
                })
            elif action == 'release_to_vendor':
                transaction.update(vendor_ref, {'walletBalance': firestore.Increment(amount)})
                tx_ref = db.collection('transactions').document()
                transaction.set(tx_ref, {
                    'student_id': student_id,
                    'vendor_id': vendor_id,
                    'amount': amount,
                    'type': 'Dispute Released',
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'status': 'completed',
                    'dispute_id': dispute_id
                })
            else:
                raise Exception("Invalid action")
                
            transaction.update(disp_ref, {
                'status': 'resolved',
                'resolution_action': action,
                'resolved_at': firestore.SERVER_TIMESTAMP
            })
            
        transaction = db.transaction()
        resolve_in_transaction(transaction, dispute_ref)
        
        log_admin_action(admin_id, 'resolve_dispute', {'dispute_id': dispute_id, 'action': action})
        return jsonify({'message': f'Dispute resolved: {action}'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/events/<event_id>/override', methods=['POST'])
def override_event(event_id):
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        make_free = data.get('make_free', False)
        db = firestore.client()
        event_ref = db.collection('events').document(event_id)
        if not event_ref.get().exists:
            event_ref = db.collection('social_events').document(event_id)
        if not event_ref.get().exists:
            return jsonify({'error': 'Event not found'}), 404
            
        updates = {}
        if make_free:
            updates['price'] = 0
            updates['isFree'] = True
            
        if updates:
            event_ref.update(updates)
        return jsonify({'message': f'Event overridden successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/platform/maintenance', methods=['POST'])
def toggle_maintenance():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        enable = data.get('enable', True)
        db = firestore.client()
        settings_ref = db.collection('system_settings').document('platform_config')
        if not settings_ref.get().exists:
            settings_ref.set({'maintenance_mode': enable})
        else:
            settings_ref.update({'maintenance_mode': enable})
        status = "enabled" if enable else "disabled"
        return jsonify({'message': f'Maintenance mode {status}'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/settings/commission', methods=['GET', 'POST'])
def manage_commission():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        settings_ref = db.collection('system_settings').document('fees')
        if request.method == 'GET':
            doc = settings_ref.get()
            if not doc.exists:
                return jsonify({'platform_commission': 5.0}), 200
            return jsonify({'platform_commission': doc.to_dict().get('platform_commission', 5.0)}), 200
        else:
            data = request.json or {}
            new_rate = data.get('platform_commission')
            if new_rate is None:
                return jsonify({'error': 'platform_commission is required'}), 400
            if not settings_ref.get().exists:
                settings_ref.set({'platform_commission': float(new_rate), 'last_updated': firestore.SERVER_TIMESTAMP})
            else:
                settings_ref.update({'platform_commission': float(new_rate), 'last_updated': firestore.SERVER_TIMESTAMP})
            log_admin_action(admin_id, 'update_commission', {'new_rate': float(new_rate)})
            return jsonify({'message': 'Commission rate updated successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/harambee/<campaign_id>/force_action', methods=['POST'])
def force_harambee_action(campaign_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        action = data.get('action') # 'pause', 'cancel_and_refund', 'release_funds'
        db = firestore.client()
        campaign_ref = db.collection('harambees').document(campaign_id)
        doc = campaign_ref.get()
        if not doc.exists:
            return jsonify({'error': 'Campaign not found'}), 404
            
        campaign_data = doc.to_dict()
        
        if action == 'pause':
            campaign_ref.update({'status': 'paused'})
            log_admin_action(admin_id, 'harambee_action', {'campaign_id': campaign_id, 'action': 'pause'})
            return jsonify({'message': 'Campaign paused'}), 200
            
        elif action == 'cancel_and_refund':
            donations = db.collection('harambees').document(campaign_id).collection('donations').stream()
            batch = db.batch()
            for donation in donations:
                d_data = donation.to_dict()
                donor_id = d_data.get('donor_id')
                amount = d_data.get('amount', 0)
                if donor_id and amount > 0:
                    donor_ref = db.collection('users').document(donor_id)
                    batch.update(donor_ref, {'walletBalance': firestore.Increment(amount)})
                    tx_ref = db.collection('transactions').document()
                    batch.set(tx_ref, {
                        'student_id': donor_id,
                        'amount': amount,
                        'type': 'Harambee Refund',
                        'timestamp': firestore.SERVER_TIMESTAMP,
                        'status': 'completed',
                        'campaign_id': campaign_id
                    })
            batch.update(campaign_ref, {'status': 'cancelled'})
            batch.commit()
            log_admin_action(admin_id, 'harambee_action', {'campaign_id': campaign_id, 'action': 'cancel_and_refund'})
            return jsonify({'message': 'Campaign cancelled and donors refunded'}), 200
            
        elif action == 'release_funds':
            organizer_id = campaign_data.get('organizer_id')
            raised = campaign_data.get('raised_amount', 0)
            if organizer_id and raised > 0:
                organizer_ref = db.collection('users').document(organizer_id)
                organizer_ref.update({'walletBalance': firestore.Increment(raised)})
                campaign_ref.update({'status': 'completed'})
                log_admin_action(admin_id, 'harambee_action', {'campaign_id': campaign_id, 'action': 'release_funds'})
                return jsonify({'message': 'Funds released to organizer'}), 200
            return jsonify({'error': 'Invalid organizer or zero funds'}), 400
        else:
            return jsonify({'error': 'Invalid action'}), 400
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/payouts/force_trigger', methods=['POST'])
def force_trigger_payouts():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        log_admin_action(admin_id, 'trigger_payouts', {})
        # In a real environment, this would call the same logic as the 70-min cron job.
        # For now, we will simulate the backend logic.
        return jsonify({'message': 'Manual payouts triggered successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/fraud_flags', methods=['GET'])
def get_fraud_flags():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(100).get()
        user_counts = {}
        for d in docs:
            tx = d.to_dict()
            uid = tx.get('user_id') or tx.get('student_id') or tx.get('vendor_id') or 'unknown'
            if uid != 'unknown':
                user_counts[uid] = user_counts.get(uid, 0) + 1
        
        flags = []
        for uid, count in user_counts.items():
            if count >= 3:
                flags.append({'user_id': uid, 'recent_tx_count': count, 'reason': 'High transaction velocity in recent history'})
                
        return jsonify({'flags': flags}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/audit_logs', methods=['GET'])
def get_audit_logs():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('admin_action_logs').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(50).get()
        logs = []
        for d in docs:
            log_data = d.to_dict()
            if 'timestamp' in log_data and hasattr(log_data['timestamp'], 'isoformat'):
                log_data['timestamp'] = log_data['timestamp'].isoformat()
            else:
                log_data['timestamp'] = str(log_data.get('timestamp'))
            log_data['id'] = d.id
            logs.append(log_data)
            
        return jsonify({'logs': logs}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/analytics/system_overview', methods=['GET'])
def system_overview():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        users_docs = db.collection('users').get()
        total_users = len(users_docs)
        total_vendors = sum(1 for d in users_docs if d.to_dict().get('role') == 'vendor')
        
        tx_docs = db.collection('transactions').get()
        total_transactions = len(tx_docs)
        total_revenue = sum(d.to_dict().get('amount', 0) for d in tx_docs if d.to_dict().get('type') == 'commission')
        
        return jsonify({
            'total_users': total_users,
            'active_users': total_users,
            'total_revenue': total_revenue,
            'total_vendors': total_vendors,
            'total_transactions': total_transactions
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/housing/pending', methods=['GET'])
def get_pending_housing():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('housing_properties').where('status', '==', 'pending').get()
        properties = [ {**d.to_dict(), 'id': d.id} for d in docs ]
        return jsonify({'properties': properties}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/housing/<action>/<property_id>', methods=['POST'])
def moderate_housing(action, property_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    if action not in ['approve', 'reject']:
        return jsonify({"error": "Invalid action"}), 400
    
    try:
        db = firestore.client()
        doc_ref = db.collection('housing_properties').document(property_id)
        if not doc_ref.get().exists:
            return jsonify({'error': 'Property not found'}), 404
            
        status = 'approved' if action == 'approve' else 'rejected'
        doc_ref.update({'status': status})
        log_admin_action(admin_id, f"{action.capitalize()} Housing Property", f"Property ID: {property_id} has been {status}")
        return jsonify({'message': f'Property {status}'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/housing/approve_all', methods=['POST'])
def approve_all_housing():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('housing_properties').where('status', '==', 'pending').get()
        count = 0
        batch = db.batch()
        for d in docs:
            batch.update(d.reference, {'status': 'approved'})
            count += 1
            if count % 400 == 0:
                batch.commit()
                batch = db.batch()
                
        if count > 0:
            batch.commit()
            log_admin_action(admin_id, "Bulk Approve Housing", f"{count} properties were automatically approved.")
            
            # Send Email
            try:
                from flask_mail import Mail, Message
                from flask import current_app
                mail = Mail(current_app)
                msg = Message("Admin Action: Bulk Housing Approval", sender="info@delstarfordworks.co.ke", recipients=["info@delstarfordworks.co.ke"])
                msg.body = f"{count} housing properties were approved by admin {admin_id}."
                mail.send(msg)
            except Exception as e:
                print(f"Failed to send email: {e}")
                
        return jsonify({'message': f'{count} properties approved.'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/notifications/broadcast', methods=['POST'])
def broadcast_notification():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.get_json()
        title = data.get('title')
        message = data.get('message')
        target_user_id = data.get('targetUserId')
        
        if not title or not message:
            return jsonify({'error': 'Title and message required'}), 400
            
        from firebase_admin import messaging
        if target_user_id:
            msg = messaging.Message(notification=messaging.Notification(title=title, body=message), topic=target_user_id)
            log_admin_action(admin_id, "Send Direct Notification", f"Target: {target_user_id}, Title: {title}")
        else:
            msg = messaging.Message(notification=messaging.Notification(title=title, body=message), topic='all_users')
            log_admin_action(admin_id, "Send Broadcast Notification", f"Title: {title}")
            
        response = messaging.send(msg)
        return jsonify({'message': 'Notification sent', 'response': response}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/transactions/rich', methods=['GET'])
def get_rich_transactions():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        tx_docs = db.collection('transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(100).get()
        
        rich_txs = []
        user_cache = {}
        
        def get_user_data(uid):
            if not uid: return None
            if uid in user_cache: return user_cache[uid]
            doc = db.collection('users').document(uid).get()
            if doc.exists:
                data = doc.to_dict()
                user_cache[uid] = {
                    'name': data.get('displayName', 'Unknown'),
                    'email': data.get('email', 'N/A'),
                    'phone': data.get('phoneNumber', 'N/A'),
                    'image': data.get('profile_pic', '') or data.get('photoURL', '')
                }
            else:
                user_cache[uid] = {'name': 'Unknown', 'email': 'N/A', 'phone': 'N/A', 'image': ''}
            return user_cache[uid]
            
        for d in tx_docs:
            tx = d.to_dict()
            tx['id'] = d.id
            if 'timestamp' in tx and hasattr(tx['timestamp'], 'isoformat'):
                tx['timestamp'] = tx['timestamp'].isoformat()
            else:
                tx['timestamp'] = str(tx.get('timestamp'))
                
            tx['student_data'] = get_user_data(tx.get('student_id') or tx.get('uid'))
            tx['vendor_data'] = get_user_data(tx.get('vendor_id'))
            rich_txs.append(tx)
            
        return jsonify({'transactions': rich_txs}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==========================================
# PHASE 5: COMMAND CENTER ENDPOINTS
# ==========================================

# 1. Financial Operations & Payout Management
@admin_bp.route('/payouts/failed', methods=['GET'])
def get_failed_payouts():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('mpesa_transactions').where('status', '==', 'failed').get()
        return jsonify({'payouts': [{**d.to_dict(), 'id': d.id} for d in docs]}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/payouts/retry/<tx_id>', methods=['POST'])
def retry_failed_payout(tx_id):
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        doc_ref = db.collection('mpesa_transactions').document(tx_id)
        if not doc_ref.get().exists: return jsonify({'error': 'Not found'}), 404
        # Mark as pending to allow backend cron to pick it up again
        doc_ref.update({'status': 'pending', 'retry_count': firestore.Increment(1)})
        log_admin_action(admin_id, "Retry Payout", f"Retried failed payout {tx_id}")
        return jsonify({'message': 'Payout queued for retry'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/escrow/summary', methods=['GET'])
def get_escrow_summary():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        tuition_docs = db.collection('tuition_escrow').where('status', '==', 'locked').get()
        housing_docs = db.collection('housing_payments').where('status', '==', 'escrow').get()
        tuition_total = sum(d.to_dict().get('amount', 0) for d in tuition_docs)
        housing_total = sum(d.to_dict().get('amount', 0) for d in housing_docs)
        return jsonify({'tuition_escrow': tuition_total, 'housing_escrow': housing_total, 'total_escrow': tuition_total + housing_total}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 2. Helpdesk & Support Ticket Center
@admin_bp.route('/tickets/active', methods=['GET'])
def get_active_tickets():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('support_tickets').where('status', '!=', 'closed').get()
        return jsonify({'tickets': [{**d.to_dict(), 'id': d.id} for d in docs]}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/tickets/<ticket_id>/close', methods=['POST'])
def close_ticket(ticket_id):
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        doc_ref = db.collection('support_tickets').document(ticket_id)
        doc = doc_ref.get()
        if not doc.exists: return jsonify({'error': 'Not found'}), 404
        data = request.get_json() or {}
        resolution = data.get('resolution', 'Resolved by Admin')
        doc_ref.update({'status': 'closed', 'resolution': resolution, 'closed_at': firestore.SERVER_TIMESTAMP})
        log_admin_action(admin_id, "Close Ticket", f"Closed ticket {ticket_id}")
        
        user_id = doc.to_dict().get('user_id')
        if user_id:
            from firebase_admin import messaging
            try:
                messaging.send(messaging.Message(notification=messaging.Notification(title="Support Ticket Closed", body=f"Your ticket has been closed: {resolution}"), topic=user_id))
            except: pass
            
        return jsonify({'message': 'Ticket closed'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 3. Community & Content Moderation Queue
@admin_bp.route('/moderation/incidents', methods=['GET'])
def get_moderation_incidents():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('match_incident_reports').where('status', '==', 'pending').get()
        return jsonify({'incidents': [{**d.to_dict(), 'id': d.id} for d in docs]}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/moderation/action', methods=['POST'])
def moderate_action():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.get_json()
        incident_id = data.get('incident_id')
        action = data.get('action') # 'warn', 'shadow_ban', 'delete_post', 'dismiss'
        db = firestore.client()
        doc_ref = db.collection('match_incident_reports').document(incident_id)
        
        if not doc_ref.get().exists: return jsonify({'error': 'Not found'}), 404
        
        # We assume action execution logic lives in frontend or here. For now just mark resolved
        doc_ref.update({'status': 'resolved', 'resolution_action': action})
        log_admin_action(admin_id, "Moderation Action", f"Incident {incident_id} resolved with {action}")
        return jsonify({'message': 'Action applied successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 4. System Configuration & Feature Flags
@admin_bp.route('/config', methods=['GET'])
def get_system_config():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('feature_flags').get()
        flags = {d.id: d.to_dict() for d in docs}
        return jsonify({'feature_flags': flags}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/config/toggle', methods=['POST'])
def toggle_config():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.get_json()
        flag_id = data.get('flag_id')
        enabled = data.get('enabled', False)
        db = firestore.client()
        db.collection('feature_flags').document(flag_id).set({'enabled': enabled}, merge=True)
        log_admin_action(admin_id, "Toggle Feature Flag", f"Set {flag_id} to {enabled}")
        return jsonify({'message': f'Flag {flag_id} updated to {enabled}'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 5. Vendor & Fundi Onboarding
@admin_bp.route('/onboarding/pending', methods=['GET'])
def get_pending_onboarding():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        vendors = db.collection('vendors').where('status', '==', 'pending').get()
        fundis = db.collection('fundi_profiles').where('status', '==', 'pending').get()
        
        v_list = [{**d.to_dict(), 'id': d.id, 'type': 'vendor'} for d in vendors]
        f_list = [{**d.to_dict(), 'id': d.id, 'type': 'fundi'} for d in fundis]
        return jsonify({'onboarding': v_list + f_list}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/onboarding/<user_type>/<user_id>/approve', methods=['POST'])
def approve_onboarding(user_type, user_id):
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        col = 'vendors' if user_type == 'vendor' else 'fundi_profiles'
        doc_ref = db.collection(col).document(user_id)
        if not doc_ref.get().exists: return jsonify({'error': 'Not found'}), 404
        
        doc_ref.update({'status': 'approved'})
        log_admin_action(admin_id, "Approve Onboarding", f"Approved {user_type} {user_id}")
        
        from firebase_admin import messaging
        try:
            messaging.send(messaging.Message(notification=messaging.Notification(title="Application Approved!", body=f"Your {user_type} account has been verified."), topic=user_id))
        except: pass
        
        return jsonify({'message': f'{user_type.capitalize()} approved'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 6. Delivery Security
@admin_bp.route('/delivery/drivers', methods=['GET'])
def get_delivery_drivers():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        drivers = db.collection('deliv_drivers').get()
        return jsonify({'drivers': [d.to_dict() for d in drivers]}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/delivery/driver/<user_id>/verify', methods=['POST'])
def verify_delivery_driver(user_id):
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        db.collection('deliv_drivers').document(user_id).update({
            'status': 'free',
            'is_available': True
        })
        log_admin_action(admin_id, "Approve Driver", f"Verified driver {user_id}")
        return jsonify({'message': 'Driver verified successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/delivery/driver/<user_id>/suspend', methods=['POST'])
def suspend_delivery_driver(user_id):
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        db.collection('deliv_drivers').document(user_id).update({
            'status': 'suspended',
            'is_available': False
        })
        log_admin_action(admin_id, "Suspend Driver", f"Suspended driver {user_id}")
        return jsonify({'message': 'Driver suspended successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/delivery/active_rides', methods=['GET'])
def get_active_rides():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        rides = db.collection('deliv_requests').where('status', 'in', ['pending', 'accepted']).get()
        return jsonify({'rides': [r.to_dict() for r in rides]}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/delivery/online_drivers', methods=['GET'])
def get_online_drivers():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        drivers = db.collection('deliv_drivers').where('isOnline', '==', True).where('status', 'in', ['free', 'busy']).get()
        return jsonify({'drivers': [d.to_dict() for d in drivers]}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/delivery/manual_dispatch', methods=['POST'])
def manual_dispatch_delivery():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.get_json()
        request_id = data.get('request_id')
        driver_id = data.get('driver_id')
        
        db = firestore.client()
        req_ref = db.collection('deliv_requests').document(request_id)
        
        req_ref.update({
            'status': 'accepted',
            'driver_id': driver_id,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        
        log_admin_action(admin_id, "Manual Dispatch", f"Assigned request {request_id} to driver {driver_id}")
        
        # Notify the driver
        from firebase_admin import messaging
        try:
            messaging.send(messaging.Message(
                notification=messaging.Notification(title="New Gig Assigned!", body="An admin has dispatched a delivery to you."),
                topic=driver_id
            ))
        except: pass
        
        return jsonify({'message': 'Dispatched successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/delivery/notify_party', methods=['POST'])
def notify_delivery_party():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.get_json()
        target_id = data.get('target_id')
        title = data.get('title', 'Admin Alert')
        message = data.get('message', 'Please check your delivery status.')
        
        from firebase_admin import messaging
        messaging.send(messaging.Message(
            notification=messaging.Notification(title=title, body=message),
            topic=target_id
        ))
        
        return jsonify({'message': 'Notification sent successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
