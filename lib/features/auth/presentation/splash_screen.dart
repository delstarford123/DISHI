import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({Key? key, required this.onInitializationComplete}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Eagerly pre-cache heavy assets to prevent layout shift / scroll lag
    await precacheImage(const AssetImage('assets/img/photo_collage.png'), context);
    await precacheImage(const AssetImage('assets/img/dishi_logo.png'), context);
    
    // Simulate backend checks or wait for minimum time
    await Future.delayed(const Duration(seconds: 2));
    
    widget.onInitializationComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Static full-page photo collage
          Image.asset(
            'assets/img/photo_collage.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF121212)),
          ),
          // Dark overlay for readability
          Container(
            color: Colors.black.withOpacity(0.7),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/img/dishi_logo.png', 
                  width: 120,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, size: 120, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Color(0xFF00E5FF)), // Teal accent
              ],
            ),
          ),
        ],
      ),
    );
  }
}
