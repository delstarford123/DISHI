import 'package:flutter/foundation.dart';
import 'biometric_engine.dart';
import 'anti_tamper_engine.dart';
import 'secure_storage_service.dart';

class SecurityEngine {
  /// Entry point for the Offline Sync authorization.
  /// Enforces the rules defined in security.txt.
  static Future<bool> authorizeOfflineSync() async {
    // 1. Network Interception Check
    final isSecure = await AntiTamperEngine.isNetworkSecure();
    if (!isSecure) {
      debugPrint('SecurityEngine: Network interception or failure detected. Aborting sync.');
      return false;
    }

    // 2. Biometric Gate
    final hasBiometrics = await BiometricEngine.isBiometricAvailable();
    if (hasBiometrics) {
      final authenticated = await BiometricEngine.authenticate(
        localizedReason: 'Authenticate to securely sync offline data to DISHI',
      );
      if (!authenticated) {
        debugPrint('SecurityEngine: Biometric authentication failed. Aborting sync.');
        return false;
      }
    }

    return true; // Authorized to proceed
  }

  /// Aggressively cleans up sensitive local credentials post-sync.
  /// (Threat 1: Credential Theft)
  static Future<void> performPostSyncCleanup() async {
    await SecureStorageService.deleteHashedPin();
    // Also delete any stored plain text passwords if they exist during account creation
    debugPrint('SecurityEngine: Post-sync credential cleanup completed.');
  }
}
