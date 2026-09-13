import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/user_model.dart';
import '../../auth/presentation/login_view.dart';
import '../../../core/services/secure_storage_service.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF161B29);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorProfileView extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const VendorProfileView({super.key, required this.user});

  @override
  State<VendorProfileView> createState() => _VendorProfileViewState();
}

class _VendorProfileViewState extends State<VendorProfileView> {
  bool _isUploading = false;
  String? _localProfileImageUrl;
  final ImagePicker _picker = ImagePicker();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();

  bool _pushNotifications = true;

  @override
  void initState() {
    super.initState();
    _localProfileImageUrl = widget.user['profileImageUrl'];
    _nameController.text = widget.user['name'] ?? widget.user['displayName'] ?? '';
    _phoneController.text = widget.user['phone'] ?? widget.user['phoneNumber'] ?? '';
    
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final actualUid = widget.user['uid'] ?? FirebaseAuth.instance.currentUser?.uid;
    if (actualUid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(actualUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          if (data['displayName'] != null) _nameController.text = data['displayName'];
          if (data['phone_number'] != null) _phoneController.text = data['phone_number'].toString();
          if (data['phone'] != null) _phoneController.text = data['phone'].toString();
          if (data['bio'] != null) _bioController.text = data['bio'];
          if (data['operatingHours'] != null) _hoursController.text = data['operatingHours'];
          if (data['pushNotifications'] != null) _pushNotifications = data['pushNotifications'];
          if (data['profileImageUrl'] != null) _localProfileImageUrl = data['profileImageUrl'];
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);
      
      final uid = widget.user['uid'] ?? FirebaseAuth.instance.currentUser?.uid;
      final ref = FirebaseStorage.instance.ref().child('profile_images').child('$uid.jpg');
      
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImageUrl': url,
      });

      setState(() {
        _localProfileImageUrl = url;
        _isUploading = false;
      });
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated', style: TextStyle(color: Colors.black)), backgroundColor: _neonCyan));
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveProfile() async {
    final uid = widget.user['uid'] ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'displayName': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'operatingHours': _hoursController.text.trim(),
        'pushNotifications': _pushNotifications,
      });
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully!', style: TextStyle(color: Colors.black)), backgroundColor: _neonCyan));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    }
  }

  Future<void> _logout() async {
    await SecureStorageService.clearAll();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text('Vendor Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: _cardColor,
                      backgroundImage: _localProfileImageUrl != null ? NetworkImage(_localProfileImageUrl!) : null,
                      child: _localProfileImageUrl == null
                          ? const Icon(Icons.store, size: 60, color: _textSecondary)
                          : null,
                    ),
                  ),
                  if (_isUploading)
                    const Positioned(
                      child: CircularProgressIndicator(color: _neonCyan),
                    )
                  else
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: _neonCyan,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              _buildTextField('Shop Name', _nameController, Icons.storefront),
              const SizedBox(height: 16),
              _buildTextField('Phone Number', _phoneController, Icons.phone, TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField('Operating Hours (e.g. 8AM - 8PM)', _hoursController, Icons.access_time),
              const SizedBox(height: 16),
              _buildTextField('Bio / Description', _bioController, Icons.info_outline, TextInputType.multiline, 3),
              const SizedBox(height: 24),
              
              // Toggles
              Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: SwitchListTile(
                  title: const Text('Push Notifications', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Receive alerts for new orders & updates', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  value: _pushNotifications,
                  activeColor: _neonCyan,
                  onChanged: (bool value) {
                    setState(() => _pushNotifications = value);
                  },
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: _neonPink),
                  label: const Text('Logout', style: TextStyle(color: _neonPink, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _neonPink),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, [TextInputType type = TextInputType.text, int maxLines = 1]) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, color: _neonCyan),
        filled: true,
        fillColor: _cardColor,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _neonCyan)),
      ),
    );
  }
}
