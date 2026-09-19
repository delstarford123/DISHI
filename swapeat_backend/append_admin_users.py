import os

code = '''
@admin_bp.route('/users/all', methods=['GET'])
def get_all_users():
    if not verify_admin(request):
        return jsonify({"error": "Unauthorized"}), 401
    try:
        db = firestore.client()
        # In a production environment with millions of users, we'd paginate this.
        # But for this dashboard, we just fetch a limited number of users (e.g. 500)
        docs = db.collection('users').limit(500).get()
        users = []
        for doc in docs:
            d = doc.to_dict()
            d['uid'] = doc.id
            if 'createdAt' in d and hasattr(d['createdAt'], 'isoformat'):
                d['createdAt'] = d['createdAt'].isoformat()
            users.append(d)
        return jsonify({"status": "success", "users": users}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
'''

with open('routes/admin_routes.py', 'a', encoding='utf-8') as f:
    f.write(code)
print('Routes added to admin_routes.py')
