from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import os
import uuid
import datetime

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
            if user_doc.exists:
                u_data = user_doc.to_dict() or {}
                if (u_data.get('role') == 'admin' or 
                    'admin' in u_data.get('roles', []) or 
                    u_data.get('isAdmin') is True or
                    decoded.get('admin') is True):
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

@admin_bp.route('/users/<user_id>/unsuspend', methods=['POST'])
def unsuspend_user(user_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        from firebase_admin import auth
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        if not user_ref.get().exists:
            return jsonify({'error': 'User not found'}), 404

        try:
            auth.update_user(user_id, disabled=False)
        except Exception as e:
            print(f"Error enabling auth for {user_id}: {e}")

        user_ref.update({
            'status': 'active',
            'suspension_reason': firestore.DELETE_FIELD,
            'unsuspended_at': firestore.SERVER_TIMESTAMP,
            'unsuspended_by': admin_id
        })
        log_admin_action(admin_id, 'unsuspend_user', {'target_user_id': user_id})
        return jsonify({'message': 'User reactivated successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/users/<user_id>/role', methods=['POST'])
def update_user_role(user_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        new_role = data.get('role', '').lower().strip()
        allowed_roles = ['student', 'vendor', 'admin', 'driver', 'caretaker', 'fundi', 'parent']
        if new_role not in allowed_roles:
            return jsonify({'error': f'Invalid role. Allowed: {", ".join(allowed_roles)}'}), 400

        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        u_doc = user_ref.get()
        if not u_doc.exists:
            return jsonify({'error': 'User not found'}), 404

        u_data = u_doc.to_dict() or {}
        roles = list(set((u_data.get('roles') or []) + [new_role]))

        user_ref.update({
            'role': new_role,
            'roles': roles,
            'isAdmin': True if new_role == 'admin' else u_data.get('isAdmin', False),
            'role_updated_at': firestore.SERVER_TIMESTAMP,
            'role_updated_by': admin_id
        })

        # Set custom claims in Firebase Auth if needed
        try:
            from firebase_admin import auth
            auth.set_custom_user_claims(user_id, {'admin': (new_role == 'admin'), 'role': new_role})
        except Exception as e:
            print(f"Error setting custom claims for {user_id}: {e}")

        log_admin_action(admin_id, 'update_user_role', {'target_user_id': user_id, 'new_role': new_role})
        return jsonify({'message': f'User role updated to {new_role}', 'role': new_role, 'roles': roles}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/users/<user_id>/reset_pin', methods=['POST'])
def reset_user_pin(user_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        if not user_ref.get().exists:
            return jsonify({'error': 'User not found'}), 404

        user_ref.update({
            'force_pin_reset': True,
            'pin_failed_attempts': 0,
            'pin_locked_until': firestore.DELETE_FIELD,
            'pin_reset_by': admin_id,
            'pin_reset_at': firestore.SERVER_TIMESTAMP
        })
        log_admin_action(admin_id, 'reset_user_pin', {'target_user_id': user_id})
        return jsonify({'message': f'Security PIN reset triggered for user'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/users/<user_id>/adjust_balance', methods=['POST'])
def adjust_user_balance(user_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        amount = data.get('amount')
        reason = data.get('reason', 'Admin balance correction')
        if amount is None or not isinstance(amount, (int, float)):
            return jsonify({'error': 'Valid amount number required'}), 400

        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        
        @firestore.transactional
        def adjust_tx(transaction, u_ref):
            snap = u_ref.get(transaction=transaction)
            if not snap.exists:
                raise Exception("User not found")
            current = float(snap.to_dict().get('walletBalance', 0))
            new_bal = current + float(amount)
            if new_bal < 0:
                raise Exception(f"Balance cannot become negative (current: {current}, adjustment: {amount})")
            transaction.update(u_ref, {'walletBalance': new_bal})

            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'user_id': user_id,
                'uid': user_id,
                'amount': abs(float(amount)),
                'type': 'Admin Credit' if float(amount) >= 0 else 'Admin Debit',
                'description': f'Admin adjustment: {reason}',
                'reason': reason,
                'admin_id': admin_id,
                'previous_balance': current,
                'new_balance': new_bal,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'status': 'completed'
            })
            return new_bal

        tx = db.transaction()
        new_balance = adjust_tx(tx, user_ref)
        log_admin_action(admin_id, 'adjust_balance', {'target_user_id': user_id, 'amount': amount, 'reason': reason, 'new_balance': new_balance})
        return jsonify({'message': f'Wallet adjusted by {amount}. New balance: {new_balance}', 'new_balance': new_balance}), 200
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
        from routes.v4.fraud_monitor_routes import get_all_fraud_flags
        return get_all_fraud_flags()
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

@admin_bp.route('/analytics/dashboard_stats', methods=['GET'])
def dashboard_stats():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        # Use aggregation queries for performance
        users_count = db.collection('users').count().get()[0][0].value
        vendors_count = db.collection('users').where('role', '==', 'vendor').count().get()[0][0].value
        float_sum = db.collection('users').aggregate(firestore.Sum('walletBalance')).get()[0][0].value
        return jsonify({
            'usersCount': users_count,
            'vendorsCount': vendors_count,
            'floatSum': float_sum,
            'flaggedTransactions': 0
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/users/all', methods=['GET'])
def get_all_users():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('users').get()
        users = []
        for d in docs:
            user_data = d.to_dict()
            user_data['uid'] = d.id
            users.append(user_data)
        return jsonify({'users': users}), 200
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
                admin_email = current_app.config.get('MAIL_USERNAME', 'dishi@delstarfordworks.co.ke')
                msg = Message("Admin Action: Bulk Housing Approval", sender=admin_email, recipients=[admin_email])
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
            
        db = firestore.client()
        # Save to Firestore 'notifications' collection so Flutter real-time stream displays it immediately
        notif_doc = {
            'title': title,
            'message': message,
            'body': message,
            'targetUserId': target_user_id if target_user_id else None,
            'type': 'broadcast' if not target_user_id else 'direct',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'created_at': datetime.datetime.utcnow().isoformat(),
            'readBy': [],
            'dismissedBy': [],
            'senderId': admin_id,
            'senderRole': 'admin'
        }
        db.collection('notifications').add(notif_doc)

        from firebase_admin import messaging
        response_msg = "Saved to Firestore"
        try:
            if target_user_id:
                msg = messaging.Message(notification=messaging.Notification(title=title, body=message), topic=target_user_id)
                log_admin_action(admin_id, "Send Direct Notification", f"Target: {target_user_id}, Title: {title}")
            else:
                msg = messaging.Message(notification=messaging.Notification(title=title, body=message), topic='all_users')
                log_admin_action(admin_id, "Send Broadcast Notification", f"Title: {title}")
            response_msg = messaging.send(msg)
        except Exception as fcm_err:
            print(f"FCM messaging send warning: {fcm_err}")

        return jsonify({'message': 'Notification sent and saved', 'response': str(response_msg)}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/profile', methods=['GET', 'POST'])
def manage_admin_profile():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    
    db = firestore.client()
    user_ref = db.collection('users').document(admin_id)
    
    if request.method == 'GET':
        doc = user_ref.get()
        if not doc.exists:
            return jsonify({"status": "error", "message": "Admin user profile not found"}), 404
        data = doc.to_dict() or {}
        return jsonify({
            "status": "success",
            "profile": {
                "uid": admin_id,
                "name": data.get('displayName') or data.get('name') or "Super Admin",
                "email": data.get('email') or "",
                "profileImageUrl": data.get('profileImageUrl') or data.get('photoUrl') or "",
                "role": data.get('role', 'admin'),
                "phone": data.get('phoneNumber') or data.get('phone') or "",
                "last_active": datetime.datetime.utcnow().isoformat()
            }
        }), 200

    # POST: Update profile
    try:
        data = request.get_json() or {}
        updates = {}
        if 'name' in data and data['name']:
            updates['name'] = str(data['name']).strip()
            updates['displayName'] = str(data['name']).strip()
        if 'email' in data and data['email']:
            updates['email'] = str(data['email']).strip().lower()
        if 'profileImageUrl' in data and data['profileImageUrl']:
            img_url = str(data['profileImageUrl']).strip()
            updates['profileImageUrl'] = img_url
            updates['photoUrl'] = img_url
            updates['photoURL'] = img_url
            updates['avatarUrl'] = img_url
        if 'phone' in data and data['phone']:
            updates['phoneNumber'] = str(data['phone']).strip()
            updates['phone'] = str(data['phone']).strip()

        updates['updatedAt'] = firestore.SERVER_TIMESTAMP

        user_ref.set(updates, merge=True)

        # Also update FirebaseAuth displayName/photoURL if possible
        try:
            from firebase_admin import auth
            auth_updates = {}
            if 'displayName' in updates:
                auth_updates['display_name'] = updates['displayName']
            if 'profileImageUrl' in updates:
                auth_updates['photo_url'] = updates['profileImageUrl']
            if 'email' in updates:
                auth_updates['email'] = updates['email']
            if auth_updates:
                auth.update_user(admin_id, **auth_updates)
        except Exception as auth_err:
            print(f"Auth user update warning: {auth_err}")

        log_admin_action(admin_id, "Update Admin Profile", f"Fields: {list(updates.keys())}")
        return jsonify({
            "status": "success",
            "message": "Admin profile updated successfully",
            "updates": {k: v for k, v in updates.items() if k != 'updatedAt'}
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

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
        gig_docs = db.collection('campus_gig_requests').where('escrow_status', '==', 'HELD').get()
        
        tuition_total = sum(d.to_dict().get('amount', 0) for d in tuition_docs)
        housing_total = sum(d.to_dict().get('amount', 0) for d in housing_docs)
        gig_total = sum(d.to_dict().get('net_amount', 0) + d.to_dict().get('fee_deducted', 0) for d in gig_docs)
        
        return jsonify({
            'tuition_escrow': tuition_total, 
            'housing_escrow': housing_total, 
            'gig_escrow': gig_total,
            'total_escrow': tuition_total + housing_total + gig_total
        }), 200
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

@admin_bp.route('/tickets/gig/refund', methods=['POST'])
def refund_gig_ticket():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.get_json() or {}
        request_id = data.get('request_id')
        if not request_id: return jsonify({'error': 'Missing request_id'}), 400
        
        db = firestore.client()
        transaction_ref = db.transaction()
        req_ref = db.collection('campus_gig_requests').document(request_id)
        
        @firestore.transactional
        def process_gig_refund(transaction):
            req_doc = req_ref.get(transaction=transaction)
            if not req_doc.exists: raise Exception("Gig not found")
            req_data = req_doc.to_dict()
            if req_data.get('escrow_status') != 'HELD': raise Exception("Gig is not in Escrow")
            
            requester_id = req_data.get('requester_id')
            net_amount = req_data.get('net_amount', 0)
            fee = req_data.get('fee_deducted', 0)
            total_refund = net_amount + fee
            
            user_ref = db.collection('users').document(requester_id)
            user_doc = user_ref.get(transaction=transaction)
            if not user_doc.exists: raise Exception("Requester not found")
            
            user_balance = float(user_doc.to_dict().get('walletBalance', 0))
            transaction.update(user_ref, {'walletBalance': user_balance + total_refund})
            
            transaction.update(req_ref, {
                'status': 'cancelled',
                'escrow_status': 'REFUNDED_BY_ADMIN',
                'cancelled_at': firestore.SERVER_TIMESTAMP
            })
            
            tx_id = str(uuid.uuid4())
            tx_ref = user_ref.collection('transactions').document(tx_id)
            transaction.set(tx_ref, {
                'type': 'ESCROW_REFUND',
                'amount': total_refund,
                'desc': 'Admin Refunded Campus Gig',
                'timestamp': firestore.SERVER_TIMESTAMP,
                'request_id': request_id
            })
            
        process_gig_refund(transaction_ref)
        log_admin_action(admin_id, "Refund Gig Escrow", f"Refunded gig {request_id}")
        return jsonify({'message': 'Gig escrow refunded successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/tickets/gig/suspend_worker', methods=['POST'])
def suspend_gig_worker():
    admin_id = verify_admin(request)
    if not admin_id: return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.get_json() or {}
        worker_id = data.get('worker_id')
        if not worker_id: return jsonify({'error': 'Missing worker_id'}), 400
        
        db = firestore.client()
        worker_ref = db.collection('campus_gig_workers').document(worker_id)
        if not worker_ref.get().exists: return jsonify({'error': 'Worker not found'}), 404
        
        worker_ref.update({
            'status': 'suspended',
            'is_available': False,
            'suspended_at': firestore.SERVER_TIMESTAMP
        })
        log_admin_action(admin_id, "Suspend Gig Worker", f"Suspended worker {worker_id}")
        return jsonify({'message': 'Worker suspended successfully'}), 200
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

# ==========================================
# PHASE 7: DATABASE HEALTH, SECURITY & MPESA RECONCILIATION
# ==========================================

@admin_bp.route('/database/health', methods=['GET'])
def get_database_health():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        start_time = datetime.datetime.now()

        # Measure connection latency with a lightweight ping
        db.collection('system_settings').document('platform_config').get()
        latency_ms = int((datetime.datetime.now() - start_time).total_seconds() * 1000)

        # Collection document counts (approximate or direct counts)
        def get_count(col_name):
            try:
                return db.collection(col_name).count().get()[0][0].value
            except:
                return len(db.collection(col_name).limit(50).get())

        counts = {
            'users': get_count('users'),
            'orders': get_count('orders'),
            'transactions': get_count('transactions'),
            'mpesa_transactions': get_count('mpesa_transactions'),
            'disputes': get_count('disputes'),
            'support_tickets': get_count('support_tickets'),
            'deliv_requests': get_count('deliv_requests'),
            'harambee_campaigns': get_count('harambee_campaigns'),
            'campus_feed': get_count('campus_feed'),
            'danger_zones': get_count('danger_zones'),
            'admin_action_logs': get_count('admin_action_logs'),
        }

        # Registered composite indexes status checklist
        registered_indexes = [
            {'collection': 'orders', 'fields': 'student_id ASC, pickupTime ASC', 'status': 'ACTIVE'},
            {'collection': 'orders', 'fields': 'vendorUid ASC, timestamp DESC', 'status': 'ACTIVE'},
            {'collection': 'transactions', 'fields': 'vendor_id ASC, timestamp DESC', 'status': 'ACTIVE'},
            {'collection': 'transactions', 'fields': 'student_id ASC, timestamp DESC', 'status': 'ACTIVE'},
            {'collection': 'deliv_rides', 'fields': 'driver_id ASC, status ASC, timestamp DESC', 'status': 'ACTIVE'},
            {'collection': 'keja_cooking', 'fields': 'status ASC, created_at DESC', 'status': 'ACTIVE'},
            {'collection': 'maintenance_tickets', 'fields': 'student_id ASC, room_id ASC, created_at DESC', 'status': 'ACTIVE'},
            {'collection': 'deliv_requests', 'fields': 'student_id ASC, status ASC', 'status': 'ACTIVE'},
            {'collection': 'vendor_kds_orders', 'fields': 'studentId ASC, delivery_status ASC', 'status': 'ACTIVE'},
            {'collection': 'support_tickets', 'fields': 'status ASC, created_at DESC', 'status': 'ACTIVE'},
            {'collection': 'mpesa_transactions', 'fields': 'user_id ASC, timestamp DESC', 'status': 'ACTIVE'},
            {'collection': 'admin_action_logs', 'fields': 'timestamp DESC', 'status': 'ACTIVE'}
        ]

        return jsonify({
            'status': 'HEALTHY' if latency_ms < 1200 else 'DEGRADED',
            'latency_ms': latency_ms,
            'counts': counts,
            'indexes': registered_indexes,
            'timestamp': datetime.datetime.now().isoformat()
        }), 200
    except Exception as e:
        return jsonify({'error': str(e), 'status': 'ERROR'}), 500

@admin_bp.route('/security/emergency_action', methods=['POST'])
def trigger_emergency_action():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        action = data.get('action') # 'LOCKDOWN', 'RESTORE', 'FREEZE_PAYOUTS', 'UNFREEZE_PAYOUTS', 'PAUSE_ORDERS', 'RESUME_ORDERS'
        reason = data.get('reason', 'Administrative emergency command')
        
        db = firestore.client()
        cfg_ref = db.collection('system_settings').document('platform_config')
        
        updates = {'updated_at': firestore.SERVER_TIMESTAMP, 'last_security_admin': admin_id}
        
        if action == 'LOCKDOWN':
            updates['maintenance_mode'] = True
            updates['payouts_frozen'] = True
            updates['ordering_paused'] = True
            updates['lockdown_reason'] = reason
        elif action == 'RESTORE':
            updates['maintenance_mode'] = False
            updates['payouts_frozen'] = False
            updates['ordering_paused'] = False
            updates['lockdown_reason'] = firestore.DELETE_FIELD
        elif action == 'FREEZE_PAYOUTS':
            updates['payouts_frozen'] = True
        elif action == 'UNFREEZE_PAYOUTS':
            updates['payouts_frozen'] = False
        elif action == 'PAUSE_ORDERS':
            updates['ordering_paused'] = True
        elif action == 'RESUME_ORDERS':
            updates['ordering_paused'] = False
        else:
            return jsonify({'error': f'Invalid emergency action: {action}'}), 400

        cfg_ref.set(updates, merge=True)
        log_admin_action(admin_id, f'EMERGENCY_{action}', {'reason': reason, 'updates': str(updates)})

        return jsonify({'message': f'Emergency action {action} executed successfully', 'action': action}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/security/status', methods=['GET'])
def get_security_status():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        cfg_doc = db.collection('system_settings').document('platform_config').get()
        cfg = cfg_doc.to_dict() or {} if cfg_doc.exists else {}

        # Recent security logs
        logs_docs = db.collection('admin_action_logs').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(10).get()
        recent_logs = []
        for l in logs_docs:
            ld = l.to_dict()
            if 'timestamp' in ld and hasattr(ld['timestamp'], 'isoformat'):
                ld['timestamp'] = ld['timestamp'].isoformat()
            else:
                ld['timestamp'] = str(ld.get('timestamp'))
            ld['id'] = l.id
            recent_logs.append(ld)

        # Flagged threats count
        flagged_count = 0
        try:
            flagged_count = db.collection('mpesa_transactions').where('status', '==', 'failed').count().get()[0][0].value
        except: pass

        is_maintenance = cfg.get('maintenance_mode', False)
        is_frozen = cfg.get('payouts_frozen', False)
        threat_level = 'CRITICAL' if (is_maintenance or is_frozen) else ('ELEVATED' if flagged_count > 5 else 'NORMAL')

        return jsonify({
            'maintenance_mode': is_maintenance,
            'payouts_frozen': is_frozen,
            'ordering_paused': cfg.get('ordering_paused', False),
            'threat_level': threat_level,
            'flagged_count': flagged_count,
            'lockdown_reason': cfg.get('lockdown_reason'),
            'recent_logs': recent_logs
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/mpesa/query_transaction', methods=['POST'])
def query_mpesa_transaction():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        query = data.get('query', '').strip()
        if not query:
            return jsonify({'error': 'Search query required'}), 400

        db = firestore.client()
        results = []

        # 1. Search by document ID (often CheckoutRequestID)
        doc = db.collection('mpesa_transactions').document(query).get()
        if doc.exists:
            d = doc.to_dict()
            d['id'] = doc.id
            results.append(d)

        # 2. Search by receipt number
        if not results:
            docs = db.collection('mpesa_transactions').where('mpesa_receipt_number', '==', query.upper()).limit(5).get()
            for d in docs:
                item = d.to_dict()
                item['id'] = d.id
                results.append(item)

        # 3. Search by MpesaReceiptNumber (alternate field)
        if not results:
            docs = db.collection('mpesa_transactions').where('MpesaReceiptNumber', '==', query.upper()).limit(5).get()
            for d in docs:
                item = d.to_dict()
                item['id'] = d.id
                results.append(item)

        # 4. Search by phone number
        if not results and query.isdigit():
            docs = db.collection('mpesa_transactions').where('phone_number', '==', query).limit(5).get()
            for d in docs:
                item = d.to_dict()
                item['id'] = d.id
                results.append(item)

        # 5. Search in ledger transactions if still not found
        if not results:
            tx_doc = db.collection('transactions').document(query).get()
            if tx_doc.exists:
                t = tx_doc.to_dict()
                t['id'] = tx_doc.id
                results.append(t)

        # Format timestamps
        for r in results:
            if 'timestamp' in r and hasattr(r['timestamp'], 'isoformat'):
                r['timestamp'] = r['timestamp'].isoformat()
            else:
                r['timestamp'] = str(r.get('timestamp'))

        return jsonify({'results': results, 'count': len(results)}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@admin_bp.route('/mpesa/manual_credit', methods=['POST'])
def manual_credit_mpesa():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        checkout_id = data.get('checkout_id')
        user_id = data.get('user_id')
        amount = float(data.get('amount', 0))
        receipt = data.get('receipt', '').strip().upper()
        reason = data.get('reason', 'Manual M-PESA reconciliation by Admin')

        if not user_id or amount <= 0:
            return jsonify({'error': 'Valid user_id and amount > 0 required'}), 400

        db = firestore.client()
        user_ref = db.collection('users').document(user_id)
        if not user_ref.get().exists:
            return jsonify({'error': 'User not found'}), 404

        # Check duplicate receipt credit
        if receipt:
            credited_docs = db.collection('transactions').where('receipt', '==', receipt).where('type', '==', 'topup').get()
            if len(credited_docs) > 0:
                return jsonify({'error': f'Receipt {receipt} has already been credited!'}), 400

        @firestore.transactional
        def do_credit(transaction):
            snap = user_ref.get(transaction=transaction)
            current_bal = float(snap.to_dict().get('walletBalance', 0))
            new_bal = current_bal + amount
            transaction.update(user_ref, {'walletBalance': new_bal})

            # Create transaction record
            tx_ref = db.collection('transactions').document()
            transaction.set(tx_ref, {
                'user_id': user_id,
                'uid': user_id,
                'amount': amount,
                'type': 'topup',
                'description': f'M-PESA Manual Credit ({receipt or "No Receipt"})',
                'receipt': receipt,
                'status': 'completed',
                'credited_by': admin_id,
                'reason': reason,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'previous_balance': current_bal,
                'new_balance': new_bal
            })

            # Mark in mpesa_transactions if checkout_id provided
            if checkout_id:
                m_ref = db.collection('mpesa_transactions').document(checkout_id)
                if m_ref.get(transaction=transaction).exists:
                    transaction.update(m_ref, {
                        'status': 'completed',
                        'manually_credited': True,
                        'credited_by': admin_id,
                        'credited_at': firestore.SERVER_TIMESTAMP
                    })
            return new_bal

        tx = db.transaction()
        new_balance = do_credit(tx)
        log_admin_action(admin_id, 'manual_mpesa_credit', {
            'target_user_id': user_id,
            'amount': amount,
            'receipt': receipt,
            'reason': reason,
            'new_balance': new_balance
        })

        return jsonify({
            'message': f'Successfully credited KES {amount} to user {user_id}. New balance: {new_balance}',
            'new_balance': new_balance
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


