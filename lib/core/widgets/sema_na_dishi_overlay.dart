import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:flutter_tts/flutter_tts.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'dart:math' as math;

import '../services/api_config.dart';

import '../../features/match/presentation/match_hub_view.dart';

import '../../features/match/presentation/match_discovery_view.dart';

import '../../features/match/presentation/match_matches_hub.dart';

import '../../features/student/presentation/student_preorders_view.dart';

import '../../features/student/presentation/campus_supermarket_view.dart';

import '../../features/student/presentation/student_ledger_view.dart';

import '../../features/student/presentation/campus_employment_hub.dart';

import '../services/secure_http_client.dart';
import '../services/dishi_voice_service.dart';
import '../services/dishi_voice_models.dart';
import '../models/user_model.dart';
import '../../features/student/presentation/split_bill_view.dart';
import '../../features/student/presentation/okoa_food_view.dart';
import '../../features/student/presentation/campus_map_view.dart';
import '../../features/housing/presentation/housing_dashboard_view.dart';
import '../../features/smartimer/presentation/daily_focus_view.dart';
import '../../features/student/presentation/request_funds_view.dart';
import '../../features/vendor/presentation/vendor_dashboard_view.dart';
import '../../features/vendor/presentation/vendor_kds_view.dart';
import '../../features/vendor/presentation/vendor_reports_view.dart';
import '../../features/vendor/presentation/inventory/inventory_dashboard_view.dart';
import '../../features/vendor/presentation/finance/payout_hub_view.dart';
import '../../features/parent/presentation/parent_dashboard_view.dart';
import '../../features/student/presentation/dynamic_qr_dialog.dart';
import '../../main.dart' show appNavigatorKey;
import 'dishi_persistent_voice_pill.dart';

const Color _bgColor = Color(0xFF0C101B);

const Color _cardColor = Color(0xFF131A2A);

const Color _surfaceLight = Color(0xFF1A2235);

const Color _neonCyan = Color(0xFF05D5AA);

const Color _neonPink = Color(0xFFF92B60);

const Color _neonOrange = Color(0xFFFF6F00);

const Color _textSecondary = Color(0xFF8B9BB4);

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

    themeColor: _neonCyan,

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

    themeColor: _neonPink,

  ),

  VoicePersona(

    id: 'chef',

    name: 'The Gourmet Chef',

    title: 'Culinary Master & Aromas',

    description: 'Passionate about food quality, flavor profiles, and culinary descriptions.',

    defaultPitch: 0.95,

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

    defaultPitch: 1.00,

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

    defaultPitch: 0.85,

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

    defaultPitch: 1.00,

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

    defaultPitch: 1.08,

    defaultRate: 0.55,

    isFemale: false,

    icon: Icons.memory,

    themeColor: Colors.cyanAccent,

  ),

  VoicePersona(

    id: 'musician',

    name: 'The Acoustic Musician',

    title: 'Laid-Back Rhythm & Poetry',

    description: 'Poetic, relaxed conversational rhythm with a soothing melodic cadence.',

    defaultPitch: 0.90,

    defaultRate: 0.46,

    isFemale: false,

    icon: Icons.music_note,

    themeColor: Colors.indigoAccent,

  ),

  VoicePersona(

    id: 'study_partner',

    name: 'The Midnight Study Partner',

    title: 'Exam Cram & Brain Fuel',

    description: 'Late-night cravings, coffee runs, and sustained focus fuel for studies.',

    defaultPitch: 1.05,

    defaultRate: 0.50,

    isFemale: true,

    icon: Icons.menu_book,

    themeColor: Colors.lightGreenAccent,

  ),

  VoicePersona(

    id: 'eco_activist',

    name: 'The Eco-Conscious Activist',

    title: 'Sustainability & Zero Waste',

    description: 'Champions sustainability, zero-waste food choices, and local ethical sourcing.',

    defaultPitch: 1.12,

    defaultRate: 0.52,

    isFemale: true,

    icon: Icons.eco,

    themeColor: Colors.lightGreen,

  ),

  VoicePersona(

    id: 'hype_man',

    name: 'The Hype Man',

    title: 'Maximum Stadium Energy',

    description: 'Extremely enthusiastic, celebrating every single meal order like a champion win.',

    defaultPitch: 1.25,

    defaultRate: 0.60,

    isFemale: false,

    icon: Icons.campaign,

    themeColor: Colors.yellowAccent,

  ),

  VoicePersona(

    id: 'sarcastic_roommate',

    name: 'The Sarcastic Roommate',

    title: 'Dry Wit & Playful Banter',

    description: 'Witty, dry humor, playful banter while getting things done.',

    defaultPitch: 0.98,

    defaultRate: 0.54,

    isFemale: false,

    icon: Icons.sentiment_very_satisfied,

    themeColor: Colors.orangeAccent,

  ),

  VoicePersona(

    id: 'zen_guide',

    name: 'The Zen Mindfulness Guide',

    title: 'Calm & Mindful Dining',

    description: 'Calm, meditative, promotes mindful eating, gratitude, and peaceful pacing.',

    defaultPitch: 0.88,

    defaultRate: 0.42,

    isFemale: true,

    icon: Icons.self_improvement,

    themeColor: Colors.cyan,

  ),

  VoicePersona(

    id: 'history_buff',

    name: 'The History Buff',

    title: 'Historical Origins & Heritage',

    description: 'Relates campus meals to interesting historical fun facts and cultural culinary origins.',

    defaultPitch: 0.96,

    defaultRate: 0.49,

    isFemale: false,

    icon: Icons.account_balance,

    themeColor: Colors.brown,

  ),

  VoicePersona(

    id: 'disciplinarian',

    name: 'The Strict Disciplinarian',

    title: 'Order, Precision & Protocol',

    description: 'Formal, orderly, precise, respectful, and punctual.',

    defaultPitch: 0.92,

    defaultRate: 0.51,

    isFemale: false,

    icon: Icons.military_tech,

    themeColor: Colors.blueGrey,

  ),

  VoicePersona(

    id: 'festival_coordinator',

    name: 'The Festival Coordinator',

    title: 'Festive Weekend Treats',

    description: 'Upbeat, celebratory energy tailored for weekend treats and campus events.',

    defaultPitch: 1.18,

    defaultRate: 0.55,

    isFemale: true,

    icon: Icons.celebration,

    themeColor: Colors.pink,

  ),

  VoicePersona(

    id: 'minimalist',

    name: 'The Minimalist',

    title: 'Ultra-Concise Zero Fluff',

    description: 'Direct, ultra-concise, zero fluff, straight to the point.',

    defaultPitch: 1.00,

    defaultRate: 0.58,

    isFemale: true,

    icon: Icons.short_text,

    themeColor: Colors.white70,

  ),

];

class SemaNaDishiOverlay extends StatefulWidget {

  final String role; // 'vendor' | 'student' | 'parent'

  final String? userUid;

  final Function(String intent, Map<String, dynamic> data)? onAction;

