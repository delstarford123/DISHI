import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/api_config.dart';
import '../../../core/services/permission_disclosure_service.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/widgets/prominent_disclosure_dialog.dart';

class DataConsentView extends StatefulWidget {
  final String userId;
  const DataConsentView({super.key, required this.userId});

  @override
  State<DataConsentView> createState() => _DataConsentViewState();
}

class _DataConsentViewState extends State<DataConsentView> {
  bool _isLoading = false;

  // Permission statuses
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _micGranted = false;
  bool _notifGranted = false;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatuses();
  }

  Future<void> _refreshPermissionStatuses() async {
    try {
      final locStatus = await Geolocator.checkPermission();
      final camStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;
      final notifStatus = await Permission.notification.status;

      if (mounted) {
        setState(() {
          _locationGranted = (locStatus == LocationPermission.always ||
              locStatus == LocationPermission.whileInUse);
          _cameraGranted = camStatus.isGranted;
          _micGranted = micStatus.isGranted;
          _notifGranted = notifStatus.isGranted;
        });
      }
    } catch (_) {}
  }

  Future<void> _showDisclosure(DisclosurePermissionType type) async {
    await ProminentDisclosureDialog.show(
      context: context,
      type: type,
    );
    await _refreshPermissionStatuses();
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(ProminentDisclosureDialog.privacyPolicyUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MPesaTheme.darkBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete DISHI Account?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to permanently delete your DISHI account?\n\n'
          'In compliance with Google Play User Data Policy and the Kenya Data Protection Act 2019, '
          'your profile, wallet links, and stored credentials will be queued for permanent erasure after a 30-day grace period.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MPesaTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Deletion'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/api/security/${widget.userId}/delete_account'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deletion process initiated.'),
              backgroundColor: MPesaTheme.primaryGreen,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection timed out. Please check your network and retry.'),
            backgroundColor: MPesaTheme.primaryRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: MPesaTheme.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MPesaTheme.darkBg,
      appBar: AppBar(
        title: const Text('Data Privacy & Permissions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: MPesaTheme.surfaceColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trust & Regulatory Pill
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MPesaTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MPesaTheme.primaryGreen.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user_rounded,
                            color: MPesaTheme.neonGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'User Privacy & Data Protection',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Google Play & Kenya Data Protection Act 2019',
                              style: TextStyle(
                                color: MPesaTheme.textSecondaryColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'DISHI operates under zero-advertising privacy standards. We only request sensitive device permissions '
                    'necessary to fulfill your food preorders, delivery dispatch, and safety emergency coordinates.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'SENSITIVE PERMISSIONS & PROMINENT DISCLOSURES',
              style: TextStyle(
                color: MPesaTheme.textSecondaryColor,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            // Location Permission Card
            _buildPermissionCard(
              title: 'Device Location (GPS)',
              purpose:
                  'Real-time courier delivery routing, campus cafeteria discovery, and safety SOS emergency broadcasts.',
              isGranted: _locationGranted,
              icon: Icons.location_on_rounded,
              accentColor: MPesaTheme.neonGreen,
              onViewDisclosure: () => _showDisclosure(DisclosurePermissionType.location),
              onToggle: () async {
                await PermissionDisclosureService.requestLocationWithDisclosure(context);
                await _refreshPermissionStatuses();
              },
            ),

            // Camera Permission Card
            _buildPermissionCard(
              title: 'Device Camera',
              purpose:
                  'Contactless vendor QR code checkout, meal photo uploads, and student ID card verification.',
              isGranted: _cameraGranted,
              icon: Icons.camera_alt_rounded,
              accentColor: MPesaTheme.neonCyan,
              onViewDisclosure: () => _showDisclosure(DisclosurePermissionType.camera),
              onToggle: () async {
                await PermissionDisclosureService.requestCameraWithDisclosure(context);
                await _refreshPermissionStatuses();
              },
            ),

            // Microphone Permission Card
            _buildPermissionCard(
              title: 'Microphone & Audio',
              purpose:
                  'Recording voice prompts for community hubs and emergency voice notes during active SOS alerts.',
              isGranted: _micGranted,
              icon: Icons.mic_rounded,
              accentColor: MPesaTheme.neonPink,
              onViewDisclosure: () => _showDisclosure(DisclosurePermissionType.microphone),
              onToggle: () async {
                await PermissionDisclosureService.requestMicrophoneWithDisclosure(context);
                await _refreshPermissionStatuses();
              },
            ),

            // Notifications Permission Card
            _buildPermissionCard(
              title: 'Push Notifications',
              purpose:
                  'Instant order preparation status, courier delivery progress, M-PESA receipts, and campus emergency alerts.',
              isGranted: _notifGranted,
              icon: Icons.notifications_active_rounded,
              accentColor: MPesaTheme.neonOrange,
              onViewDisclosure: () => _showDisclosure(DisclosurePermissionType.notifications),
              onToggle: () async {
                await PermissionDisclosureService.requestNotificationWithDisclosure(context);
                await _refreshPermissionStatuses();
              },
            ),

            const SizedBox(height: 12),

            // Privacy Policy External Button
            Container(
              decoration: BoxDecoration(
                color: MPesaTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: MPesaTheme.neonGreen),
                title: const Text('Official Privacy Policy',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('dishi.delstarfordworks.co.ke/privacy',
                    style: TextStyle(color: MPesaTheme.textSecondaryColor, fontSize: 12)),
                trailing: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
                onTap: _openPrivacyPolicy,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'DATA ERASURE & ACCOUNT MANAGEMENT',
              style: TextStyle(
                color: MPesaTheme.textSecondaryColor,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            // Delete Account Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MPesaTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MPesaTheme.primaryRed.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.delete_forever_rounded, color: MPesaTheme.primaryRed, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Permanently Delete Account',
                        style: TextStyle(
                          color: MPesaTheme.primaryRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Wipes all stored records, dining history, profile data, and linked cards from DISHI servers. '
                    'This action cannot be undone once the 30-day grace period concludes.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _deleteAccount,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: MPesaTheme.primaryRed),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(MPesaTheme.primaryRed),
                              ),
                            )
                          : const Text(
                              'Request Account Erasure',
                              style: TextStyle(
                                color: MPesaTheme.primaryRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String purpose,
    required bool isGranted,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onViewDisclosure,
    required VoidCallback onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MPesaTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGranted ? '✅ Granted & Active' : '⚪ Not Granted',
                      style: TextStyle(
                        color: isGranted ? MPesaTheme.neonGreen : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white60, size: 20),
                tooltip: 'Open Device Settings',
                onPressed: () => openAppSettings(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            purpose,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onViewDisclosure,
                icon: const Icon(Icons.info_outline, size: 14, color: MPesaTheme.neonCyan),
                label: const Text(
                  'View Disclosure',
                  style: TextStyle(color: MPesaTheme.neonCyan, fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: onToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isGranted ? MPesaTheme.surfaceLightColor : MPesaTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(
                  isGranted ? 'Re-Verify' : 'Grant Permission',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
