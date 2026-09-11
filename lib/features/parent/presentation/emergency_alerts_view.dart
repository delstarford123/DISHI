import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class EmergencyAlertsView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const EmergencyAlertsView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<EmergencyAlertsView> createState() => _EmergencyAlertsViewState();
}

class _EmergencyAlertsViewState extends State<EmergencyAlertsView> {
  Future<void> _acknowledgeAlert(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('safety_alerts').doc(docId).update({
        'status': 'Acknowledged',
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert Acknowledged'), backgroundColor: MPesaTheme.neonCyan),
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
        title: const Text('Emergency Alerts'),
        backgroundColor: MPesaTheme.primaryRed.withOpacity(0.2),
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
                Icon(Icons.warning_amber_rounded, color: MPesaTheme.primaryRed, size: 32),
                SizedBox(width: 12),
                Text(
                  'Safe Walk Panic Log',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Real-time alerts triggered by your student via the Campus Map Safe Walk feature.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('safety_alerts')
                    .where('parentUid', isEqualTo: widget.parentUser['uid'])
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryRed));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: MPesaTheme.primaryGreen, size: 64),
                          SizedBox(height: 16),
                          Text('All Clear. No safety alerts triggered.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'Unresolved';
                      final isCritical = status == 'Unresolved';

                      final studentName = 'Selected Student';

                      return Card(
                        color: isCritical ? MPesaTheme.primaryRed.withOpacity(0.15) : const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isCritical ? MPesaTheme.primaryRed : Colors.transparent, width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on, color: isCritical ? MPesaTheme.primaryRed : Colors.white54),
                                  const SizedBox(width: 8),
                                  Text(
                                    studentName,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCritical ? MPesaTheme.primaryRed : MPesaTheme.neonCyan,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(color: isCritical ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Location: ${data['location'] ?? 'Unknown Coordinates'}', style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 4),
                              Text('Time: ${data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate().toString() : 'Unknown'}', style: const TextStyle(color: Colors.white54)),
                              if (isCritical) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _acknowledgeAlert(doc.id),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Mark as Acknowledged / Resolved'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: MPesaTheme.primaryRed,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
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

