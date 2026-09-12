import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminModerationView extends StatefulWidget {
  const AdminModerationView({super.key});

  @override
  State<AdminModerationView> createState() => _AdminModerationViewState();
}

class _AdminModerationViewState extends State<AdminModerationView> {
  final AdminService _adminService = AdminService();

  Future<void> _handleAction(String incidentId, String action) async {
    try {
      await _adminService.resolveIncident(incidentId, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action "$action" applied')));
        setState(() {}); // refresh list
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
        title: const Text('Content & Community Moderation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _adminService.getModerationIncidents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
          }

          final incidents = snapshot.data ?? [];
          if (incidents.isEmpty) {
            return const Center(child: Text('Queue is clear! No pending reports.', style: TextStyle(color: _neonCyan, fontSize: 16)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: incidents.length,
            itemBuilder: (context, index) {
              final incident = incidents[index];
              return _buildIncidentCard(incident);
            },
          );
        },
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final type = incident['type'] ?? 'Report';
    final targetId = incident['target_id'] ?? 'Unknown';
    final reporterId = incident['reporter_id'] ?? 'Unknown';
    final reason = incident['reason'] ?? 'No reason provided';
    final details = incident['details'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonRed.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type.toString().toUpperCase(), style: const TextStyle(color: _neonRed, fontWeight: FontWeight.bold, fontSize: 12)),
              Text('ID: ${incident['id']?.toString().substring(0, 8)}', style: const TextStyle(color: _textSecondary, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Text(reason, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(details, style: const TextStyle(color: _textSecondary, fontSize: 14)),
          ],
          const SizedBox(height: 12),
          Text('Reported User/Post: $targetId', style: const TextStyle(color: _textSecondary, fontSize: 12)),
          Text('Reported By: $reporterId', style: const TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _surfaceLight, foregroundColor: Colors.white),
                  onPressed: () => _handleAction(incident['id'], 'dismiss'),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () => _handleAction(incident['id'], 'warn_user'),
                  child: const Text('Warn User'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonRed, foregroundColor: Colors.white),
                  onPressed: () => _handleAction(incident['id'], 'delete_post'),
                  child: const Text('Delete Content'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonRed, foregroundColor: Colors.white),
                  onPressed: () => _handleAction(incident['id'], 'shadow_ban'),
                  child: const Text('Shadow Ban'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
