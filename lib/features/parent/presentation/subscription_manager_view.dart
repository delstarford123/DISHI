import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class SubscriptionManagerView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const SubscriptionManagerView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<SubscriptionManagerView> createState() => _SubscriptionManagerViewState();
}

class _SubscriptionManagerViewState extends State<SubscriptionManagerView> {
    Future<void> _updateSubscriptionStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('subscriptions').doc(docId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription $newStatus!'),
            backgroundColor: newStatus == 'Approved' ? MPesaTheme.primaryGreen : MPesaTheme.primaryRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Subscriptions & Bills'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.autorenew, color: Colors.cyanAccent, size: 32),
                SizedBox(width: 12),
                Text(
                  'Manage Recurring Bills',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'View, approve, or deny recurring campus subscriptions like Hostel WiFi, Gym memberships, or Laundry services.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            if (widget.selectedStudentUid == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No student selected in Dependents tab.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 32),
            const Text(
              'Student Subscriptions',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: widget.selectedStudentUid == null
                  ? const Center(child: Text('Please select a student above.', style: TextStyle(color: Colors.white54)))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('subscriptions')
                          .where('studentUid', isEqualTo: widget.selectedStudentUid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No subscriptions requested.', style: TextStyle(color: Colors.white54)),
                          );
                        }

                        return ListView.builder(
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final doc = snapshot.data!.docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final status = data['status'] ?? 'Pending';

                            Color statusColor = Colors.orange;
                            if (status == 'Approved') statusColor = Colors.green;
                            if (status == 'Denied') statusColor = Colors.red;

                            return Card(
                              color: const Color(0xFF131A2A),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: statusColor, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(data['serviceName'] ?? 'Unknown Service', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        Text('Ksh ${data['amount']}', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Frequency: ${data['frequency'] ?? 'Monthly'}', style: const TextStyle(color: Colors.white54)),
                                    const SizedBox(height: 4),
                                    Text('Status: $status', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                                    if (status == 'Pending') ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _updateSubscriptionStatus(doc.id, 'Denied'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(color: Colors.red),
                                              ),
                                              child: const Text('DENY'),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _updateSubscriptionStatus(doc.id, 'Approved'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('APPROVE'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

