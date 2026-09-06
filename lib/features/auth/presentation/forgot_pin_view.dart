import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/api_config.dart';
import '../../../core/theme/mpesa_theme.dart';

class ForgotPinView extends StatefulWidget {
  const ForgotPinView({super.key});

  @override
  State<ForgotPinView> createState() => _ForgotPinViewState();
}

class _ForgotPinViewState extends State<ForgotPinView> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  int _step = 1; // 1: Email, 2: OTP, 3: New PIN
  bool _isLoading = false;
  String? _errorMessage;
  String? _resetToken;
  String? _loggedInEmail;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _loggedInEmail = user.email;
      _emailController.text = user.email!;
    }
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.authPinSendOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        setState(() => _step = 2);
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['error'] ?? 'Failed to send OTP.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit OTP');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.authPinVerifyOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim(), 'otp': otp}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _resetToken = data['reset_token'];
          _step = 3;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['error'] ?? 'Invalid OTP.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPin() async {
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin.length != 4 || confirmPin.length != 4) {
      setState(() => _errorMessage = 'PIN must be exactly 4 digits');
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _errorMessage = 'PINs do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.authPinReset),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'reset_token': _resetToken,
          'new_pin': newPin,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN reset successfully! You can now log in.')),
        );
        Navigator.of(context).pop();
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['error'] ?? 'Failed to reset PIN.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MPesaTheme.darkBg,
      appBar: AppBar(
        title: const Text('Reset PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _step == 1 ? 'Enter your email' : _step == 2 ? 'Verify OTP' : 'Create New PIN',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF92B60).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF92B60).withOpacity(0.5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFF92B60), fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_step == 1) ...[
                const Text('We will send a 6-digit OTP to your registered email address.', style: TextStyle(color: Colors.white54, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                if (_loggedInEmail != null && _loggedInEmail!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: MPesaTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MPesaTheme.neonCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user, color: MPesaTheme.neonCyan),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _loggedInEmail!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Icon(Icons.check_circle, color: MPesaTheme.neonCyan, size: 20),
                      ],
                    ),
                  )
                else
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: MPesaTheme.neonCyan.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: MPesaTheme.neonCyan), borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.email, color: MPesaTheme.neonCyan),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan))
                    : SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _sendOtp,
                          style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Send OTP', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
              ] else if (_step == 2) ...[
                Text('Enter the 6-digit code sent to ${_emailController.text}', style: const TextStyle(color: Colors.white54, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextField(
                  controller: _otpController,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: '6-Digit OTP',
                    labelStyle: const TextStyle(color: Colors.white54, letterSpacing: 0, fontSize: 16),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: MPesaTheme.neonCyan.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: MPesaTheme.neonCyan), borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.password, color: MPesaTheme.neonCyan),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (val) {
                    if (val.length == 6) {
                      FocusScope.of(context).unfocus();
                      _verifyOtp();
                    }
                  },
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan))
                    : SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _verifyOtp,
                          style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Verify Code', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
              ] else if (_step == 3) ...[
                const Text('Secure your account with a new 4-digit PIN.', style: TextStyle(color: Colors.white54, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextField(
                  controller: _newPinController,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 12),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'New 4-Digit PIN',
                    labelStyle: const TextStyle(color: Colors.white54, letterSpacing: 0, fontSize: 16),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: MPesaTheme.neonCyan.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: MPesaTheme.neonCyan), borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock, color: MPesaTheme.neonCyan),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPin ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPin = !_obscureNewPin;
                        });
                      },
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: _obscureNewPin,
                  maxLength: 4,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPinController,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 12),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Confirm PIN',
                    labelStyle: const TextStyle(color: Colors.white54, letterSpacing: 0, fontSize: 16),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: MPesaTheme.neonCyan.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: MPesaTheme.neonCyan), borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock_outline, color: MPesaTheme.neonCyan),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPin ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPin = !_obscureConfirmPin;
                        });
                      },
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: _obscureConfirmPin,
                  maxLength: 4,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan))
                    : SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _resetPin,
                          style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Save New PIN', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
