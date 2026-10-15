import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/security/security_service.dart';
import '../../../core/security/auth_rate_limiter.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/services/local_auth_service.dart';
import 'widgets/custom_secure_keypad.dart';
import 'forgot_pin_view.dart';
import 'pin_setup_view.dart';
import 'login_view.dart';

class PinUnlockView extends StatefulWidget {
  final VoidCallback onSuccess;

  const PinUnlockView({super.key, required this.onSuccess});

  @override
  State<PinUnlockView> createState() => _PinUnlockViewState();
}

class _PinUnlockViewState extends State<PinUnlockView> with SingleTickerProviderStateMixin {
  String _currentPin = "";
  bool _obscurePin = true;
  bool _isLockedOut = false;
  String _errorMessage = "";
  bool _isBiometricSupported = false;
  bool _isAuthenticatingBiometric = false;
  String _preferredMethod = 'pin'; // 'biometric' or 'pin'
  String _biometricLabel = 'Biometric / Pattern';
  
  String _userName = '';
  String _userRole = '';

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _initSecurityAndPreferences();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _initSecurityAndPreferences() async {
    // 1. Verify PIN exists
    final storedHash = await SecureStorageService.getHashedPin();
    final userData = await SecureStorageService.getUserData();
    final role = userData['role'] ?? 'student';
    final name = userData['name'] ?? '';

    if (mounted) {
      setState(() {
        _userRole = role;
        _userName = name.isNotEmpty ? name : 'User';
      });
    }

    if (storedHash == null || storedHash.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PinSetupView(role: role)),
        );
      }
      return;
    }

    // 2. Check Lockout status
    await _checkLockout();
    if (_isLockedOut) return;

    // 3. Check hardware & preferred authentication method
    final isSupported = await LocalAuthService.isAvailable();
    final label = await LocalAuthService.getBiometricLabel();
    final preferred = await LocalAuthService.getPreferredAuthMethod();

    if (mounted) {
      setState(() {
        _isBiometricSupported = isSupported;
        _biometricLabel = label;
        _preferredMethod = preferred;
      });

      // 4. Auto-trigger biometric only if user preferred it
      if (isSupported && preferred == 'biometric') {
        // Small delay to let the UI finish rendering smoothly
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_isLockedOut) {
            _authenticateBiometric(autoTriggered: true);
          }
        });
      }
    }
  }

  Future<void> _checkLockout() async {
    final locked = await AuthRateLimiter.isLockedOut();
    if (mounted) {
      setState(() => _isLockedOut = locked);
      if (locked) {
        final remainingTime = await AuthRateLimiter.getRemainingLockoutTime();
        if (!mounted) return;
        final minutes = remainingTime?.inMinutes ?? 5;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account locked due to multiple failed attempts. Please reset your PIN or wait $minutes min.'),
            backgroundColor: MPesaTheme.primaryRed,
          ),
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

    setState(() {
      _isAuthenticatingBiometric = true;
      _errorMessage = "";
    });

    try {
      final success = await LocalAuthService.authenticate(
        localizedReason: 'Scan fingerprint or use device pattern to unlock DISHI',
        title: 'DISHI Secure Unlock',
        subtitle: 'Verify using biometric or device screen lock',
        biometricOnly: false,
      );

      if (success) {
        HapticFeedback.mediumImpact();
        // Remember that user verified and prefers biometric authentication
        await LocalAuthService.setPreferredAuthMethod('biometric');
        await AuthRateLimiter.resetAttempts();

        if (mounted) {
          setState(() {
            _preferredMethod = 'biometric';
            _errorMessage = "";
          });
          widget.onSuccess();
        }
      } else {
        HapticFeedback.heavyImpact();
        if (!autoTriggered && mounted) {
          setState(() {
            _errorMessage = "Authentication cancelled or not recognized. Enter your PIN.";
          });
        }
      }
    } catch (e) {
      if (!autoTriggered && mounted) {
        setState(() => _errorMessage = "Biometric error. Please enter your PIN.");
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticatingBiometric = false);
      }
    }
  }

  void _onKeyPressed(String value) {
    if (_isLockedOut) return;
    if (_currentPin.length < 4) {
      setState(() {
        _currentPin += value;
        _errorMessage = "";
      });
      if (_currentPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (mounted) _submitPin();
        });
      }
    }
  }

  void _onBackspace() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        _errorMessage = "";
      });
    }
  }

  void _onClearAll() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = "";
        _errorMessage = "";
      });
    }
  }

  Future<void> _submitPin() async {
    if (_isLockedOut) return;

    final enteredPin = _currentPin;
    setState(() => _currentPin = "");

    final hashedInput = SecurityService.hashPin(enteredPin);
    final storedHash = await SecureStorageService.getHashedPin();

    if (storedHash == null || hashedInput == storedHash) {
      HapticFeedback.mediumImpact();
      await AuthRateLimiter.resetAttempts();
      widget.onSuccess();
    } else {
      await AuthRateLimiter.recordFailedAttempt();
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);

      final locked = await AuthRateLimiter.isLockedOut();
      if (locked) {
        _checkLockout();
      } else {
        final remaining = await AuthRateLimiter.getRemainingAttempts();
        setState(() {
          _errorMessage = "Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} remaining.";
        });
      }
    }
  }

  Future<void> _togglePreferredMethod() async {
    final newMethod = _preferredMethod == 'biometric' ? 'pin' : 'biometric';
    if (newMethod == 'biometric' && !_isBiometricSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometrics or device pattern not available on this device.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    await LocalAuthService.setPreferredAuthMethod(newMethod);
    if (!mounted) return;
    setState(() => _preferredMethod = newMethod);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          newMethod == 'biometric'
              ? 'Default unlock set to Biometric / Pattern.'
              : 'Default unlock set to 4-Digit PIN.',
        ),
        backgroundColor: MPesaTheme.primaryGreen,
        duration: const Duration(seconds: 2),
      ),
    );

    if (newMethod == 'biometric') {
      _authenticateBiometric(autoTriggered: false);
    }
  }

  Widget _buildPinBox(int index) {
    final isFilled = index < _currentPin.length;
    final isCurrent = index == _currentPin.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 58,
      height: 68,
      decoration: BoxDecoration(
        color: isFilled
            ? MPesaTheme.neonCyan.withOpacity(0.12)
            : (isCurrent ? Colors.white.withOpacity(0.08) : MPesaTheme.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFilled
              ? MPesaTheme.neonCyan
              : (isCurrent ? MPesaTheme.primaryGreen : Colors.white24),
          width: isFilled || isCurrent ? 2.0 : 1.0,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: MPesaTheme.neonCyan.withOpacity(0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      alignment: Alignment.center,
      child: isFilled
          ? Text(
              _obscurePin ? '•' : _currentPin[index],
              style: TextStyle(
                fontSize: _obscurePin ? 40 : 28,
                color: MPesaTheme.neonCyan,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                height: 1.0,
              ),
            )
          : (isCurrent
              ? Container(
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: MPesaTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedRole = _userRole.isNotEmpty
        ? (_userRole[0].toUpperCase() + _userRole.substring(1).replaceAll('_', ' '))
        : 'User';

    return Scaffold(
      backgroundColor: MPesaTheme.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar: User Profile Info & Switch Account
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: MPesaTheme.primaryGreen.withOpacity(0.18),
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: MPesaTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isNotEmpty ? 'Welcome, $_userName' : 'Welcome back',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$formattedRole • DISHI Secure Wallet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Switch Account / Log out',
                    icon: const Icon(Icons.logout_rounded, color: Colors.white60, size: 20),
                    onPressed: () async {
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: MPesaTheme.cardDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          content: const Text(
                            'Are you sure you want to sign out and return to the login screen?',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MPesaTheme.primaryRed,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );

                      if (shouldLogout == true) {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginView()),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Preferred Auth Method Switcher Chip
            if (_isBiometricSupported)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: _togglePreferredMethod,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _preferredMethod == 'biometric'
                              ? Icons.fingerprint_rounded
                              : Icons.pin_outlined,
                          color: _preferredMethod == 'biometric'
                              ? MPesaTheme.neonCyan
                              : MPesaTheme.primaryGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _preferredMethod == 'biometric'
                              ? 'Default: Biometric / Pattern'
                              : 'Default: 4-Digit PIN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.swap_horiz_rounded, color: Colors.white.withOpacity(0.5), size: 14),
                      ],
                    ),
                  ),
                ),
              ),

            const Spacer(),

            // Title & Instruction
            const Text(
              'Enter 4-Digit PIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isBiometricSupported
                  ? 'Or tap the fingerprint button for quick unlock'
                  : 'Enter your offline wallet PIN to proceed',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 24),

            // PIN Indicator with Error Shake Animation
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                // Multi-cycle horizontal shake calculation
                final double offset = math.sin(_shakeAnimation.value * math.pi * 5) * 12.0 * (1.0 - _shakeAnimation.value);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) => _buildPinBox(index)),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Error or Informational Message
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MPesaTheme.primaryRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 18),

            // Options Row: Show PIN & Forgot PIN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    icon: Icon(
                      _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white60,
                      size: 16,
                    ),
                    label: Text(
                      _obscurePin ? 'Show PIN' : 'Hide PIN',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
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
                        color: MPesaTheme.neonCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // High-Tech Keypad with Biometric Action Button
            CustomSecureKeypad(
              onKeyPressed: _onKeyPressed,
              onBackspace: _onBackspace,
              onLongPressBackspace: _onClearAll,
              onBiometricTap: () => _authenticateBiometric(autoTriggered: false),
              randomize: false,
              showBiometric: _isBiometricSupported,
              biometricLabel: _biometricLabel,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
