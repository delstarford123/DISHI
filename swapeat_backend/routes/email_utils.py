"""
DISHI Email Utility System
Provides ultra-modern, DISHI-branded HTML email templates for all communications.
Brand Identity: Dark Space (#080D18), Card Slate (#101726), Neon Mint (#05D5AA), Energy Pink (#FF2A6D).
Official Contact & Support: dishi@delstarfordworks.co.ke
"""

DISHI_LOGO_URL = "https://dishi.delstarfordworks.co.ke/static/img/dishi_logo.png"
DISHI_ECOSYSTEM_URL = "https://dishi.delstarfordworks.co.ke"
DISHI_PLAYSTORE_URL = "https://play.google.com/store/apps/details?id=co.ke.delstarfordworks.dishi"
DISHI_PRIMARY_MINT = "#00D492"
DISHI_MINT_ACCENT = "#05D5AA"
DISHI_CYAN = "#00F0FF"
DISHI_PRIMARY_PINK = "#FF2A6D"
DISHI_DARK = "#060A12"
DISHI_CARD = "#0F172A"
DISHI_CARD_ELEVATED = "#162033"
DISHI_BORDER = "rgba(255, 255, 255, 0.08)"
DISHI_BORDER_SOLID = "#1E293B"
DISHI_TEXT_MAIN = "#F8FAFC"
DISHI_TEXT_MUTED = "#94A3B8"
DISHI_SUPPORT_EMAIL = "dishi@delstarfordworks.co.ke"


def _build_preheader(preheader: str) -> str:
    """Builds hidden preheader with zero-width non-joiner padding to prevent inbox snippet bleed."""
    if not preheader:
        return ""
    padding = "&#847;&zwnj;&nbsp;" * 85
    return (
        f'<div style="display:none;font-size:1px;color:{DISHI_DARK};line-height:1px;'
        f'max-height:0px;max-width:0px;opacity:0;overflow:hidden;mso-hide:all;font-family:sans-serif;">'
        f'{preheader}{padding}'
        f'</div>'
    )


