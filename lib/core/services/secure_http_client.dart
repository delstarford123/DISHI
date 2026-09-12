import 'dart:convert';
import 'dart:async';
import 'dart:io';
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

  static Future<http.Response> _handleRequest(Future<http.Response> Function() requestFunc) async {
    try {
      return await requestFunc().timeout(_timeout);
    } on TimeoutException {
      throw Exception("Request timed out. Please check your connection.");
    } on SocketException {
      throw Exception("You are offline. Data will sync when you reconnect.");
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response> get(String url) async {
    final headers = await _getHeaders();
    return _handleRequest(() => http.get(Uri.parse(url), headers: headers));
  }

  static Future<http.Response> post(String url, {required Map<String, dynamic> body}) async {
    final headers = await _getHeaders();
    return _handleRequest(() => http.post(Uri.parse(url), headers: headers, body: jsonEncode(body)));
  }

  static Future<http.Response> put(String url, {required Map<String, dynamic> body}) async {
    final headers = await _getHeaders();
    return _handleRequest(() => http.put(Uri.parse(url), headers: headers, body: jsonEncode(body)));
  }

  static Future<http.Response> delete(String url) async {
    final headers = await _getHeaders();
    return _handleRequest(() => http.delete(Uri.parse(url), headers: headers));
  }
}
