import 'package:flutter/material.dart';

const Color kVoiceBgColor = Color(0xFF0C101B);
const Color kVoiceCardColor = Color(0xFF131A2A);
const Color kVoiceSurfaceLight = Color(0xFF1A2235);
const Color kVoiceNeonCyan = Color(0xFF05D5AA);
const Color kVoiceNeonPink = Color(0xFFF92B60);
const Color kVoiceNeonOrange = Color(0xFFFF6F00);
const Color kVoiceNeonGold = Color(0xFFFFD700);
const Color kVoiceTextSecondary = Color(0xFF8B9BB4);

/// Available AI Voice Personas for "DISHI Voice AI"
class VoicePersona {
  final String id;
  final String name;
  final String title;
  final String description;
  final double defaultPitch;
  final double defaultRate;
  final bool isFemale;
  final IconData icon;
  final Color themeColor;

  const VoicePersona({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.defaultPitch,
    required this.defaultRate,
    required this.isFemale,
    required this.icon,
    required this.themeColor,
  });
}

const List<VoicePersona> kVoicePersonas = [
  VoicePersona(
    id: 'campus_buddy',
    name: 'The Campus Buddy',
    title: 'Warm & Friendly (Default)',
    description: 'Light, approachable student camaraderie and peer support.',
    defaultPitch: 1.15,
    defaultRate: 0.52,
    isFemale: true,
    icon: Icons.handshake,
    themeColor: kVoiceNeonCyan,
  ),
  VoicePersona(
    id: 'nutritionist',
    name: 'The Professional Nutritionist',
    title: 'Health & Balanced Wellness',
    description: 'Focuses on macronutrients, balanced plates, clean fuel, and wellness guidance.',
    defaultPitch: 1.10,
    defaultRate: 0.50,
    isFemale: true,
    icon: Icons.spa,
    themeColor: Colors.greenAccent,
  ),
  VoicePersona(
    id: 'cashier',
    name: 'The Swift Canteen Cashier',
    title: 'High-Efficiency & Speed',
    description: 'Fast-paced, transactional, rapid checkout, zero line delays.',
    defaultPitch: 1.05,
    defaultRate: 0.65,
    isFemale: true,
    icon: Icons.point_of_sale,
    themeColor: kVoiceNeonPink,
  ),
  VoicePersona(
    id: 'chef',
    name: 'The Gourmet Chef',
    title: 'Culinary Master & Aromas',
    description: 'Passionate about food quality, flavor profiles, and culinary descriptions.',
    defaultPitch: 0.72,
    defaultRate: 0.48,
    isFemale: false,
    icon: Icons.restaurant,
    themeColor: Colors.amber,
  ),
  VoicePersona(
    id: 'coach',
    name: 'The Energetic Coach',
    title: 'Fitness & Stamina Fuel',
    description: 'High-energy, motivating, links food choices to energy and workouts.',
    defaultPitch: 0.72,
    defaultRate: 0.58,
    isFemale: false,
    icon: Icons.fitness_center,
    themeColor: Colors.deepOrangeAccent,
  ),
  VoicePersona(
    id: 'wise_elder',
    name: 'The Wise Elder / Mentor',
    title: 'Patient & Grounded Counsel',
    description: 'Patient, thoughtful counsel on student budgeting and wholesome habits.',
    defaultPitch: 0.70,
    defaultRate: 0.45,
    isFemale: false,
    icon: Icons.psychology,
    themeColor: Colors.teal,
  ),
  VoicePersona(
    id: 'gen_z',
    name: 'The Gen-Z Campus Insider',
    title: 'Trendy & Campus Slang',
    description: 'Trendy, upbeat, modern campus slang and authentic vibes.',
    defaultPitch: 1.20,
    defaultRate: 0.56,
    isFemale: true,
    icon: Icons.auto_awesome,
    themeColor: Colors.purpleAccent,
  ),
  VoicePersona(
    id: 'accountant',
    name: 'The Strict Budget Accountant',
    title: 'Frugality & Cash Conservation',
    description: 'Ultra-focused on stretching allowances, cost per calorie, and wallet protection.',
    defaultPitch: 0.72,
    defaultRate: 0.52,
    isFemale: false,
    icon: Icons.account_balance_wallet,
    themeColor: Colors.blueAccent,
  ),
  VoicePersona(
    id: 'mama_njeri',
    name: 'Mama Njeri (Canteen Matriarch)',
    title: 'Maternal & Caring Family Love',
    description: 'Maternal care, treats every student like family ("Umekula vizuri leo?").',
    defaultPitch: 1.22,
    defaultRate: 0.48,
    isFemale: true,
    icon: Icons.favorite,
    themeColor: Colors.pinkAccent,
  ),
  VoicePersona(
    id: 'tech_geek',
    name: 'The Tech-Geek / AI Assistant',
    title: 'System Optimization & Logic',
    description: 'Analytical, system-oriented, performance optimization and clean APIs.',
    defaultPitch: 0.72,
    defaultRate: 0.55,
    isFemale: false,
    icon: Icons.memory,
    themeColor: Colors.cyanAccent,
  ),
  VoicePersona(
    id: 'musician',
    name: 'The Acoustic Musician',
    title: 'Rhythmic & Soulful Expression',
    description: 'Poetic, musical analogies, food as harmony and melody.',
    defaultPitch: 0.72,
    defaultRate: 0.50,
    isFemale: false,
    icon: Icons.music_note,
    themeColor: Colors.indigoAccent,
  ),
  VoicePersona(
    id: 'radio_host',
    name: 'The Campus FM Radio Host',
    title: 'Booming Energy & Broadcast Polish',
    description: 'High-octane radio DJ persona with sensational campus announcements.',
    defaultPitch: 0.72,
    defaultRate: 0.60,
    isFemale: false,
    icon: Icons.mic_external_on,
    themeColor: Colors.orangeAccent,
  ),
  VoicePersona(
    id: 'zen_monk',
    name: 'The Mindfulness Guide',
    title: 'Mindful Eating & Inner Calm',
    description: 'Slow, peaceful presence helping relieve academic exam stress.',
    defaultPitch: 1.10,
    defaultRate: 0.42,
    isFemale: true,
    icon: Icons.self_improvement,
    themeColor: Colors.lightGreenAccent,
  ),
  VoicePersona(
    id: 'debater',
    name: 'The University Debater',
    title: 'Articulate Rhetoric & Debate',
    description: 'Eloquent, precise vocabulary, persuasive food recommendations.',
    defaultPitch: 0.72,
    defaultRate: 0.52,
    isFemale: false,
    icon: Icons.record_voice_over,
    themeColor: Colors.deepPurpleAccent,
  ),
  VoicePersona(
    id: 'hostel_rep',
    name: 'The Hall of Residence Representative',
    title: 'Campus Leadership & Solidarity',
    description: 'Advocates for fair portions, clean dining, and student rights.',
    defaultPitch: 0.72,
    defaultRate: 0.52,
    isFemale: false,
    icon: Icons.how_to_vote,
    themeColor: Colors.amberAccent,
  ),
  VoicePersona(
    id: 'biohacker',
    name: 'The Biohacking Optimizer',
    title: 'Cognitive Boost & Nootropics',
    description: 'Focuses on focus-enhancing foods, omega-3s, and mental stamina.',
    defaultPitch: 0.72,
    defaultRate: 0.54,
    isFemale: false,
    icon: Icons.biotech,
    themeColor: Colors.limeAccent,
  ),
  VoicePersona(
    id: 'poet',
    name: 'The Spoken Word Artist',
    title: 'Rhymes & Urban Flow',
    description: 'Speaks with rhythmic cadence, urban campus poetry and soul.',
    defaultPitch: 1.15,
    defaultRate: 0.50,
    isFemale: true,
    icon: Icons.edit_note,
    themeColor: Colors.redAccent,
  ),
  VoicePersona(
    id: 'eco_warrior',
    name: 'The Zero-Waste Champion',
    title: 'Sustainability & Planet First',
    description: 'Champions anti-food waste (Okoa Food), composting, and green living.',
    defaultPitch: 1.12,
    defaultRate: 0.52,
    isFemale: true,
    icon: Icons.eco,
    themeColor: Colors.lightGreen,
  ),
  VoicePersona(
    id: 'investor',
    name: 'The Venture Capitalist',
    title: 'High-Stakes ROI & Execution',
    description: 'Evaluates meals like startup investments — high yields and efficiency.',
    defaultPitch: 0.72,
    defaultRate: 0.52,
    isFemale: false,
    icon: Icons.trending_up,
    themeColor: Colors.blue,
  ),
  VoicePersona(
    id: 'concierge',
    name: 'The 5-Star Campus Concierge',
    title: 'Polite, Discreet & Bespoke Hospitality',
    description: 'Ultra-courteous, elite service ensuring your campus day is flawless.',
    defaultPitch: 1.18,
    defaultRate: 0.50,
    isFemale: true,
    icon: Icons.room_service,
    themeColor: Colors.white70,
  ),
];

