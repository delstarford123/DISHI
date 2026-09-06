import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  /// Marks a user (e.g. Driver) as Online or Offline using Firebase Realtime Database.
  /// Uses onDisconnect() to automatically mark them offline if they lose connection.
  static Future<void> setUserPresence(String uid, {required bool isOnline}) async {
    final userStatusRef = _database.ref('status/\$uid');
    
    // 1. Create a reference to the special '.info/connected' path in Realtime Database.
    final connectedRef = _database.ref('.info/connected');

    connectedRef.onValue.listen((event) {
      final isConnected = event.snapshot.value as bool? ?? false;
      if (isConnected) {
        // We are connected (or reconnected)!
        // Set up the disconnect operation: when this device drops the connection,
        // automatically set 'isOnline' to false in the database.
        userStatusRef.onDisconnect().update({
          'isOnline': false,
          'last_changed': ServerValue.timestamp,
        }).then((_) {
          // Once the disconnect operation is queued, we set the actual online status.
          userStatusRef.update({
            'isOnline': isOnline,
            'last_changed': ServerValue.timestamp,
          });
        });
      }
    });
  }
}
