"""
DISHI Email Utility
Provides beautiful, branded HTML email templates for all DISHI emails.
The logo is served from the hosted backend's static /static/img/dishi_logo.png path.
"""

DISHI_LOGO_URL = "https://dishi.delstarfordworks.co.ke/static/img/dishi_logo.png"
DISHI_PRIMARY_GREEN = "#00A651"
DISHI_DARK = "#0A0F1E"
DISHI_CARD = "#111827"


def _base_template(content_html: str, preheader: str = "") -> str:
    """Wraps content in the branded DISHI email shell."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>DISHI</title>
  <!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{ background-color: #0A0F1E; font-family: 'Inter', Arial, sans-serif; color: #E2E8F0; }}
    a {{ color: {DISHI_PRIMARY_GREEN}; text-decoration: none; }}
    .wrapper {{ max-width: 600px; margin: 0 auto; background-color: #0A0F1E; }}
    /* Header */
    .header {{ background: linear-gradient(135deg, #0A0F1E 0%, #111827 100%);
               border-bottom: 2px solid {DISHI_PRIMARY_GREEN}; padding: 28px 32px; text-align: center; }}
    .header img {{ max-height: 52px; width: auto; }}
    /* Body card */
    .card {{ background-color: #111827; border-radius: 16px; margin: 24px 24px; padding: 32px;
             border: 1px solid rgba(255,255,255,0.06); }}
    /* Divider */
    .divider {{ height: 1px; background: rgba(255,255,255,0.08); margin: 24px 0; }}
    /* Greeting */
    .greeting {{ font-size: 22px; font-weight: 700; color: #F8FAFC; margin-bottom: 8px; }}
    /* Body text */
    .body-text {{ font-size: 15px; line-height: 1.7; color: #94A3B8; }}
    /* Highlight box */
    .highlight {{ background: rgba(0,166,81,0.10); border-left: 3px solid {DISHI_PRIMARY_GREEN};
                  border-radius: 8px; padding: 14px 18px; margin: 20px 0; }}
    .highlight p {{ font-size: 14px; color: #CBD5E1; line-height: 1.6; }}
    /* CTA Button */
    .btn {{ display: inline-block; background: {DISHI_PRIMARY_GREEN}; color: #000 !important;
            font-weight: 700; font-size: 14px; padding: 14px 32px; border-radius: 50px;
            margin-top: 24px; text-decoration: none; letter-spacing: 0.5px; }}
    /* Match chip */
    .chip {{ display: inline-block; background: rgba(0,166,81,0.15); color: {DISHI_PRIMARY_GREEN};
             border: 1px solid rgba(0,166,81,0.35); border-radius: 50px; padding: 5px 14px;
             font-size: 13px; font-weight: 600; margin: 4px 4px 4px 0; }}
    /* Alert box */
    .alert-box {{ background: rgba(239,68,68,0.10); border: 1px solid rgba(239,68,68,0.35);
                  border-radius: 12px; padding: 18px 20px; margin: 20px 0; }}
    .alert-box p {{ color: #FCA5A5; font-size: 14px; }}
    /* Footer */
    .footer {{ text-align: center; padding: 24px 32px 32px; color: #475569; font-size: 12px; line-height: 1.6; }}
    .footer a {{ color: #64748B; }}
    .footer .brand {{ color: {DISHI_PRIMARY_GREEN}; font-weight: 700; font-size: 13px; }}
  </style>
</head>
<body>
  {'<div style="display:none;max-height:0;overflow:hidden;">' + preheader + '</div>' if preheader else ''}
  <div class="wrapper">

    <!-- Header -->
    <div class="header">
      <img src="{DISHI_LOGO_URL}" alt="DISHI" onerror="this.style.display='none'" />
    </div>

    <!-- Content Card -->
    <div class="card">
      {content_html}
    </div>

    <!-- Footer -->
    <div class="footer">
      <p class="brand">DISHI &mdash; Smart Campus Finance &amp; Lifestyle</p>
      <p style="margin-top:8px;">Delstarford Works &bull; Nairobi, Kenya</p>
      <p style="margin-top:8px;">
        <a href="https://dishi.delstarfordworks.co.ke">Visit DISHI</a> &nbsp;&bull;&nbsp;
        <a href="mailto:info@delstarfordworks.co.ke">Contact Support</a>
      </p>
      <p style="margin-top:12px; color: #334155;">
        You are receiving this because you have a DISHI account.<br/>
        &copy; 2026 Delstarford Works. All rights reserved.
      </p>
    </div>

  </div>
</body>
</html>"""


