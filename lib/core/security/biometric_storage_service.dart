import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/foundation.dart';

class BiometricStorageService {
  static const String _storageKey = 'offline_pin_storage';

  static Future<BiometricStorageFile> _getStorageFile() async {
    return await BiometricStorage().getStorage(
      _storageKey,
      options: StorageFileInitOptions(
        authenticationRequired: true,
        authenticationValidityDurationSeconds: 10, // OS caches auth for 10s
      ),
    );
  }

  /// Checks if biometrics are supported on this device.
  static Future<bool> isSupported() async {
    final response = await BiometricStorage().canAuthenticate();
    return response == CanAuthenticateResponse.success;
  }

  /// Writes the hashed PIN to the Keystore. 
  /// The OS handles the biometric prompt cryptographically.
  static Future<void> saveBiometricKey(String hashedPin) async {
    try {
      final storage = await _getStorageFile();
      await storage.write(hashedPin);
    } catch (e) {
      debugPrint('Error writing to biometric storage: $e');
      rethrow;
    }
  }

  /// Reads the hashed PIN from the Keystore.
  /// The OS will display the BiometricPrompt as part of this cryptographic read.
  static Future<String?> readBiometricKey() async {
    try {
      final storage = await _getStorageFile();
      return await storage.read();
    } catch (e) {
      debugPrint('Error reading from biometric storage: $e');
      // If it throws KeyPermanentlyInvalidatedException or auth fails, we return null.
      return null;
    }
  }

  /// Deletes the cryptographic key from the storage.
  static Future<void> deleteBiometricKey() async {
    try {
      final storage = await _getStorageFile();
      await storage.delete();
    } catch (e) {
      debugPrint('Error deleting biometric storage: $e');
    }
  }
}
