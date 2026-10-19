from flask import Blueprint, request, jsonify
from firebase_admin import firestore
import os
import requests
from requests.auth import HTTPBasicAuth
import datetime
import uuid

payroll_bp = Blueprint('admin_payroll', __name__)

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
            
    admin_token = os.getenv('ADMIN_SECRET', 'swapeat-admin-2024')
    if auth_header == f"Bearer {admin_token}":
        return "SUPERADMIN_SCRIPT"
    return None

def get_daraja_token():
    consumer_key = os.getenv('MPESA_CONSUMER_KEY')
    consumer_secret = os.getenv('MPESA_CONSUMER_SECRET')
    env = os.getenv('MPESA_ENV', 'sandbox').lower()
    base_url = "https://api.safaricom.co.ke" if env == 'production' else "https://sandbox.safaricom.co.ke"
    api_url = f"{base_url}/oauth/v1/generate?grant_type=client_credentials"

    try:
        response = requests.get(api_url, auth=HTTPBasicAuth(consumer_key, consumer_secret), timeout=15)
        if response.status_code == 200:
            return response.json().get('access_token'), base_url
    except Exception as e:
        print(f"Daraja token error: {e}")
    return None, base_url

# ==========================================
# 1. EMPLOYEE MANAGEMENT ENDPOINTS
# ==========================================

