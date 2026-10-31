import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/api_config.dart';
import 'coins_display.dart';
import 'redeem_store_view.dart';

class SpinPrize {
  final String label;
  final String type; // 'coins', 'delivery', 'discount', 'none'
  final int value;
  final Color color;
  final IconData icon;

  SpinPrize({
    required this.label,
    required this.type,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class DailySpinGame extends StatefulWidget {
  final UserModel userModel;

  const DailySpinGame({super.key, required this.userModel});

  @override
  State<DailySpinGame> createState() => _DailySpinGameState();
}

class _DailySpinGameState extends State<DailySpinGame> with SingleTickerProviderStateMixin {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _cardColor = const Color(0xFF131A2A);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  bool _isSpinning = false;
  bool _canSpin = true;
  String _timeRemaining = '';
  Timer? _countdownTimer;

  final List<SpinPrize> _prizes = [
    SpinPrize(label: '50 Coins', type: 'coins', value: 50, color: const Color(0xFF1E88E5), icon: Icons.monetization_on),
    SpinPrize(label: 'Free Delivery', type: 'delivery', value: 1, color: const Color(0xFFFB8C00), icon: Icons.two_wheeler),
    SpinPrize(label: '100 Coins', type: 'coins', value: 100, color: const Color(0xFF8E24AA), icon: Icons.monetization_on),
    SpinPrize(label: 'Try Tomorrow', type: 'none', value: 0, color: const Color(0xFF455A64), icon: Icons.sentiment_dissatisfied),
    SpinPrize(label: '250 Coins', type: 'coins', value: 250, color: const Color(0xFF00ACC1), icon: Icons.monetization_on),
    SpinPrize(label: '10% Voucher', type: 'discount', value: 10, color: const Color(0xFFD81B60), icon: Icons.local_offer),
    SpinPrize(label: '500 JACKPOT', type: 'coins', value: 500, color: const Color(0xFFFFB300), icon: Icons.stars),
    SpinPrize(label: 'Try Tomorrow', type: 'none', value: 0, color: const Color(0xFF37474F), icon: Icons.sentiment_dissatisfied),
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    _checkSpinCooldown();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSpinCooldown() async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Check user streak
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).get();
      final streak = (userDoc.data()?['streakDays'] as num?)?.toInt() ?? (userDoc.data()?['streak_days'] as num?)?.toInt() ?? 5;
      final lastStreakSpin = userDoc.data()?['last_streak_spin_date'] as String?;

      // If user has 5+ day streak and has not used today's streak spin, grant immediate access!
      if (streak >= 5 && lastStreakSpin != todayStr) {
        if (mounted) {
          setState(() {
            _canSpin = true;
            _timeRemaining = '';
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('user_game_stats').doc(widget.userModel.uid).get();
      if (doc.exists && doc.data()?['last_spin'] != null) {
        final lastSpin = (doc.data()!['last_spin'] as Timestamp).toDate();
        final diff = DateTime.now().difference(lastSpin);
        if (diff.inHours < 24) {
          if (mounted) {
            setState(() {
              _canSpin = false;
            });
            _startCountdown(lastSpin.add(const Duration(hours: 24)));
          }
        }
      }
    } catch (_) {}
  }

  void _startCountdown(DateTime nextAvailable) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = nextAvailable.difference(DateTime.now());
      if (diff.isNegative) {
        timer.cancel();
        setState(() {
          _canSpin = true;
          _timeRemaining = '';
        });
      } else {
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          _timeRemaining = '$h:$m:$s';
        });
      }
    });
  }

  Future<void> _handleSpin() async {
    if (_isSpinning || !_canSpin) return;

    setState(() {
      _isSpinning = true;
    });

    // Pick target prize
    final rand = Random();
    int targetIndex = rand.nextInt(_prizes.length);
    // 70% chance of winning a reward
    if (rand.nextDouble() > 0.3) {
      // Pick one of the winning slices
      final winningIndices = [0, 1, 2, 4, 5, 6];
      targetIndex = winningIndices[rand.nextInt(winningIndices.length)];
    }
    final prize = _prizes[targetIndex];

    // Calculate rotation:
    // Slice angle = 2*pi / length
    // Target slice at the top (top is angle = 0 / pointer at 12 o'clock)
    final double sliceAngle = (2 * pi) / _prizes.length;
    // To land targetIndex under pointer, rotate backwards
    final double targetAngle = (2 * pi) - (targetIndex * sliceAngle) - (sliceAngle / 2);
    final double totalRotation = (7 * 2 * pi) + targetAngle; // 7 full spins + target

    _spinAnimation = Tween<double>(begin: 0, end: totalRotation).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );

    _spinAnimation.addListener(() {
      // Haptic tick during spin
      if (_spinController.value < 0.9 && (_spinAnimation.value % sliceAngle).abs() < 0.1) {
        HapticFeedback.selectionClick();
      }
    });

    _spinController.forward(from: 0).then((_) async {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSpinning = false;
        _canSpin = false;
      });

      await _awardPrize(prize);

      if (!mounted) return;
      _showWinModal(prize);
      _startCountdown(DateTime.now().add(const Duration(hours: 24)));
    });
  }

  Future<void> _awardPrize(SpinPrize prize) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Backend API Call
      try {
        await http.post(
          Uri.parse(ApiConfig.gamesSpin),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}

      // 2. Direct Firestore update guaranteed
      final statsRef = FirebaseFirestore.instance.collection('user_game_stats').doc(widget.userModel.uid);
      await statsRef.set({'last_spin': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid);
      final Map<String, dynamic> userUpdates = {
        'last_streak_spin_date': todayStr,
      };

      if (prize.type == 'coins' && prize.value > 0) {
        userUpdates['dishi_coins'] = FieldValue.increment(prize.value);
        userUpdates['dishiCoins'] = FieldValue.increment(prize.value);
      } else if (prize.type == 'delivery') {
        await statsRef.set({'free_deliveries': FieldValue.increment(1)}, SetOptions(merge: true));
      } else if (prize.type == 'discount') {
        await statsRef.set({'discount_vouchers': FieldValue.increment(1)}, SetOptions(merge: true));
      }

      await userRef.set(userUpdates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error awarding spin: $e');
    }
  }

  void _showWinModal(SpinPrize prize) {
    final isWin = prize.type != 'none';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isWin ? Colors.amber : Colors.white24, width: 2),
            boxShadow: [
              BoxShadow(color: (isWin ? Colors.amber : Colors.black).withOpacity(0.3), blurRadius: 28),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isWin ? Icons.celebration : Icons.sentiment_neutral, color: isWin ? Colors.amber : Colors.white54, size: 50),
              const SizedBox(height: 12),
              Text(
                isWin ? 'PRIZE WON! 🎉' : 'NICE TRY!',
                style: TextStyle(
                  color: isWin ? Colors.amber : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isWin ? 'You unlocked ${prize.label}!' : 'No luck today! Spin again in 24 hours.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('AWESOME', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RedeemStoreView(userModel: widget.userModel)));
                    },
                    child: const Icon(Icons.storefront),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Daily Lucky Spin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [CoinsDisplay(uid: widget.userModel.uid)],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SPIN & WIN DAILY PRIZES',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Win free Dishi Coins, meal vouchers & free delivery!',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 32),

                // Wheel Container with Pointer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Golden Ring
                    Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _neonCyan.withOpacity(0.2), blurRadius: 30, spreadRadius: 4),
                        ],
                        border: Border.all(color: Colors.amber, width: 4),
                      ),
                    ),

                    // Rotating Wheel
                    AnimatedBuilder(
                      animation: _spinController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _spinController.isAnimating ? _spinAnimation.value : 0,
                          child: CustomPaint(
                            size: const Size(310, 310),
                            painter: _WheelPainter(prizes: _prizes),
                          ),
                        );
                      },
                    ),

                    // Center Hub Button
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF131A2A),
                        border: Border.all(color: Colors.amber, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.stars, color: Colors.amber, size: 36),
                      ),
                    ),

                    // Top Pointer Needle
                    Positioned(
                      top: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_drop_down, color: _neonPink, size: 48),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Cooldown countdown or Action button
                if (!_canSpin && _timeRemaining.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Next Free Spin in: $_timeRemaining',
                          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSpin ? _neonCyan : Colors.grey,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: _isSpinning ? 0 : 12,
                      shadowColor: _neonCyan.withOpacity(0.5),
                    ),
                    onPressed: (_isSpinning || !_canSpin) ? null : _handleSpin,
                    child: Text(
                      _isSpinning ? 'SPINNING...' : 'SPIN THE WHEEL 🎰',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<SpinPrize> prizes;

  _WheelPainter({required this.prizes});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * pi) / prizes.length;

    for (int i = 0; i < prizes.length; i++) {
      final startAngle = (i * sweepAngle) - (pi / 2); // Start at 12 o'clock

      final paint = Paint()
        ..color = prizes[i].color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Border between slices
      final borderPaint = Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Draw prize label
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + (sweepAngle / 2));

      final textSpan = TextSpan(
        text: prizes[i].label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(radius * 0.45, -textPainter.height / 2));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
