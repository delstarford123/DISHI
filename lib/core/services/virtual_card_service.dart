import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_config.dart';

class VirtualCardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getCardDetails(String uid) async {
    final doc = await _firestore.collection('virtual_cards').doc(uid).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  Future<Map<String, dynamic>> generateCard(String uid) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/card/generate');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['card'];
    } else {
      final err = jsonDecode(response.body)['error'] ?? 'Failed to generate card';
      throw Exception(err);
    }
  }

  Future<void> updateStatus(String uid, String status) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/card/update_status');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid, 'status': status}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body)['error'] ?? 'Failed to update status';
      throw Exception(err);
    }
  }

  Future<void> updateLimit(String uid, double limit) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/card/update_limit');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid, 'limit': limit}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body)['error'] ?? 'Failed to update limit';
      throw Exception(err);
    }
  }

  Future<Map<String, dynamic>> payLocalMerchant(String uid, double amount, String merchantId, String merchantName) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/card/pay');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': uid,
        'amount': amount,
        'merchantId': merchantId,
        'merchantName': merchantName,
        'category': 'Local Vendor'
      }),
    ).timeout(const Duration(seconds: 30));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Payment failed');
    }
  }
}