  const SemaNaDishiOverlay({

    super.key,

    this.role = 'student',

    this.userUid,

    this.onAction,

  });

  static void show(

    BuildContext context, {

    String role = 'student',

    String? userUid,

    Function(String intent, Map<String, dynamic> data)? onAction,

  }) {

    final targetContext = appNavigatorKey.currentContext ?? context;

    showModalBottomSheet(

      context: targetContext,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (ctx) => SemaNaDishiOverlay(

        role: role,

        userUid: userUid,

        onAction: onAction,

      ),

    );

  }

  @override

  State<SemaNaDishiOverlay> createState() => _SemaNaDishiOverlayState();

}

class _SemaNaDishiOverlayState extends State<SemaNaDishiOverlay> with SingleTickerProviderStateMixin {

  late stt.SpeechToText _speech;

  late FlutterTts _flutterTts;

  late AnimationController _pulseController;

  bool _isListening = false;

  bool _isProcessing = false;

  String _recognizedWords = '';

  String _assistantSpeech = 'Listening... Ask about vendors, menus, wallet balance, or split bills.';

  String? _detectedIntent;

  bool _requiresPin = false;

  String? _challengeCode;

  // Active Voice Persona & Language (Default is English and The Campus Buddy)

  VoicePersona _selectedPersona = kVoicePersonas[0];

  String _currentLanguage = 'en'; // 'en' | 'sw' | 'sheng' | 'fr' | 'es'

  String _voiceGender = 'female'; // 'female' (Lady voice - default) | 'male' (Gentleman voice)

  double _pitch = 1.15;

  double _speechRate = 0.52;

  final TextEditingController _textFallbackController = TextEditingController();

  @override

  void initState() {

    super.initState();

    _speech = stt.SpeechToText();

    _flutterTts = FlutterTts();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    DishiVoiceService.instance.activatePersistentVoice();

    _initAudioAndPreferences();

  }

  Future<void> _initAudioAndPreferences() async {

    try {

      final prefs = await SharedPreferences.getInstance();

      final savedPersonaId = prefs.getString('sema_dishi_voice_persona') ?? 'campus_buddy';

      final savedLang = prefs.getString('sema_dishi_voice_language') ?? 'en';

      final savedGender = prefs.getString('sema_dishi_voice_gender') ?? 'female';

      final persona = kVoicePersonas.firstWhere(

        (p) => p.id == savedPersonaId,

        orElse: () => kVoicePersonas[0],

      );

      final savedPitch = prefs.getDouble('sema_dishi_voice_pitch') ?? (savedGender == 'male' ? 0.72 : 1.22);

      final savedRate = prefs.getDouble('sema_dishi_voice_rate') ?? (savedGender == 'male' ? 0.48 : 0.52);

      if (mounted) {

        setState(() {

          _selectedPersona = persona;

          _currentLanguage = savedLang;

          _voiceGender = savedGender;

          _pitch = savedPitch;

          _speechRate = savedRate;

          _assistantSpeech = _currentLanguage == 'en'

              ? 'Listening (${_selectedPersona.name.split(' ')[0]})... State an order, check balance, or ask anything.'

              : 'Ninakusikiliza (${_selectedPersona.name.split(' ')[0]})... Taja agizo, uliza salio, au sema amri yoyote.';

        });

      }

      await _applyTtsSettings();

    } catch (_) {

      await _applyTtsSettings();

    }

    _startListening();

  }

