import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/security_service.dart';
import '../../../core/security/biometric_storage_service.dart';
import '../../../core/services/local_auth_service.dart';
import '../../student/presentation/student_main_scaffold.dart';
import '../../vendor/presentation/vendor_dashboard_view.dart';
import '../../admin/presentation/admin_dashboard_view.dart';
import '../../parent/presentation/parent_dashboard_view.dart';
import '../../deliv/presentation/deliv_driver_dashboard.dart';
import '../../housing/presentation/housing_dashboard_view.dart';
import '../../fundi/presentation/fundi_dashboard_view.dart';
import 'widgets/custom_secure_keypad.dart';

class PinSetupView extends StatefulWidget {
  final String role;
  const PinSetupView({super.key, required this.role});

  @override
  State<PinSetupView> createState() => _PinSetupViewState();
}

class _PinSetupViewState extends State<PinSetupView> with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';
  bool _isSaving = false;

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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String key) {
    if (_isSaving) return;

    setState(() {
      _errorMessage = '';
      if (!_isConfirming) {
        if (_pin.length < 4) _pin += key;
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 60), () {
            if (mounted) {
              setState(() {
                _isConfirming = true;
              });
            }
          });
        }
      } else {
        if (_confirmPin.length < 4) _confirmPin += key;
        if (_confirmPin.length == 4) {
          Future.delayed(const Duration(milliseconds: 60), () {
            if (mounted) _verifyAndSave();
          });
        }
      }
    });
  }

  void _onBackspace() {
    if (_isSaving) return;

    setState(() {
      _errorMessage = '';
      if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  void _onClearAll() {
    if (_isSaving) return;
    setState(() {
      _errorMessage = '';
      if (_isConfirming) {
        _confirmPin = '';
      } else {
        _pin = '';
      }
    });
  }

  Future<void> _verifyAndSave() async {
    if (_pin == _confirmPin) {
      setState(() => _isSaving = true);
      HapticFeedback.mediumImpact();

      // 1. Save hashed PIN to secure storage
      final hashed = SecurityService.hashPin(_pin);
      await SecureStorageService.saveHashedPin(hashed);

      // 2. Synchronize with cloud
      try {
        if (await BiometricStorageService.isSupported()) {
          await BiometricStorageService.saveBiometricKey(hashed);
        }
      } catch (e) {
        debugPrint('Biometric storage not available: $e');
      }

      final userData = await SecureStorageService.getUserData();
      final uid = userData['userId'];
      if (uid != null && uid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({'pin': hashed});
        } catch (e) {
          debugPrint('Error saving PIN to cloud: $e');
        }
      }

      // 3. Prompt user to choose preferred quick unlock method if device supports it
      final isBiometricAvailable = await LocalAuthService.isAvailable();
      if (isBiometricAvailable && mounted) {
        setState(() => _isSaving = false);
        await _showPreferredAuthMethodModal(userData);
      } else {
        await LocalAuthService.setPreferredAuthMethod('pin');
        if (mounted) {
          _navigateToDashboard(userData);
        }
      }
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _confirmPin = '';
      });
    }
  }

  Future<void> _showPreferredAuthMethodModal(Map<String, String?> userData) async {
    final label = await LocalAuthService.getBiometricLabel();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(
            color: Color(0xFF161616),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MPesaTheme.neonCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.security_rounded, color: MPesaTheme.neonCyan, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Default Unlock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'We will remember your choice for next time.',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Option 1: Biometric / Pattern (Recommended)
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  // Verify biometric on the spot
                  final didAuth = await LocalAuthService.authenticate(
                    localizedReason: 'Confirm $label unlock for DISHI',
                    title: 'Enable $label Unlock',
                    subtitle: 'Verify your identity to set as default login',
                  );

                  if (didAuth) {
                    await LocalAuthService.setPreferredAuthMethod('biometric');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label unlock enabled and remembered!'),
                          backgroundColor: MPesaTheme.primaryGreen,
                        ),
                      );
                      _navigateToDashboard(userData);
                    }
                  } else {
                    // Fallback to PIN if user cancelled
                    await LocalAuthService.setPreferredAuthMethod('pin');
                    if (mounted) {
                      _navigateToDashboard(userData);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MPesaTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MPesaTheme.neonCyan.withOpacity(0.4), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MPesaTheme.neonCyan.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fingerprint_rounded, color: MPesaTheme.neonCyan, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: MPesaTheme.primaryGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'RECOMMENDED',
                                    style: TextStyle(
                                      color: MPesaTheme.primaryGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Instant 1-touch unlock with fingerprint, Face ID, or pattern.',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Option 2: 4-Digit PIN
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await LocalAuthService.setPreferredAuthMethod('pin');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('4-Digit PIN set as your default unlock.'),
                        backgroundColor: MPesaTheme.primaryGreen,
                      ),
                    );
                    _navigateToDashboard(userData);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MPesaTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.dialpad_rounded, color: Colors.white70, size: 26),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '4-Digit PIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Always type your 4-digit PIN on the keypad.',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToDashboard(Map<String, String?> userData) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          final userMap = {
            'uid': userData['userId'] ?? '',
            'roles': [widget.role],
            'name': userData['name'] ?? '',
            'email': userData['email'] ?? '',
            'phoneNumber': userData['phone'] ?? '',
          };
          if (widget.role == 'vendor') return VendorDashboardView(user: userMap);
          if (widget.role == 'admin') return AdminDashboardView(user: userMap);
          if (widget.role == 'parent') return ParentDashboardView(user: userMap);
          if (widget.role == 'driver') return DelivDriverDashboard(user: userMap);
          if (widget.role == 'house_owner') return HousingDashboardView(user: userMap);
          if (widget.role == 'fundi') return FundiDashboardView(user: userMap);
          return StudentMainScaffold(user: userMap);
        },
      ),
    );
  }

  Widget _buildPinBox(int index, String activePin) {
    final isFilled = index < activePin.length;
    final isCurrent = index == activePin.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 60,
      height: 72,
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
          ? const Text(
              '•',
              style: TextStyle(
                fontSize: 42,
                color: MPesaTheme.neonCyan,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            )
          : (isCurrent
              ? Container(
                  width: 14,
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
    final activePin = _isConfirming ? _confirmPin : _pin;
    final title = _isConfirming ? 'Confirm your PIN' : 'Create 4-Digit PIN';
    final subtitle = _isConfirming
        ? 'Re-enter the 4-digit PIN to confirm'
        : 'This PIN protects your wallet and transactions';

    return Scaffold(
      backgroundColor: MPesaTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isConfirming
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isConfirming = false;
                    _confirmPin = '';
                    _errorMessage = '';
                  });
                },
              )
            : const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isConfirming ? 'Step 2 of 2' : 'Step 1 of 2',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Outfit',
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
            ),
            const SizedBox(height: 36),

            // PIN Display Boxes with Shake Effect
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final double offset = math.sin(_shakeAnimation.value * math.pi * 5) * 12.0 * (1.0 - _shakeAnimation.value);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) => _buildPinBox(index, activePin)),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: MPesaTheme.primaryRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (_isSaving)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: MPesaTheme.neonCyan)),
                  SizedBox(width: 10),
                  Text('Securing your wallet...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              )
            else
              const SizedBox(height: 16),

            const Spacer(),

            // Custom Secure Keypad
            CustomSecureKeypad(
              onKeyPressed: _onKeyPress,
              onBackspace: _onBackspace,
              onLongPressBackspace: _onClearAll,
              onBiometricTap: () {},
              showBiometric: false, // Biometric choice happens once PIN is created
              randomize: false,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