def _html_to_plain_text(raw_html: str) -> str:
    """
    Intelligently converts DISHI HTML emails to high-fidelity, clean plain-text
    to ensure 1:1 content parity and prevent spam filter divergence penalties.
    """
    import re
    import html
    if not raw_html:
        return ""
    text = re.sub(r'(?is)<head.*?>.*?</head>', '', raw_html)
    text = re.sub(r'(?is)<style.*?>.*?</style>', '', text)
    text = re.sub(r'(?is)<script.*?>.*?</script>', '', text)
    text = re.sub(r'(?is)<div style="display:none;.*?>.*?</div>', '', text)
    text = re.sub(r'(?i)<hr.*?>', '\n' + ('-' * 65) + '\n', text)
    text = re.sub(r'(?i)<br\s*/?>', '\n', text)
    text = re.sub(r'(?i)</p>', '\n\n', text)
    text = re.sub(r'(?i)</div>', '\n', text)
    text = re.sub(r'(?i)</tr>', '\n', text)
    text = re.sub(r'(?i)</td>', '   ', text)
    text = re.sub(r'(?i)</li>', '\n', text)
    text = re.sub(r'(?i)<li.*?>', ' • ', text)
    text = re.sub(r'(?is)<h[1-6].*?>(.*?)</h[1-6]>', r'\n\n=== \1 ===\n\n', text)
    text = re.sub(r'(?is)<a\s+(?:[^>]*?\s+)?href=["\']([^"\']*)["\'][^>]*>(.*?)</a>', r'\2 (\1)', text)
    text = re.sub(r'<[^>]+>', '', text)
    text = html.unescape(text)
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n[ \t]+', '\n', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def _base_template(content_html: str, preheader: str = "", title: str = "DISHI Campus Security") -> str:
    """Wraps content in the ultra-premium DISHI dark glassmorphism email shell with bulletproof table architecture."""
    preheader_html = _build_preheader(preheader)
    return f"""<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta name="x-apple-disable-message-reformatting" />
  <meta name="format-detection" content="telephone=no, date=no, address=no, email=no" />
  <title>{title}</title>
  <!--[if mso]>
  <noscript>
    <xml>
      <o:OfficeDocumentSettings>
        <o:PixelsPerInch>96</o:PixelsPerInch>
      </o:OfficeDocumentSettings>
    </xml>
  </noscript>
  <![endif]-->
  <style type="text/css">
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@700;800&display=swap');
    body, table, td, a {{ -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }}
    table, td {{ mso-table-lspace: 0pt; mso-table-rspace: 0pt; }}
    img {{ -ms-interpolation-mode: bicubic; border: 0; outline: none; text-decoration: none; }}
    body {{ margin: 0; padding: 0; width: 100% !important; background-color: {DISHI_DARK}; font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased; }}
    a {{ color: {DISHI_PRIMARY_MINT}; text-decoration: none; }}
    .divider {{ height: 1px; background: {DISHI_BORDER_SOLID}; margin: 22px 0; }}
    .highlight {{ background: {DISHI_CARD_ELEVATED}; border-left: 3px solid {DISHI_PRIMARY_MINT}; border-radius: 12px; padding: 16px 20px; margin: 20px 0; border-top: 1px solid {DISHI_BORDER_SOLID}; border-right: 1px solid {DISHI_BORDER_SOLID}; border-bottom: 1px solid {DISHI_BORDER_SOLID}; }}
    .highlight p {{ font-size: 14px; color: #E2E8F0; line-height: 1.6; margin: 0; }}
    .btn {{ display: inline-block; background: linear-gradient(135deg, {DISHI_PRIMARY_MINT} 0%, #00B48A 100%); color: #060A12 !important; font-weight: 800; font-size: 15px; padding: 15px 36px; border-radius: 50px; text-decoration: none; letter-spacing: 0.5px; box-shadow: 0 8px 25px rgba(0, 212, 146, 0.35); }}
    .chip {{ display: inline-block; background: rgba(0, 212, 146, 0.12); color: {DISHI_PRIMARY_MINT}; border: 1px solid rgba(0, 212, 146, 0.35); border-radius: 50px; padding: 6px 16px; font-size: 13px; font-weight: 700; margin: 4px 4px 4px 0; }}
    .alert-box {{ background: rgba(239, 68, 68, 0.08); border: 1px solid rgba(239, 68, 68, 0.25); border-left: 4px solid #EF4444; border-radius: 12px; padding: 16px 20px; margin: 20px 0; }}
    .alert-box p {{ color: #FCA5A5; font-size: 13px; line-height: 1.6; margin: 0; }}
    .greeting {{ font-size: 22px; font-weight: 800; color: #FFFFFF; margin-bottom: 8px; line-height: 1.3; }}
    .body-text {{ font-size: 15px; line-height: 1.7; color: {DISHI_TEXT_MUTED}; }}
    @media only screen and (max-width: 620px) {{
      .wrapper-table {{ width: 100% !important; padding: 12px 6px !important; }}
      .content-cell {{ padding: 24px 18px !important; }}
      .otp-digit {{ font-size: 32px !important; letter-spacing: 8px !important; }}
    }}
  </style>
</head>
<body bgcolor="{DISHI_DARK}" style="margin: 0; padding: 0; background-color: {DISHI_DARK};">
  {preheader_html}
  <table role="presentation" class="wrapper-table" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="{DISHI_DARK}" style="background-color: {DISHI_DARK}; width: 100%; margin: 0 auto; padding: 28px 10px;">
    <tr>
      <td align="center" valign="top">
        <!--[if mso]>
        <table role="presentation" width="600" align="center" style="width:600px;" cellpadding="0" cellspacing="0" border="0">
        <tr><td>
        <![endif]-->
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" align="center" style="max-width: 600px; width: 100%; margin: 0 auto; background-color: {DISHI_CARD}; border-radius: 18px; border: 1px solid {DISHI_BORDER_SOLID}; overflow: hidden; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.65);">
          
          <!-- Top Neon Accent Stripe -->
          <tr>
            <td height="4" bgcolor="{DISHI_PRIMARY_MINT}" style="height: 4px; line-height: 4px; font-size: 4px; background: {DISHI_PRIMARY_MINT}; background: linear-gradient(90deg, #00D492 0%, #00F0FF 50%, #FF2A6D 100%);">&nbsp;</td>
          </tr>

          <!-- Brand Header -->
          <tr>
            <td align="center" bgcolor="{DISHI_CARD}" style="padding: 28px 24px 20px; background-color: {DISHI_CARD}; border-bottom: 1px solid {DISHI_BORDER_SOLID};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="left" valign="middle">
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td valign="middle">
                          <img src="{DISHI_LOGO_URL}" alt="DISHI" width="38" height="38" style="display: block; width: 38px; height: 38px; border-radius: 10px; border: 1px solid {DISHI_BORDER_SOLID};" onerror="this.style.display='none'" />
                        </td>
                        <td valign="middle" style="padding-left: 12px;">
                          <div style="font-size: 20px; font-weight: 800; color: #FFFFFF; letter-spacing: 1.5px; line-height: 1.1;">DISHI</div>
                          <div style="font-size: 11px; font-weight: 600; color: {DISHI_TEXT_MUTED}; letter-spacing: 0.5px; text-transform: uppercase;">Campus Dining &amp; Payments OS</div>
                        </td>
                      </tr>
                    </table>
                  </td>
                  <td align="right" valign="middle">
                    <div style="display: inline-block; background-color: rgba(0, 212, 146, 0.1); border: 1px solid rgba(0, 212, 146, 0.3); border-radius: 20px; padding: 5px 12px; font-size: 11px; font-weight: 700; color: {DISHI_PRIMARY_MINT}; letter-spacing: 0.8px; text-transform: uppercase;">
                      ● SECURE 2FA
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Content Body -->
          <tr>
            <td class="content-cell" align="left" valign="top" style="padding: 34px 34px 28px; background-color: {DISHI_CARD}; color: {DISHI_TEXT_MAIN};">
              {content_html}
            </td>
          </tr>

          <!-- Official Institutional Footer -->
          <tr>
            <td align="center" bgcolor="#0A101D" style="padding: 28px 30px 24px; background-color: #0A101D; border-top: 1px solid {DISHI_BORDER_SOLID};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center" style="font-size: 12px; font-weight: 700; color: {DISHI_PRIMARY_MINT}; letter-spacing: 0.8px;">
                    DISHI SMART CAMPUS OPERATING SYSTEM
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top: 8px; font-size: 12px; color: {DISHI_TEXT_MUTED}; line-height: 1.6;">
                    Delstarford Works Ltd &bull; Technology Park &bull; Nairobi, Kenya
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top: 8px; font-size: 12px; color: {DISHI_TEXT_MUTED};">
                    <a href="{DISHI_ECOSYSTEM_URL}" style="color: {DISHI_PRIMARY_MINT}; text-decoration: none; font-weight: 600;">Ecosystem Portal</a>
                    &nbsp;&bull;&nbsp;
                    <a href="mailto:{DISHI_SUPPORT_EMAIL}" style="color: {DISHI_PRIMARY_MINT}; text-decoration: none; font-weight: 600;">Support Desk</a>
                    &nbsp;&bull;&nbsp;
                    <a href="{DISHI_ECOSYSTEM_URL}/api/v1/admin" style="color: {DISHI_TEXT_MUTED}; text-decoration: none;">Security Center</a>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top: 16px; font-size: 11px; color: #475569; line-height: 1.6;">
                    This is an automated institutional security transmission. Never disclose credentials or verification codes.<br />
                    &copy; 2026 Delstarford Works Ltd. All rights reserved.
                  </td>
                </tr>
              </table>
            </td>
          </tr>

        </table>
        <!--[if mso]>
        </td></tr>
        </table>
        <![endif]-->
      </td>
    </tr>
  </table>
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


def pin_reset_otp_email(user_name: str, otp_code: str, device_hint: str = "", expires_minutes: int = 10) -> tuple:
    """Returns (subject, html_body, plain_body) for the PIN reset & 2FA authentication OTP email."""
    from datetime import datetime, timezone
    name = (user_name or "there").strip()
    subject = f"DISHI Security: Your 6-digit verification code is {otp_code}"
    preheader = f"Your one-time verification code is {otp_code}. Valid for {expires_minutes} minutes."
    timestamp_utc = datetime.now(timezone.utc).strftime("%b %d, %Y - %H:%M UTC")

    otp_spaced = " ".join(list(otp_code))

    content_html = f"""
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
          <td>
            <div style="font-size: 12px; font-weight: 800; color: {DISHI_PRIMARY_MINT}; letter-spacing: 1.5px; text-transform: uppercase;">
              ACCOUNT AUTHORIZATION
            </div>
            <h1 style="margin: 6px 0 12px; font-size: 24px; font-weight: 800; color: #FFFFFF; line-height: 1.3;">
              Security Verification Code
            </h1>
            <p style="margin: 0 0 20px; font-size: 15px; line-height: 1.7; color: {DISHI_TEXT_MUTED};">
              Hi <strong style="color: #FFFFFF;">{name}</strong>,<br />
              We received a request to verify your identity or configure your DISHI Wallet PIN. Enter the one-time security passcode below in the DISHI app to continue:
            </p>
          </td>
        </tr>

        <!-- OTP Vault Card -->
        <tr>
          <td align="center" style="padding: 10px 0 24px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #070B14; border: 2px solid {DISHI_PRIMARY_MINT}; border-radius: 14px; text-align: center; box-shadow: 0 0 30px rgba(0, 212, 146, 0.15);">
              <tr>
                <td style="padding: 24px 20px 8px;">
                  <div style="font-size: 11px; font-weight: 800; color: #64748B; text-transform: uppercase; letter-spacing: 2px;">
                    ONE-TIME AUTHORIZATION CODE
                  </div>
                </td>
              </tr>
              <tr>
                <td style="padding: 4px 20px 14px;">
                  <div class="otp-digit" style="font-family: 'JetBrains Mono', 'SF Mono', Monaco, Consolas, monospace; font-size: 40px; font-weight: 800; color: {DISHI_PRIMARY_MINT}; letter-spacing: 12px; line-height: 1.2;">
                    {otp_code}
                  </div>
                  <div style="margin-top: 6px; font-size: 11px; font-weight: 700; color: #64748B; letter-spacing: 1px; text-transform: uppercase;">
                    TAP AND HOLD TO COPY
                  </div>
                </td>
              </tr>
              <tr>
                <td style="padding: 0 20px 20px;">
                  <table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0" style="background-color: rgba(255, 255, 255, 0.05); border-radius: 20px; padding: 6px 16px;">
                    <tr>
                      <td style="font-size: 12px; color: #CBD5E1; font-weight: 600;">
                        ⏱️ Expires in <strong style="color: #FFFFFF;">{expires_minutes} minutes</strong> &bull; Single-use token
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Request Details Table -->
        <tr>
          <td style="padding: 0 0 22px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: {DISHI_CARD_ELEVATED}; border: 1px solid {DISHI_BORDER_SOLID}; border-radius: 12px; padding: 16px 20px;">
              <tr>
                <td colspan="2" style="padding-bottom: 10px; font-size: 11px; font-weight: 800; color: {DISHI_PRIMARY_MINT}; letter-spacing: 1.2px; text-transform: uppercase;">
                  TRANSACTION VERIFICATION SUMMARY
                </td>
              </tr>
              <tr>
                <td style="padding: 5px 0; font-size: 13px; color: {DISHI_TEXT_MUTED}; width: 38%;">Service:</td>
                <td style="padding: 5px 0; font-size: 13px; font-weight: 600; color: #FFFFFF;">DISHI Campus Wallet &amp; Dining</td>
              </tr>
              <tr>
                <td style="padding: 5px 0; font-size: 13px; color: {DISHI_TEXT_MUTED};">Verification:</td>
                <td style="padding: 5px 0; font-size: 13px; font-weight: 600; color: #FFFFFF;">PIN Setup &amp; Account Authentication</td>
              </tr>
              <tr>
                <td style="padding: 5px 0; font-size: 13px; color: {DISHI_TEXT_MUTED};">Issued At:</td>
                <td style="padding: 5px 0; font-size: 13px; font-weight: 600; color: #FFFFFF;">{timestamp_utc}</td>
              </tr>
              {f'<tr><td style="padding: 5px 0; font-size: 13px; color: {DISHI_TEXT_MUTED};">Device Hint:</td><td style="padding: 5px 0; font-size: 13px; font-weight: 600; color: #FFFFFF;">{device_hint}</td></tr>' if device_hint else ''}
            </table>
          </td>
        </tr>

        <!-- Anti-Phishing Security Guarantee Box -->
        <tr>
          <td style="padding: 0 0 20px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: rgba(239, 68, 68, 0.08); border: 1px solid rgba(239, 68, 68, 0.25); border-left: 4px solid #EF4444; border-radius: 10px; padding: 16px 18px;">
              <tr>
                <td>
                  <div style="font-size: 13px; font-weight: 800; color: #EF4444; letter-spacing: 0.5px;">
                    🛡️ DISHI SECURITY POLICY &bull; DO NOT SHARE
                  </div>
                  <div style="margin-top: 6px; font-size: 13px; line-height: 1.6; color: #FCA5A5;">
                    DISHI campus staff, university cafeteria attendants, and customer support will <strong>NEVER</strong> contact you to ask for this verification code, your PIN, or your password. If anyone requests this code, do not disclose it under any circumstances.
                  </div>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Pro Tip Box -->
        <tr>
          <td style="padding: 0 0 10px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: rgba(255, 255, 255, 0.03); border: 1px solid {DISHI_BORDER_SOLID}; border-radius: 10px; padding: 14px 18px;">
              <tr>
                <td style="font-size: 13px; line-height: 1.6; color: {DISHI_TEXT_MUTED};">
                  💡 <strong style="color: #FFFFFF;">Pro Tip:</strong> After confirming your PIN, you can enable Biometric Fingerprint login in the DISHI Settings to pay at campus cafeterias in 1 second without typing your PIN every time.
                </td>
              </tr>
            </table>
          </td>
        </tr>

      </table>
    """

    plain_body = f"""========================================================================
                      DISHI CAMPUS SECURITY
