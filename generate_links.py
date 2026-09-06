import base64

def generate_link(collection, fields):
    path = f"projects/swapeat-39f5e/databases/(default)/collectionGroups/{collection}/indexes/_"
    out = b'\x0a' + bytes([len(path)]) + path.encode('utf-8')
    out += b'\x10\x01'
    
    # If the last field is descending (2), the __name__ field is also descending (2)
    # If the last field is ascending (1), the __name__ field is also ascending (1)
    all_fields = fields + [('__name__', fields[-1][1])]
        
    for name, order in all_fields:
        name_bytes = b'\x0a' + bytes([len(name)]) + name.encode('utf-8')
        order_bytes = b'\x10' + bytes([order])
        msg = name_bytes + order_bytes
        out += b'\x1a' + bytes([len(msg)]) + msg
        
    encoded = base64.urlsafe_b64encode(out).decode('utf-8').rstrip('=')
    return f"https://console.firebase.google.com/v1/r/project/swapeat-39f5e/firestore/indexes?create_composite={encoded}"

print("\n--- CLICK THE LINKS BELOW TO CREATE THE MISSING INDEXES ---\n")

print("1. Keja Cooking:")
print(generate_link('keja_cooking', [('status', 1), ('created_at', 2)]))

print("\n2. Maintenance Tickets:")
print(generate_link('maintenance_tickets', [('student_id', 1), ('room_id', 1), ('created_at', 2)]))

print("\n3. Active Gigs (Moving):")
print(generate_link('deliv_requests', [('student_id', 1), ('status', 1)]))

print("\n4. Active Gigs (Food):")
print(generate_link('vendor_kds_orders', [('studentId', 1), ('delivery_status', 1)]))

print("\n----------------------------------------------------\n")
