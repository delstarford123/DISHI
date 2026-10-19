import 'dart:convert';
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

  static const String _keyPreferredAuthMethod = 'preferred_auth_method';
  static const String _keyBiometricEnabled = 'biometric_enabled';

  // --- Preferred Auth Method ('biometric' or 'pin') ---
  static Future<void> setPreferredAuthMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPreferredAuthMethod, method);
    await _storage.write(key: _keyPreferredAuthMethod, value: method);
  }

  static Future<String> getPreferredAuthMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_keyPreferredAuthMethod);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final stored = await _storage.read(key: _keyPreferredAuthMethod);
    if (stored != null && stored.isNotEmpty) {
      await prefs.setString(_keyPreferredAuthMethod, stored);
      return stored;
    }
    return 'pin';
  }

  static Future<bool> hasPreferredAuthMethod() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyPreferredAuthMethod)) return true;
    final stored = await _storage.read(key: _keyPreferredAuthMethod);
    return stored != null && stored.isNotEmpty;
  }

  // --- Biometric Enabled Toggle ---
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyBiometricEnabled)) {
      return prefs.getBool(_keyBiometricEnabled) ?? true;
    }
    final val = await _storage.read(key: _keyBiometricEnabled);
    if (val != null) {
      final enabled = val == 'true';
      await prefs.setBool(_keyBiometricEnabled, enabled);
      return enabled;
    }
    return true;
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

  // --- Offline PIN ---
  static const String _keyOfflinePin = 'offline_pin';

  static Future<void> saveOfflinePin(String pin) async {
    await _storage.write(key: _keyOfflinePin, value: pin);
  }

  static Future<String?> getOfflinePin() async {
    final offline = await _storage.read(key: _keyOfflinePin);
    if (offline != null && offline.isNotEmpty) return offline;
    return await getHashedPin();
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

  // --- Admin Ghost Mode Session Management ---
  static const String _keyIsGhostSession = 'is_ghost_session';
  static const String _keyGhostAdminReturnToken = 'ghost_admin_return_token';
  static const String _keyGhostAdminUid = 'ghost_admin_uid';
  static const String _keyGhostAdminEmail = 'ghost_admin_email';
  static const String _keyGhostAdminName = 'ghost_admin_name';
  static const String _keyGhostAdminUserJson = 'ghost_admin_user_json';

  static Future<void> startGhostSession({
    required String adminUid,
    required String adminEmail,
    String? adminName,
    String? adminReturnToken,
    Map<String, dynamic>? adminUserMap,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGhostSession, true);
    await _storage.write(key: _keyIsGhostSession, value: 'true');
    await _storage.write(key: _keyGhostAdminUid, value: adminUid);
    await _storage.write(key: _keyGhostAdminEmail, value: adminEmail);
    if (adminName != null) {
      await _storage.write(key: _keyGhostAdminName, value: adminName);
    }
    if (adminReturnToken != null) {
      await _storage.write(key: _keyGhostAdminReturnToken, value: adminReturnToken);
    }
    if (adminUserMap != null) {
      await _storage.write(key: _keyGhostAdminUserJson, value: jsonEncode(adminUserMap));
    }
  }

  static Future<bool> isGhostSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsGhostSession) ?? false;
  }

  static Future<String?> getGhostAdminReturnToken() async {
    return await _storage.read(key: _keyGhostAdminReturnToken);
  }

  static Future<String?> getGhostAdminEmail() async {
    return await _storage.read(key: _keyGhostAdminEmail);
  }

  static Future<Map<String, dynamic>?> getGhostAdminUserMap() async {
    final raw = await _storage.read(key: _keyGhostAdminUserJson);
    if (raw != null && raw.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }
    final uid = await _storage.read(key: _keyGhostAdminUid);
    final email = await _storage.read(key: _keyGhostAdminEmail);
    final name = await _storage.read(key: _keyGhostAdminName);
    if (uid != null) {
      return {
        'uid': uid,
        'email': email ?? 'dishi@delstarfordworks.co.ke',
        'name': name ?? 'Super Admin',
        'roles': ['admin'],
        'role': 'admin',
      };
    }
    return null;
  }

  static Future<void> endGhostSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGhostSession, false);
    await prefs.setString('fast_role', 'admin');

    final adminUid = await _storage.read(key: _keyGhostAdminUid);
    final adminEmail = await _storage.read(key: _keyGhostAdminEmail);
    final adminName = await _storage.read(key: _keyGhostAdminName);

    await _storage.delete(key: _keyIsGhostSession);
    await _storage.delete(key: _keyGhostAdminReturnToken);
    await _storage.delete(key: _keyGhostAdminUserJson);

    if (adminUid != null) {
      await saveUserData(
        userId: adminUid,
        role: 'admin',
        name: adminName ?? 'Super Admin',
        email: adminEmail ?? 'dishi@delstarfordworks.co.ke',
      );
    }
  }

  // --- Clear All (Logout) ---
  static Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
