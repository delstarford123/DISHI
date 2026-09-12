import 'dart:async';
import 'package:flutter/material.dart';

class SessionManager extends StatefulWidget {
  final Widget child;
  final VoidCallback onSessionTimeout;
  final Duration timeoutDuration;

  const SessionManager({
    Key? key,
    required this.child,
    required this.onSessionTimeout,
    this.timeoutDuration = const Duration(minutes: 3),
  }) : super(key: key);

  @override
  _SessionManagerState createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
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
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleUserInteraction,
      onPointerMove: _handleUserInteraction,
      onPointerUp: _handleUserInteraction,
      child: widget.child,
    );
  }
}
