import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService {
  /// Marks a user as Online or Offline using Firestore (no firebase_database package needed).
  static Future<void> setUserPresence(String uid,
      {required bool isOnline}) async {
    try {
      await FirebaseFirestore.instance.collection('user_presence').doc(uid).set(
        {
          'isOnline': isOnline,
          'last_changed': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