========================================================================

Hi {name},

We received a request to verify your identity or configure your DISHI
Wallet PIN on the DISHI Campus Platform.

SECURITY VERIFICATION CODE:

                       [   {otp_spaced}   ]

This single-use authorization code is valid for {expires_minutes} minutes.
Enter this code in the DISHI mobile application to complete verification.

------------------------------------------------------------------------
REQUEST SUMMARY
------------------------------------------------------------------------
• Service:          DISHI Campus Wallet & Dining
• Verification:     PIN Setup & Account Authentication
• Issued At:        {timestamp_utc}
{f'• Device Hint:      {device_hint}\n' if device_hint else ''}• Expiry:           {expires_minutes} Minutes (Single Use)

------------------------------------------------------------------------
SECURITY ADVISORY — DO NOT SHARE THIS CODE
------------------------------------------------------------------------
DISHI campus staff, university cafeteria attendants, and support
representatives will NEVER contact you asking for this verification code,
your PIN, or your password via phone, SMS, WhatsApp, or email.

If you did not request this code, your account may be at risk. Please
contact our security desk immediately at:
Email: {DISHI_SUPPORT_EMAIL}
Portal: {DISHI_ECOSYSTEM_URL}

========================================================================
Delstarford Works Ltd • Technology Park • Nairobi, Kenya
Official automated notification for registered DISHI accounts.
© 2026 Delstarford Works Ltd. All rights reserved.
========================================================================
"""

    return subject, _base_template(content_html, preheader=preheader, title="DISHI Security Passcode"), plain_body


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
    name = (user_name or "there").strip()
    role_title = role.replace('_', ' ').capitalize() if role else "Student"
    subject = "Welcome to DISHI — Campus Dining & Digital Payments Operating System"
    preheader = f"Welcome {name}! Your DISHI account ({user_email}) as {role_title} is ready."

    content_html = f"""
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
          <td>
            <div style="font-size: 12px; font-weight: 800; color: {DISHI_PRIMARY_MINT}; letter-spacing: 1.5px; text-transform: uppercase;">
              OFFICIAL ONBOARDING
            </div>
            <h1 style="margin: 6px 0 12px; font-size: 24px; font-weight: 800; color: #FFFFFF; line-height: 1.3;">
              Welcome to DISHI, {name}! 🍽️
            </h1>
            <p style="margin: 0 0 20px; font-size: 15px; line-height: 1.7; color: {DISHI_TEXT_MUTED};">
              Your official DISHI account has been created successfully. DISHI is your complete university dining, contactless NFC meal card, courier delivery, and digital payments operating system.
            </p>
          </td>
        </tr>

        <!-- Account Credentials Summary Card -->
        <tr>
          <td style="padding: 0 0 24px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: {DISHI_CARD_ELEVATED}; border: 1px solid {DISHI_BORDER_SOLID}; border-left: 4px solid {DISHI_PRIMARY_MINT}; border-radius: 12px; padding: 18px 22px;">
              <tr>
                <td colspan="2" style="padding-bottom: 12px; font-size: 11px; font-weight: 800; color: {DISHI_PRIMARY_MINT}; letter-spacing: 1.2px; text-transform: uppercase;">
                  VERIFIED ACCOUNT PROFILE
                </td>
              </tr>
              <tr>
                <td style="padding: 6px 0; font-size: 13px; color: {DISHI_TEXT_MUTED}; width: 35%;">Member Name:</td>
                <td style="padding: 6px 0; font-size: 13px; font-weight: 700; color: #FFFFFF;">{name}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; font-size: 13px; color: {DISHI_TEXT_MUTED};">Registered Email:</td>
                <td style="padding: 6px 0; font-size: 13px; font-weight: 600; color: #FFFFFF;">{user_email}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; font-size: 13px; color: {DISHI_TEXT_MUTED};">Assigned Role:</td>
                <td style="padding: 6px 0; font-size: 13px; font-weight: 700; color: {DISHI_PRIMARY_MINT};">{role_title}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; font-size: 13px; color: {DISHI_TEXT_MUTED};">Account Status:</td>
                <td style="padding: 6px 0; font-size: 13px; font-weight: 700; color: #00F0FF;">Active &bull; Verified</td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- 3 Quick Steps -->
        <tr>
          <td style="padding: 0 0 24px;">
            <div style="font-size: 12px; font-weight: 800; color: #FFFFFF; letter-spacing: 1px; text-transform: uppercase; margin-bottom: 14px;">
              🚀 3 Quick Steps to Get Started
            </div>

            <!-- Step 1 -->
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: rgba(255, 255, 255, 0.03); border: 1px solid {DISHI_BORDER_SOLID}; border-radius: 10px; padding: 14px 18px; margin-bottom: 10px;">
              <tr>
                <td width="32" valign="top" style="font-size: 18px;">🔒</td>
                <td style="padding-left: 10px;">
                  <div style="font-size: 14px; font-weight: 700; color: #FFFFFF;">1. Set Up Your Wallet PIN</div>
                  <div style="font-size: 13px; color: {DISHI_TEXT_MUTED}; margin-top: 3px; line-height: 1.5;">
                    Configure your secret 4-digit PIN in the DISHI app to protect your balances and authorize cafeteria checkouts.
                  </div>
                </td>
              </tr>
            </table>

            <!-- Step 2 -->
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: rgba(255, 255, 255, 0.03); border: 1px solid {DISHI_BORDER_SOLID}; border-radius: 10px; padding: 14px 18px; margin-bottom: 10px;">
              <tr>
                <td width="32" valign="top" style="font-size: 18px;">💳</td>
                <td style="padding-left: 10px;">
                  <div style="font-size: 14px; font-weight: 700; color: #FFFFFF;">2. Top Up via Safaricom M-PESA</div>
                  <div style="font-size: 13px; color: {DISHI_TEXT_MUTED}; margin-top: 3px; line-height: 1.5;">
                    Load your digital wallet instantly using Daraja M-PESA STK Push for zero-fee cafeteria transactions.
                  </div>
                </td>
              </tr>
            </table>

            <!-- Step 3 -->
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: rgba(255, 255, 255, 0.03); border: 1px solid {DISHI_BORDER_SOLID}; border-radius: 10px; padding: 14px 18px;">
              <tr>
                <td width="32" valign="top" style="font-size: 18px;">⚡</td>
                <td style="padding-left: 10px;">
                  <div style="font-size: 14px; font-weight: 700; color: #FFFFFF;">3. Tap &amp; Dine with NFC or QR</div>
                  <div style="font-size: 13px; color: {DISHI_TEXT_MUTED}; margin-top: 3px; line-height: 1.5;">
                    Tap your student NFC wristband/card or show your dynamic offline QR code at cafeteria counters to collect meals in seconds.
                  </div>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Call to Action Button -->
        <tr>
          <td align="center" style="padding: 10px 0 28px;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center">
              <tr>
                <td align="center" style="border-radius: 50px; background: linear-gradient(135deg, {DISHI_PRIMARY_MINT} 0%, #00B48A 100%); box-shadow: 0 8px 25px rgba(0, 212, 146, 0.35);">
                  <a href="{DISHI_ECOSYSTEM_URL}" target="_blank" style="display: inline-block; padding: 16px 38px; font-size: 15px; font-weight: 800; color: #060A12; text-decoration: none; letter-spacing: 0.5px;">
                    Open DISHI Ecosystem &rarr;
                  </a>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Security Advisory -->
        <tr>
          <td style="padding: 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: rgba(0, 212, 146, 0.06); border: 1px solid rgba(0, 212, 146, 0.25); border-left: 4px solid {DISHI_PRIMARY_MINT}; border-radius: 10px; padding: 14px 18px;">
              <tr>
                <td style="font-size: 12px; line-height: 1.6; color: #CBD5E1;">
                  🛡️ <strong style="color: #FFFFFF;">Security Commitment:</strong> DISHI protects your balance with bank-grade encryption and two-factor authentication. Never share your secret 4-digit PIN or email OTP with anyone.
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    """

    plain_body = f"""========================================================================
                         WELCOME TO DISHI
               Campus Dining & Digital Payments OS
