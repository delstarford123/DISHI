import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/theme/glass_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TimerState { idle, focus, shortBreak, longBreak }

class DailyFocusView extends StatefulWidget {
  const DailyFocusView({super.key});

  @override
  State<DailyFocusView> createState() => _DailyFocusViewState();
}

class _DailyFocusViewState extends State<DailyFocusView> {
  static const int focusDuration = 25 * 60;
  static const int shortBreakDuration = 5 * 60;
  
  TimerState _currentState = TimerState.idle;
  int _secondsRemaining = focusDuration;
  Timer? _timer;
  int _completedPomodoros = 0;

  // Mocked AI Task Prediction
  final double _aiSuccessProbability = 87.5;

  void _startTimer() {
    if (_currentState == TimerState.idle) {
      _currentState = TimerState.focus;
      _secondsRemaining = focusDuration;
    }
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _handleTimerComplete();
      }
    });
    setState(() {});
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {});
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _currentState = TimerState.idle;
      _secondsRemaining = focusDuration;
    });
  }

  void _handleTimerComplete() {
    _timer?.cancel();
    
    if (_currentState == TimerState.focus) {
      _completedPomodoros++;
      
      // Sync to backend
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('academic_focus_logs')
            .add({
          'duration_minutes': 25,
          'completed_at': FieldValue.serverTimestamp(),
          'type': 'pomodoro_session'
        });
      }

      setState(() {
        _currentState = TimerState.shortBreak;
        _secondsRemaining = shortBreakDuration;
      });
      _showCompletionDialog('Focus Session Complete! Time for a short break.');
    } else {
      setState(() {
        _currentState = TimerState.idle;
        _secondsRemaining = focusDuration;
      });
      _showCompletionDialog('Break Over! Ready to focus again?');
    }
  }

  void _showCompletionDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('SmartI Engine'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_currentState != TimerState.idle) _startTimer();
            },
            child: const Text('Continue'),
          )
        ],
      ),
    );
  }

  String get _timeFormatted {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
  
  double get _progress {
    int maxDuration = _currentState == TimerState.shortBreak ? shortBreakDuration : focusDuration;
    return 1 - (_secondsRemaining / maxDuration);
  }

  String get _statusText {
    switch (_currentState) {
      case TimerState.idle: return 'Ready to Focus';
      case TimerState.focus: return 'Deep Work in Progress';
      case TimerState.shortBreak: return 'Short Break';
      case TimerState.longBreak: return 'Long Break';
    }
  }

  Color get _statusColor {
    switch (_currentState) {
      case TimerState.idle: return MPesaTheme.primaryGreen;
      case TimerState.focus: return Colors.orange;
      case TimerState.shortBreak: return Colors.blue;
      case TimerState.longBreak: return Colors.purple;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SmartI Pomodoro'),
        backgroundColor: MPesaTheme.primaryGreen,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // AI Prediction Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, color: MPesaTheme.primaryGreen, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AI Focus Prediction', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Optimal time. \$_aiSuccessProbability% predicted success.', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_statusText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _statusColor)),
                    const SizedBox(height: 32),
                    
                    // Circular Timer
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: _progress,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
                          ),
                          Center(
                            child: Text(
                              _timeFormatted,
                              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_timer == null || !_timer!.isActive)
                          _buildControlButton(Icons.play_arrow, 'Start', _statusColor, _startTimer)
                        else
                          _buildControlButton(Icons.pause, 'Pause', Colors.orange, _pauseTimer),
                        
                        const SizedBox(width: 24),
                        _buildControlButton(Icons.stop, 'Reset', Colors.red, _resetTimer),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Stats
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                      const SizedBox(height: 8),
                      const Text('Streak', style: TextStyle(color: Colors.grey)),
                      Text('\$_completedPomodoros', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.timer, color: MPesaTheme.primaryGreen, size: 32),
                      const SizedBox(height: 8),
                      const Text('Total Focus', style: TextStyle(color: Colors.grey)),
                      Text('\${(_completedPomodoros * 25)}m', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
