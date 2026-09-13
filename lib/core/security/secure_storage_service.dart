import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<void> saveHashedPin(String pin) async {
    await _storage.write(key: _keyPin, value: pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_pin', true);
  }

  static Future<String?> getHashedPin() async {
    return await _storage.read(key: _keyPin);
  }

  static Future<bool> hasPinFastCheck() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_pin') ?? false;
  }

  static Future<void> deleteHashedPin() async {
    await _storage.delete(key: _keyPin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_pin', false);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fast_role', role);

    final futures = <Future>[
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyRole, value: role),
    ];
    if (name != null) futures.add(_storage.write(key: _keyName, value: name));
    if (email != null) futures.add(_storage.write(key: _keyEmail, value: email));
    if (phone != null) futures.add(_storage.write(key: _keyPhone, value: phone));
    
    await Future.wait(futures);
  }

  static Future<String?> getRoleFastCheck() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fast_role');
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