========================================================================

Hi {name},

Welcome to DISHI — your campus dining, contactless NFC meal card,
and university digital payments operating system.

Your account has been successfully configured and activated.

------------------------------------------------------------------------
ACCOUNT SUMMARY
------------------------------------------------------------------------
• Member Name:      {name}
• Registered Email: {user_email}
• Assigned Role:    {role_title}
• Account Status:   Active & Verified
• Web Access:       {DISHI_ECOSYSTEM_URL}

------------------------------------------------------------------------
GETTING STARTED (3 QUICK STEPS)
------------------------------------------------------------------------
1. Set Up Your Wallet PIN:
   Configure your confidential 4-digit PIN in the DISHI app to unlock
   instant checkouts at campus dining halls.

2. Top Up via Safaricom M-PESA:
   Load funds instantly to your student balance with zero delays using
   our secure Daraja M-PESA STK Push gateway.

3. Tap & Dine with NFC or Dynamic QR:
   Tap your contactless student card or show your offline dynamic QR
   code at cafeteria counters to collect meals in seconds.

------------------------------------------------------------------------
ACCOUNT SECURITY GUARANTEE
------------------------------------------------------------------------
Your funds and meal entitlements are protected with bank-grade encryption.
DISHI staff and university cafeteria cashiers will NEVER ask you for your
PIN or verification code.

