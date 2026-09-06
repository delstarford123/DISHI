import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../student/presentation/student_main_scaffold.dart';
import '../../vendor/presentation/vendor_dashboard_view.dart';
import '../../admin/presentation/admin_dashboard_view.dart';
import '../../parent/presentation/parent_dashboard_view.dart';
import '../../deliv/presentation/deliv_driver_dashboard.dart';
import '../../housing/presentation/housing_dashboard_view.dart';
import '../../fundi/presentation/fundi_dashboard_view.dart';
import '../../../core/services/secure_storage_service.dart';

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
      if (!_isConfirming) {
        if (_pin.length < 4) _pin += key;
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _isConfirming = true);
          });
        }
      } else {
        if (_confirmPin.length < 4) _confirmPin += key;
        if (_confirmPin.length == 4) {
          _verifyAndSave();
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  Future<void> _verifyAndSave() async {
    if (_pin == _confirmPin) {
      // Save PIN securely
      await SecureStorageService.saveOfflinePin(_pin);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              final userMap = {'roles': [widget.role]};
              if (widget.role == 'vendor') return VendorDashboardView(user: userMap);
              if (widget.role == 'admin') return AdminDashboardView(user: userMap);
              if (widget.role == 'parent') return ParentDashboardView(user: userMap);
              if (widget.role == 'driver') return DelivDriverDashboard(user: userMap);
              if (widget.role == 'house_owner') return HousingDashboardView(user: userMap);
              if (widget.role == 'fundi') return FundiDashboardView(user: userMap);
              return StudentMainScaffold(user: userMap);
            }
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PINs do not match. Try again.', style: TextStyle(color: Colors.white)),
          backgroundColor: MPesaTheme.neonPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;
    final title = _isConfirming ? 'Confirm your PIN' : 'Create an Offline PIN';
    final subtitle = _isConfirming ? 'Re-enter your 4-digit PIN' : 'This protects your wallet when offline';

    return Scaffold(
      backgroundColor: MPesaTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isConfirming
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() {
                  _isConfirming = false;
                  _confirmPin = '';
                }),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 50),
            
            // Animated Rectangular PIN Display Area
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final bool isFilled = index < currentPin.length;
                    // Calculate wave offset based on time and index
                    final double waveOffset = math.sin((_waveController.value * 2 * math.pi) + (index * math.pi / 2)) * 8.0;
                    
                    return Transform.translate(
                      offset: Offset(0, waveOffset),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
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
            
            const Spacer(),
            _buildNumberPad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1', '2', '3'].map((k) => _buildKey(k)).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['4', '5', '6'].map((k) => _buildKey(k)).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['7', '8', '9'].map((k) => _buildKey(k)).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 80),
              _buildKey('0'),
              GestureDetector(
                onTap: _onBackspace,
                child: Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MPesaTheme.cardDark,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 32),
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
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: MPesaTheme.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }
}
