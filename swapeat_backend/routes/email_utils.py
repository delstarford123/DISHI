"""
DISHI Email Utility System
Provides ultra-modern, DISHI-branded HTML email templates for all communications.
Brand Identity: Dark Space (#080D18), Card Slate (#101726), Neon Mint (#05D5AA), Energy Pink (#FF2A6D).
Official Contact & Support: dishi@delstarfordworks.co.ke
"""

DISHI_LOGO_URL = "https://dishi.delstarfordworks.co.ke/static/img/dishi_logo.png"
DISHI_PRIMARY_MINT = "#05D5AA"
DISHI_PRIMARY_PINK = "#FF2A6D"
DISHI_DARK = "#080D18"
DISHI_CARD = "#101726"
DISHI_CARD_ELEVATED = "#162033"
DISHI_BORDER = "rgba(255, 255, 255, 0.08)"
DISHI_SUPPORT_EMAIL = "dishi@delstarfordworks.co.ke"


def _base_template(content_html: str, preheader: str = "") -> str:
    """Wraps content in the premium DISHI dark glassmorphism email shell."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>DISHI</title>
  <!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap');
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{ background-color: {DISHI_DARK}; font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #FFFFFF; -webkit-font-smoothing: antialiased; }}
    a {{ color: {DISHI_PRIMARY_MINT}; text-decoration: none; }}
    .wrapper {{ max-width: 600px; margin: 0 auto; background-color: {DISHI_DARK}; padding: 24px 12px; }}
    /* Header */
    .header {{ background: linear-gradient(180deg, #101726 0%, #080D18 100%);
               border: 1px solid {DISHI_BORDER}; border-bottom: 2px solid {DISHI_PRIMARY_MINT};
               border-radius: 20px 20px 0 0; padding: 28px 32px 24px; text-align: center; }}
    .header img {{ max-height: 48px; width: auto; border-radius: 10px; }}
    .brand-title {{ font-size: 20px; font-weight: 800; color: #FFFFFF; letter-spacing: 2px; margin-top: 10px; text-transform: uppercase; }}
    /* Body card */
    .card {{ background-color: {DISHI_CARD}; border-radius: 0 0 20px 20px; padding: 32px 28px;
             border: 1px solid {DISHI_BORDER}; border-top: none;
             box-shadow: 0 20px 50px rgba(0, 0, 0, 0.5); }}
    /* Divider */
    .divider {{ height: 1px; background: rgba(255,255,255,0.08); margin: 24px 0; }}
    /* Greeting */
    .greeting {{ font-size: 22px; font-weight: 800; color: #FFFFFF; margin-bottom: 8px; line-height: 1.3; }}
    /* Body text */
    .body-text {{ font-size: 15px; line-height: 1.7; color: #94A3B8; }}
    /* Highlight box */
    .highlight {{ background: {DISHI_CARD_ELEVATED}; border-left: 3px solid {DISHI_PRIMARY_MINT};
                  border-radius: 12px; padding: 16px 20px; margin: 20px 0; border-top: 1px solid {DISHI_BORDER};
                  border-right: 1px solid {DISHI_BORDER}; border-bottom: 1px solid {DISHI_BORDER}; }}
    .highlight p {{ font-size: 14px; color: #E2E8F0; line-height: 1.6; }}
    /* CTA Button */
    .btn {{ display: inline-block; background: linear-gradient(135deg, {DISHI_PRIMARY_MINT} 0%, #00B48A 100%);
            color: #080D18 !important; font-weight: 800; font-size: 15px; padding: 15px 34px; border-radius: 50px;
            margin-top: 24px; text-decoration: none; letter-spacing: 0.3px; box-shadow: 0 8px 25px rgba(5, 213, 170, 0.35); }}
    /* Match chip */
    .chip {{ display: inline-block; background: rgba(5, 213, 170, 0.12); color: {DISHI_PRIMARY_MINT};
             border: 1px solid rgba(5, 213, 170, 0.35); border-radius: 50px; padding: 6px 16px;
             font-size: 13px; font-weight: 700; margin: 4px 4px 4px 0; }}
    /* Alert box */
    .alert-box {{ background: rgba(255, 71, 87, 0.12); border: 1px solid rgba(255, 71, 87, 0.35);
                  border-radius: 14px; padding: 18px 20px; margin: 20px 0; }}
    .alert-box p {{ color: #FF9F9F; font-size: 14px; line-height: 1.5; }}
    /* Footer */
    .footer {{ text-align: center; padding: 28px 24px 16px; color: #64748B; font-size: 12px; line-height: 1.8; }}
    .footer a {{ color: {DISHI_PRIMARY_MINT}; text-decoration: none; font-weight: 600; }}
    .footer .brand {{ color: {DISHI_PRIMARY_MINT}; font-weight: 800; font-size: 13px; letter-spacing: 0.5px; }}
  </style>
</head>
<body>
  {'<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">' + preheader + '</div>' if preheader else ''}
  <div class="wrapper">

    <!-- Header -->
    <div class="header">
      <img src="{DISHI_LOGO_URL}" alt="DISHI" onerror="this.style.display='none'" />
      <div class="brand-title">DISHI</div>
    </div>

    <!-- Content Card -->
    <div class="card">
      {content_html}
    </div>

    <!-- Footer -->
    <div class="footer">
      <p class="brand">DISHI &bull; Smart Campus Meals, NFC &amp; Digital Operating System</p>
      <p style="margin-top:6px;">Delstarford Works Ltd &bull; Nairobi, Kenya</p>
      <p style="margin-top:8px;">
        <a href="https://dishi.delstarfordworks.co.ke">Web Ecosystem</a> &nbsp;&bull;&nbsp;
        <a href="mailto:{DISHI_SUPPORT_EMAIL}">{DISHI_SUPPORT_EMAIL}</a>
      </p>
      <p style="margin-top:12px; color: #475569; font-size: 11px;">
        Official automated notification for registered DISHI users.<br/>
        &copy; 2026 Delstarford Works Ltd. All rights reserved.
      </p>
    </div>

  </div>
</body>
</html>"""


