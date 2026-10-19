import os
import sys
import re
import shutil
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, HRFlowable
)
from reportlab.pdfgen import canvas

def clean_xml(text):
    text = re.sub(r'<br\s*>', '<br/>', text, flags=re.IGNORECASE)
    # replace naked & with &amp;
    text = re.sub(r'&(?!(?:amp|lt|gt|quot|apos);)', '&amp;', text)
    return text

def make_p(text, style):
    return Paragraph(clean_xml(text), style)

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, total_pages):
        if self._pageNumber == 1:
            return

        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#028A6E"))
        self.drawString(54, 800, "DISHI PLATFORM • THE OFFICIAL INSTITUTIONAL CONSTITUTION")
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        self.drawRightString(541, 800, "REPUBLIC OF KENYA • ENTERPRISE CHARTER")
        
        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.6)
        self.line(54, 792, 541, 792)
        self.line(54, 48, 541, 48)

        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#028A6E"))
        self.drawString(54, 36, "DELSTARFORD WORKS (KENYA) • PROPRIETARY & CONFIDENTIAL")
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        self.drawRightString(541, 36, f"Page {self._pageNumber} of {total_pages}")
        self.restoreState()

def build_constitution_pdf(output_filename):
    doc = SimpleDocTemplate(
        output_filename,
        pagesize=A4,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()

    c_title = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=24,
        leading=30,
        textColor=colors.HexColor('#064E3B'),
        alignment=1,
        spaceAfter=15
    )

    c_subtitle = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=11,
        leading=16,
        textColor=colors.HexColor('#0F766E'),
        alignment=1,
        spaceAfter=25
    )

    c_meta = ParagraphStyle(
        'CoverMeta',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=13,
        textColor=colors.HexColor('#334155'),
        alignment=1
    )

    art_heading = ParagraphStyle(
        'ArtHeading',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        textColor=colors.HexColor('#064E3B'),
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True
    )

    sec_heading = ParagraphStyle(
        'SecHeading',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=10.5,
        leading=14,
        textColor=colors.HexColor('#0F766E'),
        spaceBefore=10,
        spaceAfter=5,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'LegalBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13.2,
        textColor=colors.HexColor('#1E293B'),
        spaceAfter=6,
        alignment=4
    )

    body_bold = ParagraphStyle(
        'LegalBodyBold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )

    bullet_style = ParagraphStyle(
        'LegalBullet',
        parent=body_style,
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=4
    )

    warn_style = ParagraphStyle(
        'WarnStyle',
        parent=body_style,
        fontName='Helvetica-Bold',
        textColor=colors.HexColor('#991B1B')
    )

    story = []

    # =========================================================================
    # PAGE 1: COVER
    # =========================================================================
    story.append(Spacer(1, 35))
    story.append(make_p("THE REPUBLIC OF KENYA", ParagraphStyle('Rep', fontName='Helvetica-Bold', fontSize=14, leading=18, alignment=1, textColor=colors.HexColor('#B91C1C'))))
    story.append(make_p("IN THE MATTER OF THE COMPANIES ACT, 2015 &amp; THE EMPLOYMENT ACT, 2007", ParagraphStyle('Act', fontName='Helvetica', fontSize=9, leading=13, alignment=1, textColor=colors.HexColor('#475569'))))
    story.append(Spacer(1, 15))
    story.append(HRFlowable(width="100%", thickness=3, color=colors.HexColor('#05D5AA'), spaceAfter=20))
    story.append(make_p("THE OFFICIAL CONSTITUTION", c_title))
    story.append(make_p("AND INSTITUTIONAL GOVERNANCE CHARTER OF", ParagraphStyle('Of', fontName='Helvetica-Bold', fontSize=11, leading=15, alignment=1, textColor=colors.HexColor('#334155'))))
    story.append(make_p("DISHI PLATFORM", ParagraphStyle('Brand', fontName='Helvetica-Bold', fontSize=28, leading=34, alignment=1, textColor=colors.HexColor('#05D5AA'))))
    story.append(Spacer(1, 8))
    story.append(make_p("The Operating System for Campus Meals, 0.5% Vendor Agency Banking, Escrow Gigs, DeLiv Logistics &amp; Universal Student Inclusion", c_subtitle))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#E2E8F0'), spaceAfter=20))

    cover_table_data = [
        [make_p("<b>Document Series:</b>", body_style), make_p("Enterprise Statutory Charter • Edition 3.0", body_style)],
        [make_p("<b>Parent Corporate Entity:</b>", body_style), make_p("Delstarford Works (Nairobi, Kenya)", body_style)],
        [make_p("<b>Statutory Jurisdiction:</b>", body_style), make_p("Republic of Kenya (Constitution 2010, Companies Act 2015)", body_style)],
        [make_p("<b>Operational Effective Date:</b>", body_style), make_p("1st January 2027 (Structured Compensation Commencement)", body_style)],
        [make_p("<b>Supermajority Threshold:</b>", body_style), make_p("90% Affirmative Vote of Executive Wing Shares", body_style)],
        [make_p("<b>Desertion &amp; Abandonment Rule:</b>", body_style), make_p("3 Consecutive Weeks Unexcused Absence (Automatic Removal)", body_style)],
        [make_p("<b>Inactive Shareholder Rule:</b>", body_style), make_p("1 Month (30 Days) Notice; Compulsory Capital Refund &amp; Exit", body_style)],
        [make_p("<b>Official Digital Portal:</b>", body_style), make_p("https://dishi.delstarfordworks.co.ke", body_style)]
    ]
    t_cover = Table(cover_table_data, colWidths=[190, 290])
    t_cover.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8FAFC')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#CBD5E1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(t_cover)
    story.append(Spacer(1, 30))
    story.append(make_p("<b>RATIFIED AND ENACTED BY THE EXECUTIVE WING AND FOUNDING TRUSTEES</b><br/>FOR STRICT ENFORCEMENT ACROSS ALL HIGHER EDUCATION CAMPUSES IN KENYA", c_meta))
    story.append(PageBreak())

    # =========================================================================
    # PAGE 2: TABLE OF CONTENTS & PREAMBLE
    # =========================================================================
    story.append(make_p("TABLE OF CONTENTS &amp; STRUCTURAL OUTLINE", art_heading))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#05D5AA'), spaceAfter=10))

    toc_items = [
        ("ARTICLE I", "Foundational Sovereignty, Legal Name, Registered Office &amp; Scope", "Page 3"),
        ("ARTICLE II", "Constitutional Supremacy &amp; Alignment with the Laws of Kenya", "Page 4"),
        ("ARTICLE III", "Foundational Philosophy, Core Purpose &amp; Non-Negotiable Human Rights", "Page 5"),
        ("ARTICLE IV", "The Five (5) Permanent Operational Departments &amp; Jurisdictions", "Page 6"),
        ("ARTICLE V", "Departmental Functions: Catering, Agency Banking, Gigs, Harambee &amp; Inclusion", "Page 7"),
        ("ARTICLE VI", "Executive Wing, Board of Governance, Chief Officers &amp; Quorums", "Page 9"),
        ("ARTICLE VII", "Financial Compensation &amp; Monthly Stipends (Effective 1st January 2027)", "Page 11"),
        ("ARTICLE VIII", "Employee Responsibilities &amp; The Three-Week (3-Week) Desertion Rule", "Page 13"),
        ("ARTICLE IX", "Equity Shareholding &amp; The One-Month (1-Month) Inactivity Buyout Rule", "Page 15"),
        ("ARTICLE X", "Institutional Partnerships, Contracts &amp; The 90% Executive Vote Rule", "Page 17"),
        ("ARTICLE XI", "Constitutional Amendments, New Rules &amp; The 90% Equity Approval Rule", "Page 18"),
        ("ARTICLE XII", "Financial Architecture, M-PESA Daraja &amp; 100% Escrow Vault Protocol", "Page 19"),
        ("ARTICLE XIII", "Universal Accessibility Mandate for Differently Gifted Comrades", "Page 20"),
        ("ARTICLE XIV", "Proprietary Intellectual Property &amp; Data Protection Compliance", "Page 21"),
        ("ARTICLE XV", "Internal Discipline, Whistleblowing &amp; Arbitration (NCIA)", "Page 22"),
        ("ARTICLE XVI", "Winding Up, Dissolution, Liquidation &amp; Asset Distribution Protocol", "Page 23"),
        ("SCHEDULE A", "Enterprise Operational Hierarchy &amp; Reporting Lines", "Page 24"),
        ("SCHEDULE B", "Founding Signatories, Executive Ratification Seal &amp; Witnesses", "Page 25"),
    ]

    t_toc_data = [[
        make_p(f"<b>{art}</b>", body_style),
        make_p(f"{title}", body_style),
        make_p(f"<b>{p_no}</b>", ParagraphStyle('R', parent=body_style, alignment=2))
    ] for art, title, p_no in toc_items]
    t_toc = Table(t_toc_data, colWidths=[75, 340, 70])
    t_toc.setStyle(TableStyle([
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#F1F5F9')),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(t_toc)
    story.append(Spacer(1, 10))

    story.append(make_p("CONSTITUTIONAL PREAMBLE", sec_heading))
    story.append(make_p(
        "<b>WE, THE FOUNDERS, EXECUTIVE OFFICERS, AND STUDENT AMBASSADORS OF DISHI PLATFORM</b>, acknowledging the supremacy of the Almighty God; recognizing the systemic vulnerability, dining indignity, and financial exclusion experienced daily by comrades across universities and colleges in the Republic of Kenya; guided by an unwavering commitment to radical African empathy, socioeconomic dignity, and technological self-reliance: "
        "<br/><br/><b>COMMITTED</b> to building an impenetrable ecosystem that eliminates campus hunger through smart pre-orders, sub-300 millisecond offline NFC dining cards, 0.5% cafeteria cash-in agency banking, escrow-backed student artisan gigs, and universal barrier-free access for comrades gifted differently; "
        "<br/><br/><b>EXERCISING</b> our sovereign right and legal autonomy under the Constitution of Kenya, 2010, the Companies Act, 2015, and the Employment Act, 2007, <b>DO HEREBY ADOPT, ENACT, AND BIND OURSELVES TO THIS OFFICIAL CONSTITUTION</b> as the supreme governance framework of DISHI.",
        body_style
    ))
    story.append(PageBreak())

    # =========================================================================
    # PAGES 3 TO 25: COMPLETE ARTICLES (EXACT 25 PAGES)
    # =========================================================================
    articles_data = [
        # PAGE 3
        (
            "ARTICLE I: FOUNDATIONAL SOVEREIGNTY, NAME & REGISTERED HEADQUARTERS",
            [
                ("Section 1.1: Official Name & Legal Identity",
                 "The official name of the operating system, commercial ecosystem, and legal platform shall be DISHI (hereinafter referred to as 'DISHI Platform', 'DISHI OS', or 'The Enterprise'). The platform is established, owned, and operated under Delstarford Works, an incorporated commercial enterprise in the Republic of Kenya."),
                ("Section 1.2: Registered Corporate Headquarters",
                 "The principal corporate registered office and command nerve center of DISHI shall be situated in Nairobi County, Republic of Kenya. Regional administrative hubs, campus liaison desks, and cafeteria integration terminals shall be established in tertiary institutions across all 47 Counties of Kenya."),
                ("Section 1.3: Official Corporate Seal & Insignia",
                 "DISHI shall maintain a Common Corporate Seal and standardized cryptographic branding featuring the DISHI emblem, the African continent silhouette, and the primary brand pantone hex colors (#05D5AA Mint, #FF2A6D Electric Pink, #090E1A Deep Obsidian, #38BDF8 Sky Blue). The Seal shall be applied to all formal university concession agreements, banking partnerships, and share certificates.")
            ]
        ),
        # PAGE 4
        (
            "ARTICLE II: CONSTITUTIONAL & STATUTORY SUPREMACY",
            [
                ("Section 2.1: Alignment with the Constitution of Kenya, 2010",
                 "This Constitution derives its legal validity from the supreme law of the land, the Constitution of Kenya, 2010. Every provision within this Charter shall be interpreted in strict conformity with: "
                 "<br/>• <b>Article 43(1)(c):</b> The fundamental economic right of every person to be free from hunger and to have adequate food of acceptable quality."
                 "<br/>• <b>Article 54:</b> The affirmative rights of Persons with Disabilities to dignity, respect, reasonable accommodation, and barrier-free access to materials, devices, and dining facilities."
                 "<br/>• <b>Article 55:</b> The affirmative state obligation to empower youth through access to relevant education, employment creation, and protection from economic exploitation."
                 "<br/>• <b>Article 10:</b> The national values and principles of governance including human dignity, equity, social justice, inclusiveness, integrity, transparency, and accountability."),
                ("Section 2.2: Subordination to Kenyan Corporate & Labour Statutes",
                 "In the event of any operational ambiguity, the provisions of the Companies Act, 2015, the Employment Act, 2007, the National Payment System Act (Cap 491), and the Data Protection Act, 2019 shall take absolute precedence over any internal administrative guideline of DISHI.")
            ]
        ),
        # PAGE 5
        (
            "ARTICLE III: PHILOSOPHICAL FOUNDATIONS & CORE PURPOSE",
            [
                ("Section 3.1: The Core Mission of DISHI",
                 "The overarching mission of DISHI is to eradicate campus hunger, eliminate predatory transaction friction, and restore human dignity to the university student experience. We accomplish this by turning cafeteria food vendors into digital agency banking touchpoints, equipping students with offline-first tap-to-eat technology, providing parents with ring-fenced nutritional peace of mind, and establishing escrow-backed youth work opportunities."),
                ("Section 3.2: The Five Core Philosophical Pillars",
                 "<b>1. Radical African Empathy:</b> Engineering technology specifically adapted to African infrastructural realities—intermittent mobile internet, smartphone battery depletion, and high transaction costs. We innovate for the student standing at the back of the queue with KES 50 in their pocket.<br/>"
                 "<b>2. Absolute Dining Dignity:</b> No comrade should ever be forced to skip lunch due to a 40-minute cafeteria line before a continuous assessment test (CAT). DISHI pre-orders and sub-300ms tap-to-eat systems restore control and time sovereignty to students.<br/>"
                 "<b>3. Vendor Agency Empowerment:</b> Cafeteria caterers are not merely merchants; they are vital community anchors. By empowering them as 0.5% commission cash-in agents, DISHI bridges the gap between physical cash and digital campus micro-economies.<br/>"
                 "<b>4. Complete Parental Nutrition Assurance:</b> Eliminating the anxiety of diverted cash remittances. When a parent sends money through DISHI, they receive real-time visibility, automated SMS dining receipts, and guaranteed nutritional protection.<br/>"
                 "<b>5. Total Economic Protection for Youth (100% Escrow):</b> Eliminating wage theft and payment default in student artisan gigs through cryptographic milestone escrow vaulting."),
                ("Section 3.3: Strict Anti-Discrimination Covenant",
                 "DISHI Platform shall never discriminate against any comrade, vendor, or employee on the basis of race, ethnic origin, gender, religious creed, economic status, political affiliation, or physical disability. Universal accessibility is a constitutional command, not an optional convenience.")
            ]
        ),
        # PAGE 6
        (
            "ARTICLE IV: THE FIVE (5) PERMANENT OPERATIONAL DEPARTMENTS",
            [
                ("Section 4.1: Departmental Establishment & Structural Autonomy",
                 "To ensure specialized execution, organizational accountability, and seamless scalability across multiple university campuses, DISHI is hereby structured into five (5) permanent, autonomous Operational Departments. Each department shall be commanded by a Director/Department Lead appointed by the Executive Wing."),
                ("Section 4.2: Summary of Departmental Portfolios",
                 "• <b>Department 1: Catering & Cafeteria Food Operations:</b> Kitchen POS, menu digitisation, allergen tracking, food hygiene enforcement, and vendor relations.<br/>"
                 "• <b>Department 2: Finance, Treasury & Agency Banking:</b> M-PESA Daraja reconciliation, 0.5% vendor agent float distribution, B2C payouts, and wallet balance audits.<br/>"
                 "• <b>Department 3: Gigs Logistics & Escrow Security:</b> DeLiv dorm courier dispatch, Comrade Fundi artisan verification, dispute resolution, and 100% Escrow Vault custody.<br/>"
                 "• <b>Department 4: Harambee Solidarity & Community Welfare:</b> Emergency comrade meal aid, verified crowdfunding campaigns, alumni endowment partnerships, and gamification rewards.<br/>"
                 "• <b>Department 5: Universal Accessibility & Assistive Engineering:</b> Assistive screen readers, acoustic collection chimes, wrist haptic pulses, tactile NFC cards, and IoT hardware deployment."),
                ("Section 4.3: Inter-Departmental Collaboration & Chain of Command",
                 "No Department shall operate in a silo. The Director of Finance shall maintain joint oversight with Catering over vendor float liquidity. Gigs Logistics shall coordinate with Accessibility to prioritize dorm deliveries for mobility-challenged students. All five Department Leads report directly to the Chief Executive Officer and Chief Operating Officer.")
            ]
        ),
        # PAGE 7
        (
            "ARTICLE V: DEPARTMENTAL STATUTES (CATERING & FINANCE)",
            [
                ("Section 5.1: Department 1: Catering & Cafeteria Food Operations",
                 "The Catering Department holds primary operational responsibility over all food vendors, university mess halls, student center diners, and commercial kiosks integrated into DISHI. Specific statutory duties include: "
                 "<br/>1. <b>Digital Menu Synchronization:</b> Ensuring cafeteria food listings, live meal prices, portion sizes, and prep time estimates are updated daily by 7:00 AM."
                 "<br/>2. <b>Kitchen Queue Management:</b> Implementing kitchen display systems separating pending, preparing, and ready-to-collect food pre-orders to prevent counter congestion."
                 "<br/>3. <b>Allergen & Nutritional Disclosure:</b> Enforcing mandatory allergen declarations (peanuts, gluten, dairy) across all listed meals to protect student health."
                 "<br/>4. <b>Vendor Compliance & Hygiene Audits:</b> Conducting weekly spot inspections to verify that participating cafeteria operators maintain sanitary food handling standards."),
                ("Section 5.2: Department 2: Finance, Treasury & Agency Banking",
                 "The Finance Department governs all monetary circulation, liquidity balances, Safaricom Daraja API gateways, and commercial cash flows across DISHI. Specific statutory duties include: "
                 "<br/>1. <b>The 0.5% Cash-In Agency Banking Engine:</b> Managing the automated execution of the 0.5% cash-in agent commission credited to cafeteria vendors upon depositing student paper cash into digital wallets."
                 "<br/>2. <b>Float Liquidity Replenishment:</b> Facilitating instant STK Push vendor float top-ups and monitoring daily cafeteria deposit liquidity thresholds."
                 "<br/>3. <b>Instant B2C Merchant Payouts:</b> Maintaining automated Safaricom B2C disbursement channels enabling vendors to cash out daily revenues to M-PESA Tills or Paybills with zero delays."
                 "<br/>4. <b>Multi-Wallet Ledger Reconciliation:</b> Ensuring zero-leakage accounting across the Active Student Wallet, Vendor Float Wallet, Gigs Escrow Vault, and Harambee Pool."
                 "<br/>5. <b>Velocity Monitoring & Anti-Money Laundering (AML):</b> Detecting anomalous deposit frequencies, wash transactions, and balance tampering in compliance with CBK guidelines.")
            ]
        ),
        # PAGE 8
        (
            "ARTICLE V (CONT'D): GIGS, HARAMBEE & ACCESSIBILITY STATUTES",
            [
                ("Section 5.3: Department 3: Gigs Logistics & Escrow Security",
                 "The Gigs Logistics Department safeguards peer-to-peer campus employment and delivery courier services. Specific statutory duties include: "
                 "<br/>1. <b>DeLiv Dorm Food Couriers:</b> Managing the onboarding, dispatch, and hygiene inspection of student food runners delivering meals to university hostels and library desks at flat KES 30–50 courier fees."
                 "<br/>2. <b>Comrade Fundi Artisan Verification:</b> Reviewing student artisan credentials for phone screen replacement, laptop repair, braiding, barbering, plumbing, and tutoring."
                 "<br/>3. <b>100% Escrow Vault Custody:</b> Locking client funds programmatically before work begins and enforcing the milestone release protocol."
                 "<br/>4. <b>Dispute Adjudication:</b> Investigating failed gigs or courier delays, executing atomic escrow refunds where workers fail to show up, and penalizing malicious clients."),
                ("Section 5.4: Department 4: Harambee Solidarity & Community Welfare",
                 "The Harambee Department directs student meal relief, solidarity crowdfunding, and gamification rewards. Specific statutory duties include: "
                 "<br/>1. <b>Emergency Meal Subsidies:</b> Directing micro-aid to destitute students facing end-of-semester starvation through verified cafeteria voucher allocations."
                 "<br/>2. <b>Student Harambee Campaigns:</b> Reviewing peer fundraising campaigns, preventing fraudulent appeals, and ensuring funds land strictly in meal-locked wallets."
                 "<br/>3. <b>Alumni & Corporate Endowment:</b> Managing alumni micro-donations and CSR sponsorships that credit meal balances for vulnerable comrades."
                 "<br/>4. <b>Games Hub Oversight:</b> Governing the 12 campus arcade mini-games, coin conversion formulas, and KES 50/100 meal balance redemptions."),
                ("Section 5.5: Department 5: Universal Accessibility & Assistive Engineering",
                 "The Accessibility Department enforces radical inclusion for comrades gifted differently. Specific statutory duties include: "
                 "<br/>1. <b>Acoustic & Auditory Infrastructure:</b> Installing cafeteria counter audio chimes and voice navigation for blind comrades."
                 "<br/>2. <b>Haptic & Visual Queue Alerts:</b> Maintaining synchronized wrist vibration alerts and visual kitchen monitors for deaf students."
                 "<br/>3. <b>Physical Barrier Elimination:</b> Enforcing wheelchair-height POS mounts and priority hostel room delivery for mobility-challenged students."
                 "<br/>4. <b>Hardware Firmware Maintenance:</b> Overseeing cryptographic offline NFC wristbands, smart watches, and low-cost IoT counter terminals.")
            ]
        ),
        # PAGE 9
        (
            "ARTICLE VI: EXECUTIVE WING & CORPORATE GOVERNANCE",
            [
                ("Section 6.1: The Executive Wing Composition",
                 "The supreme executive and strategic authority of DISHI Platform resides in the Executive Wing. The Executive Wing shall consist of the following permanent seats: "
                 "<br/>1. <b>Chief Executive Officer (CEO):</b> Head of State of DISHI, Chief Visionary, Institutional Negotiator, and Official Legal Representative."
                 "<br/>2. <b>Chief Technology Officer (CTO):</b> Architect of the Flutter frontend, Python Flask backend, Firebase Firestore database, and offline NFC cryptographic infrastructure."
                 "<br/>3. <b>Chief Operating Officer (COO):</b> Commander of daily campus ground operations, cafeteria integrations, and courier fleet logistics."
                 "<br/>4. <b>Chief Financial Officer (CFO):</b> Custodian of Treasury, Daraja M-PESA channels, banking relations, agent float allocations, and financial audits."
                 "<br/>5. <b>Head of Universal Accessibility & Inclusion:</b> Constitutional guardian of differently gifted comrades' accommodations and assistive hardware."),
                ("Section 6.2: Meetings & Regular Governance Quorum",
                 "The Executive Wing shall convene mandatory weekly operational briefings and monthly strategic governance assemblies. For ordinary operational matters, a simple majority of seventy percent (70%) of voting seats shall constitute a quorum. For constitutional amendments, partnership approvals, or disciplinary removals, the supermajority specified in Articles X and XI must be satisfied."),
                ("Section 6.3: Fiduciary Duties & Duty of Loyalty",
                 "Every member of the Executive Wing owes strict fiduciary duties to DISHI under Sections 143 through 146 of the Companies Act, 2015. Executive officers must act in good faith, avoid conflicts of interest, preserve trade secrets, and never divert corporate opportunities for personal enrichment.")
            ]
        ),
        # PAGE 10
        (
            "ARTICLE VII: FINANCIAL COMPENSATION & SALARY COMMENCEMENT",
            [
                ("Section 7.1: Official Compensation Effective Date (1st January 2027)",
                 "It is hereby formally declared and codified that <b>structured monthly salaried payments, stipends, and operational compensation for all appointed employees, department heads, and executive officers of DISHI shall officially commence on the 1st of January, 2027 (01/01/2027)</b>. "
                 "This firm statutory date aligns with the completion of university cafeteria licensing pilot phases, Safaricom Daraja production scale-up, and institutional investor equity capital disbursements."),
                ("Section 7.2: Monthly Compensation Scale (KES 5,000.00 – KES 10,000.00)",
                 "Commencing 1st January 2027, all foundational operational personnel, department leads, and core contributors shall be placed on a structured monthly stipend scale ranging between <b>Kenya Shillings Five Thousand (KES 5,000.00) and Kenya Shillings Ten Thousand (KES 10,000.00) per month</b>, based on their department scale, responsibilities, and key performance indicators (KPIs). "
                 "<br/>• Department Leads & Core Officers: KES 8,000.00 – KES 10,000.00 per month."
                 "<br/>• Campus Supervisors & Coordinators: KES 6,000.00 – KES 8,000.00 per month."
                 "<br/>• Operational Marshals & Specialists: KES 5,000.00 – KES 6,500.00 per month."),
                ("Section 7.3: Foundation Volunteer Incubation Period (Prior to Jan 1, 2027)",
                 "All work performed by founders, department directors, student ambassadors, and developers prior to 1st January 2027 is formally recognized as sweat equity and foundation volunteer incubation. During this incubation phase, operational expenses (server hosting, transport, hardware prototyping) shall be reimbursed from seed treasury, but formal baseline salary liabilities shall not accrue prior to 1st January 2027.")
            ]
        ),
        # PAGE 11
        (
            "ARTICLE VIII: EMPLOYEE CODE & THE THREE-WEEK (3-WEEK) NEGLECT RULE",
            [
                ("Section 8.1: Work Responsibilities & Service Level Standards",
                 "Every worker, employee, officer, and student staff member engaged by DISHI accepts a binding duty of diligence, professionalism, and punctual execution of assigned operational responsibilities. DISHI serves vulnerable comrades where cafeteria food delivery, cash-in agent float, or accessibility guidance cannot afford unexcused operational disruption."),
                ("Section 8.2: The Three-Week (3-Week) Desertion & Automatic Dismissal Rule",
                 "<b>IF ANY WORKER, EMPLOYEE, OR APPOINTED OFFICER STOPS EXECUTING HIS OR HER ASSIGNED RESPONSIBILITIES, ABANDONS THEIR POST, CEASES COMMUNICATION, OR NEGLECTS THEIR DUTIES FOR A PERIOD OF THREE (3) CONSECUTIVE WEEKS (TWENTY-ONE CALENDAR DAYS) WITHOUT PRIOR WRITTEN PERMISSION FROM THE EXECUTIVE WING OR CERTIFIED MEDICAL/FORCE MAJEURE JUSTIFICATION, THEY SHALL BE AUTOMATICALLY AND IRREVOCABLY REMOVED FROM THE BUSINESS AND PLATFORM.</b>"),
                ("Section 8.3: Statutory Compliance with Section 44 of the Employment Act, 2007",
                 "This Three-Week Desertion Clause is enacted in strict harmony with <b>Section 44 of the Employment Act, 2007 (Laws of Kenya)</b>, which defines absenting oneself from the proper place of employment without lawful cause as statutory gross misconduct justifying summary dismissal. The 21-calendar-day unexcused absence constitutes voluntary repudiation and intentional desertion of contract."),
                ("Section 8.4: Procedural Consequences of Automatic Termination",
                 "Upon the expiration of the twenty-one (21) days of continuous unexcused neglect: "
                 "<br/>1. <b>Credential Revocation:</b> The individual's administrative login credentials, database access tokens, and POS terminal authorizations are revoked immediately and permanently."
                 "<br/>2. <b>Forfeiture of Accruals:</b> The individual forfeits all rights to future stipend allocations, performance bonuses, or operational allowances."
                 "<br/>3. <b>Surrender of Property:</b> The individual must immediately return all DISHI proprietary hardware, IoT testing units, branded apparel, documents, and assets."
                 "<br/>4. <b>Summary Record:</b> A formal Certificate of Abandonment is entered into the corporate secretariat registry, concluding their employment with prejudice.")
            ]
        ),
        # PAGE 12
        (
            "ARTICLE IX: SHAREHOLDING & THE ONE-MONTH (1-MONTH) BUYOUT RULE",
            [
                ("Section 9.1: Equity Shareholding Conditioned on Active Participation",
                 "Equity shares and founder stock allocations in DISHI Platform represent active stewardship of an African public-benefit institution. Shares are not passive speculative commodities. Every shareholder and share allocation beneficiary is legally bound to actively participate in executive deliberations, commercial development, strategic committees, and corporate governance."),
                ("Section 9.2: The One-Month (1-Month) Inactivity Default Clause",
                 "<b>IF ANY SHAREHOLDER STOPS PARTICIPATING IN THE BUSINESS, WITHDRAWS FROM STRATEGIC ENGAGEMENT, NEGLECTS SHAREHOLDER OBLIGATIONS, OR FAILS TO ATTEND MANDATED EXECUTIVE ASSEMBLIES:</b>"
                 "<br/>1. <b>Notice of Inactivity:</b> The Executive Wing shall serve a formal written Notice of Inactivity to the shareholder's registered email and physical address."
                 "<br/>2. <b>The One-Month (30-Day) Cure Window:</b> The inactive shareholder shall have exactly <b>one (1) calendar month (thirty calendar days)</b> from the date of the notice to respond by writing an official explanatory petition or letter of re-engagement to the Executive Wing."
                 "<br/>3. <b>Default & Compulsory Buyout:</b> <b>IF THE SHAREHOLDER FAILS TO COMMUNICATE, SUBMIT A FORMAL WRITTEN LETTER, OR RESUME ACTIVE RESPONSIBILITIES WITHIN THE ONE-MONTH PERIOD, THEY SHALL RECEIVE THEIR ORIGINAL CAPITAL INVESTMENT MONEY BACK IN FULL AND SHALL BE FORCED TO PERMANENTLY LEAVE AND FORFEIT ALL SHARES IN THE BUSINESS.</b>"),
                ("Section 9.3: Kenyan Corporate Law Alignment (Companies Act, 2015)",
                 "This compulsory buyout mechanism complies fully with Part XVII (Capital Maintenance) and Section 513 of the <b>Companies Act, 2015 (Laws of Kenya)</b> regarding company share repurchases, forfeiture for breach of shareholder covenant, and treasury cancellation. Upon repaying the shareholder's exact verifiable capital contribution (or par value where sweat equity was granted), the shares are transferred back to the company's unallocated equity reserve and cancelled from the shareholder's name in the Official Register of Members.")
            ]
        ),
        # PAGE 13
        (
            "ARTICLE X: INSTITUTIONAL PARTNERSHIPS & THE 90% VOTE MANDATE",
            [
                ("Section 10.1: Scope of Institutional & Commercial Partnerships",
                 "DISHI operates at the sensitive intersection of higher education administration, student dining welfare, banking agency networks, and youth gigs. All external partnership contracts, memoranda of understanding (MoUs), cafeteria concessions, and commercial joint ventures carry existential institutional significance."),
                ("Section 10.2: Mandatory 90% Executive Supermajority Requirement",
                 "<b>IN ANY EVENT OF ENTERING INTO A PARTNERSHIP WITH ANY HIGHER LEARNING INSTITUTION (PUBLIC OR PRIVATE UNIVERSITY, COLLEGE, POLYTECHNIC, TVET), INDIVIDUAL INVESTOR, COMMERCIAL BANK, SAFARICOM OR TELECOM OPERATOR, NGO, OR BUSINESS ENTITY:</b>"
                 "<br/><b>THE FORMAL PARTNERSHIP CONTRACT MUST RECEIVE AN AFFIRMATIVE VOTE AND BE SIGNED BY AT LEAST NINETY PERCENT (90%) OF THE EXECUTIVE WING'S VOTING SHARES AND SEATS IN ORDER TO BE VALID, BINDING, OR OPERATIONAL.</b>"),
                ("Section 10.3: Nullity of Unilateral or Minority Agreements",
                 "Any contract, agreement, commitment, or memorandum signed by the CEO, CTO, COO, or any individual officer without verified prior written 90% Executive Wing approval shall be <i>ultra vires</i>, null, void, and of no legal effect. The officer attempting unauthorized signature shall be personally liable for damages and subject to disciplinary removal."),
                ("Section 10.4: Mandatory Vetting Procedure for Partnerships",
                 "Prior to subjecting any partnership to the 90% vote: "
                 "<br/>• The Chief Technology Officer must certify API security and data integrity compliance."
                 "<br/>• The Chief Financial Officer must audit revenue share terms and tax exposure."
                 "<br/>• The Head of Inclusion must certify that the partner accommodates differently gifted comrades.")
            ]
        ),
        # PAGE 14
        (
            "ARTICLE XI: CONSTITUTIONAL AMENDMENTS & THE 90% SHARE RULE",
            [
                ("Section 11.1: Supreme Entrenchment of Governance Rules",
                 "To preserve corporate stability, protect student welfare, and defend founding equity, this Constitution is an entrenched document. No routine board resolution, executive decree, or simple majority vote can alter the core architecture of DISHI Platform."),
                ("Section 11.2: Mandatory 90% Shareholding Approval for Any New Rule",
                 "<b>ANY NEW RULE, AMENDMENT, ADDITION, REPEAL, POLICY MODIFICATION, SHARE DILUTION, STRATEGIC PIVOT, OR CONSTITUTIONAL ALTERATION WHATSOEVER MUST BE APPROVED BY AN AFFIRMATIVE VOTE OF AT LEAST NINETY PERCENT (90%) OF THE TOTAL VOTING SHARES HELD BY THE EXECUTIVE WING AND FOUNDING SHAREHOLDERS.</b>"),
                ("Section 11.3: Amendment Protocol & Notice Requirements",
                 "1. <b>Formal Bill of Amendment:</b> Any proposed modification must be drafted as a formal Bill specifying the exact clause, legal justification, and operational impact.<br/>"
                 "2. <b>Twenty-One (21) Days Notice:</b> The Bill must be circulated to all Executive Wing members at least twenty-one (21) calendar days prior to the voting assembly.<br/>"
                 "3. <b>Roll-Call Recorded Vote:</b> Voting shall be conducted via roll-call or cryptographic digital ledger with share weightings permanently recorded in the minutes.<br/>"
                 "4. <b>Ratification Certificate:</b> Upon attaining the 90% affirmative threshold, the amendment becomes binding only after execution of the Ratification Schedule by the CEO and Secretary.")
            ]
        ),
        # PAGE 15
        (
            "ARTICLE XII: FINANCIAL ARCHITECTURE & ESCROW PROTOCOL",
            [
                ("Section 12.1: The Safaricom M-PESA Daraja Integration Engine",
                 "All digital fiat inflows and outflows across DISHI shall interface strictly through certified production gateways connected to the <b>Safaricom M-PESA Daraja API</b> in full compliance with the Central Bank of Kenya (CBK) regulatory standards under the National Payment System Act."),
                ("Section 12.2: The 100% Escrow Vault Architecture",
                 "To protect student clients and comrade artisans in the DeLiv courier and Fundi gig marketplaces, DISHI mandates an automated 100% Escrow Vault protocol: "
                 "<br/>1. <b>Pre-Funded Lock:</b> When a gig or delivery order is initiated, 100% of the agreed fee is debited from the client's wallet and locked inside the Escrow Vault."
                 "<br/>2. <b>Milestone Execution:</b> The worker receives immediate cryptographic proof of locked funds before commencing physical labor or food transit."
                 "<br/>3. <b>Verification & Instant Settlement:</b> Once the client verifies satisfactory job completion or meal delivery, the escrow is unlocked directly into the worker's wallet in under two (2) seconds."
                 "<br/>4. <b>Automatic Refund Protection:</b> If the courier or artisan fails to show up, cancels, or breaches delivery terms, 100% of the escrowed funds are atomically credited back to the client's Active Student Wallet."),
                ("Section 12.3: Vendor Float Liquidity Protection",
                 "Vendor float balances dedicated to 0.5% cash-in agency banking are legally safeguarded as fiduciary custodial funds. DISHI shall never commingle vendor operational float with general company administrative revenues.")
            ]
        ),
        # PAGE 16
        (
            "ARTICLE XIII: RADICAL INCLUSION & DISABILITY ACCESSIBILITY",
            [
                ("Section 13.1: Constitutional Grounding under Article 54",
                 "In active compliance with <b>Article 54 of the Constitution of Kenya, 2010</b> and the Persons with Disabilities Act (Cap 133), DISHI elevates universal accessibility from a feature into an entrenched constitutional guarantee. The platform rejects all software or hardware designs that exclude differently gifted comrades."),
                ("Section 13.2: Accommodations for Blind & Visually Impaired Comrades",
                 "• <b>Auditory Speech Synthesis:</b> Complete screen-reader optimization across all Flutter mobile views and web portals.<br/>"
                 "• <b>Cafeteria Acoustic Chimes:</b> Counter hardware emitting distinct acoustic chimes upon plate readiness.<br/>"
                 "• <b>Braille & Tactile Cards:</b> Physical smart cards embossed with tactile orientation notches for effortless NFC counter checkout."),
                ("Section 13.3: Accommodations for Deaf & Hard-of-Hearing Comrades",
                 "• <b>Wrist Haptic Synchronization:</b> Vibrating alerts informing students the second their food is plated.<br/>"
                 "• <b>High-Contrast Kitchen Displays:</b> Prominent visual collection window monitors eliminating acoustic dependence."),
                ("Section 13.4: Accommodations for Mobility-Challenged Comrades",
                 "• <b>Priority Doorstep Delivery:</b> Direct dorm room meal drops eliminating steep cafeteria stairs.<br/>"
                 "• <b>Low-Elevation Terminals:</b> Accessible point-of-sale mounts compliant with seated wheelchair heights.")
            ]
        ),
        # PAGE 17
        (
            "ARTICLE XIV: INTELLECTUAL PROPERTY & DATA PRIVACY",
            [
                ("Section 14.1: Proprietary Ownership of Codebase & Trademarks",
                 "All proprietary source code (Flutter mobile application, Python Flask backend, Firebase Firestore schemas, cryptographic NFC algorithms, RESTful APIs, IoT terminal designs), brand trademarks, logos, patents, and domain names (dishi.delstarfordworks.co.ke) are the exclusive, indivisible corporate property of <b>Delstarford Works</b>."),
                ("Section 14.2: Work-for-Hire Doctrine under Kenyan Copyright Law",
                 "In accordance with the Industrial Property Act, 2001 and the Copyright Act (Cap 130, Laws of Kenya), all intellectual property created by founders, employees, contractors, or student ambassadors during their engagement with DISHI is automatically assigned as a work-for-hire to Delstarford Works. No individual contributor retains private intellectual property claims over the system."),
                ("Section 14.3: Compliance with the Kenya Data Protection Act, 2019",
                 "DISHI strictly complies with the <b>Data Protection Act, 2019</b> and regulations overseen by the Office of the Data Protection Commissioner (ODPC). Student dining records, parent phone numbers, and location logs are encrypted in transit (TLS 1.3) and at rest (AES-256). Selling, sharing, or commercializing personal student data to third-party advertisers is permanently prohibited.")
            ]
        ),
        # PAGE 18
        (
            "ARTICLE XV: INTERNAL DISCIPLINE & DISPUTE RESOLUTION",
            [
                ("Section 15.1: The Disciplinary Committee",
                 "An ad-hoc Disciplinary Committee comprising three (3) non-conflicted Executive Wing members shall investigate allegations of financial impropriety, data breaches, sexual harassment, abuse of office, or operational sabotage."),
                ("Section 15.2: Fair Hearing Guarantees (Article 50 Compliance)",
                 "In accordance with Article 50 of the Constitution of Kenya (Fair Hearing) and Section 41 of the Employment Act, 2007, any accused employee or officer shall be provided with a written Charge Sheet detailing the accusations and granted seven (7) business days to defend themselves orally or in writing, with the right to be accompanied by a representative."),
                ("Section 15.3: Mandatory Arbitration Clause (Nairobi Protocol)",
                 "Any irreconcilable dispute, controversy, or claim arising out of this Constitution, shareholder agreements, or commercial contracts shall not be litigated in public courts initially, but shall be submitted to final and binding arbitration under the rules of the <b>Nairobi Centre for International Arbitration (NCIA)</b> by a single arbitrator appointed in accordance with the Arbitration Act, 1995 (Laws of Kenya).")
            ]
        ),
        # PAGE 19
        (
            "ARTICLE XVI: DISSOLUTION & WINDING UP PROTOCOL",
            [
                ("Section 16.1: Exceptional Dissolution Threshold",
                 "DISHI is designed as a perpetual, inter-generational institution. Voluntary dissolution or winding-up of the company can only be approved by a unanimous one hundred percent (100%) affirmative vote of all Executive Wing members and founding shareholders at an Extraordinary General Meeting convened specifically for that purpose."),
                ("Section 16.2: Liquidation Waterfall under Kenyan Insolvency Law",
                 "In the event of dissolution, liquidation of corporate assets shall be conducted strictly in accordance with the <b>Insolvency Act, 2015 (Laws of Kenya)</b> following the statutory priority waterfall: "
                 "<br/>1. <b>Custodial Safeguards:</b> Complete restitution and immediate return of all 100% Escrow Vault client funds and vendor deposit float."
                 "<br/>2. <b>Statutory Obligations:</b> Payment of all outstanding government taxes, KRA levies, and regulatory fees."
                 "<br/>3. <b>Employee Wages:</b> Settlement of all accrued employee stipends and courier compensation."
                 "<br/>4. <b>Secured Creditors:</b> Settlement of verified secured and unsecured commercial obligations."
                 "<br/>5. <b>Equity Distribution:</b> Distribution of remaining net surplus to verified shareholders in direct proportion to registered equity holdings.")
            ]
        ),
        # PAGE 20
        (
            "ARTICLE XVII: STATUTORY FINANCIAL AUDIT & TAX COMPLIANCE",
            [
                ("Section 17.1: Books of Account & Financial Year",
                 "The financial year of DISHI shall run from the 1st day of January to the 31st day of December of each calendar year. The Chief Financial Officer shall maintain proper, comprehensive books of account accurately reflecting all M-PESA transaction volumes, 0.5% vendor commissions, gig fees, and platform operational expenditures."),
                ("Section 17.2: Independent Annual External Audit",
                 "In compliance with Part XXVII of the Companies Act, 2015, the books of DISHI shall be audited annually by a certified, independent public accounting firm registered with the Institute of Certified Public Accountants of Kenya (ICPAK). The audited financial statements shall be presented to the Executive Wing by March 31st following the close of each financial year."),
                ("Section 17.3: Kenya Revenue Authority (KRA) Compliance",
                 "DISHI shall strictly remit all statutory withholding taxes, corporate income tax, and value-added tax (where applicable) to the Kenya Revenue Authority. Transparent tax compliance is a non-negotiable tenet of our enterprise integrity.")
            ]
        ),
        # PAGE 21
        (
            "ARTICLE XVIII: YOUTH EMPOWERMENT & COMRADE WORKER RIGHTS",
            [
                ("Section 18.1: Alignment with National Youth Policy",
                 "DISHI operates in active synergy with the Kenya National Youth Development Policy and Article 55 of the Constitution. Every gig worker, DeLiv runner, and Comrade Fundi artisan engaged through the platform is recognized as an autonomous, dignified youth micro-entrepreneur."),
                ("Section 18.2: Transparent Courier & Artisan Commission Caps",
                 "To prevent corporate exploitation, platform service deductions on student artisan gigs shall never exceed eight percent (8%) of the contract value. Student food delivery runners shall retain ninety percent (90%) of their delivery fees. All fee structures must be publicly accessible on the app."),
                ("Section 18.3: Occupational Safety & Emergency SOS Protocols",
                 "DISHI shall maintain integrated Campus Safety SOS tools within the mobile application. Student runners and artisans encountering physical harassment, accidents, or hostility during gig execution can trigger immediate geolocation alerts to campus security marshals.")
            ]
        ),
        # PAGE 22
        (
            "ARTICLE XIX: HARAMBEE CHARITY POOL & SOLIDARITY GOVERNANCE",
            [
                ("Section 19.1: The Sacred Public Trust of Harambee Funds",
                 "The Harambee Crowdfunding and Solidarity Pool embodies the profound African tradition of mutual community upliftment. Funds contributed by friends, alumni, donors, or comrades are sacred public trust assets dedicated solely to feeding hungry students."),
                ("Section 19.2: Strict Segregation of Harambee Assets",
                 "Under no circumstances shall donations contributed to a student's Harambee meal balance be diverted to corporate operational expenses, executive bonuses, or general platform liabilities. Harambee balances are strictly locked to authorized cafeteria meal purchases."),
                ("Section 19.3: Verification of Emergency Appeals",
                 "The Harambee Department Lead, in consultation with University Dean of Students offices, shall verify that student crowdfunding appeals stem from genuine financial hardship, preventing abuse or deceptive solicitations on the platform.")
            ]
        ),
        # PAGE 23
        (
            "ARTICLE XX: HARDWARE CRYPTOGRAPHY & GENERAL PROVISIONS",
            [
                ("Section 20.1: Offline NFC Cryptographic Standards",
                 "All DISHI smart ID cards, wearable wristbands, and cafeteria POS terminals must utilize AES-256 military-grade encryption and secure cryptographic handshakes. Physical tap-to-eat verification must execute in under 300 milliseconds without requiring active internet connectivity at the till."),
                ("Section 20.2: Anti-Cloning & Replay Attack Defense",
                 "Every smart card interaction generates an encrypted, single-use, rolling sequence token (nonce). The counter terminal validates the rolling signature against offline mathematical keys. Cloned cards or intercepted replay packets are automatically rejected and flagged as security breaches."),
                ("Section 20.3: Severability & Public Availability",
                 "If any court declares any section of this Constitution invalid, the remaining clauses continue in full force. This Constitution and the companion Business Model shall remain permanently accessible in downloadable PDF format on the official web portal (https://dishi.delstarfordworks.co.ke/constitution).")
            ]
        ),
        # PAGE 24
        (
            "SCHEDULE A: ORGANIZATIONAL CHART & REPORTING HIERARCHY",
            [
                ("Enterprise Operational Hierarchy",
                 "The structured operational hierarchy of DISHI Platform, detailing executive oversight and departmental execution lines across university campus ecosystems:"),
            ]
        ),
        # PAGE 25
        (
            "SCHEDULE B: SIGNATORIES, RATIFICATION & LEGAL WITNESSES",
            [
                ("Attestation & Executive Ratification Seal",
                 "<b>IN WITNESS WHEREOF</b>, we, the undersigned Founding Executive Officers and Trustees of DISHI Platform, in the presence of legal counsel admitted to the Roll of Advocates of the High Court of Kenya, do hereby ratify, adopt, seal, and enact this Official Constitution as the supreme operational charter of DISHI Platform, binding ourselves, our successors, and all platform participants from this day forward.")
            ]
        )
    ]

    for art_title, sections in articles_data:
        story.append(make_p(art_title, art_heading))
        story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#05D5AA'), spaceAfter=8))

        if "SCHEDULE A" in art_title:
            story.append(make_p(
                "The structured operational hierarchy of DISHI Platform, detailing executive oversight and departmental execution lines across university campus ecosystems:",
                body_style
            ))
            story.append(Spacer(1, 8))
            org_chart_data = [
                [make_p("<b>EXECUTIVE WING &amp; BOARD OF GOVERNORS</b><br/>CEO • CTO • COO • CFO • Head of Accessibility", ParagraphStyle('E', fontName='Helvetica-Bold', fontSize=9.5, leading=13.5, alignment=1, textColor=colors.HexColor('#064E3B')))],
                [make_p("↓", ParagraphStyle('Arr', fontName='Helvetica-Bold', fontSize=12, leading=12, alignment=1, textColor=colors.HexColor('#05D5AA')))],
                [make_p("<b>CHIEF OPERATING OFFICER (COO) &amp; CHIEF FINANCIAL OFFICER (CFO)</b><br/>Daily Operational Nerve Center &amp; Treasury Custody", ParagraphStyle('C', fontName='Helvetica-Bold', fontSize=9, leading=13, alignment=1, textColor=colors.HexColor('#0F766E')))],
                [make_p("↓", ParagraphStyle('Arr', fontName='Helvetica-Bold', fontSize=12, leading=12, alignment=1, textColor=colors.HexColor('#05D5AA')))],
                [make_p("<b>THE FIVE PERMANENT OPERATIONAL DEPARTMENTS</b>", ParagraphStyle('D', fontName='Helvetica-Bold', fontSize=9, leading=13, alignment=1, textColor=colors.HexColor('#334155')))]
            ]
            t_org = Table(org_chart_data, colWidths=[487])
            t_org.setStyle(TableStyle([
                ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#ECFDF5')),
                ('BACKGROUND', (0,2), (-1,2), colors.HexColor('#F0FDFA')),
                ('BACKGROUND', (0,4), (-1,4), colors.HexColor('#F8FAFC')),
                ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#CBD5E1')),
                ('TOPPADDING', (0,0), (-1,-1), 5),
                ('BOTTOMPADDING', (0,0), (-1,-1), 5),
            ]))
            story.append(t_org)
            story.append(Spacer(1, 10))

            depts_grid_data = [
                [
                    make_p("<b>DEPT 1: CATERING</b><br/>• Vendor Onboarding<br/>• Menu Digitization<br/>• Queue Sync &amp; POS<br/>• Food Hygiene Audits", body_style),
                    make_p("<b>DEPT 2: FINANCE</b><br/>• 0.5% Cash-In Engine<br/>• M-PESA Daraja API<br/>• Float Liquidity<br/>• Instant B2C Payouts", body_style)
                ],
                [
                    make_p("<b>DEPT 3: GIGS &amp; ESCROW</b><br/>• DeLiv Dorm Couriers<br/>• Comrade Fundis<br/>• 100% Escrow Vault<br/>• Dispute Refunds", body_style),
                    make_p("<b>DEPT 4: HARAMBEE</b><br/>• Emergency Meal Aid<br/>• Student Crowdfunds<br/>• Alumni Endowments<br/>• 12 Arcade Games", body_style)
                ],
                [
                    make_p("<b>DEPT 5: ACCESSIBILITY</b><br/>• Acoustic Chimes for Blind<br/>• Haptic Wrist Pulses for Deaf<br/>• Wheelchair Doorstep Delivery<br/>• Offline NFC Smart Cards", body_style),
                    make_p("<b>CAMPUS AMBASSADORS</b><br/>• University Liaison Desks<br/>• Student Marshals<br/>• First-Year Orientation<br/>• Support Helpdesk", body_style)
                ]
            ]
            t_depts_grid = Table(depts_grid_data, colWidths=[240, 247])
            t_depts_grid.setStyle(TableStyle([
                ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8FAFC')),
                ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#CBD5E1')),
                ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
                ('TOPPADDING', (0,0), (-1,-1), 6),
                ('BOTTOMPADDING', (0,0), (-1,-1), 6),
                ('LEFTPADDING', (0,0), (-1,-1), 8),
                ('RIGHTPADDING', (0,0), (-1,-1), 8),
            ]))
            story.append(t_depts_grid)

        elif "SCHEDULE B" in art_title:
            story.append(make_p(sections[0][1], body_style))
            story.append(Spacer(1, 12))
            sig_table_data = [
                [
                    make_p("<b>CHIEF EXECUTIVE OFFICER (CEO)</b><br/><br/><br/>____________________________________<br/><b>OMONDI DELSTARFORD</b><br/>Founder &amp; Executive Wing Chair<br/>Date: 18th October 2026", body_style),
                    make_p("<b>CHIEF TECHNOLOGY OFFICER (CTO)</b><br/><br/><br/>____________________________________<br/><b>CHIEF ARCHITECT OF SOFTWARE</b><br/>Lead Engineering &amp; Cryptography<br/>Date: 18th October 2026", body_style)
                ],
                [
                    make_p("<b>CHIEF OPERATING OFFICER (COO)</b><br/><br/><br/>____________________________________<br/><b>HEAD OF CAMPUS LOGISTICS</b><br/>Cafeteria &amp; Courier Operations<br/>Date: 18th October 2026", body_style),
                    make_p("<b>CHIEF FINANCIAL OFFICER (CFO)</b><br/><br/><br/>____________________________________<br/><b>HEAD OF TREASURY &amp; ESCROW</b><br/>M-PESA Gateways &amp; Liquidity<br/>Date: 18th October 2026", body_style)
                ],
                [
                    make_p("<b>HEAD OF ACCESSIBILITY &amp; INCLUSION</b><br/><br/><br/>____________________________________<br/><b>COMMISSIONER FOR DISABILITY</b><br/>Article 54 Constitutional Compliance<br/>Date: 18th October 2026", body_style),
                    make_p("<b>ADVOCATE OF THE HIGH COURT OF KENYA</b><br/><br/><br/>____________________________________<br/><b>LEGAL COUNSEL &amp; COMMISSIONER FOR OATHS</b><br/>Attestation &amp; Corporate Registration<br/>Date: 18th October 2026", body_style)
                ]
            ]
            t_sig = Table(sig_table_data, colWidths=[240, 247])
            t_sig.setStyle(TableStyle([
                ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#CBD5E1')),
                ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
                ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#FAFAFA')),
                ('TOPPADDING', (0,0), (-1,-1), 10),
                ('BOTTOMPADDING', (0,0), (-1,-1), 10),
                ('LEFTPADDING', (0,0), (-1,-1), 10),
                ('RIGHTPADDING', (0,0), (-1,-1), 10),
            ]))
            story.append(t_sig)
            story.append(Spacer(1, 15))
            story.append(make_p(
                "<b>OFFICIAL COMMON SEAL OF DELSTARFORD WORKS / DISHI PLATFORM</b><br/>"
                "AFFIXED AND REGISTERED AT NAIROBI, KENYA IN ACCORDANCE WITH SECTION 37 OF THE COMPANIES ACT, 2015",
                ParagraphStyle('Seal', parent=c_meta, fontName='Helvetica-Bold', textColor=colors.HexColor('#064E3B'))
            ))
        else:
            for s_title, s_text in sections:
                story.append(make_p(f"<b>{s_title}</b>", sec_heading))
                if "AUTOMATICALLY AND IRREVOCABLY REMOVED" in s_text or "FORCE MAJEURE JUSTIFICATION" in s_text:
                    story.append(make_p(s_text, warn_style))
                elif "FORCED TO PERMANENTLY LEAVE" in s_text or "INVESTMENT MONEY BACK IN FULL" in s_text:
                    story.append(make_p(s_text, warn_style))
                elif "NINETY PERCENT (90%) OF THE EXECUTIVE WING" in s_text or "NINETY PERCENT (90%) OF THE TOTAL VOTING SHARES" in s_text:
                    story.append(make_p(s_text, ParagraphStyle('Super', parent=body_style, fontName='Helvetica-Bold', textColor=colors.HexColor('#064E3B'))))
                else:
                    story.append(make_p(s_text, body_style))

        # End of page -> PageBreak
        if art_title != articles_data[-1][0]:
            story.append(PageBreak())

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Successfully generated 25-page Enterprise Constitution: {output_filename}")

if __name__ == '__main__':
    backend_static = os.path.join(os.path.dirname(__file__), 'static', 'DISHI_Official_Constitution.pdf')
    root_static = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'DISHI_Official_Constitution.pdf'))

    build_constitution_pdf(backend_static)
    shutil.copy2(backend_static, root_static)
    print(f"Copied to root: {root_static}")
