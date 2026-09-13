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

class PinUnlockView extends StatefulWidget {
  final VoidCallback onSuccess;

  const PinUnlockView({Key? key, required this.onSuccess}) : super(key: key);

  @override
  _PinUnlockViewState createState() => _PinUnlockViewState();
}

class _PinUnlockViewState extends State<PinUnlockView> {
  final LocalAuthentication auth = LocalAuthentication();
  String currentText = "";
  bool _obscurePin = true;
  bool _isLockedOut = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _checkInitialState();
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

  Future<void> _authenticateBiometric() async {
    if (_isLockedOut) return;
    
    try {
      final String? decryptedHash = await BiometricStorageService.readBiometricKey();
      
      if (decryptedHash != null) {
        String? storedHash = await SecureStorageService.getHashedPin();
        
        if (storedHash == null || decryptedHash == storedHash) {
          await AuthRateLimiter.resetAttempts();
          if (mounted) {
            widget.onSuccess();
          }
        } else {
          setState(() => _errorMessage = "Invalid biometric payload.");
        }
      }
      // If null, user cancelled or failed, they can just use the PIN fallback.
    } catch (e) {
      setState(() => _errorMessage = "Biometric key invalidated. Please use PIN.");
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
        _submitPin();
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
                        onPressed: () => Navigator.pop(context),
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
                        child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    
                  // Elegant PIN Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < currentText.length 
                            ? (_obscurePin ? Colors.white : Colors.transparent)
                            : Colors.transparent,
                        border: Border.all(
                          color: index < currentText.length ? Colors.white : Colors.grey.shade800, 
                          width: 2
                        ),
                      ),
                      child: index < currentText.length && !_obscurePin
                          ? Center(
                              child: Text(
                                currentText[index],
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, height: 1.0),
                              ),
                            )
                          : null,
                    )),
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
                    onBiometricTap: _authenticateBiometric,
                    randomize: false, // Ensures PIN numbers are ordered 1 to 0
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
