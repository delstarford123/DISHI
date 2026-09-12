import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRateLimiter {
  static const int maxAttempts = 4;
  static const Duration lockoutDuration = Duration(minutes: 5);

  static const String _keyAttempts = 'auth_failed_attempts';
  static const String _keyLockoutTime = 'auth_lockout_time';

  static Future<bool> isLockedOut() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTimeStr = prefs.getString(_keyLockoutTime);

    if (lockoutTimeStr != null) {
      final lockoutTime = DateTime.parse(lockoutTimeStr);
      if (DateTime.now().isBefore(lockoutTime)) {
        return true;
      } else {
        // Lockout expired, reset attempts
        await prefs.remove(_keyAttempts);
        await prefs.remove(_keyLockoutTime);
        return false;
      }
    }
    return false;
  }

  static Future<Duration?> getRemainingLockoutTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTimeStr = prefs.getString(_keyLockoutTime);

    if (lockoutTimeStr != null) {
      final lockoutTime = DateTime.parse(lockoutTimeStr);
      final now = DateTime.now();
      if (now.isBefore(lockoutTime)) {
        return lockoutTime.difference(now);
      }
    }
    return null;
  }

  static Future<void> recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    int attempts = prefs.getInt(_keyAttempts) ?? 0;
    attempts++;

    await prefs.setInt(_keyAttempts, attempts);

    if (attempts >= maxAttempts) {
      final lockoutTime = DateTime.now().add(lockoutDuration);
      await prefs.setString(_keyLockoutTime, lockoutTime.toIso8601String());
    }
  }

  static Future<void> resetAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAttempts);
    await prefs.remove(_keyLockoutTime);
  }
}
