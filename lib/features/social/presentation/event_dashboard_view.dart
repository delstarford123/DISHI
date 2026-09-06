import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class EventDashboardView extends StatelessWidget {
  final Map<String, dynamic> user;

  const EventDashboardView({super.key, required this.user});

  void _copyShareLink(BuildContext context, String eventId) {
    // URL matching the Python backend route we created
    final url = 'https://dishi.delstarfordworks.co.ke/event?id=$eventId';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share Link Copied! Try pasting in WhatsApp to see the rich preview.'))
    );
  }

  void _scanTicket(BuildContext context, String eventId) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF131A2A),
      title: const Text('Scan QR Ticket', style: TextStyle(color: Colors.white)),
      content: Container(
        height: 200, width: 200,
        decoration: BoxDecoration(border: Border.all(color: MPesaTheme.neonCyan, width: 2), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Icon(Icons.qr_code_scanner, color: MPesaTheme.neonCyan, size: 64)),
      ),
      actions: [
        TextButton(onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket Validated Successfully!'), backgroundColor: MPesaTheme.primaryGreen));
        }, child: const Text('Simulate Scan', style: TextStyle(color: MPesaTheme.neonCyan)))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final userId = user['dishiId'] ?? user['uid'];

    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('My Events Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('creatorId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'You haven\'t created any events yet.',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final event = docs[index].data() as Map<String, dynamic>;
              final eventId = event['id'];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event['imageUrl'] != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          event['imageUrl'],
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event['title'] ?? 'Untitled Event', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetric('Tickets Sold', '${event['ticketsSold'] ?? 0}'),
                              _buildMetric('Revenue', 'KES ${event['revenue'] ?? 0}'),
                              _buildMetric('Views', '${event['views'] ?? 0}'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ticket Breakdown (Phase 6)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Early Bird: ${event['earlyBirdSold'] ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    Text('Regular: ${event['regularSold'] ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    Text('VIP: ${event['vipSold'] ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonCyan, padding: const EdgeInsets.symmetric(vertical: 12)),
                                  onPressed: () => _scanTicket(context, eventId),
                                  icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
                                  label: const Text('Scan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: MPesaTheme.neonCyan), padding: const EdgeInsets.symmetric(vertical: 12)),
                                  onPressed: () => _copyShareLink(context, eventId),
                                  icon: const Icon(Icons.share, color: MPesaTheme.neonCyan),
                                  label: const Text('Share Link', style: TextStyle(color: MPesaTheme.neonCyan)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: MPesaTheme.neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