def match_digest_email(student_name: str, matches: list) -> tuple:
    """
    Returns (subject, html_body) for the weekly match digest email.
    matches: list of name strings
    Format:
      Hey Student! 💘
      You have 1 compatible student at your campus who match your profile. Don't keep them waiting!
      Your Top Matches
      💚 Student
      💡 Tip: Students with the same institution as you have a 3x higher chance...
      [View Matches in DISHI →]
      Powered by DISHI Gold — exclusive weekly match insights for premium members.
    """
    name = student_name or "Student"
    match_count = len(matches)
    subject = f"💘 {match_count} New Match{'es' if match_count != 1 else ''} Waiting for You!"

    # Build match chips — each on its own line per the spec: "💚 Student"
    chips_html = "".join(
        f'<div style="margin:6px 0;"><span class="chip">💚 {m}</span></div>'
        for m in matches[:5]
    )

    content = f"""
      <p class="greeting">Hey {name}! 💘</p>
      <p class="body-text" style="margin-top:8px;">
        You have <strong style="color:#F8FAFC;">{match_count} compatible student{'s' if match_count != 1 else ''}</strong>
        at your campus who match your profile. Don't keep them waiting!
      </p>
      <div class="divider"></div>
      <p style="font-size:13px;font-weight:600;color:#64748B;text-transform:uppercase;letter-spacing:1px;margin-bottom:12px;">
        Your Top Matches
      </p>
      <div style="margin-bottom:8px;">{chips_html}</div>
      <div class="highlight" style="margin-top:24px;">
        <p>💡 <strong>Tip:</strong> Students with the same institution as you have a
        <strong>3x higher</strong> chance of becoming a real connection. Open the app and start swiping!</p>
      </div>
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke" class="btn">View Matches in DISHI &rarr;</a>
      </div>
      <div class="divider"></div>
      <p class="body-text" style="font-size:13px;">
        Powered by <strong style="color:{DISHI_PRIMARY_GREEN};">DISHI Gold</strong> &mdash; exclusive weekly match insights for premium members.
      </p>
    """
    return subject, _base_template(content, preheader=f"You have {match_count} new matches on DISHI!")


def sos_alert_email(user_id: str, user_name: str = "Unknown") -> tuple:
    """
    Returns (subject, html_body) for an SOS distress alert (sent to admin).
    """
    from datetime import datetime
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    subject = f"🚨 EMERGENCY SOS ALERT — {user_name} ({user_id})"

    content = f"""
      <div class="alert-box">
        <p>&#128680; <strong>CRITICAL ALERT — Immediate Action Required</strong></p>
        <p style="margin-top:8px;">An SOS distress signal has been triggered by a DISHI student.</p>
      </div>
      <p class="greeting" style="color:#FCA5A5;">SOS Distress Signal</p>
      <div class="divider"></div>
      <table style="width:100%;border-collapse:collapse;">
        <tr>
          <td style="padding:10px 0;color:#64748B;font-size:14px;width:40%;">Student Name</td>
          <td style="padding:10px 0;color:#F8FAFC;font-size:14px;font-weight:600;">{user_name}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">User ID</td>
          <td style="padding:10px 0;color:#F8FAFC;font-size:14px;font-weight:600;">{user_id}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">Triggered At</td>
          <td style="padding:10px 0;color:#F8FAFC;font-size:14px;font-weight:600;">{timestamp}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">Feature</td>
          <td style="padding:10px 0;color:#F8FAFC;font-size:14px;font-weight:600;">Find Your Match &mdash; Safe Walk</td>
        </tr>
      </table>
      <div class="divider"></div>
      <p class="body-text">
        Please log into the <strong style="color:#F8FAFC;">DISHI Admin Dashboard</strong> immediately and contact
        the student to ensure their safety. If the student cannot be reached, consider alerting campus security.
      </p>
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke/api/v1/admin" class="btn" style="background:#EF4444;color:#fff !important;">
          Open Admin Dashboard &rarr;
        </a>
      </div>
    """
    return subject, _base_template(content, preheader=f"URGENT: SOS alert from {user_name}")