/// Dynamic local time-based greeting for "Hello DISHI"
String getTimeBasedGreeting(String lang) {
  final hour = DateTime.now().hour;
  if (lang == 'sw' || lang == 'sheng') {
    if (hour >= 5 && hour < 12) {
      return "Habari za asubuhi! Nikusaidie nini sasa?";
    } else if (hour >= 12 && hour < 17) {
      return "Habari za mchana! Nikusaidie nini sasa?";
    } else if (hour >= 17 && hour < 21) {
      return "Habari za jioni! Nikusaidie nini sasa?";
    } else {
      return "Habari za usiku! Nikusaidie nini sasa rafiki yangu?";
    }
  } else {
    if (hour >= 5 && hour < 12) {
      return "Good morning! What can I help you with now?";
    } else if (hour >= 12 && hour < 17) {
      return "Good afternoon! What can I help you with now?";
    } else if (hour >= 17 && hour < 21) {
      return "Good evening! What can I help you with now?";
    } else {
      return "Good evening! What can I help you with now?";
    }
  }
}

/// Standby confirmation when user says "Thank you DISHI"
String getStandbyMessage(String lang) {
  if (lang == 'sw' || lang == 'sheng') {
    return "Karibu sana! DISHI Voice sasa inapumzika kwenye standby ili utumie mfumo mwenyewe. Niite wakati wowote kwa kusema Hello DISHI au kugusa kitufe!";
  } else {
    return "You're very welcome! DISHI Voice is going on standby so you can navigate manually. Call me anytime by saying Hello DISHI or tapping the voice button!";
  }
}

