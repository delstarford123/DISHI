import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../core/theme/mpesa_theme.dart';
import '../../deliv/presentation/deliv_driver_dashboard.dart';
import '../../deliv/presentation/deliv_registration_view.dart';
import '../../auth/presentation/data_consent_view.dart';
import '../../match/presentation/match_profile_setup.dart';
import '../../fundi/presentation/fundi_registration_view.dart';
import '../../../core/models/user_model.dart';

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

  @override
  void initState() {
    super.initState();
    _localProfileImageUrl = widget.userModel.profileImageUrl;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);

      final String fileName = 'profile_${widget.userModel.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child('profile_images').child(fileName);

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).update({
        'profileImageUrl': downloadUrl,
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
      body: ListView(
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
                    backgroundImage: _localProfileImageUrl != null ? NetworkImage(_localProfileImageUrl!) : null,
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _localProfileImageUrl == null 
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
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Colors.redAccent.withOpacity(0.1),
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DataConsentView(userId: 'current_user_id')));
            },
          ),
          const SizedBox(height: 40),
        ],
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
                      child: Icon(icon, color: iconColor),
                    ),
                    const SizedBox(width: 16),
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
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
}
