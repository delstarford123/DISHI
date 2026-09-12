import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';

class AdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>> _getHeaders() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> suspendUser(String userId, String reason) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/users/$userId/suspend');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'reason': reason}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to suspend user: ${response.body}');
    }
  }

  Future<void> deleteUser(String userId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/users/$userId/delete');
    final response = await http.delete(
      url,
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete user: ${response.body}');
    }
  }

  Future<void> overrideEvent(String eventId, bool makeFree) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/events/$eventId/override');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'make_free': makeFree}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to override event: ${response.body}');
    }
  }

  Future<void> toggleMaintenanceMode(bool enable) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/platform/maintenance');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'enable': enable}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle maintenance mode: ${response.body}');
    }
  }

  Future<String> impersonateUser(String userId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/users/$userId/impersonate');
    final response = await http.post(
      url,
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get impersonation token: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['token'] as String;
  }

  Future<void> resolveDispute(String disputeId, String action) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/disputes/$disputeId/resolve');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'action': action}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resolve dispute: ${response.body}');
    }
  }

  Future<double> getCommissionRate() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/settings/commission');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get commission rate: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return (data['platform_commission'] as num).toDouble();
  }

  Future<void> updateCommissionRate(double rate) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/settings/commission');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'platform_commission': rate}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to update commission rate: ${response.body}');
    }
  }

  Future<void> forceHarambeeAction(String campaignId, String action) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/harambee/$campaignId/force_action');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'action': action}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to force Harambee action: ${response.body}');
    }
  }

  Future<void> triggerManualPayout() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/payouts/force_trigger');
    final response = await http.post(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to trigger payout: ${response.body}');
    }
  }

  Future<List<dynamic>> getFraudFlags() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/fraud_flags');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get fraud flags: ${response.body}');
    }
    
    final data = jsonDecode(response.body);
    return data['flags'] as List<dynamic>;
  }

  Future<List<dynamic>> getAuditLogs() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/audit_logs');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get audit logs: ${response.body}');
    }
    
    final data = jsonDecode(response.body);
    return data['logs'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getSystemAnalytics() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/analytics/system_overview');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch analytics: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPendingHousing() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/housing/pending');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch housing: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return data['properties'] as List<dynamic>;
  }

  Future<void> approveHousing(String propertyId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/housing/$propertyId/approve');
    final response = await http.post(url, headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> rejectHousing(String propertyId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/housing/$propertyId/reject');
    final response = await http.post(url, headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> sendBroadcastNotification(String title, String message, {String? targetUserId}) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/notifications/broadcast');
    
    final body = jsonEncode({
      'title': title,
      'message': message,
      if (targetUserId != null && targetUserId.isNotEmpty) 'targetUserId': targetUserId,
    });
    
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) {
      throw Exception('Failed to send notification: ${response.body}');
    }
  }

  Future<void> approveAllHousing() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/housing/approve_all');
    final response = await http.post(url, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to bulk approve housing: ${response.body}');
    }
  }

  Future<List<dynamic>> getRichTransactions() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/transactions/rich');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch rich transactions: ${response.body}');
    }
    
    final data = jsonDecode(response.body);
    return data['transactions'] as List<dynamic>;
  // ==========================================
  // PHASE 5: COMMAND CENTER APIs
  // ==========================================

  // 1. Financial Ops
  Future<List<dynamic>> getFailedPayouts() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/payouts/failed'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['payouts'];
  }

  Future<void> retryFailedPayout(String txId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/payouts/retry/$txId'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<Map<String, dynamic>> getEscrowSummary() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/escrow/summary'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body);
  }

  // 2. Helpdesk
  Future<List<dynamic>> getActiveTickets() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/tickets/active'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['tickets'];
  }

  Future<void> closeTicket(String ticketId, String resolution) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/tickets/$ticketId/close'), headers: headers, body: jsonEncode({'resolution': resolution}));
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // 3. Moderation
  Future<List<dynamic>> getModerationIncidents() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/moderation/incidents'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['incidents'];
  }

  Future<void> resolveIncident(String incidentId, String action) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/moderation/action'), headers: headers, body: jsonEncode({'incident_id': incidentId, 'action': action}));
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // 4. Config & Feature Flags
  Future<Map<String, dynamic>> getSystemConfig() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/config'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['feature_flags'];
  }

  Future<void> toggleConfig(String flagId, bool enabled) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/config/toggle'), headers: headers, body: jsonEncode({'flag_id': flagId, 'enabled': enabled}));
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // 5. Onboarding
  Future<List<dynamic>> getPendingOnboarding() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/onboarding/pending'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['onboarding'];
  }

  Future<void> approveOnboarding(String userType, String userId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/onboarding/$userType/$userId/approve'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // ==========================================
  // PHASE 6: SECURITY & SAFETY CENTER
  // ==========================================

  // A. Delivery Security
  Future<List<dynamic>> getDeliveryDrivers() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/delivery/drivers'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['drivers'];
  }

  Future<void> verifyDriver(String userId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/delivery/driver/$userId/verify'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> suspendDriver(String userId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/delivery/driver/$userId/suspend'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<List<dynamic>> getActiveRides() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/delivery/active_rides'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['rides'];
  }

  // B. Match Safety & SOS Response
  // Note: These map directly to v5/admin_advanced_routes.py endpoints
  Future<List<dynamic>> getLiveSOSAlerts() async {
    final headers = await _getHeaders();
    // Using current user's uid as admin_id query param
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/emergency/sos?admin_id=${user.uid}'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['alerts'];
  }

  Future<void> dispatchSecurity(String alertId) async {
    final headers = await _getHeaders();
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final body = jsonEncode({'admin_id': user.uid, 'alert_id': alertId});
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/emergency/dispatch_security'), headers: headers, body: body);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> dispatchEmergencyDriver(String alertId) async {
    final headers = await _getHeaders();
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final body = jsonEncode({'admin_id': user.uid, 'alert_id': alertId});
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/emergency/dispatch_driver'), headers: headers, body: body);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> issueSafeHouseVoucher(String targetUid) async {
    final headers = await _getHeaders();
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final body = jsonEncode({'admin_id': user.uid, 'target_uid': targetUid});
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/emergency/safe_house'), headers: headers, body: body);
    if (response.statusCode != 200) throw Exception(response.body);
  }
}