def support_ticket_email(student_id: str, student_name: str, subject_text: str, description: str) -> tuple:
    """
    Returns (subject, html_body) for a support ticket (sent to admin).
    """
    from datetime import datetime
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    email_subject = f"[DISHI Support] {subject_text}"

    content = f"""
      <p class="greeting">New Support Ticket 🎫</p>
      <p class="body-text" style="margin-top:8px;">
        A student has submitted a support request through the DISHI app.
      </p>
      <div class="divider"></div>
      <table style="width:100%;border-collapse:collapse;">
        <tr>
          <td style="padding:10px 0;color:#64748B;font-size:14px;width:35%;">Student Name</td>
          <td style="padding:10px 0;color:#F8FAFC;font-size:14px;font-weight:600;">{student_name}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">Student ID</td>
          <td style="padding:10px 0;color:#F8FAFC;font-size:14px;font-weight:600;">{student_id}</td>
        </tr>
        <tr style="border-top:1px solid rgba(255,255,255,0.05);">
          <td style="padding:10px 0;color:#64748B;font-size:14px;">Submitted At</td>
          <td style="padding:10px 0;color:#F8FAFC;font-size:14px;font-weight:600;">{timestamp}</td>
        </tr>
      </table>
      <div class="divider"></div>
      <p style="font-size:13px;font-weight:600;color:#64748B;text-transform:uppercase;letter-spacing:1px;margin-bottom:10px;">
        Subject
      </p>
      <p style="font-size:16px;font-weight:700;color:#F8FAFC;">{subject_text}</p>
      <div class="divider"></div>
      <p style="font-size:13px;font-weight:600;color:#64748B;text-transform:uppercase;letter-spacing:1px;margin-bottom:10px;">
        Description
      </p>
      <div class="highlight">
        <p style="white-space:pre-wrap;">{description}</p>
      </div>
      <div style="text-align:center;margin-top:8px;">
        <a href="https://dishi.delstarfordworks.co.ke/api/v1/admin" class="btn">View Admin Dashboard &rarr;</a>
      </div>
    """
    return email_subject, _base_template(content, preheader=f"Support ticket from {student_name}: {subject_text}")


def semester_summary_email(student_name: str, student_id: str, summary_text: str = "") -> tuple:
    """
    Returns (subject, html_body) for the end-of-semester summary.
    """
    name = student_name or "Student"
    subject = f"📊 Your DISHI Semester Summary, {name}"

    content = f"""
      <p class="greeting">Semester Summary 📊</p>
      <p class="body-text" style="margin-top:8px;">
        Hi <strong style="color:#F8FAFC;">{name}</strong>,<br/><br/>
        Here is your personalised end-of-semester financial breakdown from DISHI.
        Keep this for your records!
      </p>
      <div class="divider"></div>
      <div class="highlight">
        <p><strong>Student ID:</strong> {student_id}</p>
        <p style="margin-top:8px;white-space:pre-wrap;">{summary_text or "Your detailed spending report is available in the DISHI app under Financial Wrapped."}</p>
      </div>
      <div style="text-align:center;">
        <a href="https://dishi.delstarfordworks.co.ke" class="btn">View Full Report in DISHI &rarr;</a>
      </div>
      <div class="divider"></div>
      <p class="body-text" style="font-size:13px;">
        Thank you for using DISHI this semester. We hope it helped you manage your campus finances smarter. 🎓
      </p>
    """
    return subject, _base_template(content, preheader=f"Your DISHI semester financial summary is ready, {name}!")


