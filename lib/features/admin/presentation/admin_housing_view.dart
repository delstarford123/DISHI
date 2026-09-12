import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminHousingView extends StatefulWidget {
  const AdminHousingView({super.key});

  @override
  State<AdminHousingView> createState() => _AdminHousingViewState();
}

class _AdminHousingViewState extends State<AdminHousingView> {
  Future<void> _handleAction(String propertyId, String action) async {
    try {
      if (action == 'approve') {
        await AdminService().approveHousing(propertyId);
      } else {
        await AdminService().rejectHousing(propertyId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Property \${action}d successfully')));
        setState(() {}); // refresh the FutureBuilder
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Housing Oversight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: AdminService().getPendingHousing(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading properties: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
          }

          final properties = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pending Approvals', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (properties.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonCyan,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        try {
                          await AdminService().approveAllHousing();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All properties approved')));
                            setState(() {});
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve All', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (properties.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No pending housing approvals', style: TextStyle(color: _textSecondary)),
                )),
              ...properties.map((p) => _buildPropertyCard(
                p['id'] ?? '',
                p['name'] ?? 'Unknown Property', 
                p['location'] ?? 'Unknown Location', 
                p['status'] ?? 'pending'
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPropertyCard(String id, String name, String location, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(location, style: const TextStyle(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
                  onPressed: () => _handleAction(id, 'approve'),
                  child: const Text('Approve', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonRed)),
                  onPressed: () => _handleAction(id, 'reject'),
                  child: const Text('Reject', style: TextStyle(color: _neonRed)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