@payroll_bp.route('/employees', methods=['GET'])
def get_employees():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('employees').order_by('created_at', direction=firestore.Query.DESCENDING).get()
        employees = []
        for d in docs:
            item = d.to_dict()
            item['id'] = d.id
            if 'created_at' in item and hasattr(item['created_at'], 'isoformat'):
                item['created_at'] = item['created_at'].isoformat()
            else:
                item['created_at'] = str(item.get('created_at'))
            employees.append(item)
        return jsonify({'employees': employees, 'count': len(employees)}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/employees', methods=['POST'])
def add_employee():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        name = data.get('name', '').strip()
        phone = data.get('phone', '').strip().replace('+', '')
        email = data.get('email', '').strip().lower()
        expectations = data.get('expectations', data.get('responsibilities', '')).strip()
        send_welcome_email = data.get('send_welcome_email', True)
        department = data.get('department', 'Operations')
        role = data.get('role', 'Staff')
        base_salary = float(data.get('base_salary', 0))
        salary_type = data.get('salary_type', 'MONTHLY') # MONTHLY, WEEKLY, GIG_COMMISSION
        national_id = data.get('national_id', '')
        bank_name = data.get('bank_name', '')
        bank_account = data.get('bank_account', '')
        shif_deduction = float(data.get('shif_deduction', 0))
        nssf_deduction = float(data.get('nssf_deduction', 0))
        housing_levy = float(data.get('housing_levy', 0))

        if not name or not phone or base_salary <= 0:
            return jsonify({'error': 'Name, valid phone, and base salary > 0 are required'}), 400

        # Normalize phone to 254XXXXXXXXX
        if phone.startswith('0'):
            phone = '254' + phone[1:]
        elif not phone.startswith('254') and len(phone) == 9:
            phone = '254' + phone

        db = firestore.client()
        emp_ref = db.collection('employees').document()
        emp_data = {
            'name': name,
            'phone': phone,
            'mpesa_number': phone,
            'email': email,
            'expectations': expectations,
            'department': department,
            'role': role,
            'base_salary': base_salary,
            'salary_type': salary_type,
            'national_id': national_id,
            'bank_name': bank_name,
            'bank_account': bank_account,
            'status': 'active',
            'shif_deduction': shif_deduction,
            'nssf_deduction': nssf_deduction,
            'housing_levy': housing_levy,
            'created_at': firestore.SERVER_TIMESTAMP,
            'created_by': admin_id,
            'total_paid_ytd': 0.0,
            'last_paid_at': None
        }
        emp_ref.set(emp_data)
        log_admin_action(admin_id, 'add_employee', {'employee_id': emp_ref.id, 'name': name, 'department': department, 'email': email})

        email_sent = False
        delivery_channel = None
        if email and send_welcome_email:
            try:
                from routes.email_utils import generate_staff_appointment_email, send_multi_channel_email
                subject, html_body, plain_body = generate_staff_appointment_email(
                    name=name,
                    role=role,
                    department=department,
                    base_salary=base_salary,
                    salary_type=salary_type,
                    expectations=expectations,
                    phone=phone
                )
                success, delivery_channel = send_multi_channel_email(
                    to=email,
                    subject=subject,
                    html_body=html_body,
                    plain_body=plain_body
                )
                email_sent = success
                print(f"[StaffOnboarding] Appointment email to {email}: {delivery_channel}")
            except Exception as mail_err:
                print(f"[StaffOnboarding] Error sending appointment email: {mail_err}")

        return jsonify({
            'message': 'Employee added successfully',
            'id': emp_ref.id,
            'email_sent': email_sent,
            'delivery_channel': delivery_channel
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/employees/<emp_id>', methods=['POST', 'PUT'])
def update_employee(emp_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        db = firestore.client()
        emp_ref = db.collection('employees').document(emp_id)
        if not emp_ref.get().exists:
            return jsonify({'error': 'Employee not found'}), 404

        updates = {'updated_at': firestore.SERVER_TIMESTAMP, 'updated_by': admin_id}
        for field in ['name', 'phone', 'email', 'expectations', 'department', 'role', 'base_salary', 'salary_type', 'national_id', 'bank_name', 'bank_account', 'status', 'shif_deduction', 'nssf_deduction', 'housing_levy']:
            if field in data:
                if field in ['base_salary', 'shif_deduction', 'nssf_deduction', 'housing_levy']:
                    updates[field] = float(data[field])
                else:
                    updates[field] = data[field]

        emp_ref.update(updates)
        log_admin_action(admin_id, 'update_employee', {'employee_id': emp_id, 'updates': str(updates)})
        return jsonify({'message': 'Employee updated successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/employees/<emp_id>/resend_welcome_email', methods=['POST'])
def resend_welcome_email(emp_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        emp_doc = db.collection('employees').document(emp_id).get()
        if not emp_doc.exists:
            return jsonify({'error': 'Employee not found'}), 404
        emp = emp_doc.to_dict()
        email = emp.get('email', '').strip()
        if not email:
            return jsonify({'error': 'Employee has no registered email address'}), 400

        from routes.email_utils import generate_staff_appointment_email, send_multi_channel_email
        subject, html_body, plain_body = generate_staff_appointment_email(
            name=emp.get('name', 'Staff Member'),
            role=emp.get('role', 'Staff'),
            department=emp.get('department', 'Operations'),
            base_salary=float(emp.get('base_salary', 0)),
            salary_type=emp.get('salary_type', 'MONTHLY'),
            expectations=emp.get('expectations', ''),
            phone=emp.get('phone', '')
        )
        success, channel = send_multi_channel_email(
            to=email,
            subject=subject,
            html_body=html_body,
            plain_body=plain_body
        )
        log_admin_action(admin_id, 'resend_staff_email', {'employee_id': emp_id, 'email': email, 'channel': channel})
        return jsonify({'message': f'Appointment email resent to {email} via {channel}', 'success': success, 'channel': channel}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/employees/<emp_id>/status', methods=['POST'])
def toggle_employee_status(emp_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        status = data.get('status', 'suspended')
        db = firestore.client()
        emp_ref = db.collection('employees').document(emp_id)
        if not emp_ref.get().exists:
            return jsonify({'error': 'Employee not found'}), 404

        emp_ref.update({
            'status': status,
            'status_updated_at': firestore.SERVER_TIMESTAMP,
            'status_updated_by': admin_id
        })
        log_admin_action(admin_id, 'toggle_employee_status', {'employee_id': emp_id, 'status': status})
        return jsonify({'message': f'Employee status changed to {status}'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==========================================
# 1B. DEPARTMENT & ROLE COMPENSATION ENDPOINTS
# ==========================================

DEFAULT_DEPARTMENTS = [
    {
        'name': 'Kitchen Operations',
        'code': 'KITCHEN',
        'description': 'Food preparation, cooking, pantry management, and meal assembly',
        'budget': 200000.0,
        'roles': [
            {'title': 'Head Chef', 'default_salary': 45000.0},
            {'title': 'Sous Chef', 'default_salary': 32000.0},
            {'title': 'Line Cook', 'default_salary': 25000.0},
            {'title': 'Kitchen Assistant', 'default_salary': 18000.0}
        ]
    },
    {
        'name': 'Campus Delivery',
        'code': 'DELIVERY',
        'description': 'Student meal dispatch, hostel dropoffs, and campus courier logistics',
        'budget': 150000.0,
        'roles': [
            {'title': 'Fleet Captain', 'default_salary': 35000.0},
            {'title': 'Full-time Rider', 'default_salary': 25000.0},
            {'title': 'Part-time Student Courier', 'default_salary': 15000.0}
        ]
    },
    {
        'name': 'Engineering & Tech',
        'code': 'TECH',
        'description': 'Platform infrastructure, app maintenance, payment integrations, and DevOps',
        'budget': 300000.0,
        'roles': [
            {'title': 'Lead Software Engineer', 'default_salary': 80000.0},
            {'title': 'Frontend Developer', 'default_salary': 50000.0},
            {'title': 'QA & Security Analyst', 'default_salary': 40000.0}
        ]
    },
    {
        'name': 'Support & Dispute Care',
        'code': 'SUPPORT',
        'description': 'Student ticket resolution, order refunds, and escrow mediation',
        'budget': 120000.0,
        'roles': [
            {'title': 'Support Team Lead', 'default_salary': 35000.0},
            {'title': 'Customer Support Rep', 'default_salary': 22000.0}
        ]
    },
    {
        'name': 'Hygiene & Facilities',
        'code': 'CLEANING',
        'description': 'Kitchen deep cleaning, cafeteria sanitation, and hygiene compliance',
        'budget': 80000.0,
        'roles': [
            {'title': 'Sanitation Lead', 'default_salary': 22000.0},
            {'title': 'Steward', 'default_salary': 16000.0}
        ]
    },
    {
        'name': 'Executive Management',
        'code': 'MANAGEMENT',
        'description': 'Operations oversight, finance, vendor relations, and strategy',
        'budget': 250000.0,
        'roles': [
            {'title': 'Operations Director', 'default_salary': 75000.0},
            {'title': 'Finance Manager', 'default_salary': 55000.0}
        ]
    }
]

@payroll_bp.route('/departments', methods=['GET'])
def get_departments():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        dept_docs = db.collection('departments').get()
        departments = []

        if not dept_docs:
            now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
            for d in DEFAULT_DEPARTMENTS:
                new_ref = db.collection('departments').document()
                new_ref.set({
                    **d,
                    'created_at': firestore.SERVER_TIMESTAMP,
                    'created_by': admin_id
                })
                item = {
                    **d,
                    'id': new_ref.id,
                    'created_at': now_iso,
                    'created_by': admin_id
                }
                departments.append(item)
        else:
            for d in dept_docs:
                item = d.to_dict()
                item['id'] = d.id
                if 'created_at' in item and hasattr(item['created_at'], 'isoformat'):
                    item['created_at'] = item['created_at'].isoformat()
                else:
                    item['created_at'] = str(item.get('created_at', ''))
                departments.append(item)

        emp_docs = db.collection('employees').where('status', '==', 'active').get()
        emp_counts = {}
        emp_payroll = {}
        for ed in emp_docs:
            e = ed.to_dict()
            dept_name = e.get('department', 'General')
            sal = float(e.get('base_salary', 0.0))
            emp_counts[dept_name] = emp_counts.get(dept_name, 0) + 1
            emp_payroll[dept_name] = emp_payroll.get(dept_name, 0.0) + sal

        for dept in departments:
            name = dept.get('name', '')
            dept['active_employees'] = emp_counts.get(name, 0)
            dept['monthly_payroll'] = emp_payroll.get(name, 0.0)

        return jsonify({'departments': departments, 'count': len(departments)}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/departments', methods=['POST'])
def create_department():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        name = data.get('name', '').strip()
        code = data.get('code', name[:6].upper()).strip()
        description = data.get('description', '').strip()
        budget = float(data.get('budget', 0.0))
        roles = data.get('roles', [])

        if not name:
            return jsonify({'error': 'Department name is required'}), 400

        db = firestore.client()
        new_ref = db.collection('departments').document()
        dept_data = {
            'name': name,
            'code': code,
            'description': description,
            'budget': budget,
            'roles': roles,
            'created_at': firestore.SERVER_TIMESTAMP,
            'created_by': admin_id,
            'updated_at': firestore.SERVER_TIMESTAMP
        }
        new_ref.set(dept_data)
        log_admin_action(admin_id, 'create_department', {'department_id': new_ref.id, 'name': name})

        now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
        res_dept = {
            'id': new_ref.id,
            'name': name,
            'code': code,
            'description': description,
            'budget': budget,
            'roles': roles,
            'created_at': now_iso,
            'created_by': admin_id,
            'updated_at': now_iso
        }
        return jsonify({'message': f'Department {name} created successfully', 'id': new_ref.id, 'department': res_dept}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/departments/<dept_id>', methods=['PUT', 'POST'])
def update_department(dept_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        db = firestore.client()
        dept_ref = db.collection('departments').document(dept_id)
        if not dept_ref.get().exists:
            return jsonify({'error': 'Department not found'}), 404

        updates = {'updated_at': firestore.SERVER_TIMESTAMP, 'updated_by': admin_id}
        if 'name' in data: updates['name'] = data['name'].strip()
        if 'code' in data: updates['code'] = data['code'].strip().upper()
        if 'description' in data: updates['description'] = data['description'].strip()
        if 'budget' in data: updates['budget'] = float(data['budget'])
        if 'roles' in data: updates['roles'] = data['roles']

        dept_ref.update(updates)
        log_admin_action(admin_id, 'update_department', {'department_id': dept_id, 'updates': str(updates)})
        return jsonify({'message': 'Department updated successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/departments/<dept_id>', methods=['DELETE'])
def delete_department(dept_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        dept_ref = db.collection('departments').document(dept_id)
        if not dept_ref.get().exists:
            return jsonify({'error': 'Department not found'}), 404

        dept_ref.delete()
        log_admin_action(admin_id, 'delete_department', {'department_id': dept_id})
        return jsonify({'message': 'Department deleted successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/employees/<emp_id>/compensation', methods=['POST'])
def update_employee_compensation(emp_id):
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        role = data.get('role', '').strip()
        department = data.get('department', '').strip()
        base_salary = float(data.get('base_salary', 0.0))
        salary_type = data.get('salary_type', 'MONTHLY')
        
        if not role or not department or base_salary <= 0:
            return jsonify({'error': 'Role, department, and valid base salary > 0 are required'}), 400

        db = firestore.client()
        emp_ref = db.collection('employees').document(emp_id)
        doc = emp_ref.get()
        if not doc.exists:
            return jsonify({'error': 'Employee not found'}), 404

        old_data = doc.to_dict() or {}
        updates = {
            'role': role,
            'department': department,
            'base_salary': base_salary,
            'salary_type': salary_type,
            'updated_at': firestore.SERVER_TIMESTAMP,
            'updated_by': admin_id,
            'compensation_history': firestore.ArrayUnion([{
                'old_role': old_data.get('role'),
                'old_department': old_data.get('department'),
                'old_salary': old_data.get('base_salary'),
                'new_role': role,
                'new_department': department,
                'new_salary': base_salary,
                'changed_by': admin_id,
                'changed_at': datetime.datetime.utcnow().isoformat()
            }])
        }

        if 'shif_deduction' in data: updates['shif_deduction'] = float(data['shif_deduction'])
        if 'nssf_deduction' in data: updates['nssf_deduction'] = float(data['nssf_deduction'])
        if 'housing_levy' in data: updates['housing_levy'] = float(data['housing_levy'])

        emp_ref.update(updates)
        log_admin_action(admin_id, 'update_employee_compensation', {
            'employee_id': emp_id,
            'new_role': role,
            'new_salary': base_salary,
            'department': department
        })

        return jsonify({
            'message': f"Updated {old_data.get('name', 'Employee')}'s role to {role} with salary KES {base_salary:.2f}",
            'employee_id': emp_id,
            'role': role,
            'department': department,
            'base_salary': base_salary
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==========================================
# 2. PAYROLL & B2C SALARY PAYMENTS
# ==========================================

@payroll_bp.route('/payroll/summary', methods=['GET'])
def get_payroll_summary():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        emp_docs = db.collection('employees').where('status', '==', 'active').get()
        total_liability = 0.0
        employee_count = len(emp_docs)
        departments = {}

        for d in emp_docs:
            data = d.to_dict()
            sal = float(data.get('base_salary', 0))
            dept = data.get('department', 'General')
            total_liability += sal
            departments[dept] = departments.get(dept, 0) + 1

        # Calculate paid this month
        current_month = datetime.datetime.now().strftime('%Y-%m')
        slip_docs = db.collection('payroll_slips').where('month', '==', current_month).get()
        total_paid_this_month = sum(float(s.to_dict().get('net_salary', 0)) for s in slip_docs if s.to_dict().get('status') == 'completed')

        return jsonify({
            'active_employees': employee_count,
            'monthly_liability': total_liability,
            'paid_this_month': total_paid_this_month,
            'pending_payout': max(0.0, total_liability - total_paid_this_month),
            'department_breakdown': departments,
            'current_cycle': current_month
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/payroll/disburse/b2c', methods=['POST'])
def disburse_salary_b2c():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        emp_id = data.get('employee_id')
        month = data.get('month', datetime.datetime.now().strftime('%Y-%m'))
        bonus = float(data.get('bonus', 0))
        advance_deduction = float(data.get('advance_deduction', 0))
        notes = data.get('notes', 'Monthly Salary Disbursement')

        if not emp_id:
            return jsonify({'error': 'employee_id is required'}), 400

        db = firestore.client()
        emp_doc = db.collection('employees').document(emp_id).get()
        if not emp_doc.exists:
            return jsonify({'error': 'Employee not found'}), 404

        emp = emp_doc.to_dict()
        phone = emp.get('mpesa_number') or emp.get('phone')
        base_salary = float(emp.get('base_salary', 0))
        shif = float(emp.get('shif_deduction', 0))
        nssf = float(emp.get('nssf_deduction', 0))
        housing = float(emp.get('housing_levy', 0))

        gross = base_salary + bonus
        total_deductions = shif + nssf + housing + advance_deduction
        net_salary = max(1.0, gross - total_deductions)

        # 1. Initiate Daraja B2C Salary Payment
        access_token, base_url = get_daraja_token()
        operator_id = os.getenv('MPESA_OPERATOR_ID', os.getenv('DARAJA_INITIATOR_NAME', 'OI'))
        shortcode = os.getenv('MPESA_SHORTCODE', os.getenv('MPESA_BUSINESS_SHORT_CODE', '4050545'))
        security_credential = os.getenv('SECURITY_CREDENTIAL')

        daraja_status = "simulated"
        conversation_id = f"PAY-{uuid.uuid4().hex[:10].upper()}"

        if access_token and security_credential:
            headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}
            payload = {
                "InitiatorName": operator_id,
                "SecurityCredential": security_credential,
                "CommandID": "SalaryPayment",
                "Amount": str(int(net_salary)),
                "PartyA": shortcode,
                "PartyB": phone,
                "Remarks": f"Salary {month}",
                "QueueTimeOutURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2c_timeout",
                "ResultURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2c_result",
                "Occasion": month
            }
            try:
                b2c_url = f"{base_url}/mpesa/b2c/v1/paymentrequest"
                b2c_res = requests.post(b2c_url, json=payload, headers=headers, timeout=15)
                if b2c_res.status_code == 200:
                    res_json = b2c_res.json()
                    conversation_id = res_json.get('ConversationID') or conversation_id
                    daraja_status = "queued"
                else:
                    daraja_status = f"error_{b2c_res.status_code}"
            except Exception as ex:
                daraja_status = f"daraja_timeout: {str(ex)}"

        # 2. Record Payroll Slip
        slip_ref = db.collection('payroll_slips').document()
        slip_data = {
            'employee_id': emp_id,
            'employee_name': emp.get('name'),
            'department': emp.get('department'),
            'phone': phone,
            'month': month,
            'base_salary': base_salary,
            'bonus': bonus,
            'gross_salary': gross,
            'shif_deduction': shif,
            'nssf_deduction': nssf,
            'housing_levy': housing,
            'advance_deduction': advance_deduction,
            'total_deductions': total_deductions,
            'net_salary': net_salary,
            'status': 'completed',
            'daraja_status': daraja_status,
            'conversation_id': conversation_id,
            'notes': notes,
            'disbursed_by': admin_id,
            'created_at': firestore.SERVER_TIMESTAMP
        }
        slip_ref.set(slip_data)

        # 3. Update employee record
        db.collection('employees').document(emp_id).update({
            'last_paid_at': firestore.SERVER_TIMESTAMP,
            'total_paid_ytd': firestore.Increment(net_salary)
        })

        # 4. Record in general transactions ledger
        tx_ref = db.collection('transactions').document()
        tx_ref.set({
            'amount': net_salary,
            'type': 'B2C Salary Disbursement',
            'description': f"Salary paid to {emp.get('name')} ({month})",
            'employee_id': emp_id,
            'phone': phone,
            'conversation_id': conversation_id,
            'status': 'completed',
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        log_admin_action(admin_id, 'b2c_salary_disbursement', {
            'employee_id': emp_id,
            'name': emp.get('name'),
            'amount': net_salary,
            'conversation_id': conversation_id
        })

        return jsonify({
            'message': f'Salary of KES {net_salary:.2f} disbursed to {emp.get("name")}',
            'slip_id': slip_ref.id,
            'net_salary': net_salary,
            'conversation_id': conversation_id,
            'daraja_status': daraja_status
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/payroll/bulk_disburse', methods=['POST'])
def bulk_disburse_payroll():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        department = data.get('department') # Optional filter
        month = data.get('month', datetime.datetime.now().strftime('%Y-%m'))

        db = firestore.client()
        query = db.collection('employees').where('status', '==', 'active')
        if department and department != 'ALL':
            query = query.where('department', '==', department)

        emp_docs = query.get()
        if not emp_docs:
            return jsonify({'error': 'No active employees found matching criteria'}), 404

        batch_id = f"BATCH-{uuid.uuid4().hex[:8].upper()}"
        disbursed_count = 0
        total_batch_amount = 0.0

        for d in emp_docs:
            emp = d.to_dict()
            emp_id = d.id
            phone = emp.get('mpesa_number') or emp.get('phone')
            base_salary = float(emp.get('base_salary', 0))
            deductions = float(emp.get('shif_deduction', 0)) + float(emp.get('nssf_deduction', 0)) + float(emp.get('housing_levy', 0))
            net = max(1.0, base_salary - deductions)

            slip_ref = db.collection('payroll_slips').document()
            slip_ref.set({
                'batch_id': batch_id,
                'employee_id': emp_id,
                'employee_name': emp.get('name'),
                'department': emp.get('department'),
                'phone': phone,
                'month': month,
                'base_salary': base_salary,
                'gross_salary': base_salary,
                'total_deductions': deductions,
                'net_salary': net,
                'status': 'completed',
                'disbursed_by': admin_id,
                'created_at': firestore.SERVER_TIMESTAMP
            })

            d.reference.update({
                'last_paid_at': firestore.SERVER_TIMESTAMP,
                'total_paid_ytd': firestore.Increment(net)
            })

            disbursed_count += 1
            total_batch_amount += net

        # Record batch summary
        db.collection('payroll_batches').document(batch_id).set({
            'batch_id': batch_id,
            'department': department or 'ALL',
            'month': month,
            'employee_count': disbursed_count,
            'total_amount': total_batch_amount,
            'status': 'completed',
            'initiated_by': admin_id,
            'created_at': firestore.SERVER_TIMESTAMP
        })

        log_admin_action(admin_id, 'bulk_payroll_disbursement', {
            'batch_id': batch_id,
            'count': disbursed_count,
            'total': total_batch_amount
        })

        return jsonify({
            'message': f'Bulk payroll batch {batch_id} completed for {disbursed_count} employees.',
            'batch_id': batch_id,
            'disbursed_count': disbursed_count,
            'total_amount': total_batch_amount
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/payroll/slips', methods=['GET'])
def get_payroll_slips():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('payroll_slips').order_by('created_at', direction=firestore.Query.DESCENDING).limit(100).get()
        slips = []
        for d in docs:
            item = d.to_dict()
            item['id'] = d.id
            if 'created_at' in item and hasattr(item['created_at'], 'isoformat'):
                item['created_at'] = item['created_at'].isoformat()
            else:
                item['created_at'] = str(item.get('created_at'))
            slips.append(item)
        return jsonify({'slips': slips, 'count': len(slips)}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==========================================
# 3. B2B TRANSFERS (BUSINESS TO BUSINESS)
# ==========================================

@payroll_bp.route('/finance/b2b_payment', methods=['POST'])
def execute_b2b_payment():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        data = request.json or {}
        recipient_name = data.get('recipient_name', '').strip()
        recipient_type = data.get('recipient_type', 'BusinessBuyGoods') # BusinessBuyGoods or BusinessPayBill
        destination_number = data.get('destination_number', '').strip() # Till or Paybill number
        account_ref = data.get('account_reference', 'DISHI-B2B').strip()
        amount = float(data.get('amount', 0))
        purpose = data.get('purpose', 'Vendor / Supplier Disbursement')

        if not destination_number or amount <= 0:
            return jsonify({'error': 'Valid destination till/paybill and amount > 0 required'}), 400

        access_token, base_url = get_daraja_token()
        initiator_name = os.getenv('DARAJA_INITIATOR_NAME', 'Delstarford Api')
        security_credential = os.getenv('SECURITY_CREDENTIAL')
        shortcode = os.getenv('MPESA_SHORTCODE', os.getenv('MPESA_BUSINESS_SHORT_CODE', '4050545'))

        daraja_status = "simulated"
        tx_id = f"B2B-{uuid.uuid4().hex[:10].upper()}"

        if access_token and security_credential:
            headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}
            payload = {
                "Initiator": initiator_name,
                "InitiatorName": initiator_name,
                "SecurityCredential": security_credential,
                "CommandID": recipient_type,
                "SenderIdentifierType": "4",
                "RecieverIdentifierType": "4" if recipient_type == "BusinessPayBill" else "2",
                "Amount": str(int(amount)),
                "PartyA": shortcode,
                "PartyB": destination_number,
                "AccountReference": account_ref,
                "Remarks": purpose,
                "QueueTimeOutURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2b_timeout",
                "ResultURL": "https://dishi.delstarfordworks.co.ke/api/v1/mpesa/b2b_result"
            }
            try:
                b2b_url = f"{base_url}/mpesa/b2b/v1/paymentrequest"
                b2b_res = requests.post(b2b_url, json=payload, headers=headers, timeout=15)
                if b2b_res.status_code == 200:
                    daraja_status = "queued"
                else:
                    daraja_status = f"error_{b2b_res.status_code}"
            except Exception as ex:
                daraja_status = f"daraja_timeout: {str(ex)}"

        db = firestore.client()
        transfer_ref = db.collection('b2b_transfers').document()
        transfer_data = {
            'tx_id': tx_id,
            'recipient_name': recipient_name or destination_number,
            'recipient_type': recipient_type,
            'destination_number': destination_number,
            'account_reference': account_ref,
            'amount': amount,
            'purpose': purpose,
            'status': 'completed',
            'daraja_status': daraja_status,
            'initiated_by': admin_id,
            'created_at': firestore.SERVER_TIMESTAMP
        }
        transfer_ref.set(transfer_data)

        # Log in main transactions
        db.collection('transactions').add({
            'amount': amount,
            'type': f'B2B Transfer ({recipient_type})',
            'description': f"B2B Transfer of KES {amount} to {recipient_name or destination_number}",
            'destination': destination_number,
            'tx_id': tx_id,
            'status': 'completed',
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        log_admin_action(admin_id, 'b2b_transfer', {
            'recipient': recipient_name,
            'destination': destination_number,
            'amount': amount,
            'type': recipient_type
        })

        return jsonify({
            'message': f'B2B Transfer of KES {amount:.2f} to {destination_number} dispatched.',
            'tx_id': tx_id,
            'daraja_status': daraja_status
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@payroll_bp.route('/finance/b2b_transfers', methods=['GET'])
def get_b2b_transfers():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        docs = db.collection('b2b_transfers').order_by('created_at', direction=firestore.Query.DESCENDING).limit(50).get()
        transfers = []
        for d in docs:
            item = d.to_dict()
            item['id'] = d.id
            if 'created_at' in item and hasattr(item['created_at'], 'isoformat'):
                item['created_at'] = item['created_at'].isoformat()
            else:
                item['created_at'] = str(item.get('created_at'))
            transfers.append(item)
        return jsonify({'transfers': transfers, 'count': len(transfers)}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==========================================
# 4. C2B COLLECTIONS MONITOR (CUSTOMER TO BUSINESS)
# ==========================================

@payroll_bp.route('/finance/c2b_overview', methods=['GET'])
def get_c2b_overview():
    admin_id = verify_admin(request)
    if not admin_id:
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        collections = []
        seen_tx_ids = set()
        total_volume = 0.0
        success_count = 0

        # 1. Query dedicated C2B Paybill Inbound transactions
        c2b_docs = db.collection('c2b_transactions').order_by('created_at', direction=firestore.Query.DESCENDING).limit(50).get()
        for d in c2b_docs:
            item = d.to_dict()
            tx_id = item.get('trans_id') or d.id
            if tx_id in seen_tx_ids:
                continue
            seen_tx_ids.add(tx_id)

            amt = float(item.get('amount') or item.get('trans_amount') or 0.0)
            status = item.get('status', 'completed')
            if status in ['completed', 'reconciled']:
                total_volume += amt
                success_count += 1

            ts = item.get('created_at') or item.get('timestamp')
            ts_str = ts.isoformat() if hasattr(ts, 'isoformat') else str(ts or '')

            collections.append({
                'id': d.id,
                'trans_id': tx_id,
                'amount': amt,
                'trans_amount': amt,
                'msisdn': item.get('phone') or item.get('msisdn', ''),
                'phoneNumber': item.get('phone') or item.get('msisdn', ''),
                'bill_ref_number': item.get('bill_ref') or item.get('bill_ref_number', 'WALLET-TOPUP'),
                'accountReference': item.get('bill_ref') or item.get('bill_ref_number', 'WALLET-TOPUP'),
                'first_name': item.get('customer_name', '').split()[0] if item.get('customer_name') else item.get('first_name', ''),
                'last_name': " ".join(item.get('customer_name', '').split()[1:]) if item.get('customer_name') else item.get('last_name', ''),
                'status': status,
                'reconciled': item.get('reconciled', True),
                'matched_user_name': item.get('matched_user_name', ''),
                'matched_user_id': item.get('matched_user_id', ''),
                'trans_time': ts_str,
                'timestamp': ts_str,
                'source': 'C2B Paybill Webhook'
            })

        # 2. Query recent M-PESA deposits as supplementary stream
        docs = db.collection('mpesa_transactions').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(30).get()
        for d in docs:
            item = d.to_dict()
            tx_id = item.get('receipt') or item.get('MpesaReceiptNumber') or d.id
            if tx_id in seen_tx_ids:
                continue
            seen_tx_ids.add(tx_id)

            amt = float(item.get('amount') or item.get('Amount') or 0.0)
            status = item.get('status', 'completed')
            if status == 'completed':
                total_volume += amt
                success_count += 1

            ts = item.get('timestamp')
            ts_str = ts.isoformat() if hasattr(ts, 'isoformat') else str(ts or '')

            u_name = item.get('user_name', '')
            collections.append({
                'id': d.id,
                'trans_id': tx_id,
                'amount': amt,
                'trans_amount': amt,
                'msisdn': item.get('phone', ''),
                'phoneNumber': item.get('phone', ''),
                'bill_ref_number': item.get('destination', 'WALLET-TOPUP'),
                'accountReference': item.get('destination', 'WALLET-TOPUP'),
                'first_name': u_name.split()[0] if u_name else '',
                'last_name': " ".join(u_name.split()[1:]) if u_name else '',
                'status': status,
                'reconciled': True,
                'matched_user_name': u_name,
                'matched_user_id': item.get('user_id', ''),
                'trans_time': ts_str,
                'timestamp': ts_str,
                'source': 'M-PESA Direct'
            })

        # Sort combined stream by timestamp descending
        collections.sort(key=lambda x: x.get('timestamp', ''), reverse=True)

        return jsonify({
            'paybill_number': os.getenv('MPESA_SHORTCODE', '4050545'),
            'total_collected': total_volume,
            'total_volume': total_volume,
            'total_transactions': len(collections),
            'success_rate': f"{(success_count / max(1, len(collections))) * 100:.1f}%",
            'recent_collections': collections[:50]
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
