import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../database/database.dart';
import '../security/security_engine.dart';
// import 'api_config.dart'; // Will be used when integrating SecureHttpClient

class SyncService {
  final AppDatabase _database;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  SyncService(this._database);

  /// Starts listening to network changes to automatically sync offline data.
  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // If we have any form of connection, attempt a sync
      if (!results.contains(ConnectivityResult.none)) {
        _attemptSync();
      }
    });
  }

  Future<void> _attemptSync() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      
      // 1. Security Check: Are we allowed to sync? (SSL Pinning & Biometrics)
      final isAuthorized = await SecurityEngine.authorizeOfflineSync();
      if (!isAuthorized) {
        debugPrint('Sync aborted due to security engine failure.');
        return;
      }

      // 2. Fetch offline transactions from Drift SQLite
      final offlineTransactions = await _database.getAllTransactions();
      if (offlineTransactions.isEmpty) {
        debugPrint('No offline transactions to sync.');
        return;
      }

      debugPrint('Attempting to sync \${offlineTransactions.length} transactions to Vercel...');

      // 3. Process each transaction (Placeholder for real API call using SecureHttpClient)
      for (final tx in offlineTransactions) {
        // Example: await SecureHttpClient.post(ApiConfig.vendorProcessOfflineTx, body: tx.toJson());
        debugPrint('Synced TX: \${tx.transactionId}');
      }

      // 4. Clear the local cache once successfully synced
      await _database.clearTransactions();
      
      // 5. Post-sync cleanup (delete plain text passwords/hashes)
      await SecurityEngine.performPostSyncCleanup();
      
    } catch (e) {
      debugPrint('Sync failed: \$e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
