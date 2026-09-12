import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/mpesa_theme.dart';
import '../../deliv/presentation/deliv_driver_dashboard.dart';
import '../../deliv/presentation/deliv_registration_view.dart';
import '../../auth/presentation/data_consent_view.dart';
import '../../match/presentation/match_profile_setup.dart';
import '../../fundi/presentation/fundi_registration_view.dart';
import '../../../core/models/user_model.dart';
import '../../auth/presentation/login_view.dart';
import '../../../core/services/secure_storage_service.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF161B29);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonBlue = Color(0xFF00E5FF);

class StudentProfileSettings extends StatefulWidget {
  final UserModel userModel;
  
  const StudentProfileSettings({super.key, required this.userModel});

  @override
  State<StudentProfileSettings> createState() => _StudentProfileSettingsState();
}

class _StudentProfileSettingsState extends State<StudentProfileSettings> {
  bool _isDriverMode = false;
  bool _isFundiMode = false;
  bool _autoRoundUp = false;
  
  bool _isUploading = false;
  String? _localProfileImageUrl;
  final ImagePicker _picker = ImagePicker();
  
  final TextEditingController _phoneController = TextEditingController();
  
  // New Fields
  String? _gender;
  DateTime? _dob;
  final _bioController = TextEditingController();
  final _campusController = TextEditingController();
  final _courseController = TextEditingController();
  final _dietaryController = TextEditingController();
  final _foodVibeController = TextEditingController();
  final _instagramController = TextEditingController();
  final _interestsController = TextEditingController();
  bool _pushNotifications = true;
  bool _ghostMode = false;

