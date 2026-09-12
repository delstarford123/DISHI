import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

class SecurityService {
  /// Checks if the device is rooted or jailbroken
  static Future<bool> isDeviceCompromised() async {
    try {
      bool jailbroken = await FlutterJailbreakDetection.jailbroken;
      bool developerMode = await FlutterJailbreakDetection.developerMode;
      return jailbroken || (Platform.isAndroid && developerMode);
    } catch (e) {
      return false; // Fail open if detection fails, or fail closed in strict environments
    }
  }

  /// Cryptographically hashes a PIN using SHA-256 and a standard salt
  static String hashPin(String pin) {
    const salt = "DISHI_SECURE_SALT_2026"; // In a real app, salt should be unique per user or stored securely
    var bytes = utf8.encode(pin + salt);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
