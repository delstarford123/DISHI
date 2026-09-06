import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/models/user_model.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Colors.orangeAccent;
const Color _textSecondary = Color(0xFF8B9BB4);

class FundiRegistrationView extends StatefulWidget {
  final UserModel userModel;

  const FundiRegistrationView({super.key, required this.userModel});

  @override
  State<FundiRegistrationView> createState() => _FundiRegistrationViewState();
}

class _FundiRegistrationViewState extends State<FundiRegistrationView> {
  final _formKey = GlobalKey<FormState>();
  final _skillsController = TextEditingController();
  final _rateController = TextEditingController();
  final _bioController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _skillsController.dispose();
    _rateController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _registerFundi() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await FirebaseFirestore.instance.collection('fundi_profiles').doc(user.uid).set({
        'uid': user.uid,
        'displayName': widget.userModel.displayName,
        'profileImageUrl': widget.userModel.profileImageUrl,
        'skills': _skillsController.text.trim(),
        'hourlyRate': double.tryParse(_rateController.text.trim()) ?? 0.0,
        'bio': _bioController.text.trim(),
        'isVerified': false,
        'rating': 0.0,
        'jobsCompleted': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Comrade Fundi Profile Created!'),
          backgroundColor: _neonCyan,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
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
        title: const Text('Become a Comrade Fundi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonOrange))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.handyman, size: 64, color: _neonOrange),
                  const SizedBox(height: 16),
                  const Text('Turn your skills into cash by helping out fellow comrades on campus.', 
                    style: TextStyle(color: _textSecondary, fontSize: 16)),
                  const SizedBox(height: 32),
                  
                  _buildTextField(
                    controller: _skillsController,
                    label: 'Your Skills (e.g., Plumber, Tech Support, Tutor)',
                    icon: Icons.build,
                    validator: (v) => v!.isEmpty ? 'Please enter your skills' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _rateController,
                    label: 'Hourly Rate (Ksh)',
                    icon: Icons.payments,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Please enter your hourly rate' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _bioController,
                    label: 'Short Bio / Experience',
                    icon: Icons.description,
                    maxLines: 3,
                    validator: (v) => v!.isEmpty ? 'Please enter a short bio' : null,
                  ),
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _registerFundi,
                      child: const Text('ACTIVATE PROFILE', 
                        style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, color: _neonOrange),
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _neonOrange)),
      ),
    );
  }
}
