import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class AdminSupportDashboard extends StatefulWidget {
  const AdminSupportDashboard({super.key});

  @override
  State<AdminSupportDashboard> createState() => _AdminSupportDashboardState();
}

class _AdminSupportDashboardState extends State<AdminSupportDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Admin Support Desk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('support_tickets').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No support tickets yet.', style: TextStyle(color: Colors.white70)));
          }

          final tickets = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final doc = tickets[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'open';
              
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Role: ${data['user_role']}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'resolved' ? Colors.grey : Colors.orangeAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('User ID: ${data['user_id']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 12),
                      Text(data['message'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      if (data['reply'] != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admin Reply:', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(data['reply'], style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        )
                      ],
                      const SizedBox(height: 16),
                      if (status != 'resolved')
                        ElevatedButton(
                          onPressed: () => _showReplyDialog(doc.id, data['user_id']),
                          style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                          child: const Text('Reply & Resolve', style: TextStyle(color: Colors.white)),
                        )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showReplyDialog(String ticketId, String userId) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reply to User', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Type your reply...',
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: MPesaTheme.primaryGreen.withOpacity(0.5))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: MPesaTheme.primaryGreen)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              final reply = controller.text.trim();
              if (reply.isEmpty) return;

              Navigator.pop(context);

              try {
                await FirebaseFirestore.instance.collection('support_tickets').doc(ticketId).update({
                  'reply': reply,
                  'status': 'resolved',
                  'resolved_at': FieldValue.serverTimestamp(),
                });
                
                // Could also trigger a backend endpoint to send FCM to the user here
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent!')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