  Future<void> _applyTtsSettings() async {
    try {
      String ttsLocale = "en-US";
      String baseLang = "en";
      if (_currentLanguage == 'sw' || _currentLanguage == 'sheng') {
        ttsLocale = "sw-KE";
        baseLang = "sw";
      } else if (_currentLanguage == 'fr') {
        ttsLocale = "fr-FR";
        baseLang = "fr";
      } else if (_currentLanguage == 'es') {
        ttsLocale = "es-ES";
        baseLang = "es";
      }

      await _flutterTts.setLanguage(ttsLocale);

      // Distinct pitch: 0.72 for deep masculine voice, 1.22 for lady voice
      final double targetPitch = (_voiceGender == 'male') ? 0.72 : 1.22;
      final double targetRate = (_voiceGender == 'male') ? 0.48 : 0.52;
      _pitch = targetPitch;
      _speechRate = targetRate;

      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_speechRate);

      final dynamic rawVoices = await _flutterTts.getVoices;
      if (rawVoices is List && rawVoices.isNotEmpty) {
        Map? matchedVoice;
        final bool isMaleTarget = _voiceGender == 'male';

        // PASS 1: Search in current locale with strict gender filtering (never match 'female' as male!)
        for (var v in rawVoices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            final gender = (v['gender'] ?? '').toString().toLowerCase();

            final matchesLocale = locale.contains(baseLang) || locale.contains(ttsLocale.toLowerCase());
            final isFemaleTag = name.contains('female') || name.contains('woman') || gender == 'female';

            if (isMaleTarget) {
              if (isFemaleTag) continue; // CRUCIAL: 'female'.contains('male') must be rejected!
              final isMaleTag = name.contains('#male') ||
                  name.contains('_male') ||
                  name.contains('-male') ||
                  name.contains('male_') ||
                  name.contains('male') ||
                  name.contains('man') ||
                  name.contains('-iol-') ||
                  name.contains('-tpd-') ||
                  name.contains('-iom-') ||
                  name.contains('-iob-') ||
                  name.contains('-sfk-') ||
                  name.contains('m0') ||
                  gender == 'male';
              if (matchesLocale && isMaleTag) {
                matchedVoice = v;
                break;
              }
            } else {
              if (matchesLocale && isFemaleTag) {
                matchedVoice = v;
                break;
              }
            }
          }
        }

        // PASS 2: If no voice matched in locale, search globally across all engine voices
        if (matchedVoice == null) {
          for (var v in rawVoices) {
            if (v is Map) {
              final name = (v['name'] ?? '').toString().toLowerCase();
              final gender = (v['gender'] ?? '').toString().toLowerCase();
              final isFemaleTag = name.contains('female') || name.contains('woman') || gender == 'female';

              if (isMaleTarget) {
                if (isFemaleTag) continue;
                final isMaleTag = name.contains('#male') ||
                    name.contains('_male') ||
                    name.contains('-male') ||
                    name.contains('male') ||
                    name.contains('-iol-') ||
                    name.contains('-tpd-') ||
                    name.contains('-iom-') ||
                    name.contains('m0') ||
                    gender == 'male';
                if (isMaleTag) {
                  matchedVoice = v;
                  break;
                }
              } else {
                if (isFemaleTag) {
                  matchedVoice = v;
                  break;
                }
              }
            }
          }
        }

        // PASS 3: Index-based alternating fallback (Google TTS index 0 is female, index 1 is male)
        if (matchedVoice == null) {
          final localeVoices = rawVoices.where((v) {
            if (v is! Map) return false;
            final loc = (v['locale'] ?? '').toString().toLowerCase();
            return loc.contains(baseLang);
          }).toList();

          if (localeVoices.isNotEmpty) {
            if (isMaleTarget && localeVoices.length > 1) {
              matchedVoice = localeVoices[1] as Map;
            } else {
              matchedVoice = localeVoices[0] as Map;
            }
          }
        }

        if (matchedVoice != null) {
          await _flutterTts.setVoice({
            'name': matchedVoice['name'],
            'locale': matchedVoice['locale'],
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {

    try {

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('sema_dishi_voice_persona', _selectedPersona.id);

      await prefs.setString('sema_dishi_voice_language', _currentLanguage);

      await prefs.setString('sema_dishi_voice_gender', _voiceGender);

      await prefs.setDouble('sema_dishi_voice_pitch', _pitch);

      await prefs.setDouble('sema_dishi_voice_rate', _speechRate);

    } catch (_) {}

  }

  Future<void> _speakResponse(String message) async {
    try {
      await _flutterTts.stop();
      // Synchronize exact active gender voice and pitch prior to audio playback
      await _applyTtsSettings();
      final clean = message.replaceAll(RegExp(r'[*#_~`>\[\]\(\)]'), ' ').trim();
      await _flutterTts.speak(clean);
    } catch (_) {}
  }

  Future<void> _startListening() async {

    HapticFeedback.mediumImpact();

    setState(() {

      _recognizedWords = '';

      _assistantSpeech = _currentLanguage == 'en'

          ? 'Listening (${_selectedPersona.name.split(' ')[0]})...'

          : 'Ninakusikiliza (${_selectedPersona.name.split(' ')[0]})...';

      _isListening = true;

    });

    try {

      bool available = await _speech.initialize(

        onStatus: (status) {

          if (status == 'done' || status == 'notListening') {

            if (mounted && _isListening && _recognizedWords.isNotEmpty) {

              _processSpokenText(_recognizedWords);

            }

          }

        },

        onError: (val) {

          if (mounted) setState(() => _isListening = false);

        },

      );

      if (available) {

        _speech.listen(

          onResult: (val) {

            if (mounted) {

              setState(() {

                _recognizedWords = val.recognizedWords;

              });

              if (val.finalResult) {

                _processSpokenText(val.recognizedWords);

              }

            }

          },

          listenOptions: stt.SpeechListenOptions(

            listenMode: stt.ListenMode.confirmation,

            localeId: _currentLanguage == 'sw' || _currentLanguage == 'sheng' ? 'sw_KE' : 'en_US',

          ),

        );

      } else {

        setState(() {

          _isListening = false;

          _assistantSpeech = _currentLanguage == 'en'

              ? 'Microphone unavailable. Use the text box below.'

              : 'Maikrofoni haipatikani. Tumia kisanduku cha maandishi hapa chini.';

        });

      }

    } catch (e) {

      if (mounted) {

        setState(() {

          _isListening = false;

          _assistantSpeech = _currentLanguage == 'en'

              ? 'Voice error. You can type your command below.'

              : 'Hitilafu ya sauti. Unaweza kuandika amri yako hapa chini.';

        });

      }

    }

  }

  Future<void> _stopListening() async {

    await _speech.stop();

    setState(() => _isListening = false);

  }

  void _handleDirectNavigation(String intent, Map<String, dynamic> data) async {

    if (widget.onAction != null) {

      widget.onAction!(intent, data);

    }

    final rootNav = Navigator.of(context, rootNavigator: true);

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    // Keep voice assistant online in background across screens
    DishiVoiceService.instance.activatePersistentVoice();

    final userMap = {
      'uid': widget.userUid ?? 'guest',
      'role': widget.role,
      'name': 'DISHI User',
    };
    final userModel = UserModel(
      uid: widget.userUid ?? 'guest',
      displayName: 'Comrade Student',
      email: '',
      roles: [widget.role],
      walletBalance: 0.0,
      vaultBalance: 0.0,
      okoaBalance: 0.0,
      isVerified: true,
    );

    switch (intent) {
      case 'OPEN_UNIUPTOWN':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const MatchHubView()));
        break;

      case 'START_SWIPING':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const MatchDiscoveryView()));
        break;

      case 'OPEN_MATCHES_CHATS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const MatchMatchesHub()));
        break;

      case 'OPEN_PREORDERS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const StudentPreordersView()));
        break;

      case 'OPEN_SUPERMARKET':
      case 'DISCOVER_MEALS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const CampusSupermarketView()));
        break;

      case 'CAMPUS_GIGS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const CampusEmploymentHubView()));
        break;

      case 'QUERY_BALANCE':
      case 'OPEN_SAVINGS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const StudentLedgerView()));
        break;

      case 'SPLIT_BILL':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => SplitBillView(userModel: userModel)));
        break;

