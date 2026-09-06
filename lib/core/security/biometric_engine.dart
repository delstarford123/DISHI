import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class BiometricEngine {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device has biometric hardware and it is enrolled.
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Prompts the user for biometric authentication.
  /// Used specifically as a "Biometric Gate" before accessing secure storage for offline syncs.
  static Future<bool> authenticate({required String localizedReason}) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric Gate',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: false, // Fallback to PIN/Pattern if needed
          stickyAuth: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
