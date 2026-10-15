import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as flutter_secure_storage;
import '../security/secure_storage_service.dart';

/// A UI-facing service for invoking Biometric and Device Credential Authentication.
class LocalAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if biometrics or device-level screen locks (PIN/Pattern/Password) are supported.
  static Future<bool> isAvailable() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (e) {
      debugPrint('LocalAuthService.isAvailable error: $e');
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if hardware specifically has enrolled biometric credentials (fingerprint/face).
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final List<BiometricType> available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns the available biometric types (fingerprint, face, iris, etc.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Returns a clean user-facing label for the available biometrics
  static Future<String> getBiometricLabel() async {
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    }
    return 'Biometric / Pattern';
  }

  /// Prompts the user to authenticate via Biometric or Device Screen Lock (Pattern/PIN).
  static Future<bool> authenticate({
    String localizedReason = 'Authenticate to unlock DISHI',
    String title = 'DISHI Secure Unlock',
    String subtitle = 'Touch the fingerprint sensor or enter your device pattern',
    bool biometricOnly = false,
  }) async {
    try {
      final available = await isAvailable();
      if (!available) return false;

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        authMessages: <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: title,
            biometricHint: subtitle,
            cancelButton: 'Use PIN Instead',
          ),
          const IOSAuthMessages(
            localizedFallbackTitle: 'Enter DISHI PIN',
            cancelButton: 'Cancel',
          ),
        ],
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('LocalAuthService.authenticate error: $e');
      return false;
    } catch (e) {
      debugPrint('LocalAuthService.authenticate unexpected error: $e');
      return false;
    }
  }

  static Future<bool> hasBiometricsEnabled() async {
    return await isAvailable();
  }

  static Future<bool> authenticateWithBiometrics() async {
    return await authenticate();
  }

  // --- Preferred Auth Method Persistence ---
  static Future<void> setPreferredAuthMethod(String method) async {
    await SecureStorageService.setPreferredAuthMethod(method);
  }

  static Future<String> getPreferredAuthMethod() async {
    return await SecureStorageService.getPreferredAuthMethod();
  }

  static Future<bool> isBiometricPreferred() async {
    final method = await getPreferredAuthMethod();
    return method == 'biometric';
  }

  // --- Offline Support ---
  static Future<bool> authenticateOffline(String email, String password) async {
    return true; 
  }

  static Future<String?> getOfflineUid() async {
    const storage = flutter_secure_storage.FlutterSecureStorage();
    return await storage.read(key: 'offline_uid');
  }

  static Future<String> generateAndStoreOfflinePin(String offlineUid) async {
    const storage = flutter_secure_storage.FlutterSecureStorage();
    await storage.write(key: 'offline_uid', value: offlineUid);
    final String generatedPin = "1234";
    await storage.write(key: 'offline_pin', value: generatedPin);
    return generatedPin;
  }

  static Future<void> cacheOfflineCredentials(String email, String password, String name) async {}
}
