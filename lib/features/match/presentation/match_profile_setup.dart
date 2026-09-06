import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchProfileSetup extends StatefulWidget {
  const MatchProfileSetup({super.key});

  @override
  State<MatchProfileSetup> createState() => _MatchProfileSetupState();
}

class _MatchProfileSetupState extends State<MatchProfileSetup> {
  final _bioController = TextEditingController();
  final Set<String> _selectedInterests = {};
  
  bool _isLoading = false;
  String? _localProfileImageUrl;
  final ImagePicker _picker = ImagePicker();

  final List<String> _availableInterests = ['Anime', 'Tech', 'Music', 'Sports', 'Gaming', 'Fitness', 'Art'];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()!['profileImageUrl'] != null) {
        setState(() => _localProfileImageUrl = userDoc.data()!['profileImageUrl']);
      }
      
      final matchDoc = await FirebaseFirestore.instance.collection('match_profiles').doc(user.uid).get();
      if (matchDoc.exists) {
        final data = matchDoc.data()!;
        _bioController.text = data['bio'] ?? '';
        final interests = List<String>.from(data['interests'] ?? []);
        setState(() {
          _selectedInterests.addAll(interests);
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final String fileName = 'match_profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child('match_profile_images').child(fileName);

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update the main user profile with this image as well
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profileImageUrl': downloadUrl,
      });

      setState(() {
        _localProfileImageUrl = downloadUrl;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!'), backgroundColor: _neonPink));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
  
  Future<void> _activateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    if (_bioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a short bio!'), backgroundColor: Colors.red));
      return;
    }
    
    if (_localProfileImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a profile picture first!'), backgroundColor: Colors.red));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await FirebaseFirestore.instance.collection('match_profiles').doc(user.uid).set({
        'uid': user.uid,
        'bio': _bioController.text.trim(),
        'interests': _selectedInterests.toList(),
        'primaryLoveLanguage': '',
        'is_premium': false,
        'isVerified': false,
        'vibeTags': [],
        'swipeCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match Profile Activated!'), backgroundColor: _neonPink));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Build Your Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: _neonPink))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _surfaceLight, 
                          shape: BoxShape.circle, 
                          border: Border.all(color: _neonPink, width: 2),
                          image: _localProfileImageUrl != null 
                              ? DecorationImage(image: NetworkImage(_localProfileImageUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _localProfileImageUrl == null ? const Icon(Icons.person, size: 64, color: _textSecondary) : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: _neonPink, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text('About Me', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'I love late-night coding and spicy food...',
                  hintStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              const Text('My Interests', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._selectedInterests.map((interest) {
                    return InputChip(
                      label: Text(interest, style: const TextStyle(color: Colors.white)),
                      selected: true,
                      selectedColor: _neonPurple,
                      backgroundColor: _surfaceLight,
                      deleteIconColor: Colors.white70,
                      onDeleted: () {
                        setState(() {
                          _selectedInterests.remove(interest);
                        });
                      },
                    );
                  }),
                  ActionChip(
                    label: const Text('+ Add Interest', style: TextStyle(color: _neonPink)),
                    backgroundColor: _surfaceLight,
                    onPressed: () {
                      _showAddInterestDialog();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonPink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _activateProfile,
                child: const Text('ACTIVATE PROFILE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              )
            ],
          ),
    );
  }

  void _showAddInterestDialog() {
    final TextEditingController interestController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text('Add Interest', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: interestController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'e.g. Hiking, Photography...',
              hintStyle: TextStyle(color: _textSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final newInterest = interestController.text.trim();
                if (newInterest.isNotEmpty) {
                  setState(() {
                    _selectedInterests.add(newInterest);
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add', style: TextStyle(color: _neonPink)),
            ),
          ],
        );
      },
    );
  }
}
