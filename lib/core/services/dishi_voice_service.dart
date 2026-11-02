import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dishi_voice_models.dart';
import 'api_config.dart';
import 'secure_http_client.dart';
import '../models/user_model.dart';
import '../../main.dart'; // For appNavigatorKey

// Core App Presentation Destinations
import '../../features/match/presentation/match_hub_view.dart';
import '../../features/match/presentation/match_discovery_view.dart';
import '../../features/match/presentation/match_matches_hub.dart';
import '../../features/student/presentation/student_preorders_view.dart';
import '../../features/student/presentation/campus_supermarket_view.dart';
import '../../features/student/presentation/campus_employment_hub.dart';
import '../../features/student/presentation/student_ledger_view.dart';
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
import '../../features/match/presentation/match_campus_idol_view.dart';
import '../../features/parent/presentation/parent_live_tracking_view.dart';

/// Central Persistent Voice Assistant Service for DISHI ("Sema na DISHI")
/// Keeps voice listening online continuously across the entire app once activated,
/// greets on "Hello DISHI", handles full app navigation hands-free,
/// trains users on voice commands, and goes to standby on "Thank you DISHI".
class DishiVoiceService {
  static final DishiVoiceService instance = DishiVoiceService._internal();

  DishiVoiceService._internal();

  Timer? _silenceDebounceTimer;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // State Notifiers for reactive UI binding
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isProcessingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> transcriptNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> lastSpokenResponseNotifier = ValueNotifier<String>('');
  final ValueNotifier<String?> currentIntentNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> showTrainingSheetNotifier = ValueNotifier<bool>(false);

  // Active configuration
  VoicePersona _selectedPersona = kVoicePersonas[0];
  String _currentLanguage = 'en'; // 'en' | 'sw' | 'sheng'
  String _voiceGender = 'female'; // 'female' (default) | 'male'
  double _pitch = 1.22;
  double _speechRate = 0.52;
  String _userRole = 'student';
  String? _userUid;

  Timer? _rearmTimer;
  bool _isInitialized = false;

  VoicePersona get selectedPersona => _selectedPersona;
  String get currentLanguage => _currentLanguage;
  String get voiceGender => _voiceGender;

  /// Dynamically update role and user ID when navigating between dashboards
  void setRoleAndUid({required String role, String? uid}) {
    _userRole = role;
    _userUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
  }

