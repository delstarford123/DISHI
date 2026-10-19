import 'package:flutter/material.dart';
import '../../../main.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'role_selection_view.dart';
import 'signup_view.dart';
import 'forgot_password_view.dart';
import '../../../core/security/secure_storage_service.dart';
import 'pin_setup_view.dart';
import 'pin_unlock_view.dart';
import '../../student/presentation/student_main_scaffold.dart';
import '../../vendor/presentation/vendor_dashboard_view.dart';
import '../../admin/presentation/admin_dashboard_view.dart';
import '../../parent/presentation/parent_dashboard_view.dart';
import '../../deliv/presentation/deliv_driver_dashboard.dart';
import '../../housing/presentation/housing_dashboard_view.dart';
import '../../fundi/presentation/fundi_dashboard_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() { _errorMessage = 'Please enter both email and password'; });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _handlePostAuthRouting(userCred.user!.uid);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Login failed. Please check your credentials.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
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
      
      await _handlePostAuthRouting(userCred.user!.uid);
    } catch (e) {
       if (mounted) setState(() => _errorMessage = 'Google Sign In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePostAuthRouting(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get(const GetOptions(source: Source.serverAndCache));
      if (!doc.exists) {
        setState(() => _errorMessage = 'User profile not found.');
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      // Support both 'roles' (list) and 'role' (singular string) — admin doc may use either
      final rolesList = data['roles'] as List<dynamic>? ?? [];
      final roleSingular = data['role'] as String? ?? '';
      final primaryRole = rolesList.isNotEmpty
          ? rolesList.first.toString()
          : (roleSingular.isNotEmpty ? roleSingular : 'student');
      final name = data['displayName'] as String? ?? data['name'] as String?;

      final email = data['email'] as String?;
      final phone = data['phoneNumber'] as String?;

      // Fast, parallel execution of storage saving
      final saveFuture = SecureStorageService.saveUserData(
        userId: uid, 
        role: primaryRole,
        name: name,
        email: email,
        phone: phone,
      );
      
      final cloudPin = data['pin'] as String?;
      String? localPin = await SecureStorageService.getHashedPin();

      // Restore PIN from cloud if it's missing locally (e.g. after logout)
      if (cloudPin != null && cloudPin.isNotEmpty && (localPin == null || localPin.isEmpty)) {
        await SecureStorageService.saveHashedPin(cloudPin);
        localPin = cloudPin;
      }
      
      // Wait for user data to save before pushing
      await saveFuture;

      if (mounted) {
        if (localPin == null || localPin.isEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PinSetupView(role: primaryRole)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PinUnlockView(
              onSuccess: () {
                Widget dashboard;
                if (primaryRole == 'vendor') {
                  dashboard = VendorDashboardView(user: {'uid': uid, 'roles': [primaryRole]});
                } else if (primaryRole == 'admin') {
                  dashboard = AdminDashboardView(user: {'uid': uid, 'roles': [primaryRole]});
                } else if (primaryRole == 'parent') {
                  dashboard = ParentDashboardView(user: {'uid': uid, 'roles': [primaryRole]});
                } else if (primaryRole == 'driver') {
                  dashboard = DelivDriverDashboard(user: {'uid': uid, 'roles': [primaryRole]});
                } else if (primaryRole == 'house_owner') {
                  dashboard = HousingDashboardView(user: {'uid': uid, 'roles': [primaryRole]});
                } else if (primaryRole == 'fundi') {
                  dashboard = FundiDashboardView(user: {'uid': uid, 'roles': [primaryRole]});
                } else {
                  dashboard = StudentMainScaffold(user: {'uid': uid, 'roles': [primaryRole]});
                }
                
                appNavigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute(builder: (_) => dashboard),
                );
              },
            )),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load profile. Please try again.');
    }
  }

  Widget _buildGoogleLogo() {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 17,
          fontWeight: FontWeight.w900,
          fontFamily: 'Outfit',
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MPesaTheme.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // ── Hero 512 DISHI Logo Squircle Card ────────────────
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2216),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: MPesaTheme.neonCyan.withOpacity(0.55),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MPesaTheme.neonCyan.withOpacity(0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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
                            size: 44,
                            color: MPesaTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Title & Subtitle ─────────────────────────────────
                const Text(
                  'Welcome to DISHI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Campus Meals & Agency Banking Hub',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 32),
                
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
                    labelText: 'Enter Password',
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordView()));
                    },
                    child: const Text('Forgot Password?', style: TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
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
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                // Dedicated Google Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.18), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: MPesaTheme.cardDark,
                    ),
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGoogleLogo(),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignupView()));
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                        children: const [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              color: MPesaTheme.neonCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Security Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white.withOpacity(0.35)),
                    const SizedBox(width: 6),
                    Text(
                      '256-Bit SSL Encrypted • Powered by Safaricom M-PESA',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
