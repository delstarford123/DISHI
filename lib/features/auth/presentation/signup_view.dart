import 'package:flutter/material.dart';
import '../../../core/services/local_auth_service.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/widgets/animated_food_background.dart';
import 'role_selection_view.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_view.dart';
import 'dart:ui';

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _signup() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
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
        'roles': [], // Empty so RoleSelectionView forces a pick
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _routeToRoleSelection();
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

      _routeToRoleSelection();
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleGoogleSignUp() async {
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
          'roles': [],
          'is_google': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      _routeToRoleSelection();
    } catch (e) {
       if (mounted) setState(() => _errorMessage = 'Google Sign Up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _routeToRoleSelection() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedFoodBackground(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.9)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        boxShadow: [BoxShadow(color: MPesaTheme.primaryGreen.withOpacity(0.2), blurRadius: 20)],
                      ),
                      child: Image.asset('assets/img/dishi_logo.png', height: 80, width: 80),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    const Text('Join the DISHI community today', style: TextStyle(fontSize: 16, color: Colors.white70)),
                    const SizedBox(height: 40),

                    GlassCard(
                      blur: 15,
                      opacity: 0.1,
                      padding: const EdgeInsets.all(24.0),
                      borderRadius: 32,
                      child: Column(
                        children: [
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                              child: Text(_errorMessage!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                            ),
                            
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.person, color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.email, color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MPesaTheme.primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 8,
                                shadowColor: MPesaTheme.primaryGreen.withOpacity(0.5),
                              ),
                              child: _isLoading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ),
                          ),
                          
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white24)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('OR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(child: Divider(color: Colors.white24)),
                              ],
                            ),
                          ),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleGoogleSignUp,
                              icon: const Icon(Icons.login, color: Colors.white),
                              label: const Text('Sign Up with Google', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                backgroundColor: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?", style: TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginView())),
                          child: const Text('Sign In', style: TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
