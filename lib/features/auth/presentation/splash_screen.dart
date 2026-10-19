import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({super.key, required this.onInitializationComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Floating breathing animation for logo
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Ambient pulse ring
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  // Shimmer sweep on DISHI title
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  // Golden arc rotation in corner
  late AnimationController _arcController;
  late Animation<double> _arcSweep;
  late Animation<double> _arcRotation;
  late Animation<double> _arcGlow;

  // Particle floating system
  late AnimationController _particleController;

  bool _initialized = false;

  // Network Status
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasInternet = true;

  // Dynamic Greeting
  String _greeting = 'Welcome';

  // Fast Progressive Loading Steps
  int _loadingStep = 0;
  final List<String> _loadingSteps = [
    'Connecting to DISHI Services...',
    'Securing Campus Nodes...',
    'Warming up...',
    'Ready!',
  ];
  Timer? _loadingTimer;

  // App Version
  final String _appVersion = "v1.0.2";

  // Palette
  static const Color _bg        = Color(0xFF030D08); // obsidian dark green
  static const Color _green1    = Color(0xFF072414); // deep emerald
  static const Color _greenBrt  = Color(0xFF05D5AA); // DISHI neon mint
  static const Color _greenLit  = Color(0xFF34D399); // light mint
  static const Color _gold2     = Color(0xFFFBBF24); // golden accent
  static const Color _goldLit   = Color(0xFFFDE68A); // gold shimmer

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _setGreeting();

    // Connectivity listener
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (mounted) {
        setState(() {
          _hasInternet = !result.contains(ConnectivityResult.none);
        });
      }
    });

    // Particle Animation
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

    // Floating breathing
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // Pulse Ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    _pulseOpacity = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    // Shimmer on Title
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );

    // Golden Arc
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _arcSweep = Tween<double>(begin: 0.25 * math.pi, end: 0.65 * math.pi).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeInOut),
    );

    _arcRotation = Tween<double>(begin: 0.0, end: 0.15 * math.pi).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeInOut),
    );

    _arcGlow = Tween<double>(begin: 0.45, end: 0.95).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeInOut),
    );

    // Step Timer
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 260), (timer) {
      if (mounted) {
        setState(() {
          if (_loadingStep < _loadingSteps.length - 1) {
            _loadingStep++;
          }
        });
      }
    });
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning, Comrade ☀️';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon, Comrade 🍽️';
    } else {
      _greeting = 'Good Evening, Comrade 🌙';
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
        precacheImage(const AssetImage('assets/img/app_icon_512.png'), context).catchError((_) {}),
        precacheImage(const AssetImage('assets/img/dishi_logo_512.png'), context).catchError((_) {}),
        precacheImage(const AssetImage('assets/img/dishi_logo.png'), context).catchError((_) {}),
        // Fast, snappy boot: 1100ms total
        Future.delayed(const Duration(milliseconds: 1100)),
      ]);
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1100));
    }
    if (mounted) widget.onInitializationComplete();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _connectivitySubscription.cancel();
    _particleController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _arcController.dispose();
    super.dispose();
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
          // ── Deep obsidian-emerald radial gradient ───────────────────
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.15),
                radius: 0.95,
                colors: [
                  _green1,
                  const Color(0xFF04140B),
                  _bg,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── Floating Ambient Particles ─────────────────────────────
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlePainter(
                  progress: _particleController.value,
                  particleColor: _greenBrt.withOpacity(0.20),
                ),
                size: size,
              );
            },
          ),

          // ── Top-left soft emerald glow ──────────────────────────────
          Positioned(
            top: -80,
            left: -60,
            child: _GlowOrb(size: 280, color: _greenBrt, opacity: 0.12),
          ),

          // ── Subtle dot grid ─────────────────────────────────────────
          CustomPaint(painter: _DotGridPainter()),

          // ── Golden arc in bottom-right corner ───────────────────────
          Positioned(
            bottom: -15,
            right: -15,
            child: AnimatedBuilder(
              animation: _arcController,
              builder: (_, __) {
                return Opacity(
                  opacity: _arcGlow.value,
                  child: CustomPaint(
                    size: const Size(200, 200),
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

          // ── Main Center Branding & Content ──────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Dynamic greeting badge
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.only(top: 24.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _greenBrt.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _greeting,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Hero 512 DISHI Logo with Breathing Pulse Ring ────
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated Pulse Ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) => Transform.scale(
                            scale: _pulseScale.value,
                            child: Opacity(
                              opacity: _pulseOpacity.value,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(42),
                                  border: Border.all(
                                    color: _greenBrt,
                                    width: 2.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Soft Ambient Backglow
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(38),
                            boxShadow: [
                              BoxShadow(
                                color: _greenBrt.withOpacity(0.35),
                                blurRadius: 40,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: _gold2.withOpacity(0.15),
                                blurRadius: 20,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),

                        // Official 512 DISHI Logo Squircle
                        ElasticIn(
                          duration: const Duration(milliseconds: 900),
                          child: AnimatedBuilder(
                            animation: _floatAnimation,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, _floatAnimation.value),
                              child: child,
                            ),
                            child: Container(
                              width: 124,
                              height: 124,
                              decoration: BoxDecoration(
                                color: const Color(0xFF091F13),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: _greenBrt.withOpacity(0.65),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.55),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  'assets/img/app_icon_512.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/img/dishi_logo_512.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/img/dishi_logo.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.restaurant_rounded,
                                        size: 54,
                                        color: _greenBrt,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── DISHI Brand Title with Emerald-to-Gold Shimmer ───
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 600),
                  child: AnimatedBuilder(
                    animation: _shimmerAnim,
                    builder: (_, child) => ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment(_shimmerAnim.value - 0.6, 0),
                        end: Alignment(_shimmerAnim.value + 0.6, 0),
                        colors: const [
                          _greenLit,
                          _goldLit,
                          _gold2,
                          _greenLit,
                        ],
                        stops: const [0.0, 0.35, 0.65, 1.0],
                      ).createShader(bounds),
                      child: child,
                    ),
                    child: const Text(
                      'D I S H I',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 9.0,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Tagline ──────────────────────────────────────────
                FadeIn(
                  delay: const Duration(milliseconds: 450),
                  duration: const Duration(milliseconds: 600),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            _greenBrt.withOpacity(0.6),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CAMPUS MEALS & AGENCY BANKING',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                          color: Colors.white.withOpacity(0.70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _greenBrt.withOpacity(0.6),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // ── Loading Bar & Status ─────────────────────────────
                FadeIn(
                  delay: const Duration(milliseconds: 600),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            color: _hasInternet ? _greenBrt : Colors.orangeAccent,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            minHeight: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          !_hasInternet ? 'Offline Mode Active' : _loadingSteps[_loadingStep],
                          key: ValueKey<String>(_hasInternet ? _loadingSteps[_loadingStep] : 'offline'),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            letterSpacing: 1.5,
                            color: _hasInternet ? Colors.white.withOpacity(0.55) : Colors.orangeAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Footer: Delstarford Works & Safaricom M-PESA ──────
                FadeIn(
                  delay: const Duration(milliseconds: 700),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 12, color: _greenBrt.withOpacity(0.6)),
                        const SizedBox(width: 6),
                        Text(
                          'Delstarford Works • Powered by Safaricom M-PESA • $_appVersion',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Visual Painters ─────────────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({required this.size, required this.color, required this.opacity});

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

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF05D5AA).withOpacity(0.035)
      ..style = PaintingStyle.fill;

    const spacing = 32.0;
    const radius = 1.0;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoldenArcPainter extends CustomPainter {
  final double sweepAngle;
  final double rotation;
  final double glowOpacity;

  _GoldenArcPainter({
    required this.sweepAngle,
    required this.rotation,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width, size.height);

    _drawArc(canvas, center,
        radius: 170,
        strokeWidth: 20,
        color: const Color(0xFF05D5AA).withOpacity(0.04 * glowOpacity),
        blur: 20);

    _drawArc(canvas, center,
        radius: 155,
        strokeWidth: 8,
        color: const Color(0xFFFBBF24).withOpacity(0.18 * glowOpacity),
        blur: 8);

    _drawArc(canvas, center,
        radius: 150,
        strokeWidth: 3.5,
        color: const Color(0xFFFBBF24).withOpacity(0.85),
        blur: 0);

    _drawArc(canvas, center,
        radius: 150,
        strokeWidth: 1.2,
        color: const Color(0xFFFDE68A).withOpacity(0.80),
        blur: 0);
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

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color particleColor;

  _ParticlePainter({required this.progress, required this.particleColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = particleColor;
    final random = math.Random(101);

    for (int i = 0; i < 24; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final speed = 0.2 + random.nextDouble() * 0.6;
      final currentY = (startY - (progress * size.height * speed)) % size.height;
      final currentX = startX + math.sin(progress * math.pi * 2 + i) * 16;
      final renderY = currentY < 0 ? currentY + size.height : currentY;

      canvas.drawCircle(Offset(currentX, renderY), 1.2 + random.nextDouble() * 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.progress != progress;
}
