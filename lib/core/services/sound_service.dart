import 'package:flutter_tts/flutter_tts.dart';
// import 'package:audioplayers/audioplayers.dart'; // For sound effects like NFC tap

class SoundService {
  static final FlutterTts _flutterTts = FlutterTts();
  // static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> initialize() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  /// Speaks a phrase using Text-to-Speech.
  /// Used for the SmartI Pomodoro Timer (e.g., "Halfway there, keep focusing!").
  static Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  static Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  /// Plays a success chime (e.g. for a successful NFC POS tap)
  static Future<void> playSuccessChime() async {
    // await _audioPlayer.play(AssetSource('sounds/success.mp3'));
  }

  /// Plays an error buzzer (e.g. invalid PIN or Insufficient Funds)
  static Future<void> playErrorChime() async {
    // await _audioPlayer.play(AssetSource('sounds/error.mp3'));
  }
}
