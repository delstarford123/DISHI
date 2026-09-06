import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class FocusModeView extends StatefulWidget {
  const FocusModeView({super.key});

  @override
  State<FocusModeView> createState() => _FocusModeViewState();
}

class _FocusModeViewState extends State<FocusModeView> {
  int _secondsRemaining = 3 * 60 * 60; // 3 hours
  Timer? _timer;
  bool _isActive = false;
  bool _isFinished = false;

  void _toggleTimer() {
    if (_isActive) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        } else {
          _timer?.cancel();
          setState(() {
            _isActive = false;
            _isFinished = true;
          });
          _showBadgeDialog();
        }
      });
    }
    setState(() => _isActive = !_isActive);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showBadgeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: SmartiTheme.backgroundGrey,
        title: const Text('Congratulations! 🎉', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 80),
            const SizedBox(height: 16),
            const Text('You earned the "Deep Focus" badge!', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Claim Badge', style: TextStyle(color: SmartiTheme.secondaryLightBlue)),
          )
        ],
      ),
    );
  }

  String get _formattedTime {
    int h = _secondsRemaining ~/ 3600;
    int m = (_secondsRemaining % 3600) ~/ 60;
    int s = _secondsRemaining % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartiTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Study-to-Earn (Focus Mode)'),
        backgroundColor: SmartiTheme.primaryNavy,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_library, color: SmartiTheme.secondaryLightBlue, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Stay focused for 3 hours to earn a badge!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _isActive ? SmartiTheme.secondaryLightBlue : Colors.white24, width: 8),
              ),
              child: Text(
                _formattedTime,
                style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 60),
            if (!_isFinished)
              ElevatedButton.icon(
                onPressed: _toggleTimer,
                icon: Icon(_isActive ? Icons.pause : Icons.play_arrow, color: Colors.white),
                label: Text(_isActive ? 'Pause' : 'Start Focus', style: const TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isActive ? Colors.orange : SmartiTheme.primaryNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            if (_isFinished)
              const Text('Focus session complete!', style: TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
