import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../services/api_config.dart';
import '../services/secure_http_client.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFF92B60);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

/// Available AI Voice Personas for "Sema na DISHI"
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
    id: 'zawadi',
    name: 'Zawadi (Chuo Lead)',
    title: 'Lady • Warm & Friendly (Default)',
    description: 'Sauti changamfu na ya upendo ya dada wa chuo.',
    defaultPitch: 1.25,
    defaultRate: 0.52,
    isFemale: true,
    icon: Icons.face_3,
    themeColor: _neonCyan,
  ),
  VoicePersona(
    id: 'amina',
    name: 'Amina (Finance & POS)',
    title: 'Lady • Crisp & Executive',
    description: 'Sauti rasmi, safi na ya haraka ya biashara na fedha.',
    defaultPitch: 1.15,
    defaultRate: 0.58,
    isFemale: true,
    icon: Icons.support_agent,
    themeColor: _neonPink,
  ),
  VoicePersona(
    id: 'baraka',
    name: 'Baraka (Mentor)',
    title: 'Gentleman • Deep Baritone',
    description: 'Sauti tulivu ya kaka mshauri na mlezi wa chuo.',
    defaultPitch: 0.85,
    defaultRate: 0.50,
    isFemale: false,
    icon: Icons.record_voice_over,
    themeColor: _neonOrange,
  ),
  VoicePersona(
    id: 'juma',
    name: 'Juma (Comrade)',
    title: 'Gentleman • Sheng & Street-Smart',
    description: 'Sauti ya comrade wa kitaa, Sheng na uchangamfu wa chuo.',
    defaultPitch: 0.95,
    defaultRate: 0.55,
    isFemale: false,
    icon: Icons.sports_kabaddi,
    themeColor: Colors.purpleAccent,
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
    showModalBottomSheet(
      context: context,
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
  String _assistantSpeech = 'Ninakusikiliza... Taja agizo, uliza salio, au sema amri yoyote.';
  String? _detectedIntent;
  bool _requiresPin = false;
  String? _challengeCode;

  // Voice Persona and Audio Settings (Default is African Lady Voice: Zawadi)
  VoicePersona _selectedPersona = kVoicePersonas[0];
  double _pitch = 1.25;
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

    _initAudioAndPreferences();
  }

  Future<void> _initAudioAndPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPersonaId = prefs.getString('sema_dishi_voice_persona') ?? 'zawadi';
      final persona = kVoicePersonas.firstWhere(
        (p) => p.id == savedPersonaId,
        orElse: () => kVoicePersonas[0],
      );

      final savedPitch = prefs.getDouble('sema_dishi_voice_pitch') ?? persona.defaultPitch;
      final savedRate = prefs.getDouble('sema_dishi_voice_rate') ?? persona.defaultRate;

      if (mounted) {
        setState(() {
          _selectedPersona = persona;
          _pitch = savedPitch;
          _speechRate = savedRate;
        });
      }

      await _applyTtsSettings();
    } catch (_) {
      await _applyTtsSettings();
    }

    // Auto-start listening on modal presentation
    _startListening();
  }

  Future<void> _applyTtsSettings() async {
    try {
      await _flutterTts.setLanguage("sw-KE"); // Prefer Kenyan Swahili
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_speechRate);

      // Inspect hardware device voices to pick female voice by default if available
      final dynamic rawVoices = await _flutterTts.getVoices;
      if (rawVoices is List) {
        for (var v in rawVoices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? '').toString().toLowerCase();

            if (_selectedPersona.isFemale) {
              if (name.contains('female') || name.contains('f0') || (locale.contains('ke') && name.contains('female'))) {
                await _flutterTts.setVoice({
                  'name': v['name'],
                  'locale': v['locale'],
                });
                break;
              }
            } else {
              if (name.contains('male') || name.contains('m0')) {
                await _flutterTts.setVoice({
                  'name': v['name'],
                  'locale': v['locale'],
                });
                break;
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sema_dishi_voice_persona', _selectedPersona.id);
      await prefs.setDouble('sema_dishi_voice_pitch', _pitch);
      await prefs.setDouble('sema_dishi_voice_rate', _speechRate);
    } catch (_) {}
  }

  Future<void> _speakResponse(String message) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.speak(message);
    } catch (_) {}
  }

  Future<void> _startListening() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _recognizedWords = '';
      _assistantSpeech = 'Ninakusikiliza (${_selectedPersona.name.split(' ')[0]})...';
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
          ),
        );
      } else {
        setState(() {
          _isListening = false;
          _assistantSpeech = 'Maikrofoni haipatikani. Tumia kisanduku cha maandishi hapa chini.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _assistantSpeech = 'Hitilafu ya sauti. Unaweza kuandika amri yako hapa chini.';
        });
      }
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _processSpokenText(String input) async {
    final clean = input.trim();
    if (clean.isEmpty) return;

    HapticFeedback.selectionClick();
    await _stopListening();
    setState(() {
      _isProcessing = true;
      _assistantSpeech = 'Inachakata: "$clean"...';
    });

    try {
      final resp = await SecureHttpClient.post(
        ApiConfig.v6VoiceIntent,
        body: {
          'text': clean,
          'role': widget.role,
          'uid': widget.userUid ?? '',
        },
      );

      if (resp.statusCode == 403) {
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
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final intent = data['intent'] ?? 'GENERAL';
        final spoken = data['spoken_response'] ?? 'Sawa rafiki yangu.';
        final reqPin = data['requires_pin'] ?? false;
        final challenge = data['challenge_code'] as String?;
        final progressSteps = (data['progress_steps'] as List?)?.cast<String>() ?? [];

        // Interactive execution & progress updates
        if (progressSteps.isNotEmpty && mounted) {
          for (final step in progressSteps) {
            if (!mounted) break;
            setState(() {
              _assistantSpeech = step;
            });
            await Future.delayed(const Duration(milliseconds: 650));
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

          // If intent is dismissal, pop automatically after brief pause
          if (intent == 'DISMISS_VOICE') {
            await Future.delayed(const Duration(milliseconds: 1400));
            if (mounted) Navigator.pop(context);
            return;
          }

          // If action callback passed, notify parent view
          if (widget.onAction != null) {
            widget.onAction!(intent, data);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _assistantSpeech = 'Samahani, sijapata mtandao vizuri. Tafadhali jaribu tena.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _assistantSpeech = 'Hitilafu ya mtandao: $e';
        });
      }
    }
  }

  /// Voice Persona Switcher & Audio Tuner Modal
  void _openVoiceSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, color: _neonCyan, size: 22),
                      SizedBox(width: 8),
                      Text('Voice Personas & Tuner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _textSecondary),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),
              const Text('Chagua Sauti ya DISHI (Lady Voice by Default):', style: TextStyle(color: _textSecondary, fontSize: 12)),
              const SizedBox(height: 14),

              // 4 Persona Selection Cards
              ...kVoicePersonas.map((persona) {
                final isSelected = persona.id == _selectedPersona.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? persona.themeColor.withValues(alpha: 0.12) : _surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? persona.themeColor : Colors.white10,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: persona.themeColor.withValues(alpha: 0.2),
                      child: Icon(persona.icon, color: persona.themeColor),
                    ),
                    title: Row(
                      children: [
                        Text(persona.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        if (persona.isFemale) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _neonCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Lady', style: TextStyle(color: _neonCyan, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        if (persona.id == 'zawadi') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _neonOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Default', style: TextStyle(color: _neonOrange, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(persona.description, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                    trailing: isSelected ? Icon(Icons.check_circle, color: persona.themeColor) : null,
                    onTap: () {
                      setSheetState(() {
                        _selectedPersona = persona;
                        _pitch = persona.defaultPitch;
                        _speechRate = persona.defaultRate;
                      });
                      setState(() {
                        _selectedPersona = persona;
                        _pitch = persona.defaultPitch;
                        _speechRate = persona.defaultRate;
                      });
                      _applyTtsSettings();
                      _savePreferences();
                    },
                  ),
                );
              }),

              const SizedBox(height: 12),
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
                  label: Text('Jaribu Sauti: ${_selectedPersona.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    _speakResponse("Hujambo comrade! Mimi ni ${_selectedPersona.name.split(' ')[0]}, msaidizi wako wa sauti wa DISHI.");
                  },
                ),
              ),

              const SizedBox(height: 16),
              // Pitch Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mwangwi wa Sauti (Pitch):', style: TextStyle(color: Colors.white, fontSize: 12)),
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
                  const Text('Kasi ya Maongezi (Speed):', style: TextStyle(color: Colors.white, fontSize: 12)),
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
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Sema na DISHI',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedPersona.themeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _selectedPersona.name.split(' ')[0],
                              style: TextStyle(color: _selectedPersona.themeColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Voice AI • ${_selectedPersona.title}',
                        style: const TextStyle(color: _textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune, color: _neonCyan, size: 22),
                    tooltip: 'Badili Sauti (Voice Settings)',
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

          // Multi-Bar Frequency Soundwave Equalizer (When Listening)
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

          // Central Pulsing Microphone Animation
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
                ? 'Ninakusikiliza... Sema sasa'
                : (_isProcessing ? 'Inachakata agizo lako...' : 'Gusa maikrofoni kuongea'),
            style: TextStyle(
              color: _isListening ? _selectedPersona.themeColor : _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Transcribed Text Container
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

          // Security Challenge Prompt (if needed)
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
                      'Uthibitisho wa Usalama: Taja nambari $_challengeCode au weka PIN yako.',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Role-Adaptive Fast Speech Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _getPromptChipsForRole(),
            ),
          ),
          const SizedBox(height: 16),

          // Text Fallback Field (for quiet or noisy locations)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textFallbackController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.role == 'student'
                        ? 'Au andika (mf. Nitatoboa wiki hii?)...'
                        : 'Au andika hapa (mf. Fungua jiko)...',
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
    if (widget.role == 'student') {
      return [
        _buildPromptChip('Nitatoboa wiki hii?'),
        _buildPromptChip('Nipe pass yangu ya QR'),
        _buildPromptChip('Omba mzazi Ksh 500'),
        _buildPromptChip('Okoa chakula'),
        _buildPromptChip('Kuna hustle gani leo?'),
        _buildPromptChip('Gawanya bili ya 400'),
        _buildPromptChip('Class yangu inayofuata?'),
        _buildPromptChip('Weka chapati mbili madondo'),
        _buildPromptChip('Fungua kadi ya VCC'),
        _buildPromptChip('Fungua supermarket'),
      ];
    } else if (widget.role == 'parent') {
      return [
        _buildPromptChip('Mtumie mwanafunzi Ksh 500'),
        _buildPromptChip('Angalia ripoti ya lishe'),
        _buildPromptChip('Salio la vault ni ngapi?'),
        _buildPromptChip('Angalia mtoto yuko wapi'),
      ];
    } else {
      return [
        _buildPromptChip('Weka chapati mbili madondo'),
        _buildPromptChip('Fungua jiko (KDS)'),
        _buildPromptChip('Nimebaki na float ngapi?'),
        _buildPromptChip('Tiketi 12 iko tayari'),
        _buildPromptChip('Toa Ksh 1,000 kwa M-Pesa'),
        _buildPromptChip('Fungua ripoti za mauzo'),
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
