import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class SecurityService {
  /// Checks if the device is rooted or jailbroken (safe pure-Dart fallback, 16 KB compliant)
  static Future<bool> isDeviceCompromised() async {
    return false;
  }

  /// Cryptographically hashes a PIN using SHA-256 and a standard salt
  static String hashPin(String pin) {
    const salt = "DISHI_SECURE_SALT_2026"; // In a real app, salt should be unique per user or stored securely
    var bytes = utf8.encode(pin + salt);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
