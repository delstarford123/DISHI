import 'package:flutter/material.dart';
import '../theme/mpesa_theme.dart';

/// A "Hold to Confirm" button for destructive or high-risk actions 
/// (e.g. Withdrawing E-Float or Resetting PIN)
class HighFrictionAction extends StatefulWidget {
  final String label;
  final VoidCallback onActionCompleted;
  final Color baseColor;

  const HighFrictionAction({
    super.key,
    required this.label,
    required this.onActionCompleted,
    this.baseColor = MPesaTheme.primaryGreen,
  });

  @override
  State<HighFrictionAction> createState() => _HighFrictionActionState();
}

class _HighFrictionActionState extends State<HighFrictionAction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Requires holding for 2 seconds
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isCompleted) {
        _isCompleted = true;
        widget.onActionCompleted();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_isCompleted) _controller.forward();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_isCompleted) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 50,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(25),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                height: 50,
                width: MediaQuery.of(context).size.width * _controller.value,
                decoration: BoxDecoration(
                  color: widget.baseColor,
                  borderRadius: BorderRadius.circular(25),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
