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
  
  // New Match Profile Features
  String? _genderPreference;
  String? _lookingFor;
  String? _starSign;
  final _heightController = TextEditingController();
  String? _drinkingHabit;
  String? _smokingHabit;
  String? _workoutHabit;
  String? _loveLanguage;
  final _spotifyController = TextEditingController();
  String? _profilePrompt;
  final _promptAnswerController = TextEditingController();
  
  final _genderPrefs = ['Male', 'Female', 'Everyone'];
  final _lookingForOptions = ['Serious Relationship', 'Friends', 'Study Buddy', 'Food Swap'];
  final _starSigns = ['Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo', 'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'];
  final _habits = ['Frequently', 'Socially', 'Rarely', 'Never'];
  final _workoutHabits = ['Active', 'Sometimes', 'Never'];
  final _loveLanguages = ['Words of Affirmation', 'Physical Touch', 'Receiving Gifts', 'Quality Time', 'Acts of Service'];
  final _prompts = ['The way to my heart is...', 'I geek out on...', 'A random fact I love is...', 'My simple pleasure is...'];
  
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
          _genderPreference = data['genderPreference'];
          _lookingFor = data['lookingFor'];
          _starSign = data['starSign'];
          _heightController.text = data['height'] ?? '';
          _drinkingHabit = data['drinkingHabit'];
          _smokingHabit = data['smokingHabit'];
          _workoutHabit = data['workoutHabit'];
          _loveLanguage = data['loveLanguage'];
          _spotifyController.text = data['spotifyAnthem'] ?? '';
          _profilePrompt = data['profilePrompt'];
          _promptAnswerController.text = data['promptAnswer'] ?? '';
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _heightController.dispose();
    _spotifyController.dispose();
    _promptAnswerController.dispose();
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
        'primaryLoveLanguage': _loveLanguage ?? '',
        'genderPreference': _genderPreference,
        'lookingFor': _lookingFor,
        'starSign': _starSign,
        'height': _heightController.text.trim(),
        'drinkingHabit': _drinkingHabit,
        'smokingHabit': _smokingHabit,
        'workoutHabit': _workoutHabit,
        'loveLanguage': _loveLanguage,
        'spotifyAnthem': _spotifyController.text.trim(),
        'profilePrompt': _profilePrompt,
        'promptAnswer': _promptAnswerController.text.trim(),
        'is_premium': false,
        'isVerified': false,
        'vibeTags': [],
        'swipeCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
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
              const SizedBox(height: 32),
              const Text('Vibes & Compatibility', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildDropdown('Gender Preference', _genderPrefs, _genderPreference, (val) => setState(() => _genderPreference = val)),
              _buildDropdown('Looking For', _lookingForOptions, _lookingFor, (val) => setState(() => _lookingFor = val)),
              _buildDropdown('Star Sign', _starSigns, _starSign, (val) => setState(() => _starSign = val)),
              _buildTextField('Height (e.g. 5\'9")', _heightController, icon: Icons.height),
              _buildDropdown('Love Language', _loveLanguages, _loveLanguage, (val) => setState(() => _loveLanguage = val)),
              
              const SizedBox(height: 32),
              const Text('Habits', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildDropdown('Drinking', _habits, _drinkingHabit, (val) => setState(() => _drinkingHabit = val)),
              _buildDropdown('Smoking', _habits, _smokingHabit, (val) => setState(() => _smokingHabit = val)),
              _buildDropdown('Workout', _workoutHabits, _workoutHabit, (val) => setState(() => _workoutHabit = val)),
              
              const SizedBox(height: 32),
              const Text('Personality', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTextField('Spotify Anthem (Link or Title)', _spotifyController, icon: Icons.music_note),
              const SizedBox(height: 16),
              _buildDropdown('Choose a Prompt', _prompts, _profilePrompt, (val) => setState(() => _profilePrompt = val)),
              if (_profilePrompt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _buildTextField('Your Answer...', _promptAnswerController, maxLines: 2),
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

  Widget _buildDropdown(String label, List<String> items, String? currentValue, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          hint: Text(label, style: const TextStyle(color: _textSecondary)),
          isExpanded: true,
          dropdownColor: _cardColor,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {IconData? icon, int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textSecondary),
          prefixIcon: icon != null ? Icon(icon, color: _textSecondary) : null,
          filled: true,
          fillColor: _surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
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
