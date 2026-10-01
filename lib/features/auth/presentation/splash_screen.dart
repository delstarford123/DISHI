import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:video_player/video_player.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({Key? key, required this.onInitializationComplete})
      : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Floating mascot
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Ambient pulse ring
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  // Shimmer sweep on title
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  // Golden arc rotation
  late AnimationController _arcController;
  late Animation<double> _arcSweep;
  late Animation<double> _arcRotation;
  late Animation<double> _arcGlow;

  bool _initialized = false;

  // 1. Video Background
  late VideoPlayerController _videoController;

  // 2. Network Status
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasInternet = true;

  // 3. Dynamic Greetings
  String _greeting = 'Welcome';

  // 4. Parallax Effect
  late StreamSubscription<AccelerometerEvent> _accelSubscription;
  double _parallaxX = 0;
  double _parallaxY = 0;

  // 5. Progressive Loading Steps
  int _loadingStep = 0;
  final List<String> _loadingSteps = [
    'Initialising...',
    'Connecting to servers...',
    'Warming up plates...',
    'Getting ready...',
  ];
  late Timer _loadingTimer;

  // 6. Interactive Mascot
  late AnimationController _spinController;

  // 7. Slide-in Tip of the Day
  final List<String> _tips = [
    'Did you know? Food tastes better when shared.',
    'Pro Tip: Swipe right to save a meal.',
    'Daily Hack: Check early for the best dishes.',
  ];
  late String _currentTip;

  // 8. Particle System
  late AnimationController _particleController;

  // 9. App Version Display
  final String _appVersion = "v1.0.0"; // 10. Lottie Placeholder is implemented as a shimmer box

  // ── Palette ────────────────────────────────────────────
  static const Color _bg        = Color(0xFF021A0D); // darkest forest green
  static const Color _green1    = Color(0xFF0D4A22); // deep green core
  static const Color _green2    = Color(0xFF16A34A); // mid green
  static const Color _greenBrt  = Color(0xFF22C55E); // bright accent green
  static const Color _greenLit  = Color(0xFF4ADE80); // light green shimmer
  static const Color _gold1     = Color(0xFFD97706); // deep amber
  static const Color _gold2     = Color(0xFFFBBF24); // golden yellow
  static const Color _goldLit   = Color(0xFFFDE68A); // light gold shimmer

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _setGreeting();
    _currentTip = _tips[math.Random().nextInt(_tips.length)];

    // Video Init
    _videoController = VideoPlayerController.asset('assets/videos/splash_bg.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.setVolume(0);
        _videoController.play();
        if (mounted) setState(() {});
      });

    // Connectivity Init
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (mounted) {
        setState(() {
          _hasInternet = !result.contains(ConnectivityResult.none);
        });
      }
    });

    // Parallax Init
    _accelSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      if (mounted) {
        setState(() {
          _parallaxX = event.x * -2.5;
          _parallaxY = event.y * 2.5;
        });
      }
    });

    // Loading Steps Timer
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() {
          if (_loadingStep < _loadingSteps.length - 1) {
            _loadingStep++;
          }
        });
      }
    });

    _spinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();

    // Gentle floating bob
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // Pulsing glow ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _pulseScale = Tween<double>(begin: 0.82, end: 1.38).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.60, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Green→Gold shimmer sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // ── Golden arc: draw-in + slow rotation + glow breath ──
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _arcSweep = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: math.pi)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 40),
      TweenSequenceItem(
          tween: ConstantTween<double>(math.pi), weight: 60),
    ]).animate(_arcController);

    _arcRotation = Tween<double>(begin: 0.0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _arcController, curve: Curves.linear));

    _arcGlow = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.5, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.5)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50),
    ]).animate(_arcController);
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        precacheImage(
                const AssetImage('assets/img/dishi_mascot_transparent.png'),
                context)
            .catchError((_) {}),
        precacheImage(const AssetImage('assets/img/dishi_logo.png'), context)
            .catchError((_) {}),
        Future.delayed(const Duration(milliseconds: 500)), // Reduced from 3200ms to make app load almost instantly
      ]);
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) widget.onInitializationComplete();
  }

  @override
  void dispose() {
    _videoController.dispose();
    _connectivitySubscription.cancel();
    _accelSubscription.cancel();
    _loadingTimer.cancel();
    _spinController.dispose();
    _particleController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _arcController.dispose();
    super.dispose();
  }

  void _onMascotTap() {
    if (_spinController.isAnimating) return;
    _spinController.forward(from: 0.0);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    FlutterNativeSplash.remove();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // 1. Video Background (with Gradient fallback/overlay)
          if (_videoController.value.isInitialized)
            Opacity(
              opacity: 0.25, // Blend video subtly with the background
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
            ),

          // ── Background: deep green radial ───────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.15),
                radius: 0.90,
                colors: [
                  _green1.withOpacity(0.8),   // deep green core
                  const Color(0xFF031A0C).withOpacity(0.9), // very dark green mid
                  _bg,       // near-black green edge
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),

          // 2. Particle Animation System
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlePainter(
                  progress: _particleController.value,
                  particleColor: _gold2.withOpacity(0.3),
                ),
                size: size,
              );
            },
          ),

          // ── Top-left green corner glow ───────────────────────────────
          Positioned(
            top: -90,
            left: -70,
            child: _GlowOrb(size: 300, color: _green2, opacity: 0.18),
          ),

          // ── Subtle dot-grid ──────────────────────────────────────────
          CustomPaint(painter: _DotGridPainter()),

          // ── ★ GOLDEN ARC — bottom-right animated half-circle ─────────
          Positioned(
            bottom: -10,
            right: -10,
            child: AnimatedBuilder(
              animation: _arcController,
              builder: (_, __) {
                return Opacity(
                  opacity: _arcGlow.value,
                  child: CustomPaint(
                    size: const Size(220, 220),
                    painter: _GoldenArcPainter(
                      sweepAngle: _arcSweep.value,
                      rotation: _arcRotation.value,
                      glowOpacity: _arcGlow.value,
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Main content with Parallax ───────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 100),
            left: _parallaxX,
            top: _parallaxY,
            right: -_parallaxX,
            bottom: -_parallaxY,
            child: SafeArea(
              child: Column(
                children: [
                  // 3. Dynamic Greetings
                  FadeInDown(
                    delay: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Text(
                        _greeting,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.08),

                  // ── Pulsing ring + floating/interactive logo ──────────
                  GestureDetector(
                    onTap: _onMascotTap,
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer pulse ring
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, __) => Transform.scale(
                              scale: _pulseScale.value,
                              child: Opacity(
                                opacity: _pulseOpacity.value,
                                child: Container(
                                  width: 172,
                                  height: 172,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _greenBrt,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Inner glow ring
                          Container(
                            width: 154,
                            height: 154,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _green1.withOpacity(0.7),
                                  _bg.withOpacity(0.9),
                                ],
                              ),
                              border: Border.all(
                                color: _greenBrt.withOpacity(0.40),
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _greenBrt.withOpacity(0.28),
                                  blurRadius: 36,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: _gold1.withOpacity(0.12),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),

                          // Floating & Spinning mascot
                          ElasticIn(
                            duration: const Duration(milliseconds: 1100),
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_floatAnimation, _spinController]),
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, _floatAnimation.value),
                                child: Transform.rotate(
                                  angle: _spinController.value * 2 * math.pi,
                                  child: child,
                                ),
                              ),
                              child: Image.asset(
                                'assets/img/dishi_mascot_transparent.png',
                                width: 122,
                                height: 122,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/img/dishi_logo.png',
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.restaurant_menu_rounded,
                                    size: 80,
                                    color: _greenBrt,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // ── DISHI — green→gold shimmer title ─────────────────
                  FadeInUp(
                    delay: const Duration(milliseconds: 350),
                    duration: const Duration(milliseconds: 700),
                    child: AnimatedBuilder(
                      animation: _shimmerAnim,
                      builder: (_, child) => ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment(_shimmerAnim.value - 0.6, 0),
                          end: Alignment(_shimmerAnim.value + 0.6, 0),
                          colors: const [
                            _greenLit,  // bright green
                            _goldLit,   // light gold
                            _gold2,     // golden yellow
                            _greenLit,  // bright green
                          ],
                          stops: const [0.0, 0.35, 0.65, 1.0],
                        ).createShader(bounds),
                        child: child,
                      ),
                      child: const Text(
                        'D I S H I',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 10.0,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Tagline ───────────────────────────────────────────
                  FadeIn(
                    delay: const Duration(milliseconds: 550),
                    duration: const Duration(milliseconds: 700),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              _gold2.withOpacity(0.6),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Smart Living',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 4.5,
                            color: _gold2.withOpacity(0.80),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              _gold2.withOpacity(0.6),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),

                  // ── Loader & Network Status ─────────────────────────
                  FadeIn(
                    delay: const Duration(milliseconds: 900),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 130,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              color: _hasInternet ? _gold2 : Colors.redAccent,
                              backgroundColor: _greenBrt.withOpacity(0.18),
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Progressive Loading Text
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            !_hasInternet ? 'Waiting for Network...' : _loadingSteps[_loadingStep],
                            key: ValueKey<String>(_hasInternet ? _loadingSteps[_loadingStep] : 'offline'),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              letterSpacing: 2.2,
                              color: _hasInternet ? Colors.white.withOpacity(0.5) : Colors.redAccent.withOpacity(0.8),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                  
                  // 7. Slide-in Tip of the day
                  FadeInUp(
                    delay: const Duration(milliseconds: 1000),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 15.0),
                      child: Text(
                        _currentTip,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                  
                  // 9. App Version
                  FadeIn(
                    delay: const Duration(milliseconds: 1200),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Text(
                        _appVersion,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.3),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: FadeIn(
              delay: const Duration(milliseconds: 1100),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        size: 11, color: _gold2.withOpacity(0.45)),
                    const SizedBox(width: 6),
                    Text(
                      'from Delstarford Works',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white.withOpacity(0.22),
                        fontSize: 11,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb(
      {required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ),
      ),
    );
  }
}

/// Subtle repeating dot-grid for depth
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.045)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const radius = 1.2;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animated golden half-circle arc — anchored to bottom-right corner
class _GoldenArcPainter extends CustomPainter {
  final double sweepAngle;  // 0 → π
  final double rotation;    // 0 → 2π  (slow full rotation)
  final double glowOpacity; // 0.5 → 1.0

  _GoldenArcPainter({
    required this.sweepAngle,
    required this.rotation,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width, size.height); // bottom-right corner

    // ── Layers from outermost to innermost ─────────────────────────

    // 1. Outermost soft glow halo
    _drawArc(canvas, center,
        radius: 190,
        strokeWidth: 28,
        color: const Color(0xFFF59E0B).withOpacity(0.06 * glowOpacity),
        blur: 24);

    // 2. Wide diffuse glow
    _drawArc(canvas, center,
        radius: 175,
        strokeWidth: 18,
        color: const Color(0xFFFBBF24).withOpacity(0.12 * glowOpacity),
        blur: 16);

    // 3. Mid glow ring
    _drawArc(canvas, center,
        radius: 162,
        strokeWidth: 10,
        color: const Color(0xFFFBBF24).withOpacity(0.25 * glowOpacity),
        blur: 10);

    // 4. Core arc — crisp golden line
    _drawArc(canvas, center,
        radius: 155,
        strokeWidth: 4.5,
        color: const Color(0xFFFBBF24).withOpacity(0.90),
        blur: 0);

    // 5. Inner bright highlight
    _drawArc(canvas, center,
        radius: 155,
        strokeWidth: 1.5,
        color: const Color(0xFFFDE68A).withOpacity(0.75),
        blur: 0);

    // 6. Secondary thinner arc slightly inset
    _drawArc(canvas, center,
        radius: 130,
        strokeWidth: 2.0,
        color: const Color(0xFFF59E0B).withOpacity(0.35 * glowOpacity),
        blur: 4);
  }

  void _drawArc(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double strokeWidth,
    required Color color,
    double blur = 0,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (blur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    }

    final rect = Rect.fromCircle(center: center, radius: radius);

    final startAngle = math.pi + rotation;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GoldenArcPainter old) =>
      old.sweepAngle != sweepAngle ||
      old.rotation != rotation ||
      old.glowOpacity != glowOpacity;
}

// Particle System Painter
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color particleColor;

  _ParticlePainter({required this.progress, required this.particleColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = particleColor;
    final random = math.Random(42); // fixed seed for stable paths

    for (int i = 0; i < 30; i++) {
      // Create random particles floating upwards
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final speed = 0.2 + random.nextDouble() * 0.8;
      
      final currentY = (startY - (progress * size.height * speed)) % size.height;
      final currentX = startX + math.sin(progress * math.pi * 2 + i) * 20;

      // Wrap around correctly
      final renderY = currentY < 0 ? currentY + size.height : currentY;

      canvas.drawCircle(Offset(currentX, renderY), 1.5 + random.nextDouble() * 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.progress != progress;
}
