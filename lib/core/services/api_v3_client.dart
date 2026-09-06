import 'dart:convert';
import 'package:http/http.dart' as http;
import '../security/secure_storage_service.dart';

/// Dedicated client for the v3 namespace in the Python Flask backend.
/// Primarily used for the SmartI (Academic Study Companion) features.
class ApiV3Client {
  static const String _baseUrl = 'https://dishi.delstarfordworks.co.ke/api/v3';
  static const Duration _timeout = Duration(seconds: 15);

  static Future<Map<String, String>> _getHeaders() async {
    final token = await SecureStorageService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer \$token',
    };
  }

  /// Fetches AI Study Advice from the Groq NLP engine on the backend.
  static Future<String?> getStudyAdvice(Map<String, dynamic> performanceData) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('\$_baseUrl/smarti/advice'),
            headers: headers,
            body: jsonEncode(performanceData),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['advice'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Syncs SmartI results/targets to the v3 backend.
  static Future<bool> syncAcademicProfile(Map<String, dynamic> profileData) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('\$_baseUrl/smarti/sync_profile'),
            headers: headers,
            body: jsonEncode(profileData),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
