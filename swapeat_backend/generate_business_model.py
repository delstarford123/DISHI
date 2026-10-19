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
        self.drawString(54, 800, "DISHI PLATFORM • SUSTAINABLE ENTERPRISE BUSINESS MODEL")
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        self.drawRightString(541, 800, "COMMERCIAL & FINANCIAL LOGISTICS ARCHITECTURE")
        
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

def build_business_model_pdf(output_filename):
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

    art_heading = ParagraphStyle(
        'SectionHeading',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=14,
        leading=18,
        textColor=colors.HexColor('#064E3B'),
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True
    )

    sec_heading = ParagraphStyle(
        'SubHeading',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=15,
        textColor=colors.HexColor('#0F766E'),
        spaceBefore=10,
        spaceAfter=5,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'DocBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=14,
        textColor=colors.HexColor('#1E293B'),
        spaceAfter=7,
        alignment=4
    )

    bullet_style = ParagraphStyle(
        'DocBullet',
        parent=body_style,
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=4
    )

    story = []

    # =========================================================================
    # PAGE 1: COVER PAGE
    # =========================================================================
    story.append(Spacer(1, 40))
    story.append(make_p("DELSTARFORD WORKS • NAIROBI, KENYA", ParagraphStyle('Corp', fontName='Helvetica-Bold', fontSize=12, leading=16, alignment=1, textColor=colors.HexColor('#B91C1C'))))
    story.append(Spacer(1, 15))
    story.append(HRFlowable(width="100%", thickness=3, color=colors.HexColor('#05D5AA'), spaceAfter=25))
    story.append(make_p("THE OFFICIAL ENTERPRISE BUSINESS MODEL", c_title))
    story.append(make_p("AND FINANCIAL ARCHITECTURE OF", ParagraphStyle('Of', fontName='Helvetica-Bold', fontSize=12, leading=16, alignment=1, textColor=colors.HexColor('#334155'))))
    story.append(make_p("DISHI PLATFORM", ParagraphStyle('Brand', fontName='Helvetica-Bold', fontSize=32, leading=38, alignment=1, textColor=colors.HexColor('#05D5AA'))))
    story.append(Spacer(1, 10))
    story.append(make_p("Commercial Feasibility, 0.5% Agency Banking Economics, DeLiv Courier Logistics, Escrow Monetization &amp; Institutional Scalability Across African Campuses", c_subtitle))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#E2E8F0'), spaceAfter=25))

    cover_data = [
        [make_p("<b>Enterprise Document:</b>", body_style), make_p("Commercial Business Model &amp; Investor Whitepaper", body_style)],
        [make_p("<b>Primary Market:</b>", body_style), make_p("Universities, Colleges &amp; TVET Institutions (Kenya &amp; East Africa)", body_style)],
        [make_p("<b>Core Revenue Engine:</b>", body_style), make_p("0.5% Agency Float, Pre-Orders, DeLiv Gigs, Escrow Vault, Ticketing", body_style)],
        [make_p("<b>Regulatory Framework:</b>", body_style), make_p("Central Bank of Kenya (NPS Act), ODPC, Safaricom Daraja", body_style)],
        [make_p("<b>Operational Launch Date:</b>", body_style), make_p("1st January 2027 (Structured Compensation Commencement)", body_style)],
        [make_p("<b>Official Digital Portal:</b>", body_style), make_p("https://dishi.delstarfordworks.co.ke", body_style)]
    ]
    t_cov = Table(cover_data, colWidths=[200, 280])
    t_cov.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8FAFC')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#CBD5E1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
    ]))
    story.append(t_cov)
    story.append(Spacer(1, 40))
    story.append(make_p("<b>CONFIDENTIAL COMMERCIAL DOCUMENT</b><br/>PREPARED FOR UNIVERSITY ADMINISTRATIONS, INVESTORS, FINANCIAL INSTITUTIONS &amp; CATERING PARTNERS", ParagraphStyle('Conf', fontName='Helvetica', fontSize=9, leading=13, alignment=1, textColor=colors.HexColor('#64748B'))))
    story.append(PageBreak())

    # =========================================================================
    # PAGE 2: EXECUTIVE SUMMARY & MACRO-ECONOMIC CONTEXT
    # =========================================================================
    story.append(make_p("1. EXECUTIVE SUMMARY &amp; MARKET OPPORTUNITY", art_heading))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#05D5AA'), spaceAfter=10))

    story.append(make_p(
        "Higher education across the African continent represents one of the densest, most underserved micro-economies in the world. In the Republic of Kenya alone, over <b>600,000 students</b> across 70+ universities and 200+ technical colleges navigate campus dining halls daily, transacting over <b>KES 18 Billion annually</b> in food purchases and basic campus services.",
        body_style
    ))
    story.append(make_p(
        "Despite this massive transactional volume, campus dining remains plagued by severe inefficiencies: students lose up to 40 minutes per meal in chaotic lunch queues; cafeteria operators lose 2 hours daily verifying fake M-PESA SMS confirmations; parents remain in the dark regarding diverted cash; and skilled students struggle to find safe, paying gigs without being exploited.",
        body_style
    ))
    story.append(make_p(
        "<b>DISHI</b> solves this comprehensive systemic failure with a unified operating system that combines smart pre-orders, sub-300ms offline NFC tap-to-eat dignity, 0.5% cash-in agency banking for vendors, parent spend safeguards, and 100% escrow-backed artisan student gigs.",
        body_style
    ))

    story.append(make_p("<b>Macro-Economic Addressable Market (TAM, SAM, SOM)</b>", sec_heading))
    tam_data = [
        [make_p("<b>Metric</b>", body_style), make_p("<b>Market Description</b>", body_style), make_p("<b>Est. Annual Value</b>", body_style)],
        [make_p("<b>TAM (Total Addressable)</b>", body_style), make_p("Higher Education Dining &amp; Youth Services in Sub-Saharan Africa (12M+ Students)", body_style), make_p("$4.2 Billion USD", body_style)],
        [make_p("<b>SAM (Serviceable Addressable)</b>", body_style), make_p("University &amp; Tertiary Campus Dining in East Africa (Kenya, Uganda, Tanzania, Rwanda)", body_style), make_p("$680 Million USD", body_style)],
        [make_p("<b>SOM (Serviceable Obtainable)</b>", body_style), make_p("Top 25 University Campuses in Kenya (Target: 150,000 Active Student Users by 2028)", body_style), make_p("KES 4.5 Billion", body_style)]
    ]
    t_tam = Table(tam_data, colWidths=[140, 240, 107])
    t_tam.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8FAFC')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#CBD5E1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_tam)
    story.append(PageBreak())

    # =========================================================================
    # PAGE 3: 3-TIER STAKEHOLDER VALUE PROPOSITIONS
    # =========================================================================
    story.append(make_p("2. STAKEHOLDER VALUE ARCHITECTURE", art_heading))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#05D5AA'), spaceAfter=10))

    story.append(make_p("<b>Level 1: The Student Value Proposition</b>", sec_heading))
    story.append(make_p("• <b>Queue Elimination:</b> Live digital menus allow students to pre-order and collect hot meals without queueing before lectures or exams.", bullet_style))
    story.append(make_p("• <b>Offline NFC Tap-to-Eat:</b> Fast sub-300ms checkout with physical smart cards and wearables that function even without smartphone battery or cellular data.", bullet_style))
    story.append(make_p("• <b>Student Gig Economy:</b> Earn income between classes via DeLiv dorm food delivery and Comrade Fundi artisan services protected by 100% Escrow.", bullet_style))
    story.append(make_p("• <b>Gamified Savings:</b> Play 12 arcade games to earn Dishi Coins redeemable for real KES 50 &amp; 100 meal vouchers.", bullet_style))

    story.append(make_p("<b>Level 2: The Parent Value Proposition</b>", sec_heading))
    story.append(make_p("• <b>Nutritional Ring-Fencing:</b> Allowance funds sent to the DISHI student wallet are strictly dedicated to cafeteria meals, preventing diversion to peer pressure.", bullet_style))
    story.append(make_p("• <b>Real-Time SMS Dining Receipts:</b> Instant transparency: <i>'Your student dined at Science Diner. Meal: KSh 120. Balance: KSh 1,450.'</i>", bullet_style))
    story.append(make_p("• <b>Seamless STK Push:</b> Top up student meal balances directly from any Safaricom phone in Kenya in under 5 seconds.", bullet_style))

    story.append(make_p("<b>Level 3: The Cafeteria Vendor Value Proposition</b>", sec_heading))
    story.append(make_p("• <b>0.5% Cash-In Agency Banking Revenue:</b> Cafeteria counters double as agency banking touchpoints, earning an instant 0.5% commission on student cash deposits.", bullet_style))
    story.append(make_p("• <b>High-Speed Counter Throughput:</b> Sub-300ms contactless checkout cuts transaction time by 85%, serving 4x more students during peak rush.", bullet_style))
    story.append(make_p("• <b>Zero Fraud &amp; Instant Payouts:</b> Eliminates fake M-PESA screenshots; allows instant B2C withdrawals to merchant tills or phone numbers.", bullet_style))
    story.append(PageBreak())

    # =========================================================================
    # PAGE 4: SIX DIVERSIFIED REVENUE STREAMS
    # =========================================================================
    story.append(make_p("3. SIX DIVERSIFIED REVENUE STREAMS", art_heading))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#05D5AA'), spaceAfter=10))

    story.append(make_p(
        "DISHI is engineered with robust, multi-channel unit economics ensuring profitability without imposing predatory financial burdens on students:",
        body_style
    ))

    rev_streams = [
        ("1. Vendor Agency Float Turnover", "0.5% commission split with cafeteria operators on paper cash deposits; treasury earns liquidity float interest on custodial balances."),
        ("2. Cafeteria Pre-Order MDR", "1.5% – 2.5% Merchant Discount Rate (MDR) charged to food vendors on digital orders, replacing high third-party aggregator commissions (which charge 20–30%)."),
        ("3. DeLiv Courier Platform Share", "Flat KES 30–50 delivery fee paid by the student; DISHI retains 10% (KES 3.00 – KES 5.00) for platform maintenance, routing, and insurance."),
        ("4. Comrade Fundi Escrow Fees", "5% – 8% commission on completed student artisan gigs (phone repairs, tutoring, hair styling), deducted only upon successful milestone release."),
        ("5. Event Ticketing &amp; Promotion", "Flat KES 10.00 – KES 25.00 convenience fee on campus concert, sports, and cultural ticket purchases processed through the web and mobile app."),
        ("6. Harambee Contributor &amp; Corporate CSR", "Flat KES 3.00 transaction fee on crowdfunding solidarity contributions; corporate CSR sponsorship matching fees.")
    ]

    t_rev_data = [[
        make_p(f"<b>{r[0]}</b>", body_style),
        make_p(f"{r[1]}", body_style)
    ] for r in rev_streams]

    t_rev = Table(t_rev_data, colWidths=[180, 307])
    t_rev.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8FAFC')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#CBD5E1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('TOPPADDING', (0,0), (-1,-1), 7),
        ('BOTTOMPADDING', (0,0), (-1,-1), 7),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_rev)
    story.append(PageBreak())

    # =========================================================================
    # PAGE 5: 5-YEAR FINANCIAL PROJECTIONS & METRICS
    # =========================================================================
    story.append(make_p("4. 5-YEAR FINANCIAL FORECASTS &amp; PROJECTIONS", art_heading))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#05D5AA'), spaceAfter=10))

    story.append(make_p(
        "Financial projections modeling active student adoption across Kenyan universities over a 5-year scaling trajectory (figures in Kenya Shillings KES):",
        body_style
    ))

    fin_table_data = [
        [make_p("<b>Metric / Year</b>", body_style), make_p("<b>Year 1 (2027)</b>", body_style), make_p("<b>Year 2 (2028)</b>", body_style), make_p("<b>Year 3 (2029)</b>", body_style), make_p("<b>Year 5 (2031)</b>", body_style)],
        [make_p("<b>Integrated Universities</b>", body_style), make_p("5 Campuses", body_style), make_p("15 Campuses", body_style), make_p("35 Campuses", body_style), make_p("75 Campuses", body_style)],
        [make_p("<b>Active Student Users</b>", body_style), make_p("25,000", body_style), make_p("85,000", body_style), make_p("220,000", body_style), make_p("550,000", body_style)],
        [make_p("<b>Cafeteria Vendors</b>", body_style), make_p("60 Terminals", body_style), make_p("220 Terminals", body_style), make_p("600 Terminals", body_style), make_p("1,500 Terminals", body_style)],
        [make_p("<b>Gross Annual GMV</b>", body_style), make_p("KES 225M", body_style), make_p("KES 850M", body_style), make_p("KES 2.4 Billion", body_style), make_p("KES 6.8 Billion", body_style)],
        [make_p("<b>Net Platform Revenues</b>", body_style), make_p("KES 14.5M", body_style), make_p("KES 58.2M", body_style), make_p("KES 168.0M", body_style), make_p("KES 490.0M", body_style)],
        [make_p("<b>Operating Costs &amp; Salaries</b>", body_style), make_p("KES 9.2M", body_style), make_p("KES 32.5M", body_style), make_p("KES 84.0M", body_style), make_p("KES 210.0M", body_style)],
        [make_p("<b>Net Operational Surplus</b>", body_style), make_p("<b>+KES 5.3M</b>", body_style), make_p("<b>+KES 25.7M</b>", body_style), make_p("<b>+KES 84.0M</b>", body_style), make_p("<b>+KES 280.0M</b>", body_style)]
    ]

    t_fin = Table(fin_table_data, colWidths=[127, 90, 90, 90, 90])
    t_fin.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#ECFDF5')),
        ('BACKGROUND', (0,-1), (-1,-1), colors.HexColor('#F0FDFA')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#CBD5E1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_fin)

    story.append(Spacer(1, 14))
    story.append(make_p("<b>Key Financial Assumptions:</b>", sec_heading))
    story.append(make_p("1. Average student dining spend of KES 150 per day across 20 academic days per month.", bullet_style))
    story.append(make_p("2. Vendor float turnover velocity of 2.4 cycles per week.", bullet_style))
    story.append(make_p("3. DeLiv courier adoption among 18% of hostel resident students.", bullet_style))
    story.append(make_p("4. All foundational personnel compensation starting 1st January 2027 within KES 5,000–10,000 monthly tiers.", bullet_style))
    story.append(PageBreak())

    # =========================================================================
    # PAGE 6: UNIVERSITY GO-TO-MARKET PLAYBOOK & CONCLUSION
    # =========================================================================
    story.append(make_p("5. UNIVERSITY ONBOARDING PLAYBOOK &amp; CONCLUSION", art_heading))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#05D5AA'), spaceAfter=10))

    story.append(make_p("<b>The 4-Stage Campus Deployment Playbook</b>", sec_heading))
    story.append(make_p("1. <b>Administrative Concession &amp; MoU:</b> Securing the official partnership approval requiring the mandatory 90% Executive Wing vote in accordance with Article X of the Constitution.", bullet_style))
    story.append(make_p("2. <b>Vendor Terminal Integration:</b> Equipping cafeteria operators with DISHI POS hardware, NFC card readers, and initializing their 0.5% agency float.", bullet_style))
    story.append(make_p("3. <b>Comrade Ambassador Activation:</b> Enlisting and training student marshals, DeLiv couriers, and Fundi artisans during orientation weeks.", bullet_style))
    story.append(make_p("4. <b>Offline NFC Card Issuance:</b> Distributing subsidized contactless DISHI smart cards and wristbands across student hostel clusters.", bullet_style))

    story.append(Spacer(1, 15))
    story.append(make_p("<b>Executive Conclusion</b>", sec_heading))
    story.append(make_p(
        "DISHI is more than a commercial platform; it is a scalable institutional engine engineered in Africa to solve Africa's most urgent campus dining, youth unemployment, and financial inclusion challenges. With solid unit economics, entrenched constitutional governance, and radical empathy, DISHI represents a transformative investment in the future of African youth.",
        body_style
    ))

    story.append(Spacer(1, 30))
    story.append(make_p("<b>DELSTARFORD WORKS • ENTERPRISE PLANNING DESK</b><br/>Nairobi, Kenya • https://dishi.delstarfordworks.co.ke", ParagraphStyle('Sign', fontName='Helvetica-Bold', fontSize=10, leading=14, alignment=1, textColor=colors.HexColor('#064E3B'))))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Successfully generated Enterprise Business Model PDF: {output_filename}")

if __name__ == '__main__':
    backend_static = os.path.join(os.path.dirname(__file__), 'static', 'DISHI_Enterprise_Business_Model.pdf')
    root_static = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'DISHI_Enterprise_Business_Model.pdf'))

    build_business_model_pdf(backend_static)
    shutil.copy2(backend_static, root_static)
    print(f"Copied to root: {root_static}")
