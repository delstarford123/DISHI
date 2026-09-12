import 'package:flutter/material.dart';
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) {
        setState(() => _errorMessage = 'User profile not found.');
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final roles = data['roles'] as List<dynamic>? ?? [];
      final primaryRole = roles.isNotEmpty ? roles.first.toString() : 'student';
      final name = data['name'] as String?;
      final email = data['email'] as String?;
      final phone = data['phoneNumber'] as String?;

      await SecureStorageService.saveUserData(
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

      if (mounted) {
        if (localPin == null || localPin.isEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PinSetupView(role: primaryRole)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PinUnlockView(
                onSuccess: () async {
                  if (!mounted) return;
                  final userData = await SecureStorageService.getUserData();
                  final userMap = {
                    'uid': uid,
                    'roles': [primaryRole],
                    'name': userData['name'] ?? '',
                    'email': userData['email'] ?? '',
                    'phoneNumber': userData['phone'] ?? '',
                  };
                  Widget dashboard;
                  if (primaryRole == 'vendor') {
                    dashboard = VendorDashboardView(user: userMap);
                  } else if (primaryRole == 'admin') {
                    dashboard = AdminDashboardView(user: userMap);
                  } else if (primaryRole == 'parent') {
                    dashboard = ParentDashboardView(user: userMap);
                  } else if (primaryRole == 'driver') {
                    dashboard = DelivDriverDashboard(user: userMap);
                  } else if (primaryRole == 'house_owner') {
                    dashboard = HousingDashboardView(user: userMap);
                  } else if (primaryRole == 'fundi') {
                    dashboard = FundiDashboardView(user: userMap);
                  } else {
                    dashboard = StudentMainScaffold(user: userMap);
                  }
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dashboard));
                }
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to route user. Please try again.');
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
                  'Thank you for choosing\nDISHI', 
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
                  'Sign in to continue',
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
                    label: const Text('Sign in with Google', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignupView()));
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                        children: const [
                          TextSpan(
                            text: 'Sign Up',
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