def pin_reset_otp_email(user_name: str, otp_code: str, device_hint: str = "") -> tuple:
    """
    Returns (subject, html_body) for the PIN reset OTP email sent to the user.
    Security-first: does NOT include the user's current PIN or any PII beyond their name.
    OTP is valid for 10 minutes.
    """
    name = user_name or "there"
    subject = "\U0001f512 Your DISHI PIN Reset Code"
    device_note = (
        f'<p class="body-text" style="margin-top:10px;font-size:13px;">'
        f'Requested from: <strong style="color:#F8FAFC;">{device_hint}</strong></p>'
    ) if device_hint else ""

    content = f"""
      <p class="greeting">PIN Reset Request &#128274;</p>
      <p class="body-text" style="margin-top:8px;">
        Hi <strong style="color:#F8FAFC;">{name}</strong>,<br/><br/>
        We received a request to reset your DISHI App PIN. Use the one-time code below to
        verify your identity and set a new PIN.
      </p>

      <div class="divider"></div>

      <!-- OTP Block -->
      <div style="text-align:center;margin:28px 0;">
        <p style="font-size:12px;font-weight:600;color:#64748B;text-transform:uppercase;
                  letter-spacing:2px;margin-bottom:16px;">Your One-Time Code</p>
        <div style="display:inline-block;background:linear-gradient(135deg,#0D3B26,#1A5C3A);
                    border:2px solid {DISHI_PRIMARY_GREEN};border-radius:16px;
                    padding:20px 40px;">
          <span style="font-size:42px;font-weight:800;color:{DISHI_PRIMARY_GREEN};
                       letter-spacing:10px;font-family:monospace;">{otp_code}</span>
        </div>
        <p style="margin-top:14px;font-size:13px;color:#94A3B8;">
          &#9203; Expires in <strong style="color:#F8FAFC;">10 minutes</strong>
        </p>
      </div>

      <div class="divider"></div>

      {device_note}

      <div class="alert-box">
        <p>&#128272; <strong>Security Notice</strong></p>
        <p style="margin-top:8px;">If you did not request a PIN reset, your account may be at risk.
        Please <a href="mailto:info@delstarfordworks.co.ke" style="color:#FCA5A5;">contact support</a>
        immediately and do <strong>NOT</strong> share this code with anyone &mdash; DISHI staff
        will never ask for it.</p>
      </div>

      <div class="highlight" style="margin-top:20px;">
        <p>&#128161; <strong>Tip:</strong> After resetting your PIN, consider enabling
        biometric authentication in your DISHI app settings for extra security.</p>
      </div>

      <p class="body-text" style="margin-top:20px;font-size:13px;
          color:#475569;text-align:center;">
        This code is single-use and will expire after 10 minutes or as soon as it is used.
      </p>
    """
    return subject, _base_template(
        content,
        preheader=f"Your DISHI PIN reset code is {otp_code} — valid for 10 minutes"
    )

def monthly_nutrition_report_email(student_name: str, month_name: str, macros: dict) -> tuple:
    """
    Returns (subject, html_body) for the monthly nutrition report card.
    macros: {'carbs': 40, 'protein': 30, 'sugar': 30}
    """
    subject = f"DISHI Nutritional Report Card: {student_name} - {month_name}"
    
    content = f"""
      <h2 class="greeting">Nutritional Report Card</h2>
      <p class="body-text">Here is a summary of what {student_name} ate at school in {month_name} based on POS data.</p>
      
      <div class="divider"></div>
      
      <div style="text-align:center; padding: 20px 0;">
        <div style="display:inline-block; margin: 0 10px; padding: 15px; background: rgba(0,166,81,0.1); border-radius: 8px;">
            <p style="font-size:12px; color:#94A3B8; text-transform:uppercase;">Carbs</p>
            <p style="font-size:24px; font-weight:bold; color:{DISHI_PRIMARY_GREEN};">{macros.get('carbs', 0)}%</p>
        </div>
        <div style="display:inline-block; margin: 0 10px; padding: 15px; background: rgba(59,130,246,0.1); border-radius: 8px;">
            <p style="font-size:12px; color:#94A3B8; text-transform:uppercase;">Protein</p>
            <p style="font-size:24px; font-weight:bold; color:#3B82F6;">{macros.get('protein', 0)}%</p>
        </div>
        <div style="display:inline-block; margin: 0 10px; padding: 15px; background: rgba(239,68,68,0.1); border-radius: 8px;">
            <p style="font-size:12px; color:#94A3B8; text-transform:uppercase;">Sugar/Snacks</p>
            <p style="font-size:24px; font-weight:bold; color:#EF4444;">{macros.get('sugar', 0)}%</p>
        </div>
      </div>
      
      <div class="highlight">
        <p><strong>Note:</strong> Adjust category limits and allergen blocks inside the Parent Dashboard to steer your child towards healthier choices.</p>
      </div>
    """
    return subject, _base_template(content, preheader=f"View {student_name}'s monthly nutrition breakdown for {month_name}")
