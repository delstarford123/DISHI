import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  
  static const String _keyToken = 'auth_token';
  static const String _keyPin = 'hashed_pin';
  static const String _keyUserId = 'user_id';
  static const String _keyRole = 'user_role';
  static const String _keyName = 'user_name';
  static const String _keyEmail = 'user_email';
  static const String _keyPhone = 'user_phone';

  // --- Auth Token ---
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  // --- Hashed PIN (for local verification) ---
  static Future<void> saveHashedPin(String pin) async {
    await _storage.write(key: _keyPin, value: pin);
  }

  static Future<String?> getHashedPin() async {
    return await _storage.read(key: _keyPin);
  }

  static Future<void> deleteHashedPin() async {
    await _storage.delete(key: _keyPin);
  }

  // --- User Metadata ---
  // --- User Metadata ---
  static Future<void> saveUserData({
    required String userId, 
    required String role,
    String? name,
    String? email,
    String? phone,
  }) async {
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyRole, value: role);
    if (name != null) await _storage.write(key: _keyName, value: name);
    if (email != null) await _storage.write(key: _keyEmail, value: email);
    if (phone != null) await _storage.write(key: _keyPhone, value: phone);
  }

  static Future<Map<String, String?>> getUserData() async {
    final userId = await _storage.read(key: _keyUserId);
    final role = await _storage.read(key: _keyRole);
    final name = await _storage.read(key: _keyName);
    final email = await _storage.read(key: _keyEmail);
    final phone = await _storage.read(key: _keyPhone);
    return {
      'userId': userId, 
      'role': role,
      'name': name,
      'email': email,
      'phone': phone,
    };
  }

  // --- Clear All (Logout) ---
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
