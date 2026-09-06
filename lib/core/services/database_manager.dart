import 'package:flutter/foundation.dart';
import '../database/database.dart';
import 'offline_storage_service.dart';

/// Centralized manager for initializing all local database instances.
class DatabaseManager {
  static AppDatabase? _driftDb;
  
  /// Provides global access to the Drift SQLite database.
  static AppDatabase get driftDb {
    if (_driftDb == null) {
      throw Exception('DatabaseManager has not been initialized. Call initialize() first.');
    }
    return _driftDb!;
  }

  /// Initializes all local offline storage systems (Drift and Hive).
  static Future<void> initialize() async {
    try {
      // 1. Initialize Hive (NoSQL for SmartI & Settings)
      await OfflineStorageService.initialize();
      
      // 2. Initialize Drift (SQLite for POS Transactions & Housing)
      _driftDb = AppDatabase();
      
      debugPrint('DatabaseManager: All local databases successfully initialized.');
    } catch (e) {
      debugPrint('DatabaseManager Error: Failed to initialize local databases: \$e');
      rethrow;
    }
  }

  /// Closes all database connections (e.g. on app termination)
  static Future<void> dispose() async {
    if (_driftDb != null) {
      await _driftDb!.close();
      _driftDb = null;
    }
  }
}
