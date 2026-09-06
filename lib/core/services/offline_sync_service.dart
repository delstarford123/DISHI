import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'offline_api_service.dart';
import 'secure_http_client.dart';

/// Flushes the JSON offline queue to the backend when Wi-Fi is restored.
/// Built specifically for the SmartI / General App queue (independent of Drift POS).
class OfflineSyncService {
  final OfflineApiService _apiService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  OfflineSyncService(this._apiService);

  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        _attemptQueueFlush();
      }
    });
  }

  Future<void> _attemptQueueFlush() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      final queue = await _apiService.dequeueAll();

      if (queue.isEmpty) return;

      debugPrint('Flushing \${queue.length} items from offline_queue.json...');

      for (final request in queue) {
        final url = request['url'];
        final body = request['body'];
        final method = request['method'];

        try {
          if (method == 'POST') {
            await SecureHttpClient.post(url, body: body);
          } else if (method == 'PUT') {
            await SecureHttpClient.put(url, body: body);
          }
          debugPrint('Successfully flushed offline request to \$url');
        } catch (e) {
          debugPrint('Failed to flush request to \$url: \$e');
          // Re-queue the failed request
          await _apiService.enqueueRequest(request);
        }
      }
    } catch (e) {
      debugPrint('Error flushing offline queue: \$e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  static Future<void> queueRequest(Map<String, dynamic> requestData) async {
    await OfflineApiService().enqueueRequest(requestData);
  }
}