def match_digest_email(student_name: str, matches: list) -> tuple:
    """Returns (subject, html_body) for the weekly match digest email."""
    name = student_name or "Student"
    match_count = len(matches)
    subject = f"💘 {match_count} New Match{'es' if match_count != 1 else ''} Waiting on DISHI!"

    chips_html = "".join(
        f'<div style="margin:6px 0;"><span class="chip">💚 {m}</span></div>'
        for m in matches[:5]
    )

    content = f"""
      <p class="greeting">Hey {name}! 💘</p>
      <p class="body-text" style="margin-top:8px;">
        You have <strong style="color:#FFFFFF;">{match_count} compatible student{'s' if match_count != 1 else ''}</strong>
        at your campus who match your vibe. Don't keep them waiting!
      </p>
      <div class="divider"></div>
      <p style="font-size:12px;font-weight:700;color:#64748B;text-transform:uppercase;letter-spacing:1px;margin-bottom:12px;">
        Your Top Campus Matches
      </p>
      <div style="margin-bottom:8px;">{chips_html}</div>
      <div class="highlight" style="margin-top:24px;">
        <p>💡 <strong>Pro Tip:</strong> Students at the same university have a
        <strong>3x higher chance</strong> of connecting over a campus meal. Open DISHI and start a conversation!</p>
      </div>
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke" class="btn">View Matches in DISHI &rarr;</a>
      </div>
      <div class="divider"></div>
      <p class="body-text" style="font-size:12px;">
        Powered by <strong style="color:{DISHI_PRIMARY_MINT};">DISHI Match Gold</strong> &mdash; verified campus matchmaking.
      </p>
    """
    return subject, _base_template(content, preheader=f"You have {match_count} new matches on DISHI!")


def sos_alert_email(user_id: str, user_name: str = "Unknown") -> tuple:
    """Returns (subject, html_body) for an SOS distress alert."""
    from datetime import datetime
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    subject = f"🚨 EMERGENCY SOS ALERT — {user_name} ({user_id})"

    content = f"""
      <div class="alert-box">
        <p style="font-size:16px; font-weight:800; color:#FF4757;">🚨 CRITICAL SOS ALERT &mdash; Immediate Action Required</p>
        <p style="margin-top:8px; color:#FCA5A5;">An SOS emergency signal has been triggered by a DISHI campus student.</p>
      </div>
      <p class="greeting" style="color:#FF4757;">Student Distress Signal</p>
      <div class="divider"></div>
      <table style="width:100%;border-collapse:collapse;">
        <tr>
          <td style="padding:10px 0;color:#64748B;font-size:14px;width:40%;">Student Name</td>
          <td style="padding:10px 0;color:#FFFFFF;font-size:14px;font-weight:700;">{user_name}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">User ID</td>
          <td style="padding:10px 0;color:#FFFFFF;font-size:14px;font-weight:600;">{user_id}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">Triggered Timestamp</td>
          <td style="padding:10px 0;color:#FFFFFF;font-size:14px;font-weight:600;">{timestamp}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">Safety Feature</td>
          <td style="padding:10px 0;color:{DISHI_PRIMARY_MINT};font-size:14px;font-weight:700;">DISHI Campus Safe Walk</td>
        </tr>
      </table>
      <div class="divider"></div>
      <p class="body-text">
        Please check the <strong style="color:#FFFFFF;">DISHI Admin Security Desk</strong> immediately or contact local campus security.
      </p>
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke/api/v1/admin" class="btn" style="background:#FF4757; color:#FFFFFF !important;">
          Open Admin Security Desk &rarr;
        </a>
      </div>
    """
    return subject, _base_template(content, preheader=f"URGENT: SOS alert from {user_name}")


def support_ticket_email(student_id: str, student_name: str, subject_text: str, description: str) -> tuple:
    """Returns (subject, html_body) for a support ticket."""
    from datetime import datetime
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    email_subject = f"[DISHI Support] {subject_text}"

    content = f"""
      <p class="greeting">New Student Support Ticket 🎫</p>
      <p class="body-text" style="margin-top:8px;">
        A student has submitted an inquiry to the DISHI Help Desk.
      </p>
      <div class="divider"></div>
      <table style="width:100%;border-collapse:collapse;">
        <tr>
          <td style="padding:10px 0;color:#64748B;font-size:14px;width:35%;">Student Name</td>
          <td style="padding:10px 0;color:#FFFFFF;font-size:14px;font-weight:700;">{student_name}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">Student ID</td>
          <td style="padding:10px 0;color:#FFFFFF;font-size:14px;font-weight:600;">{student_id}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">Submitted At</td>
          <td style="padding:10px 0;color:#FFFFFF;font-size:14px;font-weight:600;">{timestamp}</td>
        </tr>
      </table>
      <div class="divider"></div>
      <p style="font-size:12px;font-weight:700;color:#64748B;text-transform:uppercase;letter-spacing:1px;margin-bottom:6px;">
        Issue Subject
      </p>
      <p style="font-size:16px;font-weight:700;color:#FFFFFF;">{subject_text}</p>
      <div class="divider"></div>
      <p style="font-size:12px;font-weight:700;color:#64748B;text-transform:uppercase;letter-spacing:1px;margin-bottom:8px;">
        Message Description
      </p>
      <div class="highlight">
        <p style="white-space:pre-wrap;">{description}</p>
      </div>
      <div style="text-align:center;margin-top:12px;">
        <a href="https://dishi.delstarfordworks.co.ke/api/v1/admin" class="btn">Respond in Admin Console &rarr;</a>
      </div>
    """
    return email_subject, _base_template(content, preheader=f"Support ticket from {student_name}: {subject_text}")