      case 'OKOA_MEAL':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const OkoaFoodView()));
        break;

      case 'OPEN_CAMPUS_MAP':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => CampusMapView(studentUid: userMap['uid'] as String)));
        break;

      case 'OPEN_HOUSING':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => HousingDashboardView(user: userMap)));
        break;

      case 'OPEN_STUDY_TIMER':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const DailyFocusView()));
        break;

      case 'REQUEST_PARENT_FUNDS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const RequestFundsView()));
        break;

      case 'OPEN_VENDOR_POS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => VendorDashboardView(user: userMap)));
        break;

      case 'OPEN_KDS':
      case 'NAVIGATE_KDS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const VendorKdsView()));
        break;

      case 'OPEN_VENDOR_INVENTORY':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const InventoryDashboardView()));
        break;

      case 'OPEN_VENDOR_ANALYTICS':
      case 'NAVIGATE_REPORTS':
      case 'OPEN_VENDOR_FLASH_SALE':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const VendorReportsView()));
        break;

      case 'OPEN_VENDOR_PAYOUTS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => const PayoutHubView()));
        break;

      case 'OPEN_PARENT_ALLOWANCE':
      case 'OPEN_PARENT_DIET':
      case 'OPEN_PARENT_STATEMENTS':
        Navigator.pop(context);
        rootNav.push(MaterialPageRoute(builder: (_) => ParentDashboardView(user: userMap)));
        break;

      case 'SHOW_STUDENT_QR':
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (_) => DynamicQrDialog(
            dishiId: widget.userUid ?? 'DISHI_USER',
            purpose: 'meal_pass',
          ),
        );
        break;

      case 'VOICE_TRAINING':
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const DishiVoiceTrainingSheet(),
        );
        break;

      default:
        break;
    }

  }

  Future<void> _dispatchLocalIntent(String intent, String spoken, Map<String, dynamic> data) async {

    final progressSteps = (data['progress_steps'] as List?)?.cast<String>() ?? [];

    if (progressSteps.isNotEmpty && mounted) {

      for (final step in progressSteps) {

        if (!mounted) break;

        setState(() => _assistantSpeech = step);

        await Future.delayed(const Duration(milliseconds: 350));

      }

    }

    if (mounted) {

      setState(() {

        _detectedIntent = intent;

        _assistantSpeech = spoken;

        _isProcessing = false;

      });

      await _speakResponse(spoken);

      if (intent == 'DISMISS_VOICE') {

        await Future.delayed(const Duration(milliseconds: 1000));

        if (mounted) Navigator.pop(context);

        return;

      }

      _handleDirectNavigation(intent, data);

    }

  }

  void _fallbackLocalIntent(String clean) {
    final low = clean.toLowerCase();

    // 0.1 WAKE WORD & DYNAMIC TIME-BASED GREETING ("Hello DISHI")
    if (low.contains('hello dishi') || low.contains('hey dishi') || low.contains('hi dishi') || low.contains('sema dishi') || low.contains('habari dishi') || low.contains('wake up dishi')) {
      final greeting = getTimeBasedGreeting(_currentLanguage);
      _dispatchLocalIntent('HELLO_DISHI', greeting, {'intent': 'HELLO_DISHI'});
      return;
    }

    // 0.2 STANDBY & MANUAL NAVIGATION ("Thank you DISHI")
    if (low.contains('thank you dishi') || low.contains('thanks dishi') || low.contains('asante dishi') || low.contains('asante sana dishi') || low.contains('thank you') || low.contains('manual mode') || low.contains('stop dishi')) {
      final msg = getStandbyMessage(_currentLanguage);
      DishiVoiceService.instance.setStandby(speakDismiss: false);
      _dispatchLocalIntent('DISMISS_VOICE', msg, {'intent': 'DISMISS_VOICE'});
      return;
    }

    // 0.3 INTERACTIVE VOICE TRAINING & TUTORIAL ("Train me" / "How to use")
    if (low.contains('train me') || low.contains('how to use') || low.contains('how do i use this') || low.contains('nifundishe') || low.contains('voice tutorial') || low.contains('teach me')) {
      final trainingMsg = getVoiceTrainingOverview(_currentLanguage);
      _dispatchLocalIntent('VOICE_TRAINING', trainingMsg, {'intent': 'VOICE_TRAINING'});
      return;
    }

    // 1. UniUptown

    if (low.contains('uniuptown') || low.contains('uni uptown') || low.contains('uptown') || low.contains('dating hub')) {

      final spoken = _currentLanguage == 'en'

          ? "Opening UniUptown now! Connect with campus comrades, faculty dating, and friendships."

          : "Inafungua UniUptown sasa! Ungana na wanafunzi wa chuo kote.";

      _dispatchLocalIntent('OPEN_UNIUPTOWN', spoken, {

        'intent': 'OPEN_UNIUPTOWN',

        'action': 'open_uniuptown',

        'progress_steps': [

          'Connecting to UniUptown Campus Hub...',

          'Opening UniUptown...',

        ],

      });

      return;

    }

    // 2. Start Swiping

    if (low.contains('start swiping') || low.contains('swiping') || low.contains('swipe') || low.contains('anza kuswipe')) {

      final spoken = _currentLanguage == 'en'

          ? "Starting Comrade Swiping! Explore student profiles and find your campus match."

          : "Inaanza Swiping ya wanafunzi! Gundua wasifu wa wanafunzi na upate match wako.";

      _dispatchLocalIntent('START_SWIPING', spoken, {

        'intent': 'START_SWIPING',

        'action': 'start_swiping',

        'progress_steps': [

          'Initializing Comrade Swiping Deck...',

          'Swiping Ready!',

        ],

      });

      return;

    }

    // 3. Matches & Chats

    if (low.contains('match') || low.contains('chat') || low.contains('message') || low.contains('gumzo') || low.contains('ujumbe')) {

      final spoken = _currentLanguage == 'en'

          ? "Opening your Matches and Chats hub. Let's see who's connecting with you!"

          : "Inafungua kitovu cha Mechi na Gumzo!";

      _dispatchLocalIntent('OPEN_MATCHES_CHATS', spoken, {

        'intent': 'OPEN_MATCHES_CHATS',

        'action': 'open_matches_chats',

        'progress_steps': [

          'Synchronizing active comrade conversations...',

          'Chats ready!',

        ],

      });

      return;

    }

    // 4. Preorders

    if (low.contains('preorder') || low.contains('pre-order') || low.contains('agiza')) {

      final spoken = _currentLanguage == 'en'

          ? "Opening Pre-orders! Browse Nyawuora's menu and schedule your pickup to skip the line."

          : "Inafungua maagizo ya mapema! Chagua chakula kwa Nyawuora na uepuke foleni.";

      _dispatchLocalIntent('OPEN_PREORDERS', spoken, {

        'intent': 'OPEN_PREORDERS',

        'action': 'open_preorders',

        'progress_steps': [

          'Connecting to Nyawuora Cafeteria preorders...',

          'Preorders open!',

        ],

      });

      return;

    }

    // 5. Supermarket

    if (low.contains('supermarket') || low.contains('grocery') || low.contains('electronic') || low.contains('duka') || low.contains('calculator') || low.contains('lab coat')) {

      final spoken = _currentLanguage == 'en'

          ? "Opening Campus Supermarket and Tech locker! Explore groceries, stationery, and lab equipment."

          : "Inafungua Supermarket ya Chuo na Vifaa vya Teknolojia!";

      _dispatchLocalIntent('OPEN_SUPERMARKET', spoken, {

        'intent': 'OPEN_SUPERMARKET',

        'action': 'open_supermarket',

        'progress_steps': [

          'Fetching supermarket items & campus inventory...',

          'Supermarket ready!',

        ],

      });

      return;

    }

    // 6. Gigs & Fundi

    if (low.contains('gig') || low.contains('fundi') || low.contains('kazi') || low.contains('employment')) {

      final spoken = _currentLanguage == 'en'

          ? "Opening Campus Employment & Fundi Hub. Connect with student service providers or list your skills!"

          : "Inafungua Ajira za Chuo na Huduma za Mafundi!";

      _dispatchLocalIntent('CAMPUS_GIGS', spoken, {

        'intent': 'CAMPUS_GIGS',

        'action': 'open_gigs',

        'progress_steps': [

          'Loading campus gigs and technician rate cards...',

          'Employment hub ready!',

        ],

      });

      return;

    }

    // 7. Wallet Balance

    if (low.contains('balance') || low.contains('salio') || low.contains('how much') || low.contains('pesa')) {

      final spoken = _currentLanguage == 'en'

          ? "Opening your wallet and financial ledger."

          : "Inafungua salio lako la pochi na historia ya malipo.";

      _dispatchLocalIntent('QUERY_BALANCE', spoken, {

        'intent': 'QUERY_BALANCE',

        'action': 'open_ledger',

      });

      return;

    }

    // 8. Split Bill

    if (low.contains('split') || low.contains('gawanya') || low.contains('change')) {

      final spoken = _currentLanguage == 'en'

          ? "Opening comrade bill splitting sheet."

          : "Inafungua fomu ya kugawanya bili ya chakula.";

      _dispatchLocalIntent('SPLIT_BILL', spoken, {

        'intent': 'SPLIT_BILL',

        'action': 'open_split_bill',

        'amount': 600.0,

      });

      return;

    }

    // 9. Nearest Vendor

    if (low.contains('nearest') || low.contains('vendor') || low.contains('karibu') || low.contains('where to eat')) {

      final spoken = _currentLanguage == 'en'

          ? "Nyawuora Isaya Okuna Cafeteria at MMUST near MEA is your nearest verified vendor with a rating of 4.9."

          : "Nyawuora Isaya Okuna Cafeteria iliyoko MMUST karibu na MEA ndiye muuzaji wa karibu zaidi.";

      _dispatchLocalIntent('NEAREST_VENDOR', spoken, {

        'intent': 'NEAREST_VENDOR',

        'action': 'open_vendor_card',

        'vendor': {

          'id': 'yoDXyLq0vQRp1XNETzKFATzVDzo1',

          'businessName': 'Nyawuora Isaya Okuna Cafeteria',

          'name': 'Nyawuora Isaya Okuna',

          'location': 'MMUST near MEA',

          'rating': 4.9,

        }

      });

      return;

    }

    // 10. QR Food Pass

    if (low.contains('qr') || low.contains('pass') || low.contains('token') || low.contains('lipa')) {

      final spoken = _currentLanguage == 'en'

          ? "Opening your dynamic QR Food Pass for instant counter tap."

          : "Inafungua Pass yako ya QR ya chakula!";

      _dispatchLocalIntent('SHOW_STUDENT_QR', spoken, {

        'intent': 'SHOW_STUDENT_QR',

        'action': 'open_qr_pass',

      });

      return;

    }

    // 11. Gender Switch

    if (low.contains('male voice') || low.contains('gentleman') || low.contains('sauti ya kiume')) {

      setState(() {

        _voiceGender = 'male';

        _pitch = 0.88;

      });

      _savePreferences();

      _applyTtsSettings();

      final spoken = _currentLanguage == 'en' ? "Switched to gentleman voice. Ready to assist you, comrade!" : "Nimebadilisha hadi sauti ya kiume. Niko tayari kukusaidia!";

      _dispatchLocalIntent('CHANGE_VOICE_GENDER', spoken, {'intent': 'CHANGE_VOICE_GENDER', 'active_gender': 'male'});

      return;

    }

    if (low.contains('female voice') || low.contains('lady voice') || low.contains('sauti ya kike')) {

      setState(() {

        _voiceGender = 'female';

        _pitch = 1.18;

      });

      _savePreferences();

      _applyTtsSettings();

      final spoken = _currentLanguage == 'en' ? "Switched to DISHI lady voice. How can I brighten your campus day?" : "Nimebadilisha hadi sauti ya kike ya DISHI. Nikusaidie nini leo?";

      _dispatchLocalIntent('CHANGE_VOICE_GENDER', spoken, {'intent': 'CHANGE_VOICE_GENDER', 'active_gender': 'female'});

      return;

    }

    // Default conversational reply

    final genericSpoken = _currentLanguage == 'en'

        ? "I heard: $clean. I am your DISHI Voice AI, ready to help with orders, UniUptown, wallet balance, and cafeteria menus."

        : "Nimekusikia: $clean. Mimi ni DISHI Voice AI, niko tayari kukusaidia na maagizo, UniUptown, salio na orodha ya chakula.";

    _dispatchLocalIntent('GENERAL_QUERY', genericSpoken, {'intent': 'GENERAL_QUERY'});

  }

  Future<void> _processSpokenText(String input) async {
    final clean = input.trim();
    if (clean.isEmpty) return;

    HapticFeedback.selectionClick();
    await _stopListening();
    setState(() {
      _isProcessing = true;
      _assistantSpeech = _currentLanguage == 'en'
          ? 'Processing: "$clean"...'
          : 'Inachakata: "$clean"...';
    });

    try {
      final resp = await SecureHttpClient.post(
        ApiConfig.v6VoiceIntent,
        body: {
          'text': clean,
          'role': widget.role,
          'uid': widget.userUid ?? '',
          'active_persona': _selectedPersona.id,
          'language': _currentLanguage,
        },
      );

      if (resp.statusCode == 403) {
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final spoken = data['spoken_response'] ?? 'Security Alert: Financial command blocked.';
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _assistantSpeech = spoken;
              _requiresPin = true;
            });
            HapticFeedback.heavyImpact();
            await _speakResponse(spoken);
          }
          return;
        } catch (_) {
          _fallbackLocalIntent(clean);
          return;
        }
      }

      if (resp.statusCode == 200) {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(resp.body) as Map<String, dynamic>;
        } catch (_) {
          _fallbackLocalIntent(clean);
          return;
        }

        final intent = data['intent'] ?? 'GENERAL';
        final spoken = data['spoken_response'] ?? 'Understood, comrade.';
        final reqPin = data['requires_pin'] ?? false;
        final challenge = data['challenge_code'] as String?;
        final progressSteps = (data['progress_steps'] as List?)?.cast<String>() ?? [];

        final returnedPersona = data['active_persona'] as String?;
        final returnedLang = data['active_language'] as String?;

        if (returnedPersona != null && returnedPersona != _selectedPersona.id) {
          final matched = kVoicePersonas.firstWhere((p) => p.id == returnedPersona, orElse: () => _selectedPersona);
          _selectedPersona = matched;
          _voiceGender = matched.isFemale ? 'female' : 'male';
          _pitch = matched.isFemale ? 1.22 : 0.72;
          _speechRate = matched.defaultRate;
          _savePreferences();
          await _applyTtsSettings();
        }

        if (returnedLang != null && returnedLang != _currentLanguage) {
          _currentLanguage = returnedLang;
          _savePreferences();
          await _applyTtsSettings();
        }

        final returnedGender = data['active_gender'] as String?;
        if (returnedGender != null && (returnedGender == 'female' || returnedGender == 'male')) {
          _voiceGender = returnedGender;
          if (_voiceGender == 'female') {
            _pitch = 1.22;
            _speechRate = 0.52;
          } else {
            _pitch = 0.72;
            _speechRate = 0.48;
          }
          _savePreferences();
          await _applyTtsSettings();
        }

        if (progressSteps.isNotEmpty && mounted) {
          for (final step in progressSteps) {
            if (!mounted) break;
            setState(() => _assistantSpeech = step);
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        if (mounted) {
          setState(() {
            _detectedIntent = intent;
            _assistantSpeech = spoken;
            _requiresPin = reqPin;
            _challengeCode = challenge;
            _isProcessing = false;
          });

          await _speakResponse(spoken);

          if (intent == 'DISMISS_VOICE') {
            await Future.delayed(const Duration(milliseconds: 1200));
            if (mounted) Navigator.pop(context);
            return;
          }

          _handleDirectNavigation(intent, data);
        }
      } else {
        _fallbackLocalIntent(clean);
      }
    } catch (_) {
      _fallbackLocalIntent(clean);
    }
  }

  void _openVoiceSettingsSheet() {

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (sheetCtx) => StatefulBuilder(

        builder: (ctx, setSheetState) => Container(

          height: MediaQuery.of(context).size.height * 0.85,

          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),

          decoration: const BoxDecoration(

            color: _bgColor,

            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),

          ),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  const Row(

                    children: [

                      Icon(Icons.tune, color: _neonCyan, size: 22),

                      SizedBox(width: 8),

                      Text('DISHI Voice AI Personas', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),

                    ],

                  ),

                  IconButton(

                    icon: const Icon(Icons.close, color: _textSecondary),

                    onPressed: () => Navigator.pop(sheetCtx),

                  ),

                ],

              ),

              const Divider(color: Colors.white12),

              const SizedBox(height: 8),

              // Voice Gender Selector (Lady Voice Default vs Gentleman Voice)

              const Text('Voice Tone & Gender (Default: Lady Voice):', style: TextStyle(color: _textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👩 Lady Voice (Default)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        if (_voiceGender == 'female') ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check, size: 14, color: Colors.black),
                        ],
                      ],
                    ),
                    selected: _voiceGender == 'female',
                    selectedColor: _neonCyan,
                    backgroundColor: _surfaceLight,
                    labelStyle: TextStyle(color: _voiceGender == 'female' ? Colors.black : Colors.white70),
                    side: BorderSide(color: _voiceGender == 'female' ? _neonCyan : Colors.white12),
                    onSelected: (val) async {
                      if (val) {
                        setSheetState(() {
                          _voiceGender = 'female';
                          _pitch = 1.22;
                          _speechRate = 0.52;
                        });
                        setState(() {
                          _voiceGender = 'female';
                          _pitch = 1.22;
                          _speechRate = 0.52;
                        });
                        await _applyTtsSettings();
                        await _savePreferences();
                        final ack = _currentLanguage == 'en'
                            ? "DISHI lady voice activated. How can I help you today?"
                            : "Sauti ya kike ya DISHI imewashwa. Nikusaidie nini leo rafiki yangu?";
                        await _speakResponse(ack);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👨 Gentleman Voice', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        if (_voiceGender == 'male') ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check, size: 14, color: Colors.black),
                        ],
                      ],
                    ),
                    selected: _voiceGender == 'male',
                    selectedColor: _neonOrange,
                    backgroundColor: _surfaceLight,
                    labelStyle: TextStyle(color: _voiceGender == 'male' ? Colors.black : Colors.white70),
                    side: BorderSide(color: _voiceGender == 'male' ? _neonOrange : Colors.white12),
                    onSelected: (val) async {
                      if (val) {
                        setSheetState(() {
                          _voiceGender = 'male';
                          _pitch = 0.72;
                          _speechRate = 0.48;
                        });
                        setState(() {
                          _voiceGender = 'male';
                          _pitch = 0.72;
                          _speechRate = 0.48;
                        });
                        await _applyTtsSettings();
                        await _savePreferences();
                        final ack = _currentLanguage == 'en'
                            ? "Gentleman voice activated. Ready to assist you, comrade!"
                            : "Sauti ya kiume imewashwa. Niko tayari kukusaidia comrade!";
                        await _speakResponse(ack);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Language Selector Chips
              const Text('Active Language (Default: English):', style: TextStyle(color: _textSecondary, fontSize: 12)),

              const SizedBox(height: 8),

              SingleChildScrollView(

                scrollDirection: Axis.horizontal,

                child: Row(

                  children: [

                    _buildLangChip(setSheetState, 'en', '🇺🇸 English (Default)'),

                    _buildLangChip(setSheetState, 'sw', '🇰🇪 Kiswahili'),

                    _buildLangChip(setSheetState, 'sheng', '🔥 Sheng'),

                    _buildLangChip(setSheetState, 'fr', '🇫🇷 Français'),

                    _buildLangChip(setSheetState, 'es', '🇪🇸 Español'),

                  ],

                ),

              ),

              const SizedBox(height: 14),

              Text('Select Persona (20 Personas Available):', style: TextStyle(color: _neonCyan.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.bold)),

              const SizedBox(height: 8),

              // 20 Persona Cards Scrollable List

              Expanded(

                child: ListView.builder(

                  itemCount: kVoicePersonas.length,

                  itemBuilder: (context, index) {

                    final persona = kVoicePersonas[index];

                    final isSelected = persona.id == _selectedPersona.id;

                    return Container(

                      margin: const EdgeInsets.only(bottom: 8),

                      decoration: BoxDecoration(

                        color: isSelected ? persona.themeColor.withValues(alpha: 0.12) : _surfaceLight,

                        borderRadius: BorderRadius.circular(14),

                        border: Border.all(

                          color: isSelected ? persona.themeColor : Colors.white10,

                          width: isSelected ? 1.5 : 1,

                        ),

                      ),

                      child: ListTile(

                        dense: true,

                        leading: CircleAvatar(

                          backgroundColor: persona.themeColor.withValues(alpha: 0.2),

                          child: Icon(persona.icon, color: persona.themeColor, size: 20),

                        ),

                        title: Row(

                          children: [

                            Flexible(

                              child: Text(

                                persona.name,

                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),

                                overflow: TextOverflow.ellipsis,

                              ),

                            ),

                            if (persona.isFemale) ...[

                              const SizedBox(width: 6),

                              Container(

                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),

                                decoration: BoxDecoration(color: _neonCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),

                                child: const Text('Lady', style: TextStyle(color: _neonCyan, fontSize: 8, fontWeight: FontWeight.bold)),

                              ),

                            ] else ...[

                              const SizedBox(width: 6),

                              Container(

                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),

                                decoration: BoxDecoration(color: _neonOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),

                                child: const Text('Gent', style: TextStyle(color: _neonOrange, fontSize: 8, fontWeight: FontWeight.bold)),

                              ),

                            ],

                            if (persona.id == 'campus_buddy') ...[

                              const SizedBox(width: 6),

                              Container(

                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),

                                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),

                                child: const Text('Default', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),

                              ),

                            ],

                          ],

                        ),

                        subtitle: Text(persona.description, style: const TextStyle(color: _textSecondary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),

                        trailing: isSelected ? Icon(Icons.check_circle, color: persona.themeColor, size: 20) : null,

                        onTap: () async {
                          final gender = persona.isFemale ? 'female' : 'male';
                          final pitch = persona.isFemale ? 1.22 : 0.72;
                          setSheetState(() {
                            _selectedPersona = persona;
                            _voiceGender = gender;
                            _pitch = pitch;
                            _speechRate = persona.defaultRate;
                          });
                          setState(() {
                            _selectedPersona = persona;
                            _voiceGender = gender;
                            _pitch = pitch;
                            _speechRate = persona.defaultRate;
                          });
                          await _applyTtsSettings();
                          await _savePreferences();
                        },

                      ),

                    );

                  },

                ),

              ),

              const SizedBox(height: 10),

              // Audition Voice Button

              SizedBox(

                width: double.infinity,

                child: ElevatedButton.icon(

                  style: ElevatedButton.styleFrom(

                    backgroundColor: _selectedPersona.themeColor,

                    foregroundColor: Colors.black,

                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

                    padding: const EdgeInsets.symmetric(vertical: 12),

                  ),

                  icon: const Icon(Icons.play_arrow, size: 20),

                  label: Text('Audition Voice: ${_selectedPersona.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),

                  onPressed: () {

                    final preview = _currentLanguage == 'en'

                        ? "Hello comrade! I am ${_selectedPersona.name}, your DISHI Voice AI."

                        : "Hujambo comrade! Mimi ni ${_selectedPersona.name}, msaidizi wako wa sauti wa DISHI.";

                    _speakResponse(preview);

                  },

                ),

              ),

              const SizedBox(height: 12),

              // Pitch Slider

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  const Text('Pitch:', style: TextStyle(color: Colors.white, fontSize: 12)),

                  Text('${_pitch.toStringAsFixed(2)}x', style: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),

                ],

              ),

              Slider(

                value: _pitch,

                min: 0.6,

                max: 1.6,

                activeColor: _neonCyan,

                inactiveColor: Colors.white12,

                onChanged: (val) {

                  setSheetState(() => _pitch = val);

                  setState(() => _pitch = val);

                  _applyTtsSettings();

                  _savePreferences();

                },

              ),

              // Speech Rate Slider

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  const Text('Speed:', style: TextStyle(color: Colors.white, fontSize: 12)),

                  Text('${_speechRate.toStringAsFixed(2)}x', style: const TextStyle(color: _neonOrange, fontSize: 12, fontWeight: FontWeight.bold)),

                ],

              ),

              Slider(

                value: _speechRate,

                min: 0.35,

                max: 0.9,

                activeColor: _neonOrange,

                inactiveColor: Colors.white12,

                onChanged: (val) {

                  setSheetState(() => _speechRate = val);

                  setState(() => _speechRate = val);

                  _applyTtsSettings();

                  _savePreferences();

                },

              ),

            ],

          ),

        ),

      ),

    );

  }

  Widget _buildLangChip(StateSetter setSheetState, String code, String label) {

    final isSelected = _currentLanguage == code;

    return Padding(

      padding: const EdgeInsets.only(right: 8.0),

      child: ChoiceChip(

        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),

        selected: isSelected,

        selectedColor: _neonCyan,

        backgroundColor: _cardColor,

        side: BorderSide(color: isSelected ? _neonCyan : Colors.white12),

        onSelected: (val) {

          if (val) {

            setSheetState(() => _currentLanguage = code);

            setState(() => _currentLanguage = code);

            _applyTtsSettings();

            _savePreferences();

          }

        },

      ),

    );

  }

  @override

  void dispose() {

    _speech.stop();

    _flutterTts.stop();

    _pulseController.dispose();

    _textFallbackController.dispose();

    super.dispose();

  }

  @override

  Widget build(BuildContext context) {

    return Container(

      padding: EdgeInsets.only(

        left: 20,

        right: 20,

        top: 24,

        bottom: MediaQuery.of(context).viewInsets.bottom + 24,

      ),

      decoration: BoxDecoration(

        color: _bgColor,

        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),

        border: Border.all(color: _selectedPersona.themeColor.withValues(alpha: 0.35), width: 1.5),

        boxShadow: [

          BoxShadow(

            color: _selectedPersona.themeColor.withValues(alpha: 0.2),

            blurRadius: 30,

            spreadRadius: 2,

          )

        ],

      ),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.center,

        children: [

          // Header Bar

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Expanded(

                child: Row(

                  children: [

                    Container(

                      padding: const EdgeInsets.all(8),

                      decoration: BoxDecoration(

                        color: _selectedPersona.themeColor.withValues(alpha: 0.15),

                        shape: BoxShape.circle,

                      ),

                      child: Icon(_selectedPersona.icon, color: _selectedPersona.themeColor, size: 20),

                    ),

                    const SizedBox(width: 10),

                    Expanded(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          Row(

                            children: [

                              const Flexible(

                                child: Text(

                                  'DISHI Voice AI',

                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),

                                  overflow: TextOverflow.ellipsis,

                                ),

                              ),

                              const SizedBox(width: 6),

                              Container(

                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

                                decoration: BoxDecoration(

                                  color: _selectedPersona.themeColor.withValues(alpha: 0.2),

                                  borderRadius: BorderRadius.circular(6),

                                ),

                                child: Text(

                                  _voiceGender == 'female' ? '👩 Lady' : '👨 Gent',

                                  style: TextStyle(color: _selectedPersona.themeColor, fontSize: 9, fontWeight: FontWeight.bold),

                                ),

                              ),

                              const SizedBox(width: 4),

                              Container(

                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),

                                decoration: BoxDecoration(

                                  color: Colors.white12,

                                  borderRadius: BorderRadius.circular(4),

                                ),

                                child: Text(

                                  _currentLanguage.toUpperCase(),

                                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),

                                ),

                              ),

                            ],

                          ),

                          Text(

                            _selectedPersona.title,

                            style: const TextStyle(color: _textSecondary, fontSize: 11),

                            overflow: TextOverflow.ellipsis,

                            maxLines: 1,

                          ),

                        ],

                      ),

                    ),

                  ],

                ),

              ),

              Row(

                mainAxisSize: MainAxisSize.min,

                children: [

                  IconButton(

                    icon: const Icon(Icons.tune, color: _neonCyan, size: 22),

                    onPressed: _openVoiceSettingsSheet,

                  ),

                  IconButton(

                    icon: const Icon(Icons.close, color: _textSecondary),

                    onPressed: () => Navigator.pop(context),

                  ),

                ],

              ),

            ],

          ),

          const SizedBox(height: 20),

          // Equalizer Soundwaves

          if (_isListening) ...[

            AnimatedBuilder(

              animation: _pulseController,

              builder: (context, _) {

                return SizedBox(

                  height: 32,

                  child: Row(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: List.generate(5, (index) {

                      final wave = (math.sin((_pulseController.value * 2 * math.pi) + (index * 0.8)) + 1) / 2;

                      final h = 10.0 + (wave * 22.0);

                      return Container(

                        width: 4,

                        height: h,

                        margin: const EdgeInsets.symmetric(horizontal: 3),

                        decoration: BoxDecoration(

                          color: _selectedPersona.themeColor,

                          borderRadius: BorderRadius.circular(4),

                          boxShadow: [

                            BoxShadow(

                              color: _selectedPersona.themeColor.withValues(alpha: 0.6),

                              blurRadius: 6,

                            )

                          ],

                        ),

                      );

                    }),

                  ),

                );

              },

            ),

            const SizedBox(height: 12),

          ],

          // Central Microphone Button

          AnimatedBuilder(

            animation: _pulseController,

            builder: (context, child) {

              final scale = _isListening ? 1.0 + (_pulseController.value * 0.16) : 1.0;

              final glow = _isListening

                  ? _selectedPersona.themeColor.withValues(alpha: 0.4 + (_pulseController.value * 0.3))

                  : Colors.transparent;

              return GestureDetector(

                onTap: _isListening ? _stopListening : _startListening,

                child: Container(

                  width: 88 * scale,

                  height: 88 * scale,

                  decoration: BoxDecoration(

                    shape: BoxShape.circle,

                    gradient: LinearGradient(

                      colors: [_selectedPersona.themeColor, _neonOrange],

                      begin: Alignment.topLeft,

                      end: Alignment.bottomRight,

                    ),

                    boxShadow: [

                      BoxShadow(

                        color: glow,

                        blurRadius: 25 * scale,

                        spreadRadius: 6 * scale,

                      )

                    ],

                  ),

                  child: Center(

                    child: _isProcessing

                        ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 3)

                        : Icon(

                            _isListening ? Icons.mic : Icons.mic_none,

                            color: Colors.black,

                            size: 38,

                          ),

                  ),

                ),

              );

            },

          ),

          const SizedBox(height: 14),

          Text(

            _isListening

                ? (_currentLanguage == 'en' ? 'Listening... Speak now' : 'Ninakusikiliza... Sema sasa')

                : (_isProcessing

                    ? (_currentLanguage == 'en' ? 'Processing command...' : 'Inachakata agizo lako...')

                    : (_currentLanguage == 'en' ? 'Tap mic to speak' : 'Gusa maikrofoni kuongea')),

            style: TextStyle(

              color: _isListening ? _selectedPersona.themeColor : _textSecondary,

              fontSize: 13,

              fontWeight: FontWeight.w600,

            ),

          ),

          const SizedBox(height: 12),

          // Transcribed Text & Spoken Container

          Container(

            width: double.infinity,

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(

              color: _cardColor,

              borderRadius: BorderRadius.circular(16),

              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),

            ),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                if (_recognizedWords.isNotEmpty) ...[

                  Text(

                    '"$_recognizedWords"',

                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),

                  ),

                  const Divider(color: Colors.white12, height: 16),

                ],

                Row(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Icon(Icons.volume_up, color: _selectedPersona.themeColor, size: 18),

                    const SizedBox(width: 8),

                    Expanded(

                      child: Text(

                        _assistantSpeech,

                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),

                      ),

                    ),

                  ],

                ),

                if (_detectedIntent != null) ...[

                  const SizedBox(height: 8),

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                    decoration: BoxDecoration(

                      color: _selectedPersona.themeColor.withValues(alpha: 0.15),

                      borderRadius: BorderRadius.circular(6),

                    ),

                    child: Text(

                      'Intent: $_detectedIntent',

                      style: TextStyle(color: _selectedPersona.themeColor, fontSize: 10, fontWeight: FontWeight.bold),

                    ),

                  ),

                ],

              ],

            ),

          ),

          // Security Challenge Prompt

          if (_requiresPin) ...[

            const SizedBox(height: 12),

            Container(

              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(

                color: Colors.orange.withValues(alpha: 0.15),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(color: Colors.orangeAccent),

              ),

              child: Row(

                children: [

                  const Icon(Icons.security, color: Colors.orangeAccent),

                  const SizedBox(width: 10),

                  Expanded(

                    child: Text(

                      _currentLanguage == 'en'

                          ? 'Security Verification: State code $_challengeCode or enter your Wallet PIN.'

                          : 'Uthibitisho wa Usalama: Taja nambari $_challengeCode au weka PIN yako.',

                      style: const TextStyle(color: Colors.white, fontSize: 12),

                    ),

                  ),

                ],

              ),

            ),

          ],

          const SizedBox(height: 16),

          // Adaptive Speech Suggestion Chips

          SingleChildScrollView(

            scrollDirection: Axis.horizontal,

            child: Row(

              children: _getPromptChipsForRole(),

            ),

          ),

          const SizedBox(height: 16),

          // Text Fallback Field

          Row(

            children: [

              Expanded(

                child: TextField(

                  controller: _textFallbackController,

                  style: const TextStyle(color: Colors.white, fontSize: 14),

                  decoration: InputDecoration(

                    hintText: _currentLanguage == 'en'

                        ? 'Or type here (e.g. Nearest vendor)...'

                        : 'Au andika hapa (mf. Vendor wa karibu)...',

                    hintStyle: const TextStyle(color: _textSecondary, fontSize: 12),

                    filled: true,

                    fillColor: _cardColor,

                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                    border: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(12),

                      borderSide: BorderSide.none,

                    ),

                  ),

                  onSubmitted: (txt) {

                    _processSpokenText(txt);

                    _textFallbackController.clear();

                  },

                ),

              ),

              const SizedBox(width: 8),

              IconButton(

                style: IconButton.styleFrom(backgroundColor: _selectedPersona.themeColor),

                icon: const Icon(Icons.send, color: Colors.black, size: 20),

                onPressed: () {

                  final txt = _textFallbackController.text.trim();

                  if (txt.isNotEmpty) {

                    _processSpokenText(txt);

                    _textFallbackController.clear();

                  }

                },

              ),

            ],

          ),

        ],

      ),

    );

  }

  List<Widget> _getPromptChipsForRole() {

    if (_currentLanguage == 'en') {

      return [

        _buildPromptChip('Where is the nearest vendor?'),

        _buildPromptChip('What food is available?'),

        _buildPromptChip('Show my food QR pass'),

        _buildPromptChip('Check my wallet balance'),

        _buildPromptChip('Order 2 chapo dondo'),

        _buildPromptChip('Split a bill of 600'),

        _buildPromptChip('What should I eat? (Dietary)'),

        _buildPromptChip('Will I survive this week?'),

        _buildPromptChip('Emergency food rescue'),

      ];

    } else {

      return [

        _buildPromptChip('Vendor gani yuko karibu?'),

        _buildPromptChip('Kuna chakula gani sasa?'),

        _buildPromptChip('Nipe pass yangu ya QR'),

        _buildPromptChip('Salio langu ni ngapi?'),

        _buildPromptChip('Weka chapati mbili madondo'),

        _buildPromptChip('Gawanya bili ya 600'),

        _buildPromptChip('Ushauri wa lishe bora'),

        _buildPromptChip('Nitatoboa wiki hii?'),

        _buildPromptChip('Okoa chakula'),

      ];

    }

  }

  Widget _buildPromptChip(String label) {

    return Padding(

      padding: const EdgeInsets.only(right: 8.0),

      child: ActionChip(

        backgroundColor: _cardColor,

        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),

        label: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),

        onPressed: () => _processSpokenText(label),

      ),

    );

  }

}