/// Full interactive training tutorial speech
String getVoiceTrainingOverview(String lang) {
  if (lang == 'sw' || lang == 'sheng') {
    return "Karibu kwenye mafunzo ya DISHI Voice! Hivi ndivyo unavyoweza kutumia: "
        "Kwanza, sema 'Hello DISHI' wakati wowote kuniamsha na kusikia salamu kulingana na wakati. "
        "Pili, kwa marafiki na mahusiano, sema 'Open UniUptown', 'Anza kuswipe', au 'Matches and chats'. "
        "Tatu, kwa chakula na maduka, sema 'Open preorder and order this', 'Campus Supermarket', au 'Vendor wa karibu'. "
        "Nne, kwa vibarua au salio, sema 'Campus Gigs' au 'Salio langu'. "
        "Mwishowe, ukipenda kutumia mwenyewe bila sauti, sema tu 'Asante DISHI'. Ungependa kujaribu amri ipi sasa?";
  } else {
    return "Welcome to DISHI Voice training! Here is how to navigate the whole system hands-free: "
        "First, say 'Hello DISHI' anytime to wake me up with a time-aware greeting. "
        "Second, for campus dating and friends, say 'Open UniUptown', 'Start swiping', or 'Matches and chats'. "
        "Third, for meals and groceries, say 'Open preorder and order this', 'Campus Supermarket', or 'Where is nearest vendor'. "
        "Fourth, for gigs and wallet, say 'Campus Gigs' or 'Check balance'. "
        "Finally, whenever you want to navigate manually, just say 'Thank you DISHI' to enter standby. What would you like to try first?";
  }
}

/// Clean text for speech synthesis without awkward markdown symbols
String sanitizeForTts(String text) {
  return text.replaceAll(RegExp(r'[*#_~`>\[\]\(\)]'), ' ').trim();
}
