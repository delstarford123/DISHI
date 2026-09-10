import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class GeofenceAlertsView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final List<Map<String, dynamic>> linkedStudents;

  const GeofenceAlertsView({
    super.key,
    required this.parentUser,
    required this.linkedStudents,
  });

  @override
  State<GeofenceAlertsView> createState() => _GeofenceAlertsViewState();
}

class _GeofenceAlertsViewState extends State<GeofenceAlertsView> {
  String? _selectedStudentUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Campus Geofence'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zone Tracking',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check if your student is within the primary campus zone. (Requires student opt-in to location tracking)',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            if (widget.linkedStudents.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedStudentUid,
                dropdownColor: const Color(0xFF131A2A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Select Student',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF131A2A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: widget.linkedStudents.map((s) {
                  return DropdownMenuItem<String>(
                    value: s['uid'],
                    child: Text(s['name'] ?? 'Unknown Student'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedStudentUid = val),
              ),
            const SizedBox(height: 32),
            if (_selectedStudentUid != null) ...[
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(_selectedStudentUid).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan));
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text('No location data available.', style: TextStyle(color: Colors.white54));
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final isLocationShared = data['shareLocationWithParents'] ?? false;
                  final currentZone = data['currentZone'] ?? 'Unknown';

                  if (!isLocationShared) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_off, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'The student has not opted-in to share their location with parents.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final isOnCampus = currentZone == 'On Campus' || currentZone == 'Library' || currentZone == 'Hostels';

                  return Card(
                    color: const Color(0xFF131A2A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(
                            isOnCampus ? Icons.verified_user : Icons.directions_walk,
                            color: isOnCampus ? MPesaTheme.primaryGreen : MPesaTheme.neonOrange,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Current Status: $currentZone',
                            style: TextStyle(
                              color: isOnCampus ? MPesaTheme.primaryGreen : MPesaTheme.neonOrange,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isOnCampus
                                ? 'Student is safely within the designated campus zones.'
                                : 'Student has left the primary campus geofence.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ]
          ],
        ),
      ),
    );
  }
}
