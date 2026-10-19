import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

enum VersionAction {
  allowed,
  softUpdate,
  forceUpdate,
  maintenance,
}

class AppVersionStatus {
  final VersionAction action;
  final int minSupportedCode;
  final int latestCode;
  final String latestName;
  final String message;
  final String playStoreUrl;
  final String releaseNotes;

  const AppVersionStatus({
    required this.action,
    this.minSupportedCode = 2,
    this.latestCode = 3,
    this.latestName = '1.0.2',
    this.message = '',
    this.playStoreUrl = 'https://play.google.com/store/apps/details?id=co.ke.delstarfordworks.dishi',
    this.releaseNotes = '',
  });

  factory AppVersionStatus.allowed() => const AppVersionStatus(action: VersionAction.allowed);
}

class AppVersionService {
  // Current compiled app version metadata
  static const int currentAppVersionCode = 3;
  static const String currentAppVersionName = '1.0.2';

  /// Evaluates remote Firestore configuration with a fast 3-second timeout.
  /// If offline or unreachable, defaults to allowed so offline NFC dignity is preserved.
  static Future<AppVersionStatus> checkVersionStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('app_version')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 3));

      if (!doc.exists || doc.data() == null) {
        return AppVersionStatus.allowed();
      }

      final data = doc.data()!;
      final bool isMaintenance = data['maintenance_mode'] as bool? ?? false;
      final String maintenanceMsg = data['maintenance_message'] as String? ??
          'DISHI is currently undergoing scheduled platform upgrades. We will be back online shortly.';
      final int minSupported = (data['min_supported_version_code'] as num?)?.toInt() ?? 2;
      final int latest = (data['latest_version_code'] as num?)?.toInt() ?? 3;
      final String latestName = data['latest_version_name'] as String? ?? '1.0.2';
      final bool forceUpdateFlag = data['force_update'] as bool? ?? false;
      final String playStoreUrl = data['play_store_url'] as String? ??
          'https://play.google.com/store/apps/details?id=co.ke.delstarfordworks.dishi';
      final String releaseNotes = data['release_notes'] as String? ?? '';

      // 1. Maintenance Mode
      if (isMaintenance) {
        return AppVersionStatus(
          action: VersionAction.maintenance,
          message: maintenanceMsg,
          playStoreUrl: playStoreUrl,
        );
      }

      // 2. Critical Force Update (Installed version is below minimum supported)
      if (currentAppVersionCode < minSupported || forceUpdateFlag) {
        return AppVersionStatus(
          action: VersionAction.forceUpdate,
          minSupportedCode: minSupported,
          latestCode: latest,
          latestName: latestName,
          playStoreUrl: playStoreUrl,
          releaseNotes: releaseNotes,
          message: 'A required security and performance update (v$latestName) is available. Please update on Google Play to continue.',
        );
      }

      // 3. Optional Soft Update (Installed version is between min and latest)
      if (currentAppVersionCode < latest) {
        return AppVersionStatus(
          action: VersionAction.softUpdate,
          minSupportedCode: minSupported,
          latestCode: latest,
          latestName: latestName,
          playStoreUrl: playStoreUrl,
          releaseNotes: releaseNotes,
          message: 'A new version of DISHI (v$latestName) is available with improvements and new features.',
        );
      }

      return AppVersionStatus.allowed();
    } catch (_) {
      // Graceful offline fallback
      return AppVersionStatus.allowed();
    }
  }

  /// Opens the official DISHI page on the Google Play Store
  static Future<void> launchPlayStore(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Evaluates version and presents modern, branded dialogs if required.
  /// Returns `true` if the app can proceed to navigation, or `false` if blocked.
  static Future<bool> enforceVersionCheck(BuildContext context) async {
    final status = await checkVersionStatus();

    if (!context.mounted) return true;

    // Maintenance Mode (Blocks app)
    if (status.action == VersionAction.maintenance) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0D1520),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.engineering_rounded, color: Color(0xFFF59E0B), size: 28),
                SizedBox(width: 10),
                Text('Scheduled Maintenance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Text(
              status.message,
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.5),
            ),
          ),
        ),
      );
      return false;
    }

    // Force Update (Blocks app until updated)
    if (status.action == VersionAction.forceUpdate) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0D1520),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFF05D5AA), width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Color(0xFF05D5AA), size: 28),
                SizedBox(width: 10),
                Text('Update Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.message,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.5),
                ),
                if (status.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('What\'s New:', style: TextStyle(color: Color(0xFF05D5AA), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(status.releaseNotes, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4)),
                ],
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shop_two_rounded, color: Colors.black, size: 20),
                  label: const Text('Update on Google Play', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF05D5AA),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => launchPlayStore(status.playStoreUrl),
                ),
              ),
            ],
          ),
        ),
      );
      return false;
    }

    // Soft Update (Gentle, dismissible prompt)
    if (status.action == VersionAction.softUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D1520),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x33FFFFFF), width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.new_releases_rounded, color: Color(0xFF38BDF8), size: 24),
              SizedBox(width: 10),
              Text('Update Available', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            status.message,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                launchPlayStore(status.playStoreUrl);
              },
              child: const Text('Update Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return true;
    }

    return true;
  }
}
