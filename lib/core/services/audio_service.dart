import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();

  // Pre-configured sound paths based on assets/sounds/
  static const String _vaultAdded = 'sounds/Money added to shared vault or savings account.wav';
  static const String _purchaseSuccess = 'sounds/Student successfull purchase .wav';
  static const String _withdrawalOrLimit = 'sounds/Withdrawal sound or purchase limit reached.wav';
  static const String _chatNotification = 'sounds/chatornotification.wav';
  static const String _generalNotification = 'sounds/general notification.wav';
  static const String _purchaseLimitReached = 'sounds/student puchase limit reached.wav';
  static const String _videoCall = 'sounds/Videocall.wav';
  static const String _voiceCall = 'sounds/Voicecall.wav';

  /// Play a generic sound file from assets/sounds/
  Future<void> playSound(String path) async {
    try {
      await _sfxPlayer.play(AssetSource(path));
    } catch (e) {
      print("Error playing sound: $e");
    }
  }

  // Convenience methods for specific app events
  Future<void> playVaultAdded() => playSound(_vaultAdded);
  Future<void> playPurchaseSuccess() => playSound(_purchaseSuccess);
  Future<void> playPurchaseLimitReached() => playSound(_purchaseLimitReached);
  Future<void> playWithdrawal() => playSound(_withdrawalOrLimit);
  Future<void> playChatNotification() => playSound(_chatNotification);
  Future<void> playGeneralNotification() => playSound(_generalNotification);
  Future<void> playVideoCallRing() => playSound(_videoCall);
  Future<void> playVoiceCallRing() => playSound(_voiceCall);

  /// Start playing the ringtone in a loop until answered or ended
  Future<void> startRinging(bool isVideoCall) async {
    try {
      await _sfxPlayer.setReleaseMode(ReleaseMode.loop);
      await _sfxPlayer.play(AssetSource(isVideoCall ? _videoCall : _voiceCall));
    } catch (e) {
      print("Error starting ringtone: $e");
    }
  }

  /// Stop the ringing loop
  Future<void> stopRinging() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      print("Error stopping ringtone: $e");
    }
  }
}
