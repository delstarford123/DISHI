import 'package:flutter/material.dart';
import '../../../../core/theme/mpesa_theme.dart';

class PosNumpad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onClear;
  final VoidCallback onBackspace;

  const PosNumpad({
    super.key,
    required this.onKeyPressed,
    required this.onClear,
    required this.onBackspace,
  });

  Widget _buildKey(String label, {VoidCallback? onTap, Color? color, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: color ?? Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap ?? () => onKeyPressed(label),
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKey('1'),
              _buildKey('2'),
              _buildKey('3'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKey('4'),
              _buildKey('5'),
              _buildKey('6'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKey('7'),
              _buildKey('8'),
              _buildKey('9'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKey('C', onTap: onClear, color: Colors.red.shade100, textColor: Colors.red.shade900),
              _buildKey('0'),
              _buildKey('⌫', onTap: onBackspace, color: Colors.grey.shade300),
            ],
          ),
        ),
      ],
    );
  }
}
