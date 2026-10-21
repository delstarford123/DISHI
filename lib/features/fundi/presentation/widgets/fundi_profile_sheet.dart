import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/mpesa_theme.dart';
import '../../../student/presentation/student_main_scaffold.dart';

class FundiProfileSheet extends StatefulWidget {
  final String fundiId;
  final String fundiName;
  final String fundiPhone;
  final Map<String, dynamic> initialProfile;
  final Function(bool isOnline)? onAvailabilityChanged;

  const FundiProfileSheet({
    super.key,
    required this.fundiId,
    required this.fundiName,
    required this.fundiPhone,
    required this.initialProfile,
    this.onAvailabilityChanged,
  });

  @override
  State<FundiProfileSheet> createState() => _FundiProfileSheetState();
}

class _FundiProfileSheetState extends State<FundiProfileSheet> {
  late bool _isAvailable;
  late bool _weekends;
  late bool _nightCalls;
  late bool _ownTools;
  late String _radius;
  late String _responseTime;
  late String _bio;
  bool _isSaving = false;

  final _radiusOptions = ['Within Campus Only', 'Within 2km', 'Within 5km', 'Anywhere in City'];
  final _responseOptions = ['Under 30 mins', '1-2 Hours', 'Same Day', 'Next Day'];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _isAvailable = p['isAvailable'] ?? p['is_available'] ?? true;
    _weekends = p['availableWeekends'] ?? true;
    _nightCalls = p['nightCallouts'] ?? false;
    _ownTools = p['bringsOwnTools'] ?? true;
    _radius = p['serviceRadius'] ?? 'Within Campus Only';
    if (!_radiusOptions.contains(_radius)) _radius = _radiusOptions[0];
    _responseTime = p['responseTime'] ?? 'Under 30 mins';
    if (!_responseOptions.contains(_responseTime)) _responseTime = _responseOptions[0];
    _bio = p['bio'] ?? 'Experienced Comrade Technician & Service Pro';
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final updates = {
        'isAvailable': _isAvailable,
        'is_available': _isAvailable,
        'availableWeekends': _weekends,
        'nightCallouts': _nightCalls,
        'bringsOwnTools': _ownTools,
        'serviceRadius': _radius,
        'responseTime': _responseTime,
        'bio': _bio,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('fundi_profiles').doc(widget.fundiId).set(updates, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('campus_gig_workers').doc(widget.fundiId).set(updates, SetOptions(merge: true));

      widget.onAvailabilityChanged?.call(_isAvailable);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fundi preferences updated!'), backgroundColor: Color(0xFF05D5AA)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  void _showQrCodeModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
          child: Text('Fundi Digital Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: 'https://dishi.delstarfordworks.co.ke/fundi/${widget.fundiId}',
                version: QrVersions.auto,
                size: 180.0,
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.fundiName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(widget.fundiPhone, style: const TextStyle(color: Color(0xFF05D5AA), fontSize: 13)),
            const SizedBox(height: 6),
            const Text(
              'Clients can scan this QR code to view your rate card and hire you with DISHI Escrow.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF05D5AA))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131A26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Fundi Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF1A2235),
                    child: Text(
                      widget.fundiName.isNotEmpty ? widget.fundiName[0].toUpperCase() : 'F',
                      style: const TextStyle(color: Color(0xFF05D5AA), fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.fundiName,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: Color(0xFF05D5AA), size: 18),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(widget.fundiPhone, style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 13)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF05D5AA).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Verified Comrade Pro', style: TextStyle(color: Color(0xFF05D5AA), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF05D5AA), size: 28),
                    onPressed: _showQrCodeModal,
                    tooltip: 'View QR Pass',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Trust Badges Grid
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2235),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBadgeItem(Icons.security, 'Escrow Safe', '100% Protected'),
                    _buildBadgeItem(Icons.handyman, 'Own Tools', _ownTools ? 'Equipped' : 'Standard'),
                    _buildBadgeItem(Icons.timer, 'Response', _responseTime),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text('Duty & Availability Controls', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // Duty Toggle
              _buildToggle(
                title: 'Accepting Campus Gigs',
                subtitle: _isAvailable ? '🟢 Online • Appears in Campus Directory' : '⏸️ Offline • Taking a break',
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                activeColor: const Color(0xFF05D5AA),
              ),
              const SizedBox(height: 8),

              // Weekend Calls
              _buildToggle(
                title: 'Available on Weekends',
                subtitle: 'Saturday & Sunday campus emergency support',
                value: _weekends,
                onChanged: (v) => setState(() => _weekends = v),
              ),
              const SizedBox(height: 8),

              // Night Calls
              _buildToggle(
                title: 'Emergency Night Callouts',
                subtitle: 'Available after 9 PM for urgent plumbing/electrical',
                value: _nightCalls,
                onChanged: (v) => setState(() => _nightCalls = v),
              ),
              const SizedBox(height: 14),

              // Service Radius
              const Text('Service Coverage Radius', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _radius,
                dropdownColor: const Color(0xFF1A2235),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A2235),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: _radiusOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _radius = v ?? _radiusOptions[0]),
              ),
              const SizedBox(height: 14),

              // Response Time
              const Text('Typical Arrival / Response Time', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _responseTime,
                dropdownColor: const Color(0xFF1A2235),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A2235),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: _responseOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _responseTime = v ?? _responseOptions[0]),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MPesaTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Save Preferences', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 14),

              // Switch to Student Dashboard
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentMainScaffold(
                          user: {
                            'uid': widget.fundiId,
                            'displayName': widget.fundiName,
                            'phoneNumber': widget.fundiPhone,
                            'roles': ['student', 'fundi'],
                          },
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF05D5AA).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF05D5AA).withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.school, color: Color(0xFF05D5AA), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Switch to Student Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Cafeteria orders, upkeep wallet & campus services', style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Color(0xFF05D5AA), size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color activeColor = MPesaTheme.primaryGreen,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF05D5AA), size: 20),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(subtitle, style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 10)),
      ],
    );
  }
}
