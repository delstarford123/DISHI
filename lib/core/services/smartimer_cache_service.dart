import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Provides zero-dependency, instant offline cache loads for the SmartI Academic Study Companion.
class SmartimerCacheService {
  static const String _fileName = 'smartimer_cache.json';

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('\${dir.path}/\$_fileName');
  }

  /// Saves the student's study timetable, targets, and stats locally for instant offline access.
  static Future<void> saveCache(Map<String, dynamic> data) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(data));
  }

  /// Loads the cached study data instantly without waiting for a network request.
  static Future<Map<String, dynamic>?> loadCache() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;

      final String contents = await file.readAsString();
      if (contents.isEmpty) return null;

      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Clears the local SmartI cache (e.g. upon user logout).
  static Future<void> clearCache() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
