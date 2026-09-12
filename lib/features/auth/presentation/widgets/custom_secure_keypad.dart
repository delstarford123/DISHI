import 'package:flutter/material.dart';

class CustomSecureKeypad extends StatefulWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onBackspace;
  final VoidCallback onBiometricTap;
  final bool randomize;
  final bool showBiometric;

  const CustomSecureKeypad({
    Key? key,
    required this.onKeyPressed,
    required this.onBackspace,
    required this.onBiometricTap,
    this.randomize = true,
    this.showBiometric = true,
  }) : super(key: key);

  @override
  _CustomSecureKeypadState createState() => _CustomSecureKeypadState();
}

class _CustomSecureKeypadState extends State<CustomSecureKeypad> {
  late List<String> _keys;

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
    return Expanded(
      child: InkWell(
        onTap: () => widget.onKeyPressed(label),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          margin: const EdgeInsets.all(8),
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          margin: const EdgeInsets.all(8),
          height: 60,
          child: Center(
            child: Icon(icon, color: Colors.grey, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyKey() {
    return Expanded(child: Container());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey(_keys[0]),
            _buildKey(_keys[1]),
            _buildKey(_keys[2]),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey(_keys[3]),
            _buildKey(_keys[4]),
            _buildKey(_keys[5]),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey(_keys[6]),
            _buildKey(_keys[7]),
            _buildKey(_keys[8]),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            widget.showBiometric ? _buildActionKey(Icons.fingerprint, widget.onBiometricTap) : _buildEmptyKey(),
            _buildKey(_keys[9]),
            _buildActionKey(Icons.backspace_outlined, widget.onBackspace),
          ],
        ),
      ],
    );
  }
}
