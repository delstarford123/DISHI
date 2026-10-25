import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/prominent_disclosure_dialog.dart';

/// Centralized manager for handling Google Play Prominent Disclosures and Consent
/// prior to requesting runtime permissions for sensitive user data (Location, Camera, Mic, Notifications).
class PermissionDisclosureService {
  static const String _prefix = 'prominent_disclosure_agreed_';

  /// Checks if the user previously gave affirmative consent to the prominent disclosure.
  static Future<bool> hasAgreedDisclosure(DisclosurePermissionType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_prefix${type.name}') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Records affirmative consent for the prominent disclosure.
  static Future<void> setAgreedDisclosure(DisclosurePermissionType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix${type.name}', true);
    } catch (_) {}
  }

  /// Prompts the user with the Location Prominent Disclosure dialog (if not yet granted),
  /// and only triggers [Geolocator.requestPermission] if affirmative consent is granted.
  static Future<bool> requestLocationWithDisclosure(BuildContext context) async {
    // 1. Check if location services are enabled on device
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable device Location Services in settings.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    // 2. Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Location permission permanently denied. Enable in device settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }

    // 3. MANDATORY GOOGLE PLAY STEP:
    // Show Prominent Disclosure BEFORE triggering the runtime system permission dialog.
    if (!context.mounted) return false;
    final agreed = await ProminentDisclosureDialog.show(
      context: context,
      type: DisclosurePermissionType.location,
    );

    if (agreed != true) {
      // User tapped "No Thanks" — do NOT request system permission!
      return false;
    }

    // Save affirmative consent
    await setAgreedDisclosure(DisclosurePermissionType.location);

    // 4. Request the system permission only after affirmative consent
    permission = await Geolocator.requestPermission();
    return (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse);
  }

  /// Camera prominent disclosure & runtime request
  static Future<bool> requestCameraWithDisclosure(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera permission denied. Enable in settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }

    if (!context.mounted) return false;
    final agreed = await ProminentDisclosureDialog.show(
      context: context,
      type: DisclosurePermissionType.camera,
    );

    if (agreed != true) return false;
    await setAgreedDisclosure(DisclosurePermissionType.camera);

    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// Microphone prominent disclosure & runtime request
  static Future<bool> requestMicrophoneWithDisclosure(BuildContext context) async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission denied. Enable in settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }

    if (!context.mounted) return false;
    final agreed = await ProminentDisclosureDialog.show(
      context: context,
      type: DisclosurePermissionType.microphone,
    );

    if (agreed != true) return false;
    await setAgreedDisclosure(DisclosurePermissionType.microphone);

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Notifications prominent disclosure & runtime request
  static Future<bool> requestNotificationWithDisclosure(BuildContext context) async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    if (!context.mounted) return false;
    final agreed = await ProminentDisclosureDialog.show(
      context: context,
      type: DisclosurePermissionType.notifications,
    );

    if (agreed != true) return false;
    await setAgreedDisclosure(DisclosurePermissionType.notifications);

    final result = await Permission.notification.request();
    return result.isGranted;
  }
}
