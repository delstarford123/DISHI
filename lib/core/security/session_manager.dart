import 'dart:async';
import 'package:flutter/material.dart';

/// Professional session & inactivity security manager.
/// Preserves active app navigation and screen state during app switching.
/// Only locks/triggers timeout when the user has been inactive or the app
/// has been backgrounded for a professional duration (default: 15 minutes).
class SessionManager extends StatefulWidget {
  final Widget child;
  final VoidCallback onSessionTimeout;
  final Duration timeoutDuration;

  const SessionManager({
    super.key,
    required this.child,
    required this.onSessionTimeout,
    this.timeoutDuration = const Duration(minutes: 15),
  });

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _backgroundTimestamp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Mark when app went to background
      _backgroundTimestamp ??= DateTime.now();
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTimestamp != null) {
        final elapsed = DateTime.now().difference(_backgroundTimestamp!);
        _backgroundTimestamp = null;
        if (elapsed >= widget.timeoutDuration) {
          // Exceeded timeout duration while in background
          widget.onSessionTimeout();
          return;
        }
      }
      // Resumed safely within the timeout window — continue where user left off
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeoutDuration, () {
      widget.onSessionTimeout();
    });
  }

  void _handleUserInteraction([_]) {
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleUserInteraction,
      onPointerMove: _handleUserInteraction,
      onPointerUp: _handleUserInteraction,
      child: widget.child,
    );
  }
}
