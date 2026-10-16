import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

server = "mail.delstarfordworks.co.ke"
port_ssl = 465
port_tls = 587
username = "dishi@delstarfordworks.co.ke"
password = "dishi@delstarfordworks.co.ke"
sender = "dishi@delstarfordworks.co.ke"
recipient = "delstarfordisaiah@gmail.com"

print(f"--- Testing SMTP SSL on {server}:{port_ssl} ---")
try:
    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(server, port_ssl, context=context, timeout=15) as s:
        print("Connected via SSL! Logging in...")
        s.login(username, password)
        print("Login SUCCESSFUL via SSL!")
        
        msg = MIMEMultipart()
        msg['Subject'] = "DISHI OTP Email Test"
        msg['From'] = sender
        msg['To'] = recipient
        msg.attach(MIMEText("Hello Delstarford,\n\nThis is a test email for DISHI OTP system.", "plain"))
        
        print(f"Sending test email to {recipient}...")
        s.sendmail(sender, recipient, msg.as_string())
        print("EMAIL SENT SUCCESSFULLY via SSL 465!")
except Exception as e:
    print(f"SSL 465 FAILED: {type(e).__name__}: {e}")

print(f"\n--- Testing SMTP STARTTLS on {server}:{port_tls} ---")
try:
    context = ssl.create_default_context()
    with smtplib.SMTP(server, port_tls, timeout=15) as s:
        s.ehlo()
        print("Connected via STARTTLS! Starting TLS...")
        s.starttls(context=context)
        s.ehlo()
        print("Logging in...")
        s.login(username, password)
        print("Login SUCCESSFUL via STARTTLS!")
        
        msg = MIMEMultipart()
        msg['Subject'] = "DISHI OTP Email Test (STARTTLS)"
        msg['From'] = sender
        msg['To'] = recipient
        msg.attach(MIMEText("Hello Delstarford,\n\nThis is a test email for DISHI OTP system via STARTTLS.", "plain"))
        
        print(f"Sending test email to {recipient}...")
        s.sendmail(sender, recipient, msg.as_string())
        print("EMAIL SENT SUCCESSFULLY via STARTTLS 587!")
except Exception as e:
    print(f"STARTTLS 587 FAILED: {type(e).__name__}: {e}")
