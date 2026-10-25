import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/mpesa_theme.dart';

enum DisclosurePermissionType {
  location,
  camera,
  microphone,
  notifications,
}

/// A Google Play compliant Prominent Disclosure modal dialog.
/// Displays clear disclosure of data collected, purpose, privacy assurances,
/// and requires affirmative user consent before triggering runtime permission requests.
class ProminentDisclosureDialog extends StatelessWidget {
  final DisclosurePermissionType type;
  final VoidCallback onAgree;
  final VoidCallback onDeny;

  const ProminentDisclosureDialog({
    super.key,
    required this.type,
    required this.onAgree,
    required this.onDeny,
  });

  static const String privacyPolicyUrl = 'https://dishi.delstarfordworks.co.ke/privacy';

  static Future<bool?> show({
    required BuildContext context,
    required DisclosurePermissionType type,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProminentDisclosureDialog(
        type: type,
        onAgree: () => Navigator.of(ctx).pop(true),
        onDeny: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(privacyPolicyUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open privacy policy.')),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final data = _getDisclosureData(type);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: MPesaTheme.darkBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: MPesaTheme.darkBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: MPesaTheme.primaryGreen.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon & Pill
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: MPesaTheme.primaryGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: MPesaTheme.neonGreen.withOpacity(0.4), width: 1.5),
                  ),
                  child: Icon(data.icon, color: MPesaTheme.neonGreen, size: 32),
                ),
              ),
              const SizedBox(height: 14),

              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: MPesaTheme.surfaceLightColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🛡️ Google Play Prominent Disclosure',
                    style: TextStyle(
                      color: MPesaTheme.textSecondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle / Intro
              Text(
                data.intro,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Feature Cards
              ...data.features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MPesaTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.headline,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                f.description,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Privacy & Security Guarantee Card
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MPesaTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MPesaTheme.neonCyan.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: MPesaTheme.neonCyan, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your data is encrypted in transit (TLS 1.3) and never sold, rented, or shared with third-party advertisers.',
                        style: TextStyle(
                          color: MPesaTheme.neonCyan.withOpacity(0.9),
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Privacy Policy Link
              Center(
                child: InkWell(
                  onTap: () => _openPrivacyPolicy(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.privacy_tip_outlined, color: MPesaTheme.primaryGreen, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Read our full Privacy Policy',
                          style: TextStyle(
                            color: MPesaTheme.neonGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons (Affirmative vs Negative)
              ElevatedButton(
                onPressed: onAgree,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text(
                  'Agree & Continue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(height: 8),

              TextButton(
                onPressed: onDeny,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white60,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  'No Thanks',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _DisclosureContent _getDisclosureData(DisclosurePermissionType type) {
    switch (type) {
      case DisclosurePermissionType.location:
        return _DisclosureContent(
          icon: Icons.location_on_rounded,
          title: 'Location Access & Use',
          intro:
              'DISHI requires access to your device\'s location coordinates to enable essential dining, campus order routing, and safety features:',
          features: [
            _DisclosureFeature(
              emoji: '🛵',
              headline: 'Real-Time Order Delivery Routing',
              description:
                  'Used during active order dispatch to route orders accurately from campus cafeterias to your hostel or hall of residence.',
            ),
            _DisclosureFeature(
              emoji: '🍽️',
              headline: 'Campus Vendor & Cafeteria Discovery',
              description:
                  'Identifies nearby cafeteria counters, dining halls, and calculates distance to meal collection points.',
            ),
            _DisclosureFeature(
              emoji: '🚨',
              headline: 'Campus Safety SOS & Geofencing',
              description:
                  'Broadcasts live emergency coordinates to linked parents and campus security when an SOS distress alert is triggered.',
            ),
          ],
        );

      case DisclosurePermissionType.camera:
        return _DisclosureContent(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Camera Access Disclosure',
          intro:
              'DISHI uses your device camera solely for interactive in-app transactions and verification:',
          features: [
            _DisclosureFeature(
              emoji: '💳',
              headline: 'Contactless QR Code Payments',
              description:
                  'Quickly scans cafeteria vendor QR codes at food counters for instant cashless wallet checkout.',
            ),
            _DisclosureFeature(
              emoji: '📸',
              headline: 'Menu Item & Food Uploads',
              description:
                  'Allows cafeteria vendors to capture fresh meal images for daily student menus.',
            ),
            _DisclosureFeature(
              emoji: '🪪',
              headline: 'Student Identity Verification',
              description:
                  'Assists in verifying student dining identification cards during account setup.',
            ),
          ],
        );

      case DisclosurePermissionType.microphone:
        return _DisclosureContent(
          icon: Icons.mic_rounded,
          title: 'Microphone Access Disclosure',
          intro:
              'DISHI requires microphone access strictly when you intentionally record voice content:',
          features: [
            _DisclosureFeature(
              emoji: '🎙️',
              headline: 'Campus Voice Prompts & Notes',
              description:
                  'Enables students to record short voice memos for interactive community hubs and profile prompts.',
            ),
            _DisclosureFeature(
              emoji: '🆘',
              headline: 'Emergency SOS Voice Recording',
              description:
                  'Records an optional emergency voice snapshot during active SOS safety distress alerts for linked parents.',
            ),
          ],
        );

      case DisclosurePermissionType.notifications:
        return _DisclosureContent(
          icon: Icons.notifications_active_rounded,
          title: 'Notifications Prominent Disclosure',
          intro:
              'DISHI sends timely push notifications to keep you informed about transactions and campus alerts:',
          features: [
            _DisclosureFeature(
              emoji: '📦',
              headline: 'Order Status & Delivery Updates',
              description:
                  'Notifies you when your meal preorder is preparing, ready for pickup, or out for delivery.',
            ),
            _DisclosureFeature(
              emoji: '💚',
              headline: 'M-PESA Wallet Receipts',
              description:
                  'Instantly notifies you upon successful M-PESA deposits, transfers, and wallet deductions.',
            ),
            _DisclosureFeature(
              emoji: '🛡️',
              headline: 'Campus Safety Alerts',
              description:
                  'Delivers real-time emergency and geofence notifications to linked parent and student accounts.',
            ),
          ],
        );
    }
  }
}

class _DisclosureContent {
  final IconData icon;
  final String title;
  final String intro;
  final List<_DisclosureFeature> features;

  _DisclosureContent({
    required this.icon,
    required this.title,
    required this.intro,
    required this.features,
  });
}

class _DisclosureFeature {
  final String emoji;
  final String headline;
  final String description;

  _DisclosureFeature({
    required this.emoji,
    required this.headline,
    required this.description,
  });
}
