import 'package:flutter/foundation.dart';
import 'offline_storage_service.dart';

/// Manages Remote Config / Feature Flags for the DISHI ecosystem.
/// Allows the Admin backend to dynamically toggle features on or off.
class FeatureFlagService {
  
  // Default values
  static const Map<String, bool> _defaultFlags = {
    'okoa_food_enabled': true,         // Micro-credit facility
    'keja_protection_enabled': false,  // Landlord insurance
    'dishi_gold_enabled': true,        // Premium networking features
    'safe_walk_enabled': true,         // SOS & Location sharing
  };

  /// Initializes feature flags, fetching latest from backend if online,
  /// or loading from local Hive cache if offline.
  static Future<void> initialize() async {
    // In a production environment, this would integrate with Firebase Remote Config
    // or a dedicated Vercel /api/config endpoint.
    
    // For now, we seed the Hive settings box with defaults if they don't exist.
    final settings = OfflineStorageService.settings;
    
    for (final entry in _defaultFlags.entries) {
      if (!settings.containsKey(entry.key)) {
        await settings.put(entry.key, entry.value);
      }
    }
  }

  static bool isOkoaFoodEnabled() {
    return OfflineStorageService.settings.get('okoa_food_enabled', defaultValue: true);
  }

  static bool isKejaProtectionEnabled() {
    return OfflineStorageService.settings.get('keja_protection_enabled', defaultValue: false);
  }

  static bool isDishiGoldEnabled() {
    return OfflineStorageService.settings.get('dishi_gold_enabled', defaultValue: true);
  }
  
  static bool isSafeWalkEnabled() {
    return OfflineStorageService.settings.get('safe_walk_enabled', defaultValue: true);
  }

  /// Admin override to manually toggle a feature.
  static Future<void> toggleFeature(String featureKey, bool value) async {
    await OfflineStorageService.settings.put(featureKey, value);
    debugPrint('FeatureFlagService: Toggled \$featureKey to \$value');
  }
}
