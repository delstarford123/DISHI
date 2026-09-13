import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'widgets/custom_secure_keypad.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'forgot_pin_view.dart';
import 'pin_setup_view.dart';
import '../../../core/security/security_service.dart';
import '../../../core/security/auth_rate_limiter.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/biometric_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'login_view.dart';

class PinUnlockView extends StatefulWidget {
  final VoidCallback onSuccess;

  const PinUnlockView({Key? key, required this.onSuccess}) : super(key: key);

  @override
  _PinUnlockViewState createState() => _PinUnlockViewState();
}

class _PinUnlockViewState extends State<PinUnlockView> with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  String currentText = "";
  bool _obscurePin = true;
  bool _isLockedOut = false;
  String _errorMessage = "";
  late AnimationController _waveController;
  bool _isBiometricSupported = false;
  bool _isAuthenticatingBiometric = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _checkInitialState();
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    bool supported = await BiometricStorageService.isSupported();
    if (mounted) {
      setState(() => _isBiometricSupported = supported);
      if (supported) {
        // Feature: Auto-trigger on startup for convenience
        _authenticateBiometric(autoTriggered: true);
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialState() async {
    String? storedHash = await SecureStorageService.getHashedPin();
    if (storedHash == null || storedHash.isEmpty) {
      final userData = await SecureStorageService.getUserData();
      final role = userData['role'] ?? 'student';
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PinSetupView(role: role)),
        );
      }
      return;
    }
    _checkLockout();
  }

  Future<void> _checkLockout() async {
    bool locked = await AuthRateLimiter.isLockedOut();
    if (mounted) {
      setState(() {
        _isLockedOut = locked;
      });
      if (locked) {
        // Automatically take them to forgot PIN
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Too many failed attempts. Redirecting to reset PIN...')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ForgotPinView()),
        );
      }
    }
  }

  Future<void> _authenticateBiometric({bool autoTriggered = false}) async {
    if (_isLockedOut || _isAuthenticatingBiometric) return;
    
    if (!autoTriggered) {
      // Feature: Haptic feedback for UI responsiveness
      HapticFeedback.lightImpact();
      // Feature: Visual hint during scan
      setState(() => _errorMessage = "Scan your fingerprint or face...");
    }
    
    setState(() => _isAuthenticatingBiometric = true);
    
    try {
      final String? decryptedHash = await BiometricStorageService.readBiometricKey();
      
      if (decryptedHash != null) {
        String? storedHash = await SecureStorageService.getHashedPin();
        
        if (storedHash == null || decryptedHash == storedHash) {
          // Feature: Success Haptic feedback
          HapticFeedback.mediumImpact();
          await AuthRateLimiter.resetAttempts();
          if (mounted) {
            widget.onSuccess();
          }
        } else {
          // Feature: Error Haptic feedback
          HapticFeedback.heavyImpact();
          setState(() => _errorMessage = "Invalid biometric payload.");
        }
      } else {
        if (!autoTriggered) {
          setState(() => _errorMessage = "Biometric authentication failed or was cancelled.");
        } else {
          setState(() => _errorMessage = ""); // Clear any message if they just cancelled the auto-prompt
        }
      }
    } catch (e) {
      setState(() => _errorMessage = "Biometric key invalidated. Please use PIN.");
    } finally {
      if (mounted) {
        setState(() => _isAuthenticatingBiometric = false);
      }
    }
  }

  void _onKeyPressed(String value) {
    if (_isLockedOut) return;
    if (currentText.length < 4) {
      setState(() {
        currentText += value;
        _errorMessage = "";
      });
      if (currentText.length == 4) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _submitPin();
        });
      }
    }
  }

  void _onBackspace() {
    if (currentText.isNotEmpty) {
      setState(() {
        currentText = currentText.substring(0, currentText.length - 1);
      });
    }
  }

  Future<void> _submitPin() async {
    if (_isLockedOut) return;
    
    // Obfuscate immediately from UI state
    String enteredPin = currentText;
    setState(() => currentText = "");
    
    String hashedInput = SecurityService.hashPin(enteredPin);
    String? storedHash = await SecureStorageService.getHashedPin();
    
    // In memory obfuscation: clear immediately
    enteredPin = "******";
    
    if (storedHash == null || hashedInput == storedHash) {
      // Success (Note: null check is for development bypass if PIN isn't set)
      await AuthRateLimiter.resetAttempts();
      widget.onSuccess();
    } else {
      await AuthRateLimiter.recordFailedAttempt();
      _checkLockout();
      if (!_isLockedOut) {
        setState(() => _errorMessage = "Incorrect PIN. Please try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9), // Dark translucent background look
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A), // Sleek dark card color
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 15,
                  spreadRadius: 5,
                  offset: Offset(0, 5),
                )
              ]
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Identity Validation', 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        )
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey), 
                        onPressed: () async {
                          // Since they are trapped in the PIN screen, closing it means they want to switch accounts/exit.
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context, 
                              MaterialPageRoute(builder: (context) => const LoginView()),
                            );
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For security purposes, kindly provide your PIN below.', 
                    style: TextStyle(color: Colors.white70, fontSize: 14)
                  ),
                  const SizedBox(height: 24),
                  
                  // Professional Verification Box
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user_outlined, color: Colors.green, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Enter your 4-digit PIN to proceed securely.',
                            style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  if (_errorMessage.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage, 
                          style: TextStyle(
                            color: _errorMessage.contains("Scan") ? Colors.greenAccent : Colors.redAccent, 
                            fontSize: 14, 
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                  // Elegant PIN Indicator
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final bool isFilled = index < currentText.length;
                          // Calculate wave offset based on time and index
                          final double waveOffset = math.sin((_waveController.value * 2 * math.pi) + (index * math.pi / 2)) * 8.0;
                          
                          return Transform.translate(
                            offset: Offset(0, waveOffset),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 60,
                              height: 80,
                              decoration: BoxDecoration(
                                color: isFilled ? const Color(0xFF00E5FF).withOpacity(0.15) : const Color(0xFF1E1E1E), // MPesaTheme.neonCyan and cardDark
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isFilled ? const Color(0xFF00E5FF) : Colors.white24,
                                  width: 2,
                                ),
                                boxShadow: isFilled ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withOpacity(0.3),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  )
                                ] : [],
                              ),
                              alignment: Alignment.center,
                              child: isFilled 
                                  ? Text(
                                      _obscurePin ? '•' : currentText[index], 
                                      style: TextStyle(
                                        fontSize: _obscurePin ? 48 : 36, 
                                        color: const Color(0xFF00E5FF), 
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      )
                                    )
                                  : null,
                            ),
                          );
                        }),
                      );
                    }
                  ),
                  const SizedBox(height: 32),
                  
                  // Actions Row: Show/Hide & Forgot PIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _obscurePin = !_obscurePin);
                        },
                        icon: Icon(_obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey.shade400, size: 18),
                        label: Text(_obscurePin ? 'Show PIN' : 'Hide PIN', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ForgotPinView()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot PIN?',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Keypad - ordered professionally
                  CustomSecureKeypad(
                    onKeyPressed: _onKeyPressed,
                    onBackspace: _onBackspace,
                    onBiometricTap: () => _authenticateBiometric(autoTriggered: false),
                    randomize: false, // Ensures PIN numbers are ordered 1 to 0
                    showBiometric: _isBiometricSupported, // Feature: Only show if device supports it
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
