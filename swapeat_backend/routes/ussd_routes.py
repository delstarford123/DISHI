from flask import Blueprint, request, jsonify

ussd_bp = Blueprint('ussd', __name__)

@ussd_bp.route('/webhook', methods=['POST'])
def ussd_callback():
    # Safaricom USSD Fallback Integration webhook handler
    # Reads data like sessionId, serviceCode, phoneNumber, text
    
    data = request.form
    text = data.get("text", "")
    
    # Simple USSD logic flow
    if text == "":
        response = "CON Welcome to DISHI USSD\n"
        response += "1. Student Menu\n"
        response += "2. Parent Menu"
    elif text == "1":
        response = "CON Enter Vendor ID:"
    elif text.startswith("1*"):
        parts = text.split("*")
        if len(parts) == 2:
            response = "CON Enter Amount:"
        elif len(parts) == 3:
            response = "CON Enter PIN to confirm:"
        elif len(parts) == 4:
            # Process transaction
            response = "END Payment successful to Vendor ID " + parts[1]
    elif text == "2":
        response = "CON Parent Dashboard\n"
        response += "1. Check Child Balance\n"
        response += "2. Freeze Child Wallet"
    elif text == "2*1":
        response = "END John's wallet balance is Ksh 850."
    elif text == "2*2":
        response = "END John's wallet has been frozen successfully."
    else:
        response = "END Invalid choice."
        
    # Return plain text for Africa's Talking / Safaricom USSD gateway
    return response, 200, {'Content-Type': 'text/plain'}
