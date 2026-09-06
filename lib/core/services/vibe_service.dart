import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class VibeService {
  Future<void> sendVibe({
    required String senderId,
    required String receiverId,
    bool isSuper = false,
    bool isSecret = false,
    String icebreaker = '',
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/vibe/send');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'senderId': senderId,
        'receiverId': receiverId,
        'isSuper': isSuper,
        'isSecret': isSecret,
        'icebreaker': icebreaker,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to send vibe');
    }
  }

  Future<void> respondToVibe({
    required String vibeId,
    required String action, // 'accept' or 'reject'
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/vibe/respond');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'vibeId': vibeId,
        'action': action,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to process vibe');
    }
  }
}
