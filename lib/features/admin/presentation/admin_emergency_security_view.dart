import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/widgets/high_friction_action.dart';
import 'fraud_velocity_view.dart';

// -- CUSTOM EXECUTIVE THEME COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminEmergencySecurityView extends StatefulWidget {
  const AdminEmergencySecurityView({super.key});

  @override
  State<AdminEmergencySecurityView> createState() => _AdminEmergencySecurityViewState();
}

class _AdminEmergencySecurityViewState extends State<AdminEmergencySecurityView> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _statusData;
  String _selectedLogFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchSecurityStatus();
  }

  Future<void> _fetchSecurityStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await _adminService.getSecurityStatus();
      if (mounted) {
        setState(() {
          _statusData = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _executeEmergencyProtocol(String action, String label, {String? reason}) async {
    try {
      await _adminService.triggerEmergencyAction(action, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Protocol "$label" successfully activated'), backgroundColor: _neonCyan),
        );
        _fetchSecurityStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Emergency Action Error: $e'), backgroundColor: _neonRed),
        );
      }
    }
  }

  void _showLockdownConfirmDialog() {
    final TextEditingController reasonController = TextEditingController(text: 'System emergency protocol initiated');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonRed, width: 2)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _neonRed),
            SizedBox(width: 8),
            Expanded(child: Text('Confirm System Lockdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activating System Lockdown immediately puts the app in maintenance mode for all non-admins, freezes withdrawals, and halts ordering.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Reason for Lockdown',
                labelStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonRed),
            onPressed: () {
              Navigator.pop(context);
              _executeEmergencyProtocol('LOCKDOWN', 'System Lockdown', reason: reasonController.text.trim());
            },
            child: const Text('ENGAGE LOCKDOWN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMaintenance = _statusData?['maintenance_mode'] == true;
    final bool isPayoutsFrozen = _statusData?['payouts_frozen'] == true;
    final bool isOrderingPaused = _statusData?['ordering_paused'] == true;
    final String threatLevel = _statusData?['threat_level'] ?? 'NORMAL';
    final int flaggedCount = _statusData?['flagged_count'] ?? 0;
    final List<dynamic> recentLogs = (_statusData?['recent_logs'] as List<dynamic>?) ?? [];

    final filteredLogs = recentLogs.where((log) {
      if (_selectedLogFilter == 'ALL') return true;
      final action = (log['action'] ?? '').toString().toUpperCase();
      if (_selectedLogFilter == 'EMERGENCY') return action.contains('EMERGENCY') || action.contains('LOCKDOWN');
      if (_selectedLogFilter == 'USER') return action.contains('USER') || action.contains('ROLE') || action.contains('PIN');
      if (_selectedLogFilter == 'FINANCIAL') return action.contains('PAYOUT') || action.contains('CREDIT') || action.contains('BALANCE');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Security & Circuit Breakers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            tooltip: 'Refresh Status',
            onPressed: _fetchSecurityStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  color: _neonCyan,
                  backgroundColor: _cardColor,
                  onRefresh: _fetchSecurityStatus,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Threat Gauge
                      _buildThreatGauge(threatLevel, isMaintenance, isPayoutsFrozen, flaggedCount),
                      const SizedBox(height: 24),

                      // Circuit Breakers
                      const Text('Emergency Circuit Breakers', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('High-level kill switches to isolate services during critical incidents', style: TextStyle(color: _textSecondary, fontSize: 12)),
                      const SizedBox(height: 12),

                      // Global Lockdown Switch
                      _buildBreakerCard(
                        title: 'Platform Lockdown Mode',
                        description: isMaintenance ? 'Active: All non-admin requests are blocked' : 'Normal: Platform is live for students & vendors',
                        isActive: isMaintenance,
                        activeColor: _neonRed,
                        icon: Icons.shield,
                        actionButton: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMaintenance ? _neonCyan : _neonRed,
                            foregroundColor: isMaintenance ? Colors.black : Colors.white,
                          ),
                          onPressed: () {
                            if (isMaintenance) {
                              _executeEmergencyProtocol('RESTORE', 'Platform Restored');
                            } else {
                              _showLockdownConfirmDialog();
                            }
                          },
                          child: Text(isMaintenance ? 'Restore Normal Ops' : 'Engage Lockdown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // M-PESA Payouts Breaker
                      _buildBreakerCard(
                        title: 'M-PESA Payouts Circuit Breaker',
                        description: isPayoutsFrozen ? 'FROZEN: Automated B2C vendor disbursements stopped' : 'ACTIVE: Withdrawals & vendor payouts proceeding normally',
                        isActive: isPayoutsFrozen,
                        activeColor: _neonOrange,
                        icon: Icons.payments,
                        actionButton: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPayoutsFrozen ? _neonCyan : _neonOrange,
                            foregroundColor: isPayoutsFrozen ? Colors.black : Colors.white,
                          ),
                          onPressed: () {
                            _executeEmergencyProtocol(isPayoutsFrozen ? 'UNFREEZE_PAYOUTS' : 'FREEZE_PAYOUTS', isPayoutsFrozen ? 'Payouts Unfrozen' : 'Payouts Frozen');
                          },
                          child: Text(isPayoutsFrozen ? 'Unfreeze Payouts' : 'Freeze Payouts', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Food Ordering Breaker
                      _buildBreakerCard(
                        title: 'Campus Food Ordering Breaker',
                        description: isOrderingPaused ? 'PAUSED: Ordering checkout disabled during curfew/emergency' : 'ACTIVE: Cafeteria & vendor orders operational',
                        isActive: isOrderingPaused,
                        activeColor: Colors.amberAccent,
                        icon: Icons.restaurant,
                        actionButton: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOrderingPaused ? _neonCyan : Colors.amber.shade700,
                            foregroundColor: isOrderingPaused ? Colors.black : Colors.white,
                          ),
                          onPressed: () {
                            _executeEmergencyProtocol(isOrderingPaused ? 'RESUME_ORDERS' : 'PAUSE_ORDERS', isOrderingPaused ? 'Ordering Resumed' : 'Ordering Paused');
                          },
                          child: Text(isOrderingPaused ? 'Resume Orders' : 'Pause Orders', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Velocity & Wash Trading
                      InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const FraudVelocityView()));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: flaggedCount > 0 ? _neonRed : _surfaceLight),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _neonRed.withOpacity(0.15), shape: BoxShape.circle),
                                child: const Icon(Icons.radar_rounded, color: _neonRed, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Fraud & Velocity Threat Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text('$flaggedCount suspicious transactions or wash-trading flags pending review', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Security Audit Log Stream
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Security Audit Trail', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${filteredLogs.length} Events', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['ALL', 'EMERGENCY', 'USER', 'FINANCIAL'].map((filter) {
                            final isSel = _selectedLogFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(filter, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                selected: isSel,
                                selectedColor: _neonCyan,
                                backgroundColor: _surfaceLight,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedLogFilter = filter);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (filteredLogs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                          child: const Text('No matching security events found.', style: TextStyle(color: _textSecondary)),
                        )
                      else
                        ...filteredLogs.map((log) => _buildLogCard(log)),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildThreatGauge(String threatLevel, bool isMaintenance, bool isPayoutsFrozen, int flaggedCount) {
    Color gaugeColor = _neonCyan;
    IconData gaugeIcon = Icons.verified_user_rounded;
    if (threatLevel == 'CRITICAL' || isMaintenance) {
      gaugeColor = _neonRed;
      gaugeIcon = Icons.warning_rounded;
    } else if (threatLevel == 'ELEVATED' || isPayoutsFrozen || flaggedCount > 0) {
      gaugeColor = _neonOrange;
      gaugeIcon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gaugeColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: gaugeColor.withOpacity(0.1), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: gaugeColor.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(gaugeIcon, color: gaugeColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('THREAT DEFENSE: ', style: TextStyle(color: _textSecondary, fontSize: 12)),
                    Text(threatLevel, style: TextStyle(color: gaugeColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isMaintenance ? 'SYSTEM IS UNDER LOCKDOWN' : (isPayoutsFrozen ? 'PAYOUT SAFEGUARDS ACTIVE' : 'ALL CORE SYSTEMS ONLINE'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Audit tracking enabled • Token signature verification enforced',
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakerCard({
    required String title,
    required String description,
    required bool isActive,
    required Color activeColor,
    required IconData icon,
    required Widget actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? activeColor : _surfaceLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (isActive ? activeColor : _neonCyan).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: isActive ? activeColor : _neonCyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(description, style: TextStyle(color: isActive ? activeColor : _textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: actionButton),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = log['action'] ?? 'Unknown';
    final adminId = log['admin_id'] ?? 'SYSTEM';
    final timestamp = log['timestamp']?.toString() ?? '';
    final details = log['details']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  action,
                  style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                timestamp.length > 16 ? timestamp.substring(0, 16) : timestamp,
                style: const TextStyle(color: _textSecondary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Admin UID: $adminId', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(details, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _neonRed, size: 54),
            const SizedBox(height: 16),
            const Text('Security Status Error', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Failed to retrieve security configuration', style: const TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: _fetchSecurityStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
