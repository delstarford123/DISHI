import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
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
  // Cache for student names fetched from Firestore
  final Map<String, String> _studentNameCache = {};

  /// Returns the student's display name, fetching from Firestore once and caching.
  Future<String> _getStudentName(String? studentUid, String? fallback) async {
    if (studentUid == null || studentUid.isEmpty) return fallback ?? 'Unknown Student';
    if (_studentNameCache.containsKey(studentUid)) {
      return _studentNameCache[studentUid]!;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(studentUid).get();
      final name = doc.data()?['displayName'] as String? ??
          doc.data()?['name'] as String? ??
          fallback ??
          'Unknown Student';
      _studentNameCache[studentUid] = name;
      return name;
    } catch (_) {
      return fallback ?? 'Unknown Student';
    }
  }

  Future<void> _acknowledgeAlert(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('safety_alerts').doc(docId).update({
        'status': 'Acknowledged',
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert Acknowledged — stay in contact with your student.'),
            backgroundColor: MPesaTheme.neonCyan,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentUid = widget.parentUser['uid'] as String? ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';

    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('🚨 Emergency SOS Alerts'),
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
                Expanded(
                  child: Text(
                    'SOS Panic Log',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Real-time emergency alerts triggered by your student. Unresolved alerts are shown first.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('safety_alerts')
                    .where('parentUids', arrayContains: parentUid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryRed));
                  }
                  if (snapshot.hasError) {
                    // Index might still be building — show a helpful fallback
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off, color: Colors.white38, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Loading alerts... If this persists,\ncheck Firestore index setup.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: MPesaTheme.primaryGreen, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'All Clear. No SOS alerts triggered.',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] as String? ?? 'Unresolved';
                      final isCritical = status == 'Unresolved';
                      final isAcknowledged = status == 'Acknowledged';

                      // Use studentName field from doc, or fetch async
                      final studentNameFromDoc = data['studentName'] as String? ?? '';
                      final studentUid = data['studentUid'] as String?;
                      final location = data['location'] as String? ?? 'Unknown';
                      final lat = data['lat'] as double?;
                      final lng = data['lng'] as double?;
                      final createdAt = data['createdAt'] != null
                          ? (data['createdAt'] as Timestamp).toDate()
                          : null;

                      final statusColor = isCritical
                          ? MPesaTheme.primaryRed
                          : isAcknowledged
                              ? const Color(0xFFFF9800)
                              : const Color(0xFF4CAF50);

                      return Card(
                        color: isCritical
                            ? MPesaTheme.primaryRed.withOpacity(0.12)
                            : const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isCritical ? MPesaTheme.primaryRed : Colors.white12,
                            width: isCritical ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row: name + status chip
                              Row(
                                children: [
                                  Icon(
                                    isCritical ? Icons.emergency : Icons.check_circle_outline,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FutureBuilder<String>(
                                      future: _getStudentName(studentUid, studentNameFromDoc),
                                      builder: (context, nameSnap) {
                                        final displayName = nameSnap.data?.isNotEmpty == true
                                            ? nameSnap.data!
                                            : studentNameFromDoc.isNotEmpty
                                                ? studentNameFromDoc
                                                : 'Student';
                                        return Text(
                                          displayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Location row
                              Row(
                                children: [
                                  const Icon(Icons.location_pin, color: Colors.white54, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ),
                                  if (lat != null && lng != null)
                                    TextButton.icon(
                                      onPressed: () => _openInMaps(lat, lng),
                                      icon: const Icon(Icons.map_outlined, size: 16),
                                      label: const Text('View Map'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF3B82F6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Timestamp
                              if (createdAt != null)
                                Text(
                                  '${_timeAgo(createdAt)} · ${_formatTime(createdAt)}',
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),

                              // Acknowledge button (only for Unresolved)
                              if (isCritical) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _acknowledgeAlert(doc.id),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Acknowledge — I am handling this'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: MPesaTheme.primaryRed,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