Need assistance? Our campus support team is always here for you:
Support Email: {DISHI_SUPPORT_EMAIL}
Ecosystem:     {DISHI_ECOSYSTEM_URL}

========================================================================
Delstarford Works Ltd • Technology Park • Nairobi, Kenya
Official automated notification for registered DISHI accounts.
© 2026 Delstarford Works Ltd. All rights reserved.
========================================================================
"""

    return subject, _base_template(content_html, preheader=preheader, title="Welcome to DISHI"), plain_body


def send_multi_channel_email(to: str, subject: str, html_body: str, plain_body: str = None, user_id: str = None, otp_code: str = None) -> tuple:
    """
    Sends email via available channels in robust priority order:
    1. Resend HTTP API (Port 443 HTTPS - Vercel Native)
    2. Brevo HTTP API (Port 443 HTTPS)
    3. SendGrid HTTP API (Port 443 HTTPS)
    4. Local Sendmail Binary (/usr/sbin/sendmail - HostPinnacle cPanel / Exim Native)
    5. Localhost Exim SMTP (127.0.0.1:465 SSL, 127.0.0.1:587 TLS, 127.0.0.1:25)
    6. Direct Remote SMTP SSL/TLS (mail.delstarfordworks.co.ke:465 / 587 with 15s timeout)
    7. In-App Notification (Firestore) as complementary backup

    Anti-Spam Optimizations:
    - RFC 5322 MIME Multipart Alternative structure (text/plain + text/html)
    - Automatic plain-text generation if omitted or identical to HTML
    - RFC 3834 Auto-Submitted: auto-generated (bypasses Promotions/Spam classification)
    - X-Auto-Response-Suppress: All (Outlook / Office 365 deliverability)
    - High-Priority security transmission headers
    - FQDN Message-ID matching sender domain (@delstarfordworks.co.ke)

    Returns: (success: bool, delivery_method: str)
    """
    import os
    import sys
    import shutil
    import subprocess
    import requests
    import smtplib
    import ssl
    import time
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

    # Fallback to high-fidelity plain text if plain_body is missing, empty, or passed as raw HTML
    if not plain_body or not plain_body.strip() or plain_body == html_body or plain_body.strip().startswith(('<!DOCTYPE', '<html', '<table', '<div')):
        plain_body = _html_to_plain_text(html_body)

    # Build RFC 5322 compliant MIME message with bank-grade deliverability headers
    msg = MIMEMultipart("alternative")
    msg['Subject'] = subject
    msg['From'] = f'"DISHI Security" <{sender}>'
    msg['To'] = to
    msg['Reply-To'] = f'"DISHI Support" <{sender}>'
    msg['Sender'] = sender
    msg['Return-Path'] = f"<{sender}>"
    msg['Date'] = formatdate(localtime=True)
    msg['Message-ID'] = make_msgid(domain='delstarfordworks.co.ke')
    msg['MIME-Version'] = "1.0"
    msg['X-Mailer'] = "DISHI Security Gateway/2.4 (Enterprise Linux)"
    # RFC 3834 transactional machine-generated email indicator
    msg['Auto-Submitted'] = "auto-generated"
    # Suppress out-of-office autoreplies in Microsoft 365 / Exchange
    msg['X-Auto-Response-Suppress'] = "All"
    # Security transaction priority flags
    msg['X-Priority'] = "1 (Highest)"
    msg['X-MSMail-Priority'] = "High"
    msg['Importance'] = "High"

    # Attach plain text part first, then HTML part (standard RFC 2046 multipart/alternative order)
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
                    "from": {"email": sender, "name": "DISHI Security"},
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
