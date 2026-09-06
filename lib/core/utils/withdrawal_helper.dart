import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/secure_http_client.dart';
import '../services/api_config.dart';

class WithdrawalHelper {
  /// Initiates a B2C / B2B Payout from the Vercel Python Backend.
  /// Used for Drivers cashing out, Vendors withdrawing E-Float, and Parents withdrawing from the Vault.
  static Future<bool> initiateWithdrawal({
    required String targetNumber,
    required double amount,
    required String withdrawalType, // 'B2C' (Personal) or 'B2B' (Till/Paybill)
  }) async {
    try {
      final response = await SecureHttpClient.post(
        '\${ApiConfig.baseUrl}/api/mpesa/withdraw',
        body: {
          'target_number': targetNumber,
          'amount': amount,
          'type': withdrawalType,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("Withdrawal Initiated successfully: ${data['ConversationID']}");
        return true;
      } else {
        debugPrint("Withdrawal Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error initiating Withdrawal: $e");
      return false;
    }
  }
}
