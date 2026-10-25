import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _agreedToTerms = true;

  static const String privacyPolicyUrl = 'https://dishi.delstarfordworks.co.ke/privacy';
  static const String termsUrl = 'https://dishi.delstarfordworks.co.ke/terms';

  Future<void> _launchLegalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open page.')),
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();

    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'Please accept the Terms of Service & Privacy Policy.';
      });
      return;
    }

    if (name.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty) {
      setState(() { _errorMessage = 'Please fill all fields.'; });
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() { _errorMessage = 'Please enter a valid email address.'; });
      return;
    }

    if (password.length < 6) {
      setState(() { _errorMessage = 'Password must be at least 6 characters.'; });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
        'name': name,
        'email': email,
        'phoneNumber': phone,
        'roles': [_selectedRole],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await SecureStorageService.saveUserData(
        userId: userCred.user!.uid, 
        role: _selectedRole,
        name: name,
        email: email,
        phone: phone,
      );

      _routeToPinSetup();
    } on FirebaseAuthException catch (e) {
      String msg = 'Sign up failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        msg = 'An account already exists with this email. Please sign in.';
      } else if (e.code == 'weak-password') {
        msg = 'Password is too weak. Please use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        msg = 'The email address format is invalid.';
      } else if (e.code == 'network-request-failed') {
        await _handleOfflineSignup(name, email, phone);
        return;
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      await _handleOfflineSignup(name, email, phone);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleOfflineSignup(String name, String email, String phone) async {
    // Offline Signup Workflow
    final offlineUid = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    await LocalAuthService.generateAndStoreOfflinePin(offlineUid);

    await SecureStorageService.saveUserData(
      userId: offlineUid,
      role: _selectedRole,
      name: name,
      email: email,
      phone: phone,
    );
    
    OfflineSyncService.queueRequest({
      'endpoint': '/api/auth/sync_offline_profile',
      'method': 'POST',
      'payload': {
        'offline_uid': offlineUid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': _selectedRole,
      },
    });

    _routeToPinSetup();
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
                const SizedBox(height: 12),

                // ── Hero 512 DISHI Logo Squircle Card ────────────────
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2216),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: MPesaTheme.neonCyan.withOpacity(0.55),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MPesaTheme.neonCyan.withOpacity(0.25),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/img/app_icon_512.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/img/dishi_logo_512.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/img/dishi_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant_rounded,
                              size: 40,
                              color: MPesaTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Create Your Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Join the DISHI campus dining community',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 14,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
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
                const SizedBox(height: 18),

                // Terms of Service & Privacy Policy Agreement Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        activeColor: MPesaTheme.primaryGreen,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white54, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          setState(() {
                            _agreedToTerms = val ?? true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: 'I agree to DISHI\'s ',
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: const TextStyle(
                                color: MPesaTheme.neonGreen,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _launchLegalUrl(termsUrl),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: MPesaTheme.neonGreen,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _launchLegalUrl(privacyPolicyUrl),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
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
                const SizedBox(height: 28),
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
                const SizedBox(height: 24),
                // Footer Legal Links
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _launchLegalUrl(termsUrl),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Terms of Service',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const Text(' • ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      InkWell(
                        onTap: () => _launchLegalUrl(privacyPolicyUrl),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
