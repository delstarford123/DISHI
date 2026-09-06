import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _requireAuth() {
    if (_auth.currentUser == null) {
      throw Exception('User must be authenticated to upload files.');
    }
  }

  /// Validates file extension against rules (images only)
  bool _isValidImage(File file) {
    final ext = path.extension(file.path).toLowerCase();
    return ['.jpg', '.jpeg', '.png'].contains(ext);
  }

  /// Upload Profile Image (Rules Path: /profile_images/{uid}.jpg)
  Future<String> uploadProfileImage(File file) async {
    _requireAuth();
    if (!_isValidImage(file)) throw Exception('Invalid image format (must be jpg/png)');
    
    final uid = _auth.currentUser!.uid;
    final ext = path.extension(file.path).toLowerCase();
    final ref = _storage.ref().child('profile_images/${uid}$ext');
    
    final uploadTask = await ref.putFile(file, SettableMetadata(contentType: 'image/${ext.substring(1)}'));
    return await uploadTask.ref.getDownloadURL();
  }

  /// Upload Property Image (Rules Path: /property_images/{propertyId}/{imageId})
  Future<String> uploadPropertyImage(String propertyId, File file) async {
    _requireAuth();
    if (!_isValidImage(file)) throw Exception('Invalid image format');

    final filename = path.basename(file.path);
    final ref = _storage.ref().child('property_images/$propertyId/$filename');
    
    final ext = path.extension(file.path).toLowerCase();
    final uploadTask = await ref.putFile(file, SettableMetadata(contentType: 'image/${ext.substring(1)}'));
    return await uploadTask.ref.getDownloadURL();
  }

  /// Upload Generic Document for User (Rules Path: /{userId}/...)
  Future<String> uploadUserDocument(String folder, File file) async {
    _requireAuth();
    final uid = _auth.currentUser!.uid;
    final filename = path.basename(file.path);
    final ref = _storage.ref().child('$uid/$folder/$filename');
    
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Upload Voice Intro (Rules Path: /voice_intros/{audioId})
  Future<String> uploadVoiceIntro(File audioFile) async {
    _requireAuth();
    final uid = _auth.currentUser!.uid;
    final ext = path.extension(audioFile.path).toLowerCase();
    if (ext != '.m4a' && ext != '.mp3') throw Exception('Invalid audio format');

    final ref = _storage.ref().child('voice_intros/${uid}_intro$ext');
    final uploadTask = await ref.putFile(audioFile, SettableMetadata(contentType: 'audio/${ext.substring(1)}'));
    return await uploadTask.ref.getDownloadURL();
  }
}
