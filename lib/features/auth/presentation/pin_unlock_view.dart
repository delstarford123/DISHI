import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../student/presentation/student_main_scaffold.dart';
import 'login_view.dart';
import 'forgot_pin_view.dart';

class PinUnlockView extends StatefulWidget {
  const PinUnlockView({super.key});

  @override
  State<PinUnlockView> createState() => _PinUnlockViewState();
}

class _PinUnlockViewState extends State<PinUnlockView> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isLoading = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _onKeyPress(String key) {
    setState(() {
      if (_pin.length < 4) _pin += key;
      if (_pin.length == 4) {
        _verifyPin();
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    
    final savedPin = await SecureStorageService.getOfflinePin();
    
    setState(() => _isLoading = false);

    if (savedPin == _pin) {
      _routeToDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Incorrect PIN.', style: TextStyle(color: Colors.white)),
          backgroundColor: MPesaTheme.neonPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _pin = '');
    }
  }

  void _routeToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const StudentMainScaffold(user: {})),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MPesaTheme.darkBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
            const SizedBox(height: 16),
            
            // Header Profile / Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MPesaTheme.cardDark,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: MPesaTheme.neonCyan.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: MPesaTheme.neonCyan.withOpacity(0.5), width: 2),
              ),
              child: const Icon(Icons.person, size: 40, color: MPesaTheme.neonCyan),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome Back', 
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              )
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your PIN to unlock DISHI',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            
            // Animated Rectangular PIN Display Area
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final bool isFilled = index < _pin.length;
                    // Calculate wave offset based on time and index
                    final double waveOffset = math.sin((_waveController.value * 2 * math.pi) + (index * math.pi / 2)) * 8.0;
                    
                    return Transform.translate(
                      offset: Offset(0, waveOffset),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 60,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isFilled ? MPesaTheme.neonCyan.withOpacity(0.15) : MPesaTheme.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isFilled ? MPesaTheme.neonCyan : Colors.white24,
                            width: 2,
                          ),
                          boxShadow: isFilled ? [
                            BoxShadow(
                              color: MPesaTheme.neonCyan.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ] : [],
                        ),
                        alignment: Alignment.center,
                        child: isFilled 
                            ? const Text(
                                '•', 
                                style: TextStyle(
                                  fontSize: 48, 
                                  color: MPesaTheme.neonCyan, 
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
            
            const SizedBox(height: 16),
            if (_isLoading) const CircularProgressIndicator(color: MPesaTheme.neonCyan),
            const SizedBox(height: 32),
            
            // Modern Dark Number Pad
            _buildNumberPad(),
            const SizedBox(height: 16),
            
            // Forgot PIN
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPinView()));
              },
              child: const Text(
                'Forgot PIN?', 
                style: TextStyle(
                  color: MPesaTheme.neonCyan,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                )
              ),
            ),
            
            // Logout
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
              },
              child: const Text(
                'Sign out / Switch Account', 
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                )
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['1', '2', '3'].map((k) => _buildKey(k)).toList()),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['4', '5', '6'].map((k) => _buildKey(k)).toList()),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['7', '8', '9'].map((k) => _buildKey(k)).toList()),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 65), // Spacer
              _buildKey('0'),
              GestureDetector(
                onTap: _onBackspace,
                child: Container(
                  width: 65, height: 65, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MPesaTheme.cardDark,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String value) {
    return GestureDetector(
      onTap: () => _onKeyPress(value),
      child: Container(
        width: 65, 
        height: 65, 
        decoration: BoxDecoration(
          color: MPesaTheme.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          value, 
          style: const TextStyle(
            fontSize: 32, 
            fontWeight: FontWeight.w600,
            color: Colors.white,
          )
        ),
      ),
    );
  }
}
