import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Manages a local `offline_queue.json` to silently intercept failed network requests.
class OfflineApiService {
  static const String _fileName = 'offline_queue.json';

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('\${dir.path}/\$_fileName');
  }

  /// Adds a failed network request to the offline queue.
  Future<void> enqueueRequest(Map<String, dynamic> requestData) async {
    final file = await _getFile();
    List<dynamic> queue = [];

    if (await file.exists()) {
      final String contents = await file.readAsString();
      if (contents.isNotEmpty) {
        queue = jsonDecode(contents);
      }
    }

    queue.add(requestData);
    await file.writeAsString(jsonEncode(queue));
  }

  /// Retrieves and clears the queue for processing.
  Future<List<Map<String, dynamic>>> dequeueAll() async {
    final file = await _getFile();
    if (!await file.exists()) return [];

    final String contents = await file.readAsString();
    if (contents.isEmpty) return [];

    final List<dynamic> queue = jsonDecode(contents);
    
    // Clear the queue after retrieving
    await file.writeAsString('[]');

    return queue.cast<Map<String, dynamic>>();
  }
}