  @override
  void initState() {
    super.initState();
    _localProfileImageUrl = widget.userModel.profileImageUrl;
    _gender = widget.userModel.gender;
    _dob = widget.userModel.dob;
    _bioController.text = widget.userModel.bio ?? '';
    _campusController.text = widget.userModel.campus ?? '';
    _courseController.text = widget.userModel.course ?? '';
    _dietaryController.text = widget.userModel.dietaryPreferences.join(', ');
    _foodVibeController.text = widget.userModel.foodVibe ?? '';
    _instagramController.text = widget.userModel.instagram ?? '';
    _interestsController.text = widget.userModel.interests.join(', ');
    _pushNotifications = widget.userModel.pushNotifications;
    _ghostMode = widget.userModel.ghostMode;
    
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final actualUid = widget.userModel.uid.isNotEmpty ? widget.userModel.uid : FirebaseAuth.instance.currentUser?.uid;
    if (actualUid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(actualUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          if (data['phone_number'] != null) _phoneController.text = data['phone_number'].toString();
          if (data['gender'] != null) _gender = data['gender'];
          if (data['dob'] != null) _dob = (data['dob'] as Timestamp).toDate();
          if (data['bio'] != null) _bioController.text = data['bio'];
          if (data['campus'] != null) _campusController.text = data['campus'];
          if (data['course'] != null) _courseController.text = data['course'];
          if (data['dietaryPreferences'] != null) _dietaryController.text = List<String>.from(data['dietaryPreferences']).join(', ');
          if (data['foodVibe'] != null) _foodVibeController.text = data['foodVibe'];
          if (data['instagram'] != null) _instagramController.text = data['instagram'];
          if (data['interests'] != null) _interestsController.text = List<String>.from(data['interests']).join(', ');
          if (data['pushNotifications'] != null) _pushNotifications = data['pushNotifications'];
          if (data['ghostMode'] != null) _ghostMode = data['ghostMode'];
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bioController.dispose();
    _campusController.dispose();
    _courseController.dispose();
    _dietaryController.dispose();
    _foodVibeController.dispose();
    _instagramController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);

      final String actualUid = FirebaseAuth.instance.currentUser?.uid ?? widget.userModel.uid;
      final String fileName = 'profile_${actualUid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child('profile_images').child(fileName);

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).update({
        'profileImageUrl': downloadUrl,
      });
      
      // Send in-app notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Profile Updated',
        'message': 'Looking good! Your new profile picture is live.',
        'targetUserId': widget.userModel.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _localProfileImageUrl = downloadUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!'), backgroundColor: _neonCyan));
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _neonPink)),
        title: const Text('Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await SecureStorageService.clearAll();
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginView()),
                  (Route<dynamic> route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonPink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Profile Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Builder(
        builder: (context) {
          final actualUid = widget.userModel.uid.isNotEmpty ? widget.userModel.uid : FirebaseAuth.instance.currentUser?.uid;
          if (actualUid == null || actualUid.isEmpty) {
            return const Center(child: Text("Error: User ID is missing."));
          }
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(actualUid).snapshots(),
        builder: (context, snapshot) {
          final liveImageUrl = snapshot.hasData && snapshot.data!.exists 
              ? (snapshot.data!.data() as Map<String, dynamic>)['profileImageUrl'] 
              : _localProfileImageUrl;
              
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: _neonCyan,
                        backgroundImage: liveImageUrl != null ? NetworkImage(liveImageUrl) : null,
                        child: _isUploading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : liveImageUrl == null 
                                ? const Icon(Icons.person, size: 50, color: Colors.black) 
                                : null,
                      ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: _neonPink, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.userModel.displayName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(widget.userModel.email, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 32),
          
          _buildSectionHeader('Personal Details', Icons.person_outline, _neonCyan),
          const SizedBox(height: 16),
          _buildGenderDropdown(),
          _buildSettingTextField(label: 'Bio', hint: 'Tell us about yourself...', icon: Icons.description, controller: _bioController, firestoreKey: 'bio', maxLines: 3),
          _buildSettingTextField(label: 'Instagram', hint: '@username', icon: Icons.camera_alt, controller: _instagramController, firestoreKey: 'instagram'),
          _buildSectionSaveButton(() => {
            'bio': _bioController.text.trim(),
            'instagram': _instagramController.text.trim(),
          }),
          
          const SizedBox(height: 32),
          _buildSectionHeader('Campus Life', Icons.school, Colors.orangeAccent),
          const SizedBox(height: 16),
          _buildSettingTextField(label: 'Campus/University', hint: 'e.g. UoN', icon: Icons.location_city, controller: _campusController, firestoreKey: 'campus'),
          _buildSettingTextField(label: 'Course/Major', hint: 'e.g. Computer Science', icon: Icons.menu_book, controller: _courseController, firestoreKey: 'course'),
          _buildSectionSaveButton(() => {
            'campus': _campusController.text.trim(),
            'course': _courseController.text.trim(),
          }),
          
          const SizedBox(height: 32),
          _buildSectionHeader('Swapeat Vibe', Icons.restaurant, _neonPink),
          const SizedBox(height: 16),
          _buildSettingTextField(label: 'Dietary Preferences', hint: 'Vegan, Halal, Nut Allergy (comma separated)', icon: Icons.no_food, controller: _dietaryController, firestoreKey: 'dietaryPreferences'),
          _buildSettingTextField(label: 'Food Vibe', hint: 'e.g. Foodie, Chef', icon: Icons.local_dining, controller: _foodVibeController, firestoreKey: 'foodVibe'),
          _buildSettingTextField(label: 'Interests & Hobbies', hint: 'Gaming, Hiking, Coding (comma separated)', icon: Icons.star, controller: _interestsController, firestoreKey: 'interests'),
          _buildSectionSaveButton(() => {
            'dietaryPreferences': _dietaryController.text.trim(),
            'foodVibe': _foodVibeController.text.trim(),
            'interests': _interestsController.text.trim(),
          }),
          
          const SizedBox(height: 32),
          _buildSectionHeader('Contact Info', Icons.phone, _neonPink),
          const SizedBox(height: 16),
          _buildSettingTextField(label: 'Phone Number', hint: 'e.g. 0712345678', icon: Icons.phone, controller: _phoneController, firestoreKey: 'phone_number', keyboardType: TextInputType.phone),
          _buildSectionSaveButton(() => {
            'phone_number': _phoneController.text.trim(),
          }),

          const SizedBox(height: 32),
          
          _buildSectionHeader('App Preferences', Icons.settings, _neonCyan),
          const SizedBox(height: 16),
          _buildToggleCard('Push Notifications', 'Receive match alerts and ecosystem updates', Icons.notifications_active, _neonCyan, _pushNotifications, (val) {
            setState(() => _pushNotifications = val);
            _saveField('pushNotifications', val);
          }),
          _buildToggleCard('Ghost Mode', 'Hide your profile temporarily', Icons.visibility_off, Colors.grey, _ghostMode, (val) {
            setState(() => _ghostMode = val);
            _saveField('ghostMode', val);
          }),
          
          const SizedBox(height: 32),
          
          _buildSectionHeader('Ecosystem Profiles', Icons.account_circle, _neonCyan),
          const SizedBox(height: 16),
          
          _buildProfileCard(
            'Find Your Match Profile', 
            'Update your dating preferences, vibe check, and bio.',
            Icons.favorite,
            _neonPink,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchProfileSetup())),
          ),
          
          _buildToggleCard(
            'Campus Driver Profile',
            'Toggle to instantly switch to the DeLiv Driver Dashboard.',
            Icons.delivery_dining,
            Colors.orange,
            _isDriverMode,
            (val) {
              setState(() => _isDriverMode = val);
              if (val) {
                if (!widget.userModel.isDriverVerified) {
                  setState(() => _isDriverMode = false);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DelivRegistrationView()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DelivDriverDashboard(user: {}))).then((_) {
                    if (mounted) setState(() => _isDriverMode = false);
                  });
                }
              }
            }
          ),
          
          _buildToggleCard(
            'Comrade Fundi Profile',
            'Provide services to students and earn extra cash.',
            Icons.handyman,
            Colors.orangeAccent,
            _isFundiMode,
            (val) {
              setState(() => _isFundiMode = val);
              if (val) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FundiRegistrationView(userModel: widget.userModel))).then((_) {
                  if (mounted) setState(() => _isFundiMode = false);
                });
              }
            },
          ),
          
          const SizedBox(height: 32),
          _buildSectionHeader('Financial Settings', Icons.account_balance_wallet, Colors.greenAccent),
          const SizedBox(height: 16),
          
          _buildToggleCard(
            'Auto Round-Ups',
            'Round up purchases to the nearest 10 Ksh and deposit change into your savings vault.',
            Icons.savings,
            Colors.greenAccent,
            _autoRoundUp,
            (val) {
              setState(() => _autoRoundUp = val);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto Round-Ups ${val ? 'Enabled' : 'Disabled'}')));
            }
          ),

          const SizedBox(height: 32),
          const SizedBox(height: 32),
          SafeArea(
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.redAccent.withOpacity(0.1),
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DataConsentView(userId: 'current_user_id')));
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
            ],
          );
        },
      );
      },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
  
  Widget _buildProfileCard(String title, String subtitle, IconData icon, Color iconColor, VoidCallback onTap) {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      ),
    );
  }

  Widget _buildToggleCard(String title, String subtitle, IconData icon, Color iconColor, bool value, Function(bool) onChanged) {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
                        child: Icon(icon, color: iconColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  activeColor: iconColor,
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGenderDropdown() {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _neonPink.withOpacity(0.15), shape: BoxShape.circle),
          child: const Icon(Icons.wc, color: _neonPink),
        ),
        title: const Text('Gender', style: TextStyle(color: Colors.white54, fontSize: 12)),
        subtitle: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _gender,
            dropdownColor: _cardColor,
            hint: const Text('Select Gender', style: TextStyle(color: Colors.white)),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _gender = val);
                _saveField('gender', val);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String firestoreKey,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Container(
              margin: EdgeInsets.only(top: maxLines > 1 ? 8 : 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: _neonCyan),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                keyboardType: keyboardType,
                maxLines: maxLines,
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) => _saveField(firestoreKey, value.trim()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.save, color: _neonCyan),
              onPressed: () => _saveField(firestoreKey, controller.text.trim()),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSaveButton(Map<String, dynamic> Function() getData) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: ElevatedButton.icon(
          onPressed: () {
            _saveMultipleFields(getData());
          },
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save Section'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _neonCyan,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }

  Future<void> _saveField(String key, dynamic value) async {
    final actualUid = widget.userModel.uid.isNotEmpty ? widget.userModel.uid : FirebaseAuth.instance.currentUser?.uid;
    if (actualUid != null) {
      if (key == 'dietaryPreferences' || key == 'interests') {
        value = (value as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      await FirebaseFirestore.instance.collection('users').doc(actualUid).update({key: value});
      if (key == 'gender') {
        await FirebaseFirestore.instance.collection('match_profiles').doc(actualUid).set({'gender': value}, SetOptions(merge: true));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved!'), backgroundColor: _neonCyan));
      }
    }
  }

  Future<void> _saveMultipleFields(Map<String, dynamic> data) async {
    final actualUid = widget.userModel.uid.isNotEmpty ? widget.userModel.uid : FirebaseAuth.instance.currentUser?.uid;
    if (actualUid != null) {
      if (data.containsKey('dietaryPreferences')) {
        data['dietaryPreferences'] = (data['dietaryPreferences'] as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      if (data.containsKey('interests')) {
        data['interests'] = (data['interests'] as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      
      await FirebaseFirestore.instance.collection('users').doc(actualUid).update(data);
      if (data.containsKey('gender')) {
        await FirebaseFirestore.instance.collection('match_profiles').doc(actualUid).set({'gender': data['gender']}, SetOptions(merge: true));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Section Saved!'), backgroundColor: _neonCyan, duration: const Duration(seconds: 2)));
      }
    }
  }
}
