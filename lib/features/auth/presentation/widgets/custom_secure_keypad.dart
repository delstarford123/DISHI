import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/mpesa_theme.dart';

class CustomSecureKeypad extends StatefulWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onBackspace;
  final VoidCallback onBiometricTap;
  final VoidCallback? onLongPressBackspace;
  final bool randomize;
  final bool showBiometric;
  final String biometricLabel;

  const CustomSecureKeypad({
    super.key,
    required this.onKeyPressed,
    required this.onBackspace,
    required this.onBiometricTap,
    this.onLongPressBackspace,
    this.randomize = false,
    this.showBiometric = true,
    this.biometricLabel = 'Biometric',
  });

  @override
  State<CustomSecureKeypad> createState() => _CustomSecureKeypadState();
}

class _CustomSecureKeypadState extends State<CustomSecureKeypad> {
  late List<String> _keys;

  final Map<String, String> _subtitles = {
    '1': '',
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+',
  };

  @override
  void initState() {
    super.initState();
    _initializeKeys();
  }

  void _initializeKeys() {
    _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    if (widget.randomize) {
      _keys.shuffle();
    }
  }

  Widget _buildKey(String label) {
    final sub = _subtitles[label] ?? '';
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onKeyPressed(label);
            },
            borderRadius: BorderRadius.circular(32),
            splashColor: MPesaTheme.neonCyan.withOpacity(0.2),
            highlightColor: Colors.white.withOpacity(0.08),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                      height: 1.1,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricKey() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onBiometricTap();
            },
            borderRadius: BorderRadius.circular(32),
            splashColor: MPesaTheme.neonCyan.withOpacity(0.3),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MPesaTheme.neonCyan.withOpacity(0.18),
                    MPesaTheme.primaryGreen.withOpacity(0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: MPesaTheme.neonCyan.withOpacity(0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: MPesaTheme.neonCyan.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.fingerprint_rounded,
                  color: MPesaTheme.neonCyan,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onBackspace();
            },
            onLongPress: () {
              HapticFeedback.heavyImpact();
              if (widget.onLongPressBackspace != null) {
                widget.onLongPressBackspace!();
              } else {
                widget.onBackspace();
              }
            },
            borderRadius: BorderRadius.circular(32),
            splashColor: Colors.white.withOpacity(0.1),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Center(
                child: Icon(
                  Icons.backspace_outlined,
                  color: Colors.white.withOpacity(0.7),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyKey() {
    return const Expanded(child: SizedBox(height: 64));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildKey(_keys[0]),
              _buildKey(_keys[1]),
              _buildKey(_keys[2]),
            ],
          ),
          Row(
            children: [
              _buildKey(_keys[3]),
              _buildKey(_keys[4]),
              _buildKey(_keys[5]),
            ],
          ),
          Row(
            children: [
              _buildKey(_keys[6]),
              _buildKey(_keys[7]),
              _buildKey(_keys[8]),
            ],
          ),
          Row(
            children: [
              widget.showBiometric ? _buildBiometricKey() : _buildEmptyKey(),
              _buildKey(_keys[9]),
              _buildBackspaceKey(),
            ],
          ),
        ],
      ),
    );
  }
}
