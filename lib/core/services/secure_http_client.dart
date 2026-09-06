import 'dart:convert';
import 'package:http/http.dart' as http;
import '../security/secure_storage_service.dart';

class SecureHttpClient {
  static const Duration _timeout = Duration(seconds: 30);

  /// Automatically attaches the secure Auth Token to every request.
  static Future<Map<String, String>> _getHeaders() async {
    final token = await SecureStorageService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer \$token',
    };
  }

  static Future<http.Response> get(String url) async {
    final headers = await _getHeaders();
    return await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
  }

  static Future<http.Response> post(String url, {required Map<String, dynamic> body}) async {
    final headers = await _getHeaders();
    return await http
        .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
  }

  static Future<http.Response> put(String url, {required Map<String, dynamic> body}) async {
    final headers = await _getHeaders();
    return await http
        .put(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
  }

  static Future<http.Response> delete(String url) async {
    final headers = await _getHeaders();
    return await http.delete(Uri.parse(url), headers: headers).timeout(_timeout);
  }
}
