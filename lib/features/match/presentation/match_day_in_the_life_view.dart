import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchDayInTheLifeView extends StatefulWidget {
  const MatchDayInTheLifeView({super.key});

  @override
  State<MatchDayInTheLifeView> createState() => _MatchDayInTheLifeViewState();
}

class _MatchDayInTheLifeViewState extends State<MatchDayInTheLifeView> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _uploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);
      
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final storageRef = FirebaseStorage.instance.ref().child('$uid/day_in_the_life_$timestamp.jpg');
      await storageRef.putFile(File(image.path), SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('day_in_the_life_posts').add({
        'uid': uid,
        'imageUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('A Day in the Life 📸')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Colors.yellowAccent, size: 80),
            const SizedBox(height: 20),
            const Text('Daily photo prompts. Disappears in 24h.', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 20),
            _isUploading
                ? const CircularProgressIndicator(color: Colors.yellowAccent)
                : ElevatedButton(
                    onPressed: _uploadPhoto,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent),
                    child: const Text('Upload Photo', style: TextStyle(color: Colors.black)),
                  )
          ],
        ),
      ),
    );
  }
}

