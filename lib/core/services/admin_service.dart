import 'dart:convert';
import 'dart:async';
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

  static String _parseError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded.containsKey('error')) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  Future<void> suspendUser(String userId, String reason) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users/$userId/suspend');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'reason': reason}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to suspend user'));
    }
  }

  Future<void> deleteUser(String userId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users/$userId/delete');
    final response = await http.delete(
      url,
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to delete user'));
    }
  }

  Future<void> overrideEvent(String eventId, bool makeFree) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/events/$eventId/override');
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
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/platform/maintenance');
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
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users/$userId/impersonate');
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
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/disputes/$disputeId/resolve');
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
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/settings/commission');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get commission rate: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return (data['platform_commission'] as num).toDouble();
  }

  Future<void> updateCommissionRate(double rate) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/settings/commission');
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
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/harambee/$campaignId/force_action');
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
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/payouts/force_trigger');
    final response = await http.post(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to trigger payout: ${response.body}');
    }
  }

  Future<List<dynamic>> getFraudFlags() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/fraud_flags');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get fraud flags: ${response.body}');
    }
    
    final data = jsonDecode(response.body);
    return data['flags'] as List<dynamic>;
  }

  Future<List<dynamic>> getAuditLogs() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/audit_logs');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get audit logs: ${response.body}');
    }
    
    final data = jsonDecode(response.body);
    return data['logs'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getSystemAnalytics() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/analytics/system_overview');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch analytics: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPendingHousing() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/housing/pending');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch housing: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return data['properties'] as List<dynamic>;
  }

  Future<void> approveHousing(String propertyId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/housing/$propertyId/approve');
    final response = await http.post(url, headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> rejectHousing(String propertyId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/housing/$propertyId/reject');
    final response = await http.post(url, headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> sendBroadcastNotification(String title, String message, {String? targetUserId}) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/notifications/broadcast');
    
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
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/housing/approve_all');
    final response = await http.post(url, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to bulk approve housing: ${response.body}');
    }
  }

  Future<List<dynamic>> getRichTransactions() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/transactions/rich');
    final response = await http.get(url, headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch rich transactions: ${response.body}');
    }
    
    final data = jsonDecode(response.body);
    return data['transactions'] as List<dynamic>;
  }

  // ==========================================
  // PHASE 5: COMMAND CENTER APIs
  // ==========================================

  // 1. Financial Ops
  Future<List<dynamic>> getFailedPayouts() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/payouts/failed'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['payouts'];
  }

  Future<void> retryFailedPayout(String txId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/payouts/retry/$txId'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<Map<String, dynamic>> getEscrowSummary() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/escrow/summary'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body);
  }

  // 2. Helpdesk
  Future<List<dynamic>> getActiveTickets() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/tickets/active'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['tickets'];
  }

  Future<void> closeTicket(String ticketId, String resolution) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/tickets/$ticketId/close'), headers: headers, body: jsonEncode({'resolution': resolution}));
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> refundGigTicket(String requestId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/tickets/gig/refund'), headers: headers, body: jsonEncode({'request_id': requestId}));
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> suspendGigWorker(String workerId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/tickets/gig/suspend_worker'), headers: headers, body: jsonEncode({'worker_id': workerId}));
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // 3. Moderation
  Future<List<dynamic>> getModerationIncidents() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/moderation/incidents'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['incidents'];
  }

  Future<void> resolveIncident(String incidentId, String action) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/moderation/action'), headers: headers, body: jsonEncode({'incident_id': incidentId, 'action': action}));
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // 4. Config & Feature Flags
  Future<Map<String, dynamic>> getSystemConfig() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/config'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['feature_flags'];
  }

  Future<void> toggleConfig(String flagId, bool enabled) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/config/toggle'), headers: headers, body: jsonEncode({'flag_id': flagId, 'enabled': enabled}));
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // 5. Onboarding
  Future<List<dynamic>> getPendingOnboarding() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/onboarding/pending'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['onboarding'];
  }

  Future<void> approveOnboarding(String userType, String userId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/onboarding/$userType/$userId/approve'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // ==========================================
  // PHASE 6: SECURITY & SAFETY CENTER
  // ==========================================

  // A. Delivery Security
  Future<List<dynamic>> getDeliveryDrivers() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/delivery/drivers'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['drivers'];
  }

  Future<void> verifyDriver(String userId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/delivery/driver/$userId/verify'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> suspendDriver(String userId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/delivery/driver/$userId/suspend'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<List<dynamic>> getActiveRides() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/delivery/active_rides'), headers: headers);
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
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v5/admin/emergency/sos?admin_id=${user.uid}'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['alerts'];
  }

  Future<void> dispatchSecurity(String alertId) async {
    final headers = await _getHeaders();
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final body = jsonEncode({'admin_id': user.uid, 'alert_id': alertId});
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v5/admin/emergency/dispatch_security'), headers: headers, body: body);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> dispatchEmergencyDriver(String alertId) async {
    final headers = await _getHeaders();
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final body = jsonEncode({'admin_id': user.uid, 'alert_id': alertId});
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v5/admin/emergency/dispatch_driver'), headers: headers, body: body);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> issueSafeHouseVoucher(String targetUid) async {
    final headers = await _getHeaders();
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final body = jsonEncode({'admin_id': user.uid, 'target_uid': targetUid});
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v5/admin/emergency/safe_house'), headers: headers, body: body);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // C. Manual Dispatch
  Future<List<dynamic>> getOnlineDrivers() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/delivery/online_drivers'), headers: headers);
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['drivers'];
  }

  Future<void> manualDispatchDelivery(String requestId, String driverId) async {
    final headers = await _getHeaders();
    final body = jsonEncode({'request_id': requestId, 'driver_id': driverId});
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/delivery/manual_dispatch'), headers: headers, body: body);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  Future<void> notifyDeliveryParty(String targetId, String title, String message) async {
    final headers = await _getHeaders();
    final body = jsonEncode({'target_id': targetId, 'title': title, 'message': message});
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/delivery/notify_party'), headers: headers, body: body);
    if (response.statusCode != 200) throw Exception(response.body);
  }

  // D. General Admin Dashboard Stats
  Future<Map<String, dynamic>> getSystemOverview() async {
    final headers = await _getHeaders();
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/analytics/dashboard_stats'), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to load system stats'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAllUsers() async {
    final headers = await _getHeaders();
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users/all'), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to fetch users'));
    }
    return jsonDecode(response.body)['users'] as List<dynamic>;
  }

  // ==========================================
  // PHASE 7: POWER ADMIN & SECURITY CONTROLS
  // ==========================================

  Future<void> unsuspendUser(String userId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users/$userId/unsuspend');
    final response = await http
        .post(url, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to unsuspend user'));
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users/$userId/role');
    final response = await http
        .post(url, headers: headers, body: jsonEncode({'role': role}))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to update user role'));
    }
  }

  Future<void> resetUserPin(String userId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users/$userId/reset_pin');
    final response = await http
        .post(url, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to reset user PIN'));
    }
  }

  Future<double> adjustUserBalance(String userId, double amount, String reason) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users/$userId/adjust_balance');
    final response = await http
        .post(url, headers: headers, body: jsonEncode({'amount': amount, 'reason': reason}))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to adjust user balance'));
    }
    final data = jsonDecode(response.body);
    return (data['new_balance'] as num).toDouble();
  }

  Future<Map<String, dynamic>> getDatabaseHealth() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/database/health');
    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to fetch database health metrics'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> triggerEmergencyAction(String action, {String? reason}) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/security/emergency_action');
    final response = await http
        .post(url, headers: headers, body: jsonEncode({'action': action, 'reason': reason ?? 'Admin emergency command'}))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to execute emergency protocol'));
    }
  }

  Future<Map<String, dynamic>> getSecurityStatus() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/security/status');
    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to load security status'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> queryMpesaTransaction(String query) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/mpesa/query_transaction');
    final response = await http
        .post(url, headers: headers, body: jsonEncode({'query': query}))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to query M-PESA record'));
    }
    final data = jsonDecode(response.body);
    return data['results'] as List<dynamic>;
  }

  Future<void> manualCreditMpesa({
    String? checkoutId,
    required String userId,
    required double amount,
    required String receipt,
    String? reason,
  }) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/mpesa/manual_credit');
    final body = jsonEncode({
      if (checkoutId != null && checkoutId.isNotEmpty) 'checkout_id': checkoutId,
      'user_id': userId,
      'amount': amount,
      'receipt': receipt,
      'reason': reason ?? 'Admin manual reconciliation',
    });
    final response = await http
        .post(url, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to manually credit M-PESA transaction'));
    }
  }

  // ==========================================
  // PHASE 8: EMPLOYEE MANAGEMENT & PAYROLL (B2C, B2B, C2B)
  // ==========================================

  Future<List<dynamic>> getEmployees() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/employees');
    final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to fetch employees'));
    }
    return jsonDecode(response.body)['employees'] as List<dynamic>;
  }

  Future<String> addEmployee(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/employees');
    final response = await http.post(url, headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 30));

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to add employee'));
    }
    return jsonDecode(response.body)['id'] as String;
  }

  Future<void> updateEmployee(String empId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/employees/$empId');
    final response = await http.post(url, headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to update employee'));
    }
  }

  Future<void> toggleEmployeeStatus(String empId, String status) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/employees/$empId/status');
    final response = await http.post(url, headers: headers, body: jsonEncode({'status': status})).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to update employee status'));
    }
  }

  Future<Map<String, dynamic>> getPayrollSummary() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/payroll/summary');
    final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to fetch payroll summary'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> disburseSalaryB2C({
    required String employeeId,
    String? month,
    double bonus = 0.0,
    double advanceDeduction = 0.0,
    String? notes,
  }) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/payroll/disburse/b2c');
    final body = jsonEncode({
      'employee_id': employeeId,
      'month': month,
      'bonus': bonus,
      'advance_deduction': advanceDeduction,
      'notes': notes,
    });
    final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to disburse salary via B2C'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bulkDisbursePayroll({String? department, String? month}) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/payroll/bulk_disburse');
    final body = jsonEncode({
      if (department != null) 'department': department,
      if (month != null) 'month': month,
    });
    final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to execute bulk payroll run'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPayrollSlips() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/payroll/slips');
    final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to fetch payroll history'));
    }
    return jsonDecode(response.body)['slips'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> executeB2BPayment({
    required String recipientName,
    required String recipientType,
    required String destinationNumber,
    required double amount,
    String? accountRef,
    String? purpose,
  }) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/finance/b2b_payment');
    final body = jsonEncode({
      'recipient_name': recipientName,
      'recipient_type': recipientType,
      'destination_number': destinationNumber,
      'amount': amount,
      'account_reference': accountRef ?? 'DISHI-B2B',
      'purpose': purpose ?? 'Merchant/Supplier Payout',
    });
    final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to execute B2B transfer'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getB2BTransfers() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/finance/b2b_transfers');
    final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to fetch B2B transfers'));
    }
    return jsonDecode(response.body)['transfers'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getC2BOverview() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/finance/c2b_overview');
    final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to fetch C2B collections'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ==========================================
  // PHASE 9: DEPARTMENT & ROLE COMPENSATION MANAGEMENT
  // ==========================================

  Future<List<dynamic>> getDepartments() async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/departments');
    final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to fetch departments'));
    }
    return jsonDecode(response.body)['departments'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createDepartment({
    required String name,
    required String code,
    String? description,
    double budget = 0.0,
    List<Map<String, dynamic>>? roles,
  }) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/departments');
    final body = jsonEncode({
      'name': name,
      'code': code,
      'description': description ?? '',
      'budget': budget,
      'roles': roles ?? [],
    });
    final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to create department'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateDepartment(String deptId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/departments/$deptId');
    final response = await http.post(url, headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to update department'));
    }
  }

  Future<void> deleteDepartment(String deptId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/departments/$deptId');
    final response = await http.delete(url, headers: headers).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to delete department'));
    }
  }

  Future<Map<String, dynamic>> updateEmployeeCompensation({
    required String employeeId,
    required String role,
    required String department,
    required double baseSalary,
    String salaryType = 'MONTHLY',
    double? shifDeduction,
    double? nssfDeduction,
    double? housingLevy,
  }) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/employees/$employeeId/compensation');
    final body = jsonEncode({
      'role': role,
      'department': department,
      'base_salary': baseSalary,
      'salary_type': salaryType,
      if (shifDeduction != null) 'shif_deduction': shifDeduction,
      if (nssfDeduction != null) 'nssf_deduction': nssfDeduction,
      if (housingLevy != null) 'housing_levy': housingLevy,
    });
    final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to update compensation'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
