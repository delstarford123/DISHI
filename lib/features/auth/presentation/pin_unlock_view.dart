import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'widgets/custom_secure_keypad.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'forgot_pin_view.dart';
import '../../../core/security/security_service.dart';
import '../../../core/security/auth_rate_limiter.dart';
import '../../../core/security/secure_storage_service.dart';

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
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to proceed',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (didAuthenticate) {
        await AuthRateLimiter.resetAttempts();
        widget.onSuccess();
      }
    } catch (e) {
      setState(() => _errorMessage = "Biometric authentication failed");
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
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Identity Validation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('For security purposes, kindly provide your PIN below:', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('PIN VERIFICATION', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('To proceed with identity validation, kindly\nenter your 4 digit PIN', 
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                  ),
                  
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) => Container(
                    width: 50,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: index < currentText.length ? const Color(0xFF00E5FF) : Colors.grey, width: 3)),
                    ),
                    child: Center(
                      child: Text(
                        index < currentText.length ? (_obscurePin ? '*' : currentText[index]) : '',
                        style: const TextStyle(color: Colors.white, fontSize: 32)
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _obscurePin = !_obscurePin);
                  },
                  icon: Icon(_obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
                  label: Text(_obscurePin ? 'Show PIN' : 'Hide PIN', style: const TextStyle(color: Colors.grey)),
                ),
                
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPinView()),
                    );
                  },
                  child: const Text(
                    'Forgot PIN?',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                // Spacer before keypad
                const SizedBox(height: 8),
                
                CustomSecureKeypad(
                  onKeyPressed: _onKeyPressed,
                  onBackspace: _onBackspace,
                  onBiometricTap: _authenticateBiometric,
                  randomize: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
