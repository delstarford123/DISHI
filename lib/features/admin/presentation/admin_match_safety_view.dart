import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminMatchSafetyView extends StatefulWidget {
  const AdminMatchSafetyView({super.key});

  @override
  State<AdminMatchSafetyView> createState() => _AdminMatchSafetyViewState();
}

class _AdminMatchSafetyViewState extends State<AdminMatchSafetyView> {
  final AdminService _adminService = AdminService();

  Future<void> _handleEmergencyAction(String alertId, String targetUid, String actionType) async {
    try {
      if (actionType == 'security') {
        await _adminService.dispatchSecurity(alertId);
      } else if (actionType == 'driver') {
        await _adminService.dispatchEmergencyDriver(alertId);
      } else if (actionType == 'safe_house') {
        await _adminService.issueSafeHouseVoucher(targetUid);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dispatched $actionType successfully'), backgroundColor: _neonCyan));
        setState(() {}); // refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Match Safety Response', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _adminService.getLiveSOSAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonRed));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
          }

          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield, color: _neonCyan, size: 48),
                  SizedBox(height: 16),
                  Text('All Clear. No active SOS alerts.', style: TextStyle(color: _textSecondary, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return _buildSOSCard(alert);
            },
          );
        },
      ),
    );
  }

  Widget _buildSOSCard(Map<String, dynamic> alert) {
    final alertId = alert['id'];
    final userId = alert['user_id'] ?? 'Unknown';
    final location = alert['location'] ?? 'Location not provided';
    final timestamp = alert['timestamp'] ?? 'Unknown time';
    
    final bool securityDispatched = alert['security_dispatched'] ?? false;
    final bool driverDispatched = alert['driver_dispatched'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonRed, width: 2),
        boxShadow: [BoxShadow(color: _neonRed.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: _neonRed),
                  SizedBox(width: 8),
                  Text('SOS ALERT', style: TextStyle(color: _neonRed, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
                ],
              ),
              Text(timestamp.toString().substring(0, 16), style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text('User ID: $userId', style: const TextStyle(color: Colors.white, fontSize: 14)),
          Text('Location: $location', style: const TextStyle(color: _neonOrange, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Dispatch Units:', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: securityDispatched ? _surfaceLight : _neonRed, foregroundColor: Colors.white),
                  onPressed: securityDispatched ? null : () => _handleEmergencyAction(alertId, userId, 'security'),
                  icon: const Icon(Icons.local_police, size: 16),
                  label: Text(securityDispatched ? 'Security Sent' : 'Campus Security'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: driverDispatched ? _surfaceLight : Colors.blue, foregroundColor: Colors.white),
                  onPressed: driverDispatched ? null : () => _handleEmergencyAction(alertId, userId, 'driver'),
                  icon: const Icon(Icons.directions_car, size: 16),
                  label: Text(driverDispatched ? 'Driver Sent' : 'Evac Driver'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: () => _handleEmergencyAction(alertId, userId, 'safe_house'),
              icon: const Icon(Icons.house, size: 16),
              label: const Text('Issue Safe-House Voucher'),
            ),
          )
        ],
      ),
    );
  }
}
