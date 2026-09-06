import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/secure_http_client.dart';
import '../services/api_config.dart';

class DepositHelper {
  /// Initiates an M-PESA STK Push via the Vercel Python Backend.
  /// Used for Wallet Top-ups, Vault Funding, and Vendor E-Float injections.
  static Future<bool> initiateStkPush({
    required String phoneNumber,
    required double amount,
    required String accountReference,
  }) async {
    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/mpesa/stk_push',
        body: {
          'phone_number': phoneNumber,
          'amount': amount,
          'account_reference': accountReference,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("STK Push Initiated: ${data['CheckoutRequestID']}");
        return true;
      } else {
        debugPrint('STK Push Failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error initiating STK Push: $e');
      return false;
    }
  }
}
