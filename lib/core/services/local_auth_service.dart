import '../security/biometric_engine.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as flutter_secure_storage;

/// A UI-facing service for invoking Biometric Authentication.
/// Wraps the underlying BiometricEngine which handles the deep offline security gating.
class LocalAuthService {
  /// Checks if biometrics are available on the hardware
  static Future<bool> isAvailable() async {
    return await BiometricEngine.isBiometricAvailable();
  }

  /// Prompts the user to authenticate via Fingerprint or FaceID.
  /// Used in the UI (e.g. before viewing the Savings Vault or transferring money).
  static Future<bool> authenticate(String localizedReason) async {
    return await BiometricEngine.authenticate(localizedReason: localizedReason);
  }

  static Future<bool> hasBiometricsEnabled() async {
    return await isAvailable();
  }

  static Future<bool> authenticateWithBiometrics() async {
    return await authenticate("Please authenticate to proceed.");
  }

  static Future<bool> authenticateOffline(String email, String password) async {
    // Mock implementation for offline authentication
    return true; 
  }

  static Future<String?> getOfflineUid() async {
    // Implement offline UID retrieval from secure storage
    const storage = flutter_secure_storage.FlutterSecureStorage();
    return await storage.read(key: 'offline_uid');
  }

  static Future<String> generateAndStoreOfflinePin(String offlineUid) async {
    const storage = flutter_secure_storage.FlutterSecureStorage();
    await storage.write(key: 'offline_uid', value: offlineUid);
    final String generatedPin = "1234"; // Defaulting or you can accept pin from UI
    await storage.write(key: 'offline_pin', value: generatedPin);
    return generatedPin;
  }

  static Future<void> cacheOfflineCredentials(String email, String password, String name) async {
    // Mock implementation
  }
}
