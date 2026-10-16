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


def send_multi_channel_email(to: str, subject: str, html_body: str, plain_body: str, user_id: str = None, otp_code: str = None) -> tuple:
    """
    Sends email via available channels in priority order:
    1. Resend HTTP API (Port 443 HTTPS - Vercel Native, no socket blocking)
    2. Brevo HTTP API (Port 443 HTTPS)
    3. Direct SMTP (Port 465 SSL or Port 587 TLS with strict 5s timeout)
    4. In-App Notification (Firestore)
    Returns: (success: bool, delivery_method: str)
    """
    import os
    import requests
    import smtplib
    import ssl
    from email.mime.text import MIMEText
    from email.mime.multipart import MIMEMultipart

    # ── 1. Resend HTTP API (Vercel Native over HTTPS) ───────────
    resend_key = os.getenv('RESEND_API_KEY')
    if resend_key:
        try:
            from_sender = os.getenv('RESEND_FROM', 'DISHI Security <onboarding@resend.dev>')
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
                timeout=8
            )
            if resp.status_code in [200, 201]:
                print(f"[EmailEngine] Dispatched successfully via Resend to {to}")
                return True, "Resend HTTP API"
            else:
                print(f"[EmailEngine] Resend returned {resp.status_code}: {resp.text}")
        except Exception as e:
            print(f"[EmailEngine] Resend attempt error: {e}")

    # ── 2. Brevo HTTP API (Port 443 HTTPS) ──────────────────────
    brevo_key = os.getenv('BREVO_API_KEY')
    if brevo_key:
        try:
            sender_email = os.getenv('MAIL_DEFAULT_SENDER', 'dishi@delstarfordworks.co.ke')
            resp = requests.post(
                "https://api.brevo.com/v3/smtp/email",
                headers={
                    "api-key": brevo_key,
                    "Content-Type": "application/json"
                },
                json={
                    "sender": {"name": "DISHI Support", "email": sender_email},
                    "to": [{"email": to}],
                    "subject": subject,
                    "htmlContent": html_body,
                    "textContent": plain_body
                },
                timeout=8
            )
            if resp.status_code in [200, 201]:
                print(f"[EmailEngine] Dispatched successfully via Brevo to {to}")
                return True, "Brevo HTTP API"
            else:
                print(f"[EmailEngine] Brevo returned {resp.status_code}: {resp.text}")
        except Exception as e:
            print(f"[EmailEngine] Brevo attempt error: {e}")

    # ── 3. SMTP (with strict 5s timeout to prevent hanging on Vercel) ──
    mail_server = os.getenv('MAIL_SERVER', '')
    if mail_server:
        try:
            mail_port = int(os.getenv('MAIL_PORT', '465'))
            use_ssl = os.getenv('MAIL_USE_SSL', 'True').lower() in ['true', '1', 't']
            username = os.getenv('MAIL_USERNAME', '')
            password = os.getenv('MAIL_PASSWORD', '')
            sender = os.getenv('MAIL_DEFAULT_SENDER', username or 'dishi@delstarfordworks.co.ke')

            msg = MIMEMultipart("alternative")
            msg['Subject'] = subject
            msg['From'] = sender
            msg['To'] = to
            msg.attach(MIMEText(plain_body, 'plain'))
            msg.attach(MIMEText(html_body, 'html'))

            if use_ssl:
                context = ssl.create_default_context()
                with smtplib.SMTP_SSL(mail_server, mail_port, context=context, timeout=5) as s:
                    if username and password:
                        s.login(username, password)
                    s.sendmail(sender, [to], msg.as_string())
                    print(f"[EmailEngine] Dispatched successfully via SMTP SSL ({mail_server}) to {to}")
                    return True, f"SMTP SSL ({mail_server})"
            else:
                context = ssl.create_default_context()
                with smtplib.SMTP(mail_server, mail_port, timeout=5) as s:
                    s.starttls(context=context)
                    if username and password:
                        s.login(username, password)
                    s.sendmail(sender, [to], msg.as_string())
                    print(f"[EmailEngine] Dispatched successfully via SMTP TLS ({mail_server}) to {to}")
                    return True, f"SMTP TLS ({mail_server})"
        except Exception as e:
            print(f"[EmailEngine] SMTP ({mail_server}:{os.getenv('MAIL_PORT', '465')}) timed out or failed: {e}")

    # ── 4. In-App Notification (Firestore) ──────────────────────
    if user_id:
        try:
            from firebase_admin import firestore
            db = firestore.client()
            db.collection('notifications').add({
                'title': subject,
                'message': f"Your verification code is: {otp_code} (expires in 10 minutes).",
                'targetUserId': user_id,
                'type': 'pin_reset_otp',
                'createdAt': firestore.SERVER_TIMESTAMP,
                'readBy': [],
                'dismissedBy': []
            })
            print(f"[EmailEngine] In-app notification created for user {user_id}")
            return True, "In-App Notification"
        except Exception as e:
            print(f"[EmailEngine] In-App notification error: {e}")

    return False, "All channels failed or timed out"

