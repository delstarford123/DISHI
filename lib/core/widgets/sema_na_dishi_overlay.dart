import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/dishi_voice_service.dart';
import '../services/dishi_voice_models.dart';
import '../../main.dart' show appNavigatorKey;
const Color _bgColor = Color(0xFF0C101B);

const Color _cardColor = Color(0xFF131A2A);

const Color _surfaceLight = Color(0xFF1A2235);

const Color _neonCyan = Color(0xFF05D5AA);

const Color _neonOrange = Color(0xFFFF6F00);

const Color _textSecondary = Color(0xFF8B9BB4);

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
  late AnimationController _pulseController;

  bool _isListening = false;
  bool _isProcessing = false;
  String _recognizedWords = '';
  String _assistantSpeech = 'Listening... Ask about vendors, menus, wallet balance, or split bills.';
  String? _detectedIntent;
  final bool _requiresPin = false;
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
    DishiVoiceService.instance.setRoleAndUid(
      role: widget.role,
      uid: widget.userUid,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _selectedPersona = DishiVoiceService.instance.selectedPersona;
    _currentLanguage = DishiVoiceService.instance.currentLanguage;
    _voiceGender = DishiVoiceService.instance.voiceGender;
    _isListening = DishiVoiceService.instance.isListeningNotifier.value;
    _isProcessing = DishiVoiceService.instance.isProcessingNotifier.value;
    _recognizedWords = DishiVoiceService.instance.transcriptNotifier.value;
    if (DishiVoiceService.instance.lastSpokenResponseNotifier.value.isNotEmpty) {
      _assistantSpeech = DishiVoiceService.instance.lastSpokenResponseNotifier.value;
    }

    DishiVoiceService.instance.transcriptNotifier.addListener(_onVoiceTranscript);
    DishiVoiceService.instance.isListeningNotifier.addListener(_onVoiceListening);
    DishiVoiceService.instance.isProcessingNotifier.addListener(_onVoiceProcessing);
    DishiVoiceService.instance.lastSpokenResponseNotifier.addListener(_onVoiceSpoken);
    DishiVoiceService.instance.currentIntentNotifier.addListener(_onVoiceIntent);

    DishiVoiceService.instance.activatePersistentVoice();
  }

  void _onVoiceTranscript() {
    if (mounted) {
      setState(() => _recognizedWords = DishiVoiceService.instance.transcriptNotifier.value);
    }
  }

  void _onVoiceListening() {
    if (mounted) {
      setState(() => _isListening = DishiVoiceService.instance.isListeningNotifier.value);
    }
  }

  void _onVoiceProcessing() {
    if (mounted) {
      setState(() => _isProcessing = DishiVoiceService.instance.isProcessingNotifier.value);
    }
  }

  void _onVoiceSpoken() {
    if (mounted && DishiVoiceService.instance.lastSpokenResponseNotifier.value.isNotEmpty) {
      setState(() => _assistantSpeech = DishiVoiceService.instance.lastSpokenResponseNotifier.value);
    }
  }

  void _onVoiceIntent() {
    final intent = DishiVoiceService.instance.currentIntentNotifier.value;
    if (intent != null && mounted) {
      setState(() => _detectedIntent = intent);
      if (widget.onAction != null) {
        widget.onAction!(intent, {'intent': intent});
      }
      if (intent == 'DISMISS_VOICE' || intent == 'THANK_YOU_DISHI') {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.pop(context);
        });
      } else if (intent != 'GENERAL_QUERY' && intent != 'HELLO_DISHI') {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  Future<void> _applyTtsSettings() async {}

  Future<void> _savePreferences() async {}

  Future<void> _speakResponse(String message) async {
    await DishiVoiceService.instance.speak(message);
  }

  Future<void> _startListening() async {
    HapticFeedback.mediumImpact();
    await DishiVoiceService.instance.activatePersistentVoice();
  }

  Future<void> _stopListening() async {
    await DishiVoiceService.instance.stopListening();
  }

  Future<void> _processSpokenText(String input) async {
    final clean = input.trim();
    if (clean.isEmpty) return;

    HapticFeedback.selectionClick();
    await _stopListening();
    if (mounted) {
      setState(() {
        _isProcessing = true;
        _recognizedWords = clean;
        _assistantSpeech = _currentLanguage == 'en'
            ? 'Processing: "$clean"...'
            : 'Inachakata: "$clean"...';
      });
    }

    try {
      await DishiVoiceService.instance.processVoiceCommand(clean);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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
                        await DishiVoiceService.instance.setVoiceGender('female');
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
                        await DishiVoiceService.instance.setVoiceGender('male');
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
                          await DishiVoiceService.instance.setVoicePersona(persona);
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

        onSelected: (val) async {
          if (val) {
            setSheetState(() => _currentLanguage = code);
            setState(() => _currentLanguage = code);
            await DishiVoiceService.instance.setLanguage(code);
          }
        },

      ),

    );

  }

  @override
  void dispose() {
    DishiVoiceService.instance.transcriptNotifier.removeListener(_onVoiceTranscript);
    DishiVoiceService.instance.isListeningNotifier.removeListener(_onVoiceListening);
    DishiVoiceService.instance.isProcessingNotifier.removeListener(_onVoiceProcessing);
    DishiVoiceService.instance.lastSpokenResponseNotifier.removeListener(_onVoiceSpoken);
    DishiVoiceService.instance.currentIntentNotifier.removeListener(_onVoiceIntent);

    _pulseController.dispose();
    _textFallbackController.dispose();

    // Ensure persistent listening remains active in background!
    DishiVoiceService.instance.ensureListeningInBackground();
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