def semester_summary_email(student_name: str, student_id: str, summary_text: str = "") -> tuple:
    """Returns (subject, html_body) for the end-of-semester summary."""
    name = student_name or "Student"
    subject = f"📊 Your DISHI Semester Financial Wrapped, {name}"

    content = f"""
      <p class="greeting">Semester Wrapped 📊</p>
      <p class="body-text" style="margin-top:8px;">
        Hi <strong style="color:#FFFFFF;">{name}</strong>,<br/><br/>
        Here is your personalized end-of-semester campus meal and finance breakdown from DISHI.
      </p>
      <div class="divider"></div>
      <div class="highlight">
        <p><strong>Student ID:</strong> {student_id}</p>
        <p style="margin-top:8px;white-space:pre-wrap;">{summary_text or "Your full cafeteria savings, nutrition grade, and budget overview are ready in the DISHI app."}</p>
      </div>
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke" class="btn">View Full Wrapped Report &rarr;</a>
      </div>
      <div class="divider"></div>
      <p class="body-text" style="font-size:12px;">
        Thank you for trusting DISHI for your campus nutrition. Have a productive break! 🎓
      </p>
    """
    return subject, _base_template(content, preheader=f"Your DISHI semester financial summary is ready, {name}!")


def pin_reset_otp_email(user_name: str, otp_code: str, device_hint: str = "") -> tuple:
    """Returns (subject, html_body) for the PIN reset OTP email."""
    name = user_name or "there"
    subject = "🔒 Your DISHI One-Time Security Code"
    device_note = (
        f'<p class="body-text" style="margin-top:10px;font-size:13px;">'
        f'Requested from device: <strong style="color:#FFFFFF;">{device_hint}</strong></p>'
    ) if device_hint else ""

    content = f"""
      <p class="greeting">PIN Reset Request 🔒</p>
      <p class="body-text" style="margin-top:8px;">
        Hi <strong style="color:#FFFFFF;">{name}</strong>,<br/><br/>
        We received a request to verify or reset your DISHI Wallet PIN. Enter the one-time authorization code below:
      </p>

      <div class="divider"></div>

      <!-- OTP Box -->
      <div style="text-align:center;margin:28px 0;">
        <p style="font-size:12px;font-weight:700;color:#64748B;text-transform:uppercase;letter-spacing:2px;margin-bottom:14px;">Your Verification Code</p>
        <div style="display:inline-block;background:#0B111E;border:2px solid {DISHI_PRIMARY_MINT};border-radius:16px;padding:18px 36px;box-shadow:0 0 25px rgba(5,213,170,0.3);">
          <span style="font-size:40px;font-weight:900;color:{DISHI_PRIMARY_MINT};letter-spacing:10px;font-family:monospace;">{otp_code}</span>
        </div>
        <p style="margin-top:14px;font-size:13px;color:#94A3B8;">
          ⏱️ Valid for <strong style="color:#FFFFFF;">10 minutes</strong>
        </p>
      </div>

      <div class="divider"></div>

      {device_note}

      <div class="alert-box">
        <p style="font-weight:700;color:#FF4757;">🛡️ Security Advisory</p>
        <p style="margin-top:6px;">If you did not request this verification, your account may be vulnerable.
        Contact our team immediately at <a href="mailto:{DISHI_SUPPORT_EMAIL}" style="color:#FF9F9F;font-weight:700;">{DISHI_SUPPORT_EMAIL}</a>.
        DISHI will never ask for your code over phone or chat.</p>
      </div>

      <div class="highlight" style="margin-top:20px;">
        <p>💡 <strong>Tip:</strong> You can also enable Biometric &amp; Fingerprint login in the DISHI Settings to authenticate without entering your PIN every time.</p>
      </div>
    """
    return subject, _base_template(content, preheader=f"Your DISHI PIN reset code is {otp_code} (expires in 10 mins)")


def monthly_nutrition_report_email(student_name: str, month_name: str, macros: dict) -> tuple:
    """Returns (subject, html_body) for the monthly nutrition report card."""
    subject = f"🥗 DISHI Monthly Nutrition Report: {student_name} ({month_name})"
    
    content = f"""
      <h2 class="greeting">Campus Nutrition Card 🥗</h2>
      <p class="body-text">Here is a verified summary of meals consumed by <strong style="color:#FFFFFF;">{student_name}</strong> during {month_name}.</p>
      
      <div class="divider"></div>
      
      <div style="text-align:center; padding: 16px 0;">
        <div style="display:inline-block; margin: 4px; padding: 16px 20px; background: rgba(5,213,170,0.1); border: 1px solid rgba(5,213,170,0.3); border-radius: 12px;">
            <p style="font-size:11px; color:#94A3B8; text-transform:uppercase; font-weight:700;">Carbs</p>
            <p style="font-size:26px; font-weight:800; color:{DISHI_PRIMARY_MINT};">{macros.get('carbs', 0)}%</p>
        </div>
        <div style="display:inline-block; margin: 4px; padding: 16px 20px; background: rgba(0,240,255,0.1); border: 1px solid rgba(0,240,255,0.3); border-radius: 12px;">
            <p style="font-size:11px; color:#94A3B8; text-transform:uppercase; font-weight:700;">Protein</p>
            <p style="font-size:26px; font-weight:800; color:#00F0FF;">{macros.get('protein', 0)}%</p>
        </div>
        <div style="display:inline-block; margin: 4px; padding: 16px 20px; background: rgba(255,42,109,0.1); border: 1px solid rgba(255,42,109,0.3); border-radius: 12px;">
            <p style="font-size:11px; color:#94A3B8; text-transform:uppercase; font-weight:700;">Snacks</p>
            <p style="font-size:26px; font-weight:800; color:{DISHI_PRIMARY_PINK};">{macros.get('sugar', 0)}%</p>
        </div>
      </div>
      
      <div class="highlight">
        <p><strong>Parent Assurance Note:</strong> Parents can configure daily meal allowances, spending limits, and dietary guardrails directly in the DISHI Parent Console.</p>
      </div>
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke" class="btn">Open Parent Dashboard &rarr;</a>
      </div>
    """
    return subject, _base_template(content, preheader=f"View {student_name}'s monthly nutrition breakdown for {month_name}")


def harambee_thank_you_email(student_name: str, campaign_title: str, amount: float) -> tuple:
    """Returns (subject, html_body) for a Harambee campaign donation thank you email."""
    name = student_name or "a DISHI Student"
    subject = "🤝 Asante Sana! Your DISHI Harambee Contribution was Successful"
    
    content = f"""
      <p class="greeting">Thank You for Empowering Education! 🤝</p>
      <p class="body-text" style="margin-top:8px;">
        Your contribution of <strong style="color:{DISHI_PRIMARY_MINT};">KES {amount:,.0f}</strong> has been successfully credited directly to the student's project wallet.
      </p>
      
      <div class="divider"></div>
      
      <div class="highlight">
        <p style="font-size:11px;text-transform:uppercase;color:#64748B;letter-spacing:1px;margin-bottom:6px;font-weight:700;">Campaign Supported</p>
        <p style="font-size:17px;font-weight:800;color:#FFFFFF;margin-bottom:8px;">{campaign_title or 'Student Fund'}</p>
        <p><strong>Organizer / Beneficiary:</strong> {name}</p>
        <p><strong>Platform Commission:</strong> 0% (DISHI charges 0% on student Harambees)</p>
      </div>
      
      <p class="body-text" style="margin-top:20px;">
        On behalf of {name} and the entire campus community, thank you for making a real difference.
      </p>
      
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke" class="btn">Explore DISHI Community &rarr;</a>
      </div>
    """
    return subject, _base_template(content, preheader="Your donation receipt and appreciation from DISHI.")


def event_ticket_email(event_title: str, ticket_tier: str, amount: float, ticket_id: str) -> tuple:
    """Returns (subject, html_body) for a successful event ticket purchase."""
    subject = f"🎟️ Your Verified Ticket for {event_title} is Ready!"
    
    content = f"""
      <p class="greeting">You're Attending {event_title}! 🎉</p>
      <p class="body-text" style="margin-top:8px;">
        Payment of <strong style="color:#FFFFFF;">KES {amount:,.0f}</strong> confirmed. Here is your official entry pass:
      </p>
      
      <div class="divider"></div>
      
      <div style="text-align:center;margin:24px 0;">
        <p style="font-size:12px;font-weight:700;color:#64748B;text-transform:uppercase;letter-spacing:2px;margin-bottom:14px;">Entry QR Code Pass</p>
        <div style="display:inline-block;background:#FFFFFF;border:2px solid {DISHI_PRIMARY_MINT};border-radius:16px;padding:16px;box-shadow:0 0 25px rgba(5,213,170,0.3);">
          <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=ticket_scan_{ticket_id}" alt="QR Code" width="180" height="180" style="display:block;border-radius:8px;"/>
        </div>
        <p style="margin-top:14px;font-size:14px;color:#94A3B8;">
          Tier: <strong style="color:{DISHI_PRIMARY_MINT};">{ticket_tier}</strong><br/>
          Ticket Code: <strong style="color:#FFFFFF;">{ticket_id}</strong>
        </p>
      </div>

      <div class="highlight">
        <p><strong>Door Entrance Note:</strong> Present this QR pass on your phone or printed at the gate. The organizer will scan it using the DISHI scanner app for instant verification.</p>
      </div>
      
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke" class="btn">View in DISHI App &rarr;</a>
      </div>
    """
    return subject, _base_template(content, preheader=f"Your {ticket_tier} entry ticket for {event_title}")


def campus_gig_alert_email(worker_name: str, category: str, price: float) -> tuple:
    """Returns (subject, html_body) for a Campus Gig request alert."""
    name = worker_name or "DISHI Partner"
    subject = f"💼 New {category} Gig Available on Campus!"
    
    content = f"""
      <p class="greeting">New Campus Gig Alert! 💼</p>
      <p class="body-text" style="margin-top:8px;">
        Hi <strong style="color:#FFFFFF;">{name}</strong>,<br/><br/>
        A fellow student just posted a request for <strong style="color:{DISHI_PRIMARY_MINT};">{category}</strong>. As an active provider, you can claim this gig right now:
      </p>
      
      <div class="divider"></div>
      
      <div class="highlight">
        <p style="font-size:11px;text-transform:uppercase;color:#64748B;letter-spacing:1px;margin-bottom:6px;font-weight:700;">Opportunity Details</p>
        <p style="font-size:17px;font-weight:800;color:#FFFFFF;margin-bottom:6px;">Category: {category}</p>
        <p><strong>Offer Budget:</strong> KES {price:,.2f}</p>
      </div>
      
      <p class="body-text" style="margin-top:16px;">
        Open DISHI immediately to review and accept the gig before another campus provider does!
      </p>
      
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke" class="btn">Claim Gig in DISHI &rarr;</a>
      </div>
    """
    return subject, _base_template(content, preheader=f"A new {category} gig is available on campus!")


def campus_gig_accepted_email(requester_name: str, worker_name: str, category: str) -> tuple:
    """Returns (subject, html_body) for when a worker accepts a gig request."""
    r_name = requester_name or "Student"
    w_name = worker_name or "A DISHI Provider"
    subject = f"✅ Your {category} Gig Request Was Accepted!"
    
    content = f"""
      <p class="greeting">Gig Accepted! ✅</p>
      <p class="body-text" style="margin-top:8px;">
        Hi <strong style="color:#FFFFFF;">{r_name}</strong>,<br/><br/>
        Great news! <strong style="color:{DISHI_PRIMARY_MINT};">{w_name}</strong> has accepted your <strong style="color:#FFFFFF;">{category}</strong> request.
      </p>
      
      <div class="divider"></div>
      
      <div class="highlight">
        <p style="font-size:11px;text-transform:uppercase;color:#64748B;letter-spacing:1px;margin-bottom:6px;font-weight:700;">Next Steps</p>
        <p><strong>1.</strong> Open the DISHI app &rarr; Campus Gigs &rarr; Active Gigs.</p>
        <p><strong>2.</strong> Tap <strong>Chat</strong> to coordinate timing with {w_name}.</p>
        <p><strong>3.</strong> Funds remain safe in DISHI Escrow until you confirm work completion.</p>
      </div>
      
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke" class="btn">Open App to Chat &rarr;</a>
      </div>
    """
    return subject, _base_template(content, preheader=f"{w_name} has accepted your {category} gig request!")


def generate_staff_appointment_email(
    name: str,
    role: str,
    department: str,
    base_salary: float,
    salary_type: str = "MONTHLY",
    expectations: str = "",
    phone: str = ""
) -> tuple:
    """
    Returns (subject, html_body, plain_body) for official staff onboarding and appointment letter.
    """
    staff_name = name or "Staff Member"
    staff_role = role or "Operational Staff"
    dept_name = department or "Operations Department"
    salary_str = f"KES {base_salary:,.2f}"
    cycle_str = salary_type.title() if salary_type else "Monthly"
    phone_str = phone or "Registered Phone"
    app_download_url = "https://dishi.delstarfordworks.co.ke"
    play_store_url = "https://play.google.com/store/apps/details?id=co.ke.delstarfordworks.dishi"
    
    if not expectations.strip():
        expectations_html = f"""
        <ul style="margin-left: 20px; color: #CBD5E1; font-size: 14px; line-height: 1.8;">
          <li>Support daily operational delivery across {dept_name}.</li>
          <li>Ensure seamless customer experience and dignified student cafeteria meal distribution.</li>
          <li>Reconcile operational logs and report key performance indicators to Department Leads.</li>
          <li>Comply with DISHI enterprise governance standards and zero-tolerance wash trading policies.</li>
        </ul>
        """
        expectations_plain = f"- Support daily operational delivery across {dept_name}.\n- Ensure seamless customer experience.\n- Reconcile operational logs and report KPIs."
    else:
        exp_lines = [line.strip() for line in expectations.strip().split('\n') if line.strip()]
        if len(exp_lines) > 1:
            list_items = "".join([f"<li>{l.lstrip('-*• ')}</li>" for l in exp_lines])
            expectations_html = f"""<ul style="margin-left: 20px; color: #CBD5E1; font-size: 14px; line-height: 1.8;">{list_items}</ul>"""
            expectations_plain = "\n".join([f"- {l.lstrip('-*• ')}" for l in exp_lines])
        else:
            expectations_html = f"""<p style="color: #CBD5E1; font-size: 14px; line-height: 1.7;">{expectations.strip()}</p>"""
            expectations_plain = expectations.strip()

    subject = f"Official DISHI Appointment: Welcome to {dept_name} as {staff_role}"
    
    content = f"""
      <p class="greeting">Welcome to DISHI, {staff_name}! 🚀</p>
      <p class="body-text" style="margin-top:8px;">
        We are thrilled to officially welcome you to the <strong style="color:#FFFFFF;">DISHI Operations Team</strong> at Delstarford Works Ltd. 
        Your appointment has been confirmed in our enterprise personnel register.
      </p>

      <div class="divider"></div>

      <div class="highlight" style="border-left: 3px solid #05D5AA; background: #162033;">
        <p style="font-size:11px;text-transform:uppercase;color:#05D5AA;letter-spacing:1.2px;margin-bottom:10px;font-weight:800;">
          APPOINTMENT &amp; PAYROLL SUMMARY
        </p>
        <table style="width: 100%; border-collapse: collapse; font-size: 13px; color: #E2E8F0;">
          <tr>
            <td style="padding: 6px 0; color: #94A3B8; width: 40%;">🏢 Department:</td>
            <td style="padding: 6px 0; font-weight: 700; color: #FFFFFF;">{dept_name}</td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94A3B8;">💼 Assigned Role:</td>
            <td style="padding: 6px 0; font-weight: 700; color: #05D5AA;">{staff_role}</td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94A3B8;">💵 Base Compensation:</td>
            <td style="padding: 6px 0; font-weight: 700; color: #FFFFFF;">{salary_str} <span style="font-size: 11px; color: #94A3B8;">({cycle_str})</span></td>
          </tr>
          <tr>
            <td style="padding: 6px 0; color: #94A3B8;">📱 M-PESA Payout:</td>
            <td style="padding: 6px 0; font-weight: 600; color: #CBD5E1;">{phone_str}</td>
          </tr>
        </table>
      </div>

      <div style="background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; padding: 18px 20px; margin: 20px 0;">
        <p style="font-size:11px;text-transform:uppercase;color:#FF6F00;letter-spacing:1.2px;margin-bottom:8px;font-weight:800;">
          📋 EXPECTED DUTIES &amp; DELIVERABLES
        </p>
        {expectations_html}
      </div>

      <div class="divider"></div>

      <p class="body-text" style="font-weight: 600; color: #FFFFFF; margin-bottom: 6px;">
        📲 Download the DISHI App &amp; Access Your Staff Portal
      </p>
      <p class="body-text" style="font-size: 13px;">
        Install the DISHI mobile application or access our ecosystem to view operational tasks, review your daily shifts, and manage university meal workflows.
      </p>

      <div style="text-align:center; margin: 24px 0 10px;">
        <a href="{play_store_url}" class="btn" style="background: linear-gradient(135deg, #05D5AA 0%, #00B48A 100%); margin-right: 8px;">
          Download from Google Play &rarr;
        </a>
      </div>
      <div style="text-align:center;">
        <a href="{app_download_url}" style="font-size: 12px; color: #05D5AA; text-decoration: underline;">
          Or open DISHI Web Ecosystem ({app_download_url})
        </a>
      </div>

      <div class="highlight" style="margin-top: 24px; border-left: 3px solid #3B82F6;">
        <p style="font-size:11px;text-transform:uppercase;color:#3B82F6;letter-spacing:1px;margin-bottom:6px;font-weight:700;">Getting Started</p>
        <p>1. Open the DISHI App &rarr; Log in with your registered phone number (<strong>{phone_str}</strong>).</p>
        <p>2. Complete identity confirmation via SMS OTP.</p>
        <p>3. If you require assistance, contact <strong>dishi@delstarfordworks.co.ke</strong>.</p>
      </div>
    """

    plain_body = f"""Dear {staff_name},

Welcome to DISHI at Delstarford Works Ltd!
You have been appointed to {dept_name} as {staff_role}.

APPOINTMENT DETAILS:
- Department: {dept_name}
- Role: {staff_role}
- Base Compensation: {salary_str} ({cycle_str})
- M-PESA Phone: {phone_str}

EXPECTED DUTIES & DELIVERABLES:
{expectations_plain}

DOWNLOAD THE APP:
Install the DISHI App from Google Play: {play_store_url}
Or visit our web ecosystem: {app_download_url}

Log in using your registered phone number: {phone_str}.

Best regards,
DISHI Operations Team
Delstarford Works Ltd
dishi@delstarfordworks.co.ke
"""

    return subject, _base_template(content, preheader=f"Welcome to DISHI! Official appointment details for {staff_name} as {staff_role}."), plain_body


def welcome_account_email(user_name: str, user_email: str, role: str = "Student") -> tuple:
    """Returns (subject, html_body, plain_body) for new account registration & onboarding."""
    name = user_name or "there"
    subject = "🎉 Welcome to DISHI — Your Account is Ready"
    role_title = role.replace('_', ' ').capitalize() if role else "Student"

    content = f"""
      <p class="greeting">Welcome to DISHI, {name}! 🎉</p>
      <p class="body-text" style="margin-top:8px;">
        Your official DISHI account has been created successfully. You can now use DISHI for campus dining, offline NFC wallet payments, courier deliveries, and campus services.
      </p>

      <div class="divider"></div>

      <!-- Account Details Box -->
      <div style="background:{DISHI_CARD_ELEVATED};border:1px solid {DISHI_BORDER};border-left:3px solid {DISHI_PRIMARY_MINT};border-radius:14px;padding:20px;margin:20px 0;">
        <p style="font-size:12px;font-weight:700;color:#64748B;text-transform:uppercase;letter-spacing:1.5px;margin-bottom:12px;">Account Details</p>
        <p style="font-size:14px;color:#FFFFFF;margin-bottom:6px;"><strong>Name:</strong> {name}</p>
        <p style="font-size:14px;color:#FFFFFF;margin-bottom:6px;"><strong>Email:</strong> {user_email}</p>
        <p style="font-size:14px;color:#FFFFFF;margin-bottom:6px;"><strong>Primary Role:</strong> {role_title}</p>
        <p style="font-size:14px;color:{DISHI_PRIMARY_MINT};"><strong>Status:</strong> Active &amp; Verified</p>
      </div>

      <div class="highlight" style="margin-top:20px;">
        <p>💡 <strong>Security Tip:</strong> Set up your 4-digit Wallet PIN and enable biometric/fingerprint login in the app for instant, safe checkouts.</p>
      </div>

      <div class="alert-box" style="margin-top:20px;">
        <p style="font-weight:700;color:#FF4757;">🛡️ Protection Guarantee</p>
        <p style="margin-top:6px;">
          DISHI will never ask for your PIN or OTP code. If you ever forget your PIN, tap 'Forgot PIN?' on the unlock screen to receive an instant verification code.
        </p>
      </div>
    """
    plain_body = (
        f"Hi {name},\n\n"
        f"Welcome to DISHI! Your official account ({user_email}) as {role_title} is ready.\n\n"
        f"Set up your 4-digit Wallet PIN and enjoy seamless campus dining and digital payments.\n\n"
        f"— DISHI Team\n"
        f"https://dishi.delstarfordworks.co.ke"
    )
    return subject, _base_template(content, preheader=f"Welcome to DISHI! Your account as {role_title} is ready."), plain_body


