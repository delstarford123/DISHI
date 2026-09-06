import base64
from pathlib import Path
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.x509 import load_pem_x509_certificate, load_der_x509_certificate

def generate_security_credential(password: str, cert_path: str | Path) -> str:
    """
    Encrypts the M-Pesa API operator password using Safaricom's Public Key.
    """
    cert_path = Path(cert_path)
    if not cert_path.is_file():
        raise FileNotFoundError(f"Certificate file not found at: {cert_path}")

    with open(cert_path, "rb") as cert_file:
        cert_data = cert_file.read()
        
        # Safaricom certificates are often in PEM format, despite the .cer extension.
        # We try to load it as PEM first.
        try:
            cert = load_pem_x509_certificate(cert_data, default_backend())
        except ValueError:
            # If it fails, we fall back to attempting a DER binary load
            try:
                cert = load_der_x509_certificate(cert_data, default_backend())
            except Exception as e:
                raise ValueError("Could not parse the certificate. Make sure the file is valid and not corrupted.") from e

        public_key = cert.public_key()

    # Encrypt the password using RSA algorithm and PKCS1v15 padding
    encrypted_password = public_key.encrypt(
        password.encode('utf-8'),
        padding.PKCS1v15()
    )
    
    # Convert the resulting encrypted byte array into a base64 encoded string
    return base64.b64encode(encrypted_password).decode('utf-8')

if __name__ == "__main__":
    # --- CONFIGURATION ---
    # ⚠️ Use the API password you just set in the portal, NOT your USSD PIN!
    OPERATOR_PASSWORD = "Delstarford@123" 
    CERTIFICATE_FILE = "ProductionCertificate.cer" 

    try:
        credential = generate_security_credential(OPERATOR_PASSWORD, CERTIFICATE_FILE)
        print("\n✅ SUCCESS! Copy the strings below and paste them into your .env file:")
        print("=" * 70)
        print(f'SECURITY_CREDENTIAL="{credential}"')
        print(f'DARAJA_SECURITY_CREDENTIAL="{credential}"')
        print("=" * 70)
    except Exception as e:
        print(f"❌ An error occurred: {e}")