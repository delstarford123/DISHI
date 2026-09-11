import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../auth/presentation/login_view.dart';
import '../../../core/services/secure_storage_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class ParentProfileSettings extends StatefulWidget {
  final Map<String, dynamic> userMap;

  const ParentProfileSettings({super.key, required this.userMap});

  @override
  State<ParentProfileSettings> createState() => _ParentProfileSettingsState();
}

class _ParentProfileSettingsState extends State<ParentProfileSettings> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsAlerts = true;
  String? _localProfileImageUrl;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _localProfileImageUrl = widget.userMap['profileImageUrl'];
    _phoneController.text = widget.userMap['phone'] ?? widget.userMap['phone_number'] ?? '';
    _bioController.text = widget.userMap['bio'] ?? '';
    _pushNotifications = widget.userMap['pushNotifications'] ?? true;
    _emailNotifications = widget.userMap['emailNotifications'] ?? true;
    _smsAlerts = widget.userMap['smsAlerts'] ?? true;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);

      final String actualUid = FirebaseAuth.instance.currentUser?.uid ?? widget.userMap['uid'] ?? 'parent';
      final String fileName = 'profile_${actualUid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child('profile_images').child(fileName);

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'profileImageUrl': downloadUrl,
        });
      }

      setState(() {
        _localProfileImageUrl = downloadUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!'), backgroundColor: MPesaTheme.mpesaGreen));
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _saveField(String key, dynamic value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({key: value});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated'), backgroundColor: MPesaTheme.mpesaGreen));
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MPesaTheme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: MPesaTheme.mpesaRed)),
        title: const Text('Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: MPesaTheme.textSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: MPesaTheme.textSecondaryColor)),
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
              backgroundColor: MPesaTheme.mpesaRed,
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
    final parentName = widget.userMap['name'] ?? widget.userMap['displayName'] ?? 'Parent';
    final email = widget.userMap['email'] ?? 'N/A';

    return Scaffold(
      backgroundColor: MPesaTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Parent Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _localProfileImageUrl != null
                          ? NetworkImage(_localProfileImageUrl!)
                          : const AssetImage('assets/img/dishi_logo.png')
                              as ImageProvider,
                      backgroundColor: MPesaTheme.surfaceLightColor,
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : _localProfileImageUrl == null
                              ? const Icon(Icons.person, color: MPesaTheme.textSecondaryColor, size: 50)
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: MPesaTheme.mpesaGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              parentName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: const TextStyle(color: MPesaTheme.textSecondaryColor),
            ),
            const SizedBox(height: 32),
            
            _buildSectionHeader('Contact Info'),
            _buildSettingTextField(label: 'Phone Number', icon: Icons.phone, controller: _phoneController, firestoreKey: 'phone_number', keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Personal Details'),
            _buildSettingTextField(label: 'Bio', icon: Icons.description, controller: _bioController, firestoreKey: 'bio', maxLines: 3),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Notification Preferences'),
            _buildSwitchTile(
              title: 'Push Notifications',
              subtitle: 'Receive alerts for child spending',
              value: _pushNotifications,
              onChanged: (val) {
                setState(() => _pushNotifications = val);
                _saveField('pushNotifications', val);
              },
            ),
            _buildSwitchTile(
              title: 'Email Notifications',
              subtitle: 'Receive weekly summaries',
              value: _emailNotifications,
              onChanged: (val) {
                setState(() => _emailNotifications = val);
                _saveField('emailNotifications', val);
              },
            ),
            _buildSwitchTile(
              title: 'SMS Alerts',
              subtitle: 'For emergency security alerts',
              value: _smsAlerts,
              onChanged: (val) {
                setState(() => _smsAlerts = val);
                _saveField('smsAlerts', val);
              },
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('Security'),
            _buildListTile(
                icon: Icons.lock,
                title: 'Change Password',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Change Password coming soon')));
                }),
            _buildListTile(
                icon: Icons.security,
                title: 'Parent PIN Settings',
                subtitle: 'Manage vault authorization PIN',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN Settings coming soon')));
                }),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Support & Legal'),
            _buildListTile(
                icon: Icons.help,
                title: 'Help Center',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Help Center coming soon')));
                }),
            _buildListTile(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () {}),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.mpesaRed.withOpacity(0.1),
                  foregroundColor: MPesaTheme.mpesaRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: MPesaTheme.mpesaRed),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: MPesaTheme.mpesaGreen,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MPesaTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: MPesaTheme.textSecondaryColor, fontSize: 12)),
        value: value,
        activeColor: MPesaTheme.mpesaGreen,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSettingTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String firestoreKey,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MPesaTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: MPesaTheme.textSecondaryColor),
          prefixIcon: Icon(icon, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          suffixIcon: IconButton(
            icon: const Icon(Icons.save, color: MPesaTheme.mpesaGreen),
            onPressed: () => _saveField(firestoreKey, controller.text.trim()),
          ),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MPesaTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MPesaTheme.surfaceLightColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(color: MPesaTheme.textSecondaryColor))
            : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Colors.white54)
            : null,
        onTap: onTap,
      ),
    );
  }
}

