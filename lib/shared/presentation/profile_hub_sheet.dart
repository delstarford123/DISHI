import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/secure_storage_service.dart';
import '../../features/auth/presentation/login_view.dart';
import '../../core/theme/mpesa_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileHubSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const ProfileHubSheet({super.key, required this.user});

  @override
  State<ProfileHubSheet> createState() => _ProfileHubSheetState();
}

class _ProfileHubSheetState extends State<ProfileHubSheet> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _cardColor = const Color(0xFF131A2A);
  final Color _textSecondary = const Color(0xFF8B9BB4);

  bool _pushNotifications = true;
  bool _ghostMode = false;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.user['uid']).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _pushNotifications = _userData?['pushEnabled'] ?? true;
          _ghostMode = _userData?['ghostMode'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateField(String field, dynamic value) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user['uid']).update({field: value});
      setState(() {
        _userData?[field] = value;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update $field')));
    }
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    
    if (pickedFile != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final File file = File(pickedFile.path);
        final ref = FirebaseStorage.instance.ref().child('profile_images/${widget.user['uid']}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        await _updateField('photoUrl', url);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editDisplayName() async {
    final currentName = _userData?['name'] ?? _userData?['displayName'] ?? '';
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Edit Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Enter new name', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty && newName != currentName) {
      await _updateField('name', newName.trim());
      await _updateField('displayName', newName.trim());
    }
  }

  Future<void> _editPhone() async {
    final currentPhone = _userData?['phoneNumber'] ?? '';
    final controller = TextEditingController(text: currentPhone);
    final newPhone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Edit Phone', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Enter new phone number', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newPhone != null && newPhone.trim().isNotEmpty && newPhone != currentPhone) {
      await _updateField('phoneNumber', newPhone.trim());
    }
  }

  Future<void> _logout() async {
    try {
      await SecureStorageService.clearAll();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Delete Account?', style: TextStyle(color: Colors.redAccent)),
        content: const Text('This action is irreversible. All your data, history, and active gigs will be permanently removed.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final pwdController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Re-authenticate', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: pwdController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Enter your password', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, pwdController.text), 
            child: const Text('Confirm', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (password == null || password.isEmpty) return;

    if (mounted) setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final credential = EmailAuthProvider.credential(email: user.email!, password: password);
        await user.reauthenticateWithCredential(credential);
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        await user.delete();
        await SecureStorageService.clearAll();
        
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginView()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: _isLoading && _userData == null 
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Profile Actions'),
                  _buildActionTile(Icons.camera_alt_outlined, 'Change Profile Photo', onTap: _changePhoto),
                  _buildActionTile(Icons.edit_outlined, 'Edit Display Name', onTap: _editDisplayName),
                  _buildActionTile(Icons.phone_outlined, 'Edit Phone Number', onTap: _editPhone),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Preferences'),
                  _buildSwitchTile(Icons.notifications_active_outlined, 'Push Notifications', _pushNotifications, (val) {
                    _updateField('pushEnabled', val);
                    setState(() => _pushNotifications = val);
                  }),
                  _buildSwitchTile(Icons.visibility_off_outlined, 'Ghost Mode', _ghostMode, (val) {
                    _updateField('ghostMode', val);
                    setState(() => _ghostMode = val);
                  }),
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  _buildActionTile(Icons.logout, 'Logout', color: Colors.orangeAccent, onTap: _logout),
                  _buildActionTile(Icons.delete_forever, 'Delete Account', color: Colors.redAccent, onTap: _deleteAccount),
                  const SizedBox(height: 40),
                ],
              ),
        );
      },
    );
  }

  Widget _buildHeader() {
    // Check all known photo field names in priority order
    final photoUrl = _userData?['photoUrl']
        ?? _userData?['profileImageUrl']
        ?? _userData?['profilePic']
        ?? _userData?['image']
        ?? _userData?['studentImageUrl'];
    final name = (_userData?['name'] ?? _userData?['displayName'] ?? widget.user['name'] ?? widget.user['displayName'] ?? 'User').toString();
    final course = (_userData?['course'] ?? '').toString();
    final bio = (_userData?['bio'] ?? '').toString();
    final subtitle = course.isNotEmpty ? course : (bio.isNotEmpty ? bio : null);
    final dishiId = widget.user['uid'].toString().substring(0, 8).toUpperCase();

    return Column(
      children: [
        GestureDetector(
          onTap: _changePhoto,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MPesaTheme.primaryGreen, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: MPesaTheme.primaryGreen.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: _cardColor,
                  backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty)
                      ? NetworkImage(photoUrl.toString())
                      : null,
                  child: (photoUrl == null || photoUrl.toString().isEmpty)
                      ? const Icon(Icons.person, size: 52, color: Colors.white54)
                      : null,
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: MPesaTheme.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: _bgColor, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                    child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined, size: 14, color: _textSecondary),
              const SizedBox(width: 6),
              Text('DISHI ID: $dishiId', style: TextStyle(color: _textSecondary, fontSize: 13, fontFamily: 'monospace')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildActionTile(IconData icon, String title, {Color color = Colors.white, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: MPesaTheme.primaryGreen,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
