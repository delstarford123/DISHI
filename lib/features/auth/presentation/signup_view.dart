import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/local_auth_service.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/security/secure_storage_service.dart';
import 'pin_setup_view.dart';
import 'login_view.dart';

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedRole = 'student';
  final List<String> _availableRoles = ['student', 'vendor', 'parent', 'driver', 'house_owner', 'fundi'];
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty || _passwordController.text.isEmpty || _phoneController.text.trim().isEmpty) {
      setState(() { _errorMessage = 'Please fill all fields'; });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'roles': [_selectedRole],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await SecureStorageService.saveUserData(
        userId: userCred.user!.uid, 
        role: _selectedRole,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      _routeToPinSetup();
    } catch (e) {
      // Offline Signup Workflow
      final offlineUid = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      await LocalAuthService.generateAndStoreOfflinePin(offlineUid);
      
      OfflineSyncService.queueRequest({
        'endpoint': '/api/auth/sync_offline_profile',
        'method': 'POST',
        'payload': {
          'offline_uid': offlineUid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        },
      });

      _routeToPinSetup();
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() { _errorMessage = 'Please enter your phone number before continuing with Google'; });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final googleSignIn = GoogleSignIn();
      try { await googleSignIn.disconnect(); } catch (_) {}
      await googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final doc = await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).get();
      
      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
          'name': userCred.user!.displayName ?? 'Google User',
          'email': userCred.user!.email,
          'phoneNumber': _phoneController.text.trim(),
          'roles': [_selectedRole],
          'is_google': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await SecureStorageService.saveUserData(
        userId: userCred.user!.uid, 
        role: _selectedRole,
        name: userCred.user!.displayName ?? 'Google User',
        email: userCred.user!.email,
        phone: _phoneController.text.trim(),
      );
      
      _routeToPinSetup();
    } catch (e) {
       if (mounted) setState(() => _errorMessage = 'Google Sign Up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _routeToPinSetup() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PinSetupView(role: _selectedRole)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MPesaTheme.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset(
                    'assets/img/dishi_logo.png', 
                    height: 60,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, size: 60, color: MPesaTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Create\nAccount', 
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    fontFamily: 'Outfit',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Join the DISHI community today.',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 40),
                
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: MPesaTheme.errorBackground.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MPesaTheme.primaryRed.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: MPesaTheme.primaryRed, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: MPesaTheme.primaryRed), textAlign: TextAlign.left),
                        ),
                      ],
                    ),
                  ),
                  
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: MPesaTheme.primaryGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: MPesaTheme.cardDark,
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: MPesaTheme.primaryGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: MPesaTheme.cardDark,
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: MPesaTheme.primaryGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: MPesaTheme.cardDark,
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: MPesaTheme.primaryGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: MPesaTheme.cardDark,
                  ),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  dropdownColor: MPesaTheme.cardDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.badge_outlined, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: MPesaTheme.primaryGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: MPesaTheme.cardDark,
                  ),
                  items: _availableRoles.map((role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role.substring(0, 1).toUpperCase() + role.substring(1).replaceAll('_', ' ')),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MPesaTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      shadowColor: MPesaTheme.primaryGreen.withOpacity(0.5),
                    ),
                    onPressed: _isLoading ? null : _signup,
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    ),
                    const Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 24),
                // Dedicated Google Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: MPesaTheme.cardDark,
                    ),
                    icon: Image.asset(
                      'assets/img/google_icon.png', 
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 30),
                    ),
                    label: const Text('Sign up with Google', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    onPressed: _isLoading ? null : _handleGoogleSignUp,
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginView()));
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                        children: const [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
