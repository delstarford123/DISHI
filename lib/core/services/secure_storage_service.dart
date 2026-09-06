import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  
  static Future<void> saveOfflinePin(String pin) async {
    await _storage.write(key: 'offline_pin', value: pin);
  }
  
  static Future<String?> getOfflinePin() async {
    return await _storage.read(key: 'offline_pin');
  }
}