  /// Initialize speech engines and load stored voice preferences
  Future<void> init({String role = 'student', String? uid}) async {
    _userRole = role;
    _userUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final personaId = prefs.getString('sema_dishi_voice_persona') ?? 'campus_buddy';
      _currentLanguage = prefs.getString('sema_dishi_voice_language') ?? 'en';
      _voiceGender = prefs.getString('sema_dishi_voice_gender') ?? 'female';

      _selectedPersona = kVoicePersonas.firstWhere(
        (p) => p.id == personaId,
        orElse: () => kVoicePersonas[0],
      );

      _pitch = _voiceGender == 'male' ? 0.72 : 1.22;
      _speechRate = _voiceGender == 'male' ? 0.48 : 0.52;

      await _applyTtsSettings();

      // Configure TTS completion handler to resume listening loop
      _flutterTts.setCompletionHandler(() {
        isSpeakingNotifier.value = false;
        if (isOnlineNotifier.value) {
          _scheduleRestartListening(delayMs: 300);
        }
      });

      _flutterTts.setErrorHandler((_) {
        isSpeakingNotifier.value = false;
        if (isOnlineNotifier.value) {
          _scheduleRestartListening(delayMs: 400);
        }
      });

      _isInitialized = true;
    } catch (_) {}
  }

  UserModel _resolveUserModel() {
    final uid = _userUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return UserModel(
      uid: uid,
      displayName: 'Comrade Student',
      email: FirebaseAuth.instance.currentUser?.email ?? '',
      roles: [_userRole],
      walletBalance: 0.0,
      vaultBalance: 0.0,
      okoaBalance: 0.0,
      isVerified: true,
    );
  }

  Map<String, dynamic> _resolveUserMap() {
    final uid = _userUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return {
      'uid': uid,
      'email': FirebaseAuth.instance.currentUser?.email ?? '',
      'role': _userRole,
      'name': 'DISHI User',
    };
  }

  /// Activate persistent voice mode: stays online across the whole app
  Future<void> activatePersistentVoice({String? customWelcome}) async {
    await init();
    isOnlineNotifier.value = true;
    HapticFeedback.mediumImpact();

    if (customWelcome != null && customWelcome.isNotEmpty) {
      await speak(customWelcome);
    } else {
      await _startListeningLoop();
    }
  }

  /// Put voice into standby manual mode when user says "Thank you DISHI"
  Future<void> setStandby({bool speakDismiss = true}) async {
    isOnlineNotifier.value = false;
    _rearmTimer?.cancel();

    if (speakDismiss) {
      final msg = getStandbyMessage(_currentLanguage);
      lastSpokenResponseNotifier.value = msg;
      await speak(msg, resumeListeningAfter: false);
    }

    try {
      await _speech.stop();
    } catch (_) {}

    isListeningNotifier.value = false;
    isProcessingNotifier.value = false;
    transcriptNotifier.value = '';
    currentIntentNotifier.value = 'THANK_YOU_DISHI';
  }

  /// Toggle online voice listening
  Future<void> toggleVoiceOnline() async {
    if (isOnlineNotifier.value) {
      await setStandby(speakDismiss: true);
    } else {
      await activatePersistentVoice();
    }
  }

  /// Set Voice Gender and synchronize exact pitch
  Future<void> setVoiceGender(String gender) async {
    _voiceGender = gender == 'male' ? 'male' : 'female';
    _pitch = _voiceGender == 'male' ? 0.72 : 1.22;
    _speechRate = _voiceGender == 'male' ? 0.48 : 0.52;
    await _applyTtsSettings();
    await _savePreferences();

    final ack = _currentLanguage == 'en'
        ? (_voiceGender == 'male'
            ? "Gentleman voice activated. Ready to assist you, comrade!"
            : "DISHI lady voice activated. How can I help you today?")
        : (_voiceGender == 'male'
            ? "Sauti ya kiume imewashwa. Niko tayari kukusaidia comrade!"
            : "Sauti ya kike ya DISHI imewashwa. Nikusaidie nini leo rafiki yangu?");
    await speak(ack);
  }

  /// Set Voice Persona
  Future<void> setVoicePersona(VoicePersona persona) async {
    _selectedPersona = persona;
    _voiceGender = persona.isFemale ? 'female' : 'male';
    _pitch = persona.isFemale ? 1.22 : 0.72;
    _speechRate = persona.defaultRate;
    await _applyTtsSettings();
    await _savePreferences();

    final preview = _currentLanguage == 'en'
        ? "Hello comrade! I am ${_selectedPersona.name}, your DISHI Voice AI."
        : "Hujambo comrade! Mimi ni ${_selectedPersona.name}, msaidizi wako wa sauti wa DISHI.";
    await speak(preview);
  }

  /// Set Active Spoken Language
  Future<void> setLanguage(String lang) async {
    _currentLanguage = lang;
    await _applyTtsSettings();
    await _savePreferences();

    final ack = lang == 'en'
        ? "English language selected. How can I help you?"
        : "Lugha ya Kiswahili imechaguliwa. Nikusaidie nini leo?";
    await speak(ack);
  }

  /// Trigger Interactive Voice Training
  Future<void> launchVoiceTraining() async {
    showTrainingSheetNotifier.value = true;
    final trainingMsg = getVoiceTrainingOverview(_currentLanguage);
    await speak(trainingMsg);
  }

  /// Speak response via FlutterTTS with calibrated masculine/feminine acoustics
  Future<void> speak(String text, {bool resumeListeningAfter = true}) async {
    try {
      isSpeakingNotifier.value = true;
      try {
        await _speech.stop();
        isListeningNotifier.value = false;
      } catch (_) {}

      await _flutterTts.stop();
      await _applyTtsSettings();
      final clean = sanitizeForTts(text);
      lastSpokenResponseNotifier.value = clean;
      await _flutterTts.speak(clean);

      if (!resumeListeningAfter) {
        isSpeakingNotifier.value = false;
      }
    } catch (_) {
      isSpeakingNotifier.value = false;
      if (resumeListeningAfter && isOnlineNotifier.value) {
        _scheduleRestartListening(delayMs: 300);
      }
    }
  }

  /// Native Android TTS calibration with strict female rejection in male matching
  Future<void> _applyTtsSettings() async {
    try {
      String ttsLocale = "en-US";
      String baseLang = "en";
      if (_currentLanguage == 'sw' || _currentLanguage == 'sheng') {
        ttsLocale = "sw-KE";
        baseLang = "sw";
      }

      await _flutterTts.setLanguage(ttsLocale);
      _pitch = _voiceGender == 'male' ? 0.72 : 1.22;
      _speechRate = _voiceGender == 'male' ? 0.48 : 0.52;

      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_speechRate);

      final dynamic rawVoices = await _flutterTts.getVoices;
      if (rawVoices is List && rawVoices.isNotEmpty) {
        Map? matchedVoice;
        final bool isMaleTarget = _voiceGender == 'male';

        // PASS 1: Search in current locale with strict female exclusion
        for (var v in rawVoices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            final gender = (v['gender'] ?? '').toString().toLowerCase();

            final matchesLocale = locale.contains(baseLang) || locale.contains(ttsLocale.toLowerCase());
            final isFemaleTag = name.contains('female') || name.contains('woman') || gender == 'female';

            if (isMaleTarget) {
              if (isFemaleTag) continue; // CRUCIAL: 'female' contains 'male' substring!
              final isMaleTag = name.contains('#male') ||
                  name.contains('_male') ||
                  name.contains('-male') ||
                  name.contains('male_') ||
                  name.contains('male') ||
                  name.contains('man') ||
                  name.contains('-iol-') ||
                  name.contains('-tpd-') ||
                  name.contains('-iom-') ||
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

        // PASS 2: Global engine fallback
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
                    name.contains('male') ||
                    name.contains('-iol-') ||
                    name.contains('-tpd-') ||
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

        // PASS 3: Index alternating pair fallback (index 1 is male, 0 is female in Google TTS bundles)
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

  /// Internal continuous listening loop
  Future<void> _startListeningLoop() async {
    if (!isOnlineNotifier.value || isSpeakingNotifier.value || isProcessingNotifier.value) return;

    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            isListeningNotifier.value = false;
            if (isOnlineNotifier.value && !isSpeakingNotifier.value && !isProcessingNotifier.value) {
              final txt = transcriptNotifier.value.trim();
              if (txt.isNotEmpty) {
                _silenceDebounceTimer?.cancel();
                processVoiceCommand(txt);
              } else {
                _scheduleRestartListening(delayMs: 150);
              }
            }
          }
        },
        onError: (_) {
          isListeningNotifier.value = false;
          if (isOnlineNotifier.value && !isSpeakingNotifier.value && !isProcessingNotifier.value) {
            _scheduleRestartListening(delayMs: 300);
          }
        },
      );

      if (available) {
        isListeningNotifier.value = true;
        await _speech.listen(
          onResult: (val) {
            transcriptNotifier.value = val.recognizedWords;
            final words = val.recognizedWords.trim();
            if (words.isNotEmpty) {
              if (val.finalResult) {
                _silenceDebounceTimer?.cancel();
                _speech.stop();
                processVoiceCommand(words);
              } else {
                // Real-time debounce: trigger 850ms after the comrade pauses speaking!
                _silenceDebounceTimer?.cancel();
                _silenceDebounceTimer = Timer(const Duration(milliseconds: 850), () async {
                  if (isOnlineNotifier.value && !isSpeakingNotifier.value && !isProcessingNotifier.value) {
                    final currentText = transcriptNotifier.value.trim();
                    if (currentText.isNotEmpty) {
                      await _speech.stop();
                      processVoiceCommand(currentText);
                    }
                  }
                });
              }
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            partialResults: true,
            cancelOnError: false,
            localeId: _currentLanguage == 'sw' || _currentLanguage == 'sheng' ? 'sw_KE' : 'en_US',
          ),
        );
      }
    } catch (_) {
      isListeningNotifier.value = false;
      if (isOnlineNotifier.value && !isSpeakingNotifier.value && !isProcessingNotifier.value) {
        _scheduleRestartListening(delayMs: 400);
      }
    }
  }

  void _scheduleRestartListening({int delayMs = 150}) {
    _rearmTimer?.cancel();
    _rearmTimer = Timer(Duration(milliseconds: delayMs), () {
      if (isOnlineNotifier.value && !isSpeakingNotifier.value && !isProcessingNotifier.value) {
        _startListeningLoop();
      }
    });
  }

  /// Toggle manual microphone listening state
  Future<void> toggleListening() async {
    if (isListeningNotifier.value) {
      _silenceDebounceTimer?.cancel();
      await _speech.stop();
      isListeningNotifier.value = false;
    } else {
      await _startListeningLoop();
    }
  }

  /// Ensure background listening loop is active without resetting user state
  void ensureListeningInBackground() {
    if (isOnlineNotifier.value && !isSpeakingNotifier.value && !isProcessingNotifier.value && !isListeningNotifier.value) {
      _scheduleRestartListening(delayMs: 100);
    }
  }

  /// Fast-path filter for immediate local execution without network latency
  bool _matchesDirectLocalIntent(String low) {
    const keywords = [
      'uniuptown', 'uni uptown', 'uptown', 'dating hub',
      'swiping', 'swipe', 'anza kuswipe',
      'matches and chats', 'matches', 'chats', 'gumzo', 'ujumbe',
      'preorder', 'pre-order', 'order this', 'agiza',
      'supermarket', 'grocer', 'calculator', 'lab coat', 'duka',
      'gig', 'fundi', 'kazi', 'employment', 'kibarua',
      'balance', 'salio', 'pesa', 'wallet',
      'split', 'gawanya',
      'nearest', 'vendor', 'where to eat',
      'qr', 'pass', 'token',
      'okoa', 'emergency food', 'rescue',
      'hostel', 'keja', 'housing', 'rent',
      'map', 'ramani', 'directions',
      'timer', 'study', 'timetable', 'smartimer', 'focus',
      'saving', 'stash', 'akiba',
      'child', 'dependant', 'dependent', 'student', 'mtoto', 'kijana', 'watoto', 'mwanafunzi',
      'last bought', 'which shop', 'where is my', 'what did my',
      'parent', 'mzazi', 'omba pesa',
      'pos', 'counter terminal', 'kds', 'kitchen', 'inventory', 'stock', 'report', 'analytics', 'payout',
      'idol', 'campus idol', 'audition', 'the voice', 'sing', 'imba',
      'time', 'saa ngapi', 'what time',
    ];
    for (final kw in keywords) {
      if (low.contains(kw)) return true;
    }
    return false;
  }

  /// Core Voice Command Parser & Universal System Dispatcher
  Future<void> processVoiceCommand(String rawInput) async {
    final clean = rawInput.trim();
    if (clean.isEmpty) return;

    final low = clean.toLowerCase();
    isProcessingNotifier.value = true;
    HapticFeedback.selectionClick();

    // 1. WAKE WORD & TIME-BASED GREETING: "Hello DISHI"
    if (low.contains('hello dishi') ||
        low.contains('hey dishi') ||
        low.contains('hi dishi') ||
        low.contains('sema dishi') ||
        low.contains('habari dishi') ||
        low.contains('wake up dishi') ||
        low.contains('dishi voice')) {
      final greeting = getTimeBasedGreeting(_currentLanguage);
      currentIntentNotifier.value = 'HELLO_DISHI';
      isProcessingNotifier.value = false;
      transcriptNotifier.value = '';
      await speak(greeting);
      return;
    }

    // 2. MANUAL MODE & STANDBY: "Thank you DISHI"
    if (low.contains('thank you dishi') ||
        low.contains('thanks dishi') ||
        low.contains('asante dishi') ||
        low.contains('asante sana dishi') ||
        low.contains('thank you') ||
        low.contains('stop dishi') ||
        low.contains('standby dishi') ||
        low.contains('manual mode') ||
        low.contains('kwaheri dishi')) {
      await setStandby(speakDismiss: true);
      return;
    }

    // 3. VOICE TRAINING & TUTORIAL: "Train me" / "How to use"
    if (low.contains('train me') ||
        low.contains('how to use') ||
        low.contains('how do i use this') ||
        low.contains('nifundishe') ||
        low.contains('help with voice') ||
        low.contains('voice tutorial') ||
        low.contains('what can i say') ||
        low.contains('teach me')) {
      isProcessingNotifier.value = false;
      transcriptNotifier.value = '';
      currentIntentNotifier.value = 'VOICE_TRAINING';
      await launchVoiceTraining();
      return;
    }

    // 4. VOICE GENDER SWITCHING
    if (low.contains('male voice') || low.contains('gentleman voice') || low.contains('sauti ya kiume')) {
      isProcessingNotifier.value = false;
      transcriptNotifier.value = '';
      await setVoiceGender('male');
      return;
    }
    if (low.contains('female voice') || low.contains('lady voice') || low.contains('sauti ya kike')) {
      isProcessingNotifier.value = false;
      transcriptNotifier.value = '';
      await setVoiceGender('female');
      return;
    }

    // 5. FAST-PATH DIRECT LOCAL INTENTS: Immediate local response (<20ms) for known actions
    if (_matchesDirectLocalIntent(low)) {
      _dispatchLocalFallback(clean);
      return;
    }

    // 6. ATTEMPT SECURE BACKEND INTENT PARSING
    try {
      final resp = await SecureHttpClient.post(
        ApiConfig.v6VoiceIntent,
        body: {
          'text': clean,
          'role': _userRole,
          'uid': _userUid ?? '',
          'active_persona': _selectedPersona.id,
          'language': _currentLanguage,
        },
      ).timeout(const Duration(milliseconds: 3000));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final intent = data['intent'] ?? 'GENERAL';
        final spoken = data['spoken_response'] ?? 'Understood, comrade.';
        final keepListening = data['keep_listening'] ?? true;

        currentIntentNotifier.value = intent;
        isProcessingNotifier.value = false;
        transcriptNotifier.value = '';

        await speak(spoken, resumeListeningAfter: keepListening);
        _dispatchUniversalNavigation(intent, data);
        return;
      }
    } catch (_) {}

    // 6. ROBUST LOCAL INTENT FALLBACK (Guarantees zero downtime / works fully offline)
    _dispatchLocalFallback(clean);
  }

  /// Fetches real student dependant details from Firestore for parents:
  /// Name, wallet balance, current campus/hostel location, last bought item and vendor shop.
  Future<Map<String, dynamic>> fetchParentDependantsReport({String queryType = 'all'}) async {
    try {
      final parentUid = _userUid ?? FirebaseAuth.instance.currentUser?.uid;
      if (parentUid == null || parentUid.isEmpty) {
        return {
          'spoken': _currentLanguage == 'sw'
              ? "Tafadhali ingia katika akaunti yako ya mzazi ili kuona taarifa za mtoto wako."
              : "Please sign into your parent account to check dependant details.",
          'students': [],
        };
      }

      final parentDoc = await FirebaseFirestore.instance.collection('users').doc(parentUid).get();
      List<dynamic> studentUids = [];
      String parentPhone = '';

      if (parentDoc.exists) {
        final pData = parentDoc.data() ?? {};
        studentUids = List<dynamic>.from(pData['linkedStudents'] ?? pData['dependants'] ?? []);
        parentPhone = (pData['phoneNumber'] ?? pData['phone'] ?? '').toString();
      }

      if (studentUids.isEmpty) {
        final q1 = await FirebaseFirestore.instance
            .collection('users')
            .where('parentUid', isEqualTo: parentUid)
            .limit(5)
            .get();
        if (q1.docs.isNotEmpty) {
          studentUids = q1.docs.map((d) => d.id).toList();
        } else if (parentPhone.isNotEmpty) {
          final q2 = await FirebaseFirestore.instance
              .collection('users')
              .where('parentPhone', isEqualTo: parentPhone)
              .limit(5)
              .get();
          studentUids = q2.docs.map((d) => d.id).toList();
        }
      }

      if (studentUids.isEmpty) {
        return {
          'spoken': _currentLanguage == 'sw'
              ? "Hujaunganisha mwanafunzi yeyote kwenye akaunti yako bado. Unaweza kumuunganisha kupitia kitufe cha Link Student kwenye dashibodi ya mzazi."
              : "You do not have any linked student dependants yet. You can link your student by tapping Link Student in your parent dashboard.",
          'students': [],
        };
      }

      final reports = <String>[];
      final studentList = <Map<String, dynamic>>[];

      for (final sUid in studentUids.take(2)) {
        final sDoc = await FirebaseFirestore.instance.collection('users').doc(sUid.toString()).get();
        if (!sDoc.exists) continue;

        final sData = sDoc.data() ?? {};
        final name = sData['name'] ?? sData['displayName'] ?? 'Comrade Student';
        final bal = (sData['walletBalance'] as num?)?.toDouble() ?? (sData['balance'] as num?)?.toDouble() ?? 0.0;

        // Resolve location
        String locationDesc = 'MMUST Main Campus';
        final locObj = sData['location'];
        if (locObj is Map<String, dynamic>) {
          locationDesc = locObj['address'] ?? locObj['place'] ?? 'MMUST Campus';
        } else if (locObj is String && locObj.isNotEmpty) {
          locationDesc = locObj;
        } else if (sData['hostel'] != null && sData['campus'] != null) {
          locationDesc = "${sData['hostel']}, ${sData['campus']}";
        } else if (sData['campus'] != null) {
          locationDesc = sData['campus'];
        }

        // Query last transaction
        String lastBoughtItem = 'Lunch meal';
        String lastShop = 'Nyawuora Isaya Okuna Cafeteria';
        double lastAmount = 0.0;
        String timeAgo = 'recently';
        bool hasTx = false;

        try {
          final txSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(sUid.toString())
              .collection('transactions')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          Map<String, dynamic>? txData;
          if (txSnap.docs.isNotEmpty) {
            txData = txSnap.docs.first.data();
          } else {
            final rootTx = await FirebaseFirestore.instance
                .collection('transactions')
                .where('student_id', isEqualTo: sUid.toString())
                .limit(5)
                .get();
            if (rootTx.docs.isNotEmpty) {
              final sorted = rootTx.docs.toList()
                ..sort((a, b) {
                  final tA = a.data()['timestamp'] as Timestamp?;
                  final tB = b.data()['timestamp'] as Timestamp?;
                  if (tA != null && tB != null) return tB.compareTo(tA);
                  return 0;
                });
              txData = sorted.first.data();
            }
          }

          if (txData != null) {
            hasTx = true;
            lastBoughtItem = txData['itemName'] ?? txData['item'] ?? txData['description'] ?? txData['title'] ?? 'Food meal';
            lastShop = txData['vendorName'] ?? txData['vendor_name'] ?? txData['shopName'] ?? txData['vendor'] ?? 'Nyawuora Cafeteria';
            lastAmount = (txData['amount'] as num?)?.toDouble() ?? 0.0;

            final ts = txData['timestamp'] as Timestamp?;
            if (ts != null) {
              final dt = ts.toDate();
              final diff = DateTime.now().difference(dt);
              if (diff.inMinutes < 60) {
                timeAgo = '${diff.inMinutes} minutes ago';
              } else if (diff.inHours < 24) {
                timeAgo = '${diff.inHours} hours ago';
              } else {
                timeAgo = '${diff.inDays} days ago';
              }
            }
          }
        } catch (_) {}

        studentList.add({
          'uid': sUid.toString(),
          'name': name,
          'balance': bal,
          'location': locationDesc,
          'lastItem': lastBoughtItem,
          'lastShop': lastShop,
          'lastAmount': lastAmount,
          'timeAgo': timeAgo,
        });

        if (_currentLanguage == 'sw') {
          if (queryType == 'location') {
            reports.add("$name yupo katika eneo la $locationDesc. Salio lake ni Shilingi ${bal.toStringAsFixed(0)}.");
          } else if (queryType == 'spending' && hasTx) {
            reports.add("Ununuzi wa mwisho wa $name ulikuwa $lastBoughtItem katika mkahawa wa $lastShop kwa Shilingi ${lastAmount.toStringAsFixed(0)} ($timeAgo).");
          } else {
            final txDetail = hasTx
                ? " Ununuzi wake wa mwisho ulikuwa $lastBoughtItem katika mkahawa wa $lastShop kwa Shilingi ${lastAmount.toStringAsFixed(0)} ($timeAgo)."
                : " Hakuna manunuzi mapya yaliyorekodiwa leo.";
            reports.add("$name ana salio la Shilingi ${bal.toStringAsFixed(0)}, yupo eneo la $locationDesc.$txDetail");
          }
        } else {
          if (queryType == 'location') {
            reports.add("$name is currently located at $locationDesc. Current wallet balance is KES ${bal.toStringAsFixed(0)}.");
          } else if (queryType == 'spending' && hasTx) {
            reports.add("$name's last purchase was $lastBoughtItem from $lastShop costing KES ${lastAmount.toStringAsFixed(0)} ($timeAgo).");
          } else {
            final txDetail = hasTx
                ? " Last purchase was $lastBoughtItem at $lastShop for KES ${lastAmount.toStringAsFixed(0)} ($timeAgo)."
                : " No recent food purchases recorded today.";
            reports.add("$name has a wallet balance of KES ${bal.toStringAsFixed(0)}, located at $locationDesc.$txDetail");
          }
        }
      }

      return {
        'spoken': reports.join(' '),
        'students': studentList,
      };
    } catch (_) {
      return {
        'spoken': _currentLanguage == 'sw'
            ? "Kuna tatizo kidogo kupata taarifa za mwanafunzi kutoka kanzidata. Tafadhali jaribu tena."
            : "Could not retrieve student dependant details right now. Please try again.",
        'students': [],
      };
    }
  }

  /// Offline direct fallback intent matcher covering the entire application
  void _dispatchLocalFallback(String clean) async {
    final low = clean.toLowerCase();
    String intent = 'GENERAL';
    String spoken = '';
    Map<String, dynamic> data = {'intent': intent};

    // 0. PARENT DEPENDANT QUERY (Details, Location, Last Bought Item, Shop)
    if (_userRole == 'parent' ||
        low.contains('child') ||
        low.contains('mtoto') ||
        low.contains('dependant') ||
        low.contains('dependent') ||
        low.contains('kijana') ||
        low.contains('watoto') ||
        low.contains('mwanafunzi') ||
        low.contains('last bought') ||
        low.contains('which shop') ||
        low.contains('what did my') ||
        low.contains('where is my') ||
        (low.contains('student') && (_userRole == 'parent' || low.contains('balance') || low.contains('location') || low.contains('details')))) {
      intent = 'QUERY_PARENT_DEPENDANTS';

      String queryType = 'all';
      if (low.contains('where') || low.contains('location') || low.contains('ramani') || low.contains('wapi')) {
        queryType = 'location';
      } else if (low.contains('bought') || low.contains('buy') || low.contains('shop') || low.contains('nunua') || low.contains('mkahawa') || low.contains('item')) {
        queryType = 'spending';
      }

      isProcessingNotifier.value = true;
      final report = await fetchParentDependantsReport(queryType: queryType);
      spoken = report['spoken'] as String;
      data['queryType'] = queryType;
      data['students'] = report['students'];
    }
    // 1. UniUptown
    else if (low.contains('uniuptown') || low.contains('uni uptown') || low.contains('uptown') || low.contains('dating hub')) {
      intent = 'OPEN_UNIUPTOWN';
      spoken = _currentLanguage == 'en'
          ? "Opening UniUptown now! Connect with campus comrades, faculty dating, and friendships."
          : "Inafungua UniUptown sasa! Ungana na wanafunzi wa chuo kote.";
    }
    // 2. Start Swiping
    else if (low.contains('start swiping') || low.contains('swiping') || low.contains('swipe') || low.contains('anza kuswipe')) {
      intent = 'START_SWIPING';
      spoken = _currentLanguage == 'en'
          ? "Starting Comrade Swiping! Explore student profiles and find your campus match."
          : "Inaanza Swiping ya wanafunzi! Gundua wasifu wa wanafunzi na upate match wako.";
    }
    // 3. Matches and Chats
    else if (low.contains('matches and chats') || low.contains('matches') || low.contains('chats') || low.contains('gumzo') || low.contains('ujumbe')) {
      intent = 'OPEN_MATCHES_CHATS';
      spoken = _currentLanguage == 'en'
          ? "Opening your Matches and Chats hub. Let's see who's connecting with you!"
          : "Inafungua kitovu cha Mechi na Gumzo!";
    }
    // 4. Preorders & Order ahead
    else if (low.contains('preorder') || low.contains('pre-order') || low.contains('order this') || low.contains('agiza')) {
      intent = 'OPEN_PREORDERS';
      spoken = _currentLanguage == 'en'
          ? "Opening Pre-orders! Browse Nyawuora's menu and schedule your pickup to skip the line."
          : "Inafungua maagizo ya mapema! Chagua chakula kwa Nyawuora na uepuke foleni.";
    }
    // 5. Campus Supermarket & Electronics
    else if (low.contains('supermarket') || low.contains('grocer') || low.contains('calculator') || low.contains('lab coat') || low.contains('duka')) {
      intent = 'OPEN_SUPERMARKET';
      spoken = _currentLanguage == 'en'
          ? "Opening Campus Supermarket and Tech locker! Explore groceries, stationery, and lab equipment."
          : "Inafungua Supermarket ya Chuo na Vifaa vya Teknolojia!";
    }
    // 6. Campus Gigs & Employment Hub
    else if (low.contains('gig') || low.contains('fundi') || low.contains('kazi') || low.contains('employment') || low.contains('kibarua')) {
      intent = 'CAMPUS_GIGS';
      spoken = _currentLanguage == 'en'
          ? "Opening Campus Employment & Fundi Hub. Connect with student service providers or list your skills!"
          : "Inafungua Ajira za Chuo na Huduma za Mafundi!";
    }
    // 7. Wallet Balance & Financial Ledger
    else if (low.contains('balance') || low.contains('salio') || low.contains('how much') || low.contains('pesa') || low.contains('wallet')) {
      intent = 'QUERY_BALANCE';
      spoken = _currentLanguage == 'en'
          ? "Opening your wallet and financial ledger."
          : "Inafungua salio lako la pochi na historia ya malipo.";
    }
    // 8. Comrade Bill Split
    else if (low.contains('split') || low.contains('gawanya')) {
      intent = 'SPLIT_BILL';
      spoken = _currentLanguage == 'en'
          ? "Opening comrade bill splitting sheet."
          : "Inafungua fomu ya kugawanya bili ya chakula.";
    }
    // 9. Nearest Vendor (Nyawuora Isaya Okuna)
    else if (low.contains('nearest') || low.contains('vendor') || low.contains('karibu') || low.contains('where to eat')) {
      intent = 'NEAREST_VENDOR';
      spoken = _currentLanguage == 'en'
          ? "Nyawuora Isaya Okuna Cafeteria at MMUST near MEA is your nearest verified vendor with a 4.9 rating."
          : "Nyawuora Isaya Okuna Cafeteria iliyoko MMUST karibu na MEA ndiye muuzaji wa karibu zaidi.";
    }
    // 10. QR Food Pass
    else if (low.contains('qr') || low.contains('pass') || low.contains('token') || low.contains('counter tap')) {
      intent = 'SHOW_STUDENT_QR';
      spoken = _currentLanguage == 'en'
          ? "Opening your dynamic QR Food Pass for instant counter tap."
          : "Inafungua Pass yako ya QR ya chakula!";
    }
    // 11. Emergency Food Rescue (Okoa Food)
    else if (low.contains('okoa') || low.contains('emergency food') || low.contains('nimeishiwa') || low.contains('rescue')) {
      intent = 'OKOA_MEAL';
      spoken = _currentLanguage == 'en'
          ? "Opening Okoa Food emergency meal rescue. Nobody goes hungry on campus!"
          : "Inafungua Okoa Food kwa chakula cha dharura!";
    }
    // 12. Hostels & Keja Housing
    else if (low.contains('hostel') || low.contains('keja') || low.contains('housing') || low.contains('rent')) {
      intent = 'OPEN_HOUSING';
      spoken = _currentLanguage == 'en'
          ? "Opening Campus Keja and Student Housing hub."
          : "Inafungua Keja na makazi ya chuo!";
    }
    // 13. Campus Map
    else if (low.contains('map') || low.contains('ramani') || low.contains('location') || low.contains('directions')) {
      intent = 'OPEN_CAMPUS_MAP';
      spoken = _currentLanguage == 'en'
          ? "Opening Campus Map and Dining Locations."
          : "Inafungua ramani ya chuo na maeneo ya kula.";
    }
    // 14. Academic Study Timer & Focus
    else if (low.contains('timer') || low.contains('study') || low.contains('timetable') || low.contains('smartimer') || low.contains('focus')) {
      intent = 'OPEN_STUDY_TIMER';
      spoken = _currentLanguage == 'en'
          ? "Opening SmartiMer Academic Study Focus and Timetable."
          : "Inafungua ratiba ya masomo na SmartiMer!";
    }
    // 15. Student Savings & Stash
    else if (low.contains('saving') || low.contains('stash') || low.contains('akiba')) {
      intent = 'QUERY_BALANCE';
      spoken = _currentLanguage == 'en'
          ? "Opening your financial ledger and student balance."
          : "Inafungua salio lako la chuo na historia ya fedha.";
    }
    // 16. Request Parent Funds
    else if (_userRole != 'parent' && (low.contains('parent') || low.contains('mzazi') || low.contains('omba pesa'))) {
      intent = 'REQUEST_PARENT_FUNDS';
      spoken = _currentLanguage == 'en'
          ? "Opening Parent Meal Allowance request."
          : "Inafungua fomu ya kuomba pesa ya chakula kutoka kwa mzazi.";
    }
    // 17. Vendor POS & Operations
    else if (low.contains('pos') || low.contains('counter terminal') || low.contains('vendor dashboard')) {
      intent = 'OPEN_VENDOR_POS';
      spoken = _currentLanguage == 'en'
          ? "Opening Vendor Point of Sale terminal."
          : "Inafungua kituo cha mauzo cha muuzaji.";
    }
    // 18. Kitchen Queue / KDS
    else if (low.contains('kds') || low.contains('kitchen') || low.contains('jikoni')) {
      intent = 'OPEN_KDS';
      spoken = _currentLanguage == 'en'
          ? "Opening Kitchen Display System and active food orders."
          : "Inafungua maagizo ya chakula jikoni.";
    }
    // 19. Vendor Inventory
    else if (low.contains('inventory') || low.contains('stock') || low.contains('stoo')) {
      intent = 'OPEN_VENDOR_INVENTORY';
      spoken = _currentLanguage == 'en'
          ? "Opening Vendor Inventory and stock tracker."
          : "Inafungua stoo na hesabu ya bidhaa.";
    }
    // 20. Vendor Reports & Analytics
    else if (low.contains('report') || low.contains('analytics') || low.contains('ripoti ya mauzo') || low.contains('mauzo')) {
      intent = 'OPEN_VENDOR_ANALYTICS';
      spoken = _currentLanguage == 'en'
          ? "Opening Vendor Financial Reports and daily sales graphs."
          : "Inafungua ripoti za mauzo na uchambuzi wa kifedha.";
    }
    // 21. Vendor Payouts
    else if (low.contains('payout') || low.contains('settlement') || low.contains('toa pesa ya biashara')) {
      intent = 'OPEN_VENDOR_PAYOUTS';
      spoken = _currentLanguage == 'en'
          ? "Opening Vendor Payout and M-PESA settlement hub."
          : "Inafungua kitovu cha malipo na kutoa pesa ya muuzaji.";
    }
    // 22. Campus Idol & Voice Auditions
    else if (low.contains('campus idol') ||
        low.contains('idol') ||
        low.contains('the voice') ||
        low.contains('audition') ||
        low.contains('sing') ||
        low.contains('imba') ||
        low.contains('voice contest')) {
      intent = 'OPEN_CAMPUS_IDOL';
      spoken = _currentLanguage == 'en'
          ? "Opening Campus Idol! Listen to real student voice auditions, record your voice, and turn chairs."
          : "Inafungua Campus Idol! Sikiliza sauti za wanafunzi, rekodi sauti yako na upige kura.";
    }
    // 23. Current Time
    else if (low.contains('time') || low.contains('saa ngapi') || low.contains('what time')) {
      intent = 'CHECK_TIME';
      final now = DateTime.now();
      final hourStr = now.hour > 12 ? '${now.hour - 12}' : (now.hour == 0 ? '12' : '${now.hour}');
      final amPm = now.hour >= 12 ? 'PM' : 'AM';
      final minStr = now.minute.toString().padLeft(2, '0');
      spoken = _currentLanguage == 'en'
          ? "The current time is $hourStr:$minStr $amPm, comrade."
          : "Sasa ni saa $hourStr na dakika $minStr $amPm, comrade.";
    }
    // 24. General AI Reply
    else {
      intent = 'GENERAL_QUERY';
      spoken = _currentLanguage == 'en'
          ? "I heard: $clean. I am your DISHI Voice AI, ready to help with orders, UniUptown, wallet, or cafeteria menus."
          : "Nimekusikia: $clean. Mimi ni DISHI Voice AI, niko tayari kukusaidia na maagizo, UniUptown, salio na mikahawa.";
    }

    currentIntentNotifier.value = intent;
    isProcessingNotifier.value = false;
    transcriptNotifier.value = '';

    await speak(spoken);
    _dispatchUniversalNavigation(intent, data);
  }

  /// Global route dispatcher: smoothly opens destination views via root Navigator
  void _dispatchUniversalNavigation(String intent, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    final userMap = _resolveUserMap();
    final userModel = _resolveUserModel();

    switch (intent) {
      case 'OPEN_UNIUPTOWN':
        nav.push(MaterialPageRoute(builder: (_) => const MatchHubView()));
        break;

      case 'START_SWIPING':
        nav.push(MaterialPageRoute(builder: (_) => const MatchDiscoveryView()));
        break;

      case 'OPEN_MATCHES_CHATS':
        nav.push(MaterialPageRoute(builder: (_) => const MatchMatchesHub()));
        break;

      case 'OPEN_PREORDERS':
        nav.push(MaterialPageRoute(builder: (_) => const StudentPreordersView()));
        break;

      case 'OPEN_SUPERMARKET':
      case 'DISCOVER_MEALS':
        nav.push(MaterialPageRoute(builder: (_) => const CampusSupermarketView()));
        break;

      case 'CAMPUS_GIGS':
        nav.push(MaterialPageRoute(builder: (_) => const CampusEmploymentHubView()));
        break;

      case 'QUERY_BALANCE':
        nav.push(MaterialPageRoute(builder: (_) => const StudentLedgerView()));
        break;

      case 'SPLIT_BILL':
        nav.push(MaterialPageRoute(builder: (_) => SplitBillView(userModel: userModel)));
        break;

      case 'OKOA_MEAL':
        nav.push(MaterialPageRoute(builder: (_) => const OkoaFoodView()));
        break;

      case 'OPEN_CAMPUS_MAP':
        nav.push(MaterialPageRoute(builder: (_) => CampusMapView(studentUid: userMap['uid'] as String)));
        break;

      case 'OPEN_HOUSING':
        nav.push(MaterialPageRoute(builder: (_) => HousingDashboardView(user: userMap)));
        break;

      case 'OPEN_STUDY_TIMER':
        nav.push(MaterialPageRoute(builder: (_) => const DailyFocusView()));
        break;

      case 'REQUEST_PARENT_FUNDS':
        nav.push(MaterialPageRoute(builder: (_) => const RequestFundsView()));
        break;

      case 'OPEN_VENDOR_POS':
        nav.push(MaterialPageRoute(builder: (_) => VendorDashboardView(user: userMap)));
        break;

      case 'OPEN_KDS':
      case 'NAVIGATE_KDS':
        nav.push(MaterialPageRoute(builder: (_) => const VendorKdsView()));
        break;

      case 'OPEN_VENDOR_INVENTORY':
        nav.push(MaterialPageRoute(builder: (_) => const InventoryDashboardView()));
        break;

      case 'OPEN_VENDOR_ANALYTICS':
      case 'NAVIGATE_REPORTS':
        nav.push(MaterialPageRoute(builder: (_) => const VendorReportsView()));
        break;

      case 'OPEN_VENDOR_PAYOUTS':
        nav.push(MaterialPageRoute(builder: (_) => const PayoutHubView()));
        break;

      case 'OPEN_CAMPUS_IDOL':
        nav.push(MaterialPageRoute(builder: (_) => const MatchCampusIdolView()));
        break;

      case 'OPEN_PARENT_ALLOWANCE':
      case 'OPEN_PARENT_DIET':
      case 'OPEN_PARENT_STATEMENTS':
        nav.push(MaterialPageRoute(builder: (_) => ParentDashboardView(user: userMap)));
        break;

      case 'QUERY_PARENT_DEPENDANTS':
        if (data['queryType'] == 'location' && data['students'] != null && (data['students'] as List).isNotEmpty) {
          final firstStudent = (data['students'] as List).first as Map<String, dynamic>;
          nav.push(
            MaterialPageRoute(
              builder: (_) => ParentLiveTrackingView(
                studentUid: firstStudent['uid'] as String,
                studentName: firstStudent['name'] as String,
              ),
            ),
          );
        }
        break;

      case 'SHOW_STUDENT_QR':
        final ovContext = appNavigatorKey.currentState?.overlay?.context;
        if (ovContext != null && ovContext.mounted) {
          showDialog(
            context: ovContext,
            builder: (_) => DynamicQrDialog(
              dishiId: _userUid ?? 'DISHI_USER',
              purpose: 'meal_pass',
            ),
          );
        }
        break;

      default:
        break;
    }
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
}
