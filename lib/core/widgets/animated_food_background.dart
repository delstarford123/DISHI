import 'package:flutter/material.dart';

class AnimatedFoodBackground extends StatefulWidget {
  final Widget? child;

  const AnimatedFoodBackground({super.key, this.child});

  @override
  State<AnimatedFoodBackground> createState() => _AnimatedFoodBackgroundState();
}

class _AnimatedFoodBackgroundState extends State<AnimatedFoodBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Color
        Container(color: const Color(0xFFF5F7FA)),
        
        // Animated Floating Elements (Abstract representations of food/campus)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: -50 + (_controller.value * 100),
                  left: -50,
                  child: Opacity(
                    opacity: 0.05,
                    child: Icon(Icons.restaurant, size: 300, color: Colors.green.shade900),
                  ),
                ),
                Positioned(
                  bottom: -100 - (_controller.value * 50),
                  right: -50,
                  child: Opacity(
                    opacity: 0.05,
                    child: Icon(Icons.fastfood, size: 400, color: Colors.blue.shade900),
                  ),
                ),
              ],
            );
          },
        ),
        
        // The main content overlaid
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
