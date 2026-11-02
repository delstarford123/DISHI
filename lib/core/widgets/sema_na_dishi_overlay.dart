import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import '../services/api_config.dart';
import '../services/secure_http_client.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class SemaNaDishiOverlay extends StatefulWidget {
  final String role; // 'vendor' | 'student' | 'parent'
  final String? userUid;
  final Function(String intent, Map<String, dynamic> data)? onAction;

  const SemaNaDishiOverlay({
    super.key,
    this.role = 'vendor',
    this.userUid,
    this.onAction,
  });

  static void show(
    BuildContext context, {
    String role = 'vendor',
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
  String _assistantSpeech = 'Ninakusikiliza... Taja agizo au amri ya sauti.';
  String? _detectedIntent;
  bool _requiresPin = false;
  String? _challengeCode;

  final TextEditingController _textFallbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startListening();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("sw-KE"); // Prefer Swahili / Kenyan English
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.85);
    } catch (_) {}
  }

  Future<void> _speakResponse(String message) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(message);
    } catch (_) {}
  }

  Future<void> _startListening() async {
    setState(() {
      _recognizedWords = '';
      _assistantSpeech = 'Ninakusikiliza...';
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
          _assistantSpeech = 'Hitilafu ya sauti. Unaweza kuandika hapa chini.';
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

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final intent = data['intent'] ?? 'GENERAL';
        final spoken = data['spoken_response'] ?? 'Sawa.';
        final reqPin = data['requires_pin'] ?? false;
        final challenge = data['challenge_code'] as String?;

        if (mounted) {
          setState(() {
            _detectedIntent = intent;
            _assistantSpeech = spoken;
            _requiresPin = reqPin;
            _challengeCode = challenge;
            _isProcessing = false;
          });

          _speakResponse(spoken);

          // If action callback passed, notify parent view
          if (widget.onAction != null) {
            widget.onAction!(intent, data);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _assistantSpeech = 'Samahani, jaribu tena.';
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
        border: Border.all(color: _neonCyan.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _neonCyan.withValues(alpha: 0.2),
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
                      color: _neonCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.record_voice_over, color: _neonCyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sema na DISHI',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Hands-Free Voice AI (Sheng & Swahili)',
                        style: TextStyle(color: _textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: _textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Central Pulsing Microphone / Soundwave Animation
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _isListening ? 1.0 + (_pulseController.value * 0.18) : 1.0;
              final glow = _isListening ? _neonCyan.withValues(alpha: 0.4 + (_pulseController.value * 0.3)) : Colors.transparent;

              return GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: Container(
                  width: 90 * scale,
                  height: 90 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_neonCyan, _neonOrange],
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
                            size: 40,
                          ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          Text(
            _isListening
                ? 'Ninakusikiliza... Sema sasa'
                : (_isProcessing ? 'Inachakata amri yako...' : 'Gusa maikrofoni kuongea tena'),
            style: TextStyle(
              color: _isListening ? _neonCyan : _textSecondary,
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
                    const Icon(Icons.volume_up, color: _neonCyan, size: 18),
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
                      color: _neonCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Intent: $_detectedIntent',
                      style: const TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // High Friction Voice PIN Security Challenge (if cash out or sensitive)
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
                      'Uthibitisho wa Usalama: Taja nambari $_challengeCode au weka PIN.',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Fast Voice Prompt Chips for Vendors
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPromptChip('Weka chapati mbili madondo'),
                _buildPromptChip('Fungua jiko (KDS)'),
                _buildPromptChip('Nimebaki na float ngapi?'),
                _buildPromptChip('Tiketi 12 iko tayari'),
                _buildPromptChip('Toa Ksh 1,000 kwa M-Pesa'),
                _buildPromptChip('Fungua ripoti za mauzo'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Text Fallback Field (for noisy kitchens)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textFallbackController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Au andika hapa (mf. Fungua jiko)...',
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
                style: IconButton.styleFrom(backgroundColor: _neonCyan),
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