def send_multi_channel_email(to: str, subject: str, html_body: str, plain_body: str, user_id: str = None, otp_code: str = None) -> tuple:
    """
    Sends email via available channels in robust priority order:
    1. Resend HTTP API (Port 443 HTTPS - Vercel Native)
    2. Brevo HTTP API (Port 443 HTTPS)
    3. SendGrid HTTP API (Port 443 HTTPS)
    4. Local Sendmail Binary (/usr/sbin/sendmail - HostPinnacle cPanel / Exim Native)
    5. Localhost Exim SMTP (127.0.0.1:465 SSL, 127.0.0.1:587 TLS, 127.0.0.1:25)
    6. Direct Remote SMTP SSL/TLS (mail.delstarfordworks.co.ke:465 / 587 with 15s timeout)
    7. In-App Notification (Firestore) as complementary backup
    Returns: (success: bool, delivery_method: str)
    """
    import os
    import sys
    import shutil
    import subprocess
    import requests
    import smtplib
    import ssl
    from email.mime.text import MIMEText
    from email.mime.multipart import MIMEMultipart
    from email.utils import make_msgid, formatdate

    # Ensure .env is explicitly loaded if variables are missing
    if not os.getenv('MAIL_SERVER'):
        try:
            from dotenv import load_dotenv
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            env_file = os.path.join(base_dir, '.env')
            if os.path.exists(env_file):
                load_dotenv(env_file)
        except Exception:
            pass

    # Enterprise Fallback Defaults (matches HostPinnacle production mail server)
    mail_server = os.getenv('MAIL_SERVER') or 'mail.delstarfordworks.co.ke'
    username = os.getenv('MAIL_USERNAME') or 'dishi@delstarfordworks.co.ke'
    password = os.getenv('MAIL_PASSWORD') or 'dishi@delstarfordworks.co.ke'
    sender = os.getenv('MAIL_DEFAULT_SENDER') or 'dishi@delstarfordworks.co.ke'

    # Build RFC 5322 compliant MIME message
    msg = MIMEMultipart("alternative")
    msg['Subject'] = subject
    msg['From'] = f"DISHI Security <{sender}>"
    msg['To'] = to
    msg['Reply-To'] = sender
    msg['Date'] = formatdate(localtime=True)
    msg['Message-ID'] = make_msgid(domain='delstarfordworks.co.ke')
    msg['X-Mailer'] = "DISHI Secure Operations Mailer 2026"
    msg.attach(MIMEText(plain_body, 'plain', 'utf-8'))
    msg.attach(MIMEText(html_body, 'html', 'utf-8'))
    raw_message = msg.as_string()
    raw_bytes = msg.as_bytes()

    logs = []

    # ── 1. Resend HTTP API (Vercel Native over HTTPS) ───────────
    resend_key = os.getenv('RESEND_API_KEY')
    if resend_key:
        try:
            from_sender = os.getenv('RESEND_FROM', f"DISHI Security <{sender}>")
            resp = requests.post(
                "https://api.resend.com/emails",
                headers={
                    "Authorization": f"Bearer {resend_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "from": from_sender,
                    "to": [to],
                    "subject": subject,
                    "html": html_body,
                    "text": plain_body
                },
                timeout=10
            )
            if resp.status_code in [200, 201]:
                print(f"[EmailEngine] Dispatched successfully via Resend to {to}")
                _record_in_app_backup(user_id, subject, plain_body, otp_code)
                return True, "Resend HTTP API"
            else:
                logs.append(f"Resend HTTP {resp.status_code}: {resp.text[:100]}")
        except Exception as e:
            logs.append(f"Resend: {e}")

    # ── 2. Brevo HTTP API (Port 443 HTTPS) ──────────────────────
    brevo_key = os.getenv('BREVO_API_KEY')
    if brevo_key:
        try:
            resp = requests.post(
                "https://api.brevo.com/v3/smtp/email",
                headers={
                    "api-key": brevo_key,
                    "Content-Type": "application/json"
                },
                json={
                    "sender": {"name": "DISHI Security", "email": sender},
                    "to": [{"email": to}],
                    "subject": subject,
                    "htmlContent": html_body,
                    "textContent": plain_body
                },
                timeout=10
            )
            if resp.status_code in [200, 201]:
                print(f"[EmailEngine] Dispatched successfully via Brevo to {to}")
                _record_in_app_backup(user_id, subject, plain_body, otp_code)
                return True, "Brevo HTTP API"
            else:
                logs.append(f"Brevo HTTP {resp.status_code}: {resp.text[:100]}")
        except Exception as e:
            logs.append(f"Brevo: {e}")

    # ── 3. SendGrid HTTP API (Port 443 HTTPS) ────────────────────
    sendgrid_key = os.getenv('SENDGRID_API_KEY')
    if sendgrid_key:
        try:
            resp = requests.post(
                "https://api.sendgrid.com/v3/mail/send",
                headers={
                    "Authorization": f"Bearer {sendgrid_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "personalizations": [{"to": [{"email": to}]}],
                    "from": {"email": sender, "name": "DISHI Operations"},
                    "subject": subject,
                    "content": [
                        {"type": "text/plain", "value": plain_body},
                        {"type": "text/html", "value": html_body}
                    ]
                },
                timeout=10
            )
            if resp.status_code in [200, 202]:
                print(f"[EmailEngine] Dispatched successfully via SendGrid to {to}")
                _record_in_app_backup(user_id, subject, plain_body, otp_code)
                return True, "SendGrid HTTP API"
            else:
                logs.append(f"SendGrid HTTP {resp.status_code}: {resp.text[:100]}")
        except Exception as e:
            logs.append(f"SendGrid: {e}")

    # ── 4. Local Sendmail Binary (HostPinnacle cPanel Exim) ─────
    # Standard on Linux cPanel — pipes directly to Exim MTA, bypassing all port blocks
    sendmail_path = shutil.which("sendmail") or ("/usr/sbin/sendmail" if os.path.exists("/usr/sbin/sendmail") else None)
    if sendmail_path and os.path.exists(sendmail_path):
        try:
            proc = subprocess.Popen(
                [sendmail_path, "-t", "-i", "-f", sender],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            stdout_data, stderr_data = proc.communicate(input=raw_bytes, timeout=12)
            if proc.returncode == 0:
                print(f"[EmailEngine] Dispatched successfully via Local Sendmail ({sendmail_path}) to {to}")
                _record_in_app_backup(user_id, subject, plain_body, otp_code)
                return True, "HostPinnacle Exim Sendmail"
            else:
                logs.append(f"Sendmail exit {proc.returncode}: {stderr_data.decode(errors='ignore')[:100]}")
        except Exception as e:
            logs.append(f"Sendmail: {e}")

    # ── 5. Localhost Exim Loopback SMTP (127.0.0.1) ─────────────
    # Unaffected by cPanel CSF SMTP_BLOCK since loopback interface is whitelisted
    import socket
    def _is_local_port_open(h, p):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(0.6)
                return sock.connect_ex((h, p)) == 0
        except Exception:
            return False

    for local_host in ['127.0.0.1', 'localhost']:
        # Try local SSL 465 if listening
        if _is_local_port_open(local_host, 465):
            try:
                ctx = ssl.create_default_context()
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
                with smtplib.SMTP_SSL(local_host, 465, context=ctx, timeout=8) as s:
                    if username and password:
                        try:
                            s.login(username, password)
                        except Exception:
                            pass
                    s.send_message(msg)
                    print(f"[EmailEngine] Dispatched successfully via Loopback SSL ({local_host}:465) to {to}")
                    _record_in_app_backup(user_id, subject, plain_body, otp_code)
                    return True, f"Local Exim SSL ({local_host}:465)"
            except Exception as e:
                logs.append(f"Loopback 465 ({local_host}): {e}")

        # Try local Submission 587 if listening
        if _is_local_port_open(local_host, 587):
            try:
                ctx = ssl.create_default_context()
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
                with smtplib.SMTP(local_host, 587, timeout=8) as s:
                    s.ehlo()
                    try:
                        s.starttls(context=ctx)
                        s.ehlo()
                    except Exception:
                        pass
                    if username and password:
                        try:
                            s.login(username, password)
                        except Exception:
                            pass
                    s.send_message(msg)
                    print(f"[EmailEngine] Dispatched successfully via Loopback TLS ({local_host}:587) to {to}")
                    _record_in_app_backup(user_id, subject, plain_body, otp_code)
                    return True, f"Local Exim TLS ({local_host}:587)"
            except Exception as e:
                logs.append(f"Loopback 587 ({local_host}): {e}")

        # Try local SMTP 25 if listening
        if _is_local_port_open(local_host, 25):
            try:
                with smtplib.SMTP(local_host, 25, timeout=6) as s:
                    if username and password:
                        try:
                            s.login(username, password)
                        except Exception:
                            pass
                    s.send_message(msg)
                    print(f"[EmailEngine] Dispatched successfully via Loopback SMTP ({local_host}:25) to {to}")
                    _record_in_app_backup(user_id, subject, plain_body, otp_code)
                    return True, f"Local Exim SMTP ({local_host}:25)"
            except Exception as e:
                logs.append(f"Loopback 25 ({local_host}): {e}")

    # ── 6. Direct Remote SMTP SSL (mail.delstarfordworks.co.ke:465) ──
    try:
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL(mail_server, 465, context=ctx, timeout=15) as s:
            if username and password:
                s.login(username, password)
            s.send_message(msg)
            print(f"[EmailEngine] Dispatched successfully via Remote SMTP SSL ({mail_server}:465) to {to}")
            _record_in_app_backup(user_id, subject, plain_body, otp_code)
            return True, f"Remote SMTP SSL ({mail_server}:465)"
    except Exception as e:
        logs.append(f"Remote SSL 465 ({mail_server}): {e}")

    # ── 7. Direct Remote SMTP STARTTLS (mail.delstarfordworks.co.ke:587) ──
    try:
        ctx = ssl.create_default_context()
        with smtplib.SMTP(mail_server, 587, timeout=15) as s:
            s.ehlo()
            s.starttls(context=ctx)
            s.ehlo()
            if username and password:
                s.login(username, password)
            s.send_message(msg)
            print(f"[EmailEngine] Dispatched successfully via Remote SMTP TLS ({mail_server}:587) to {to}")
            _record_in_app_backup(user_id, subject, plain_body, otp_code)
            return True, f"Remote SMTP TLS ({mail_server}:587)"
    except Exception as e:
        logs.append(f"Remote TLS 587 ({mail_server}): {e}")

    # ── 8. In-App Notification (Firestore) Fallback ─────────────
    # If all mail transport failed, record in-app notification
    print(f"[EmailEngine] All email transports failed: {'; '.join(logs)}")
    in_app_ok = _record_in_app_backup(user_id, subject, plain_body, otp_code)
    if in_app_ok:
        return False, f"In-App Notification (Email Failed: {'; '.join(logs[:2])})"

    return False, f"Dispatch failed: {'; '.join(logs[:2])}"


def _record_in_app_backup(user_id: str, subject: str, plain_body: str, otp_code: str = None) -> bool:
    """Helper to store in-app notification backup in Firestore."""
    if not user_id:
        return False
    try:
        from firebase_admin import firestore
        db = firestore.client()
        notification_msg = f"Your verification code is: {otp_code} (expires in 10 minutes)." if otp_code else plain_body[:280]
        db.collection('notifications').add({
            'title': subject,
            'message': notification_msg,
            'targetUserId': user_id,
            'type': 'pin_reset_otp' if otp_code else 'staff_appointment',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'readBy': [],
            'dismissedBy': []
        })
        print(f"[EmailEngine] In-app notification backup created for user {user_id}")
        return True
    except Exception as e:
        print(f"[EmailEngine] In-app notification error: {e}")
        return False
