import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DailySpinGame extends StatefulWidget {
  final UserModel userModel;

  const DailySpinGame({super.key, required this.userModel});

  @override
  State<DailySpinGame> createState() => _DailySpinGameState();
}

class _DailySpinGameState extends State<DailySpinGame> with SingleTickerProviderStateMixin {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);
  final Color _cardColor = const Color(0xFF131A2A);

  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  bool isSpinning = false;
  bool hasSpun = false;
  int? coinsWon;
  String errorMessage = '';

  final List<int> prizes = [50, 1, 0, 100, 10, 0]; // 1 = delivery, 10 = discount

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _handleSpin() async {
    if (isSpinning || hasSpun) return;

    setState(() {
      isSpinning = true;
      errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/spin'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        int won = 0;
        if (data['reward'] != null) {
          won = data['reward']['value'] ?? 0;
        }
        
        // Find which slice corresponds to the won amount
        int targetIndex = prizes.indexOf(won);
        if (targetIndex == -1) targetIndex = prizes.indexOf(0);

        // Calculate rotation
        // Each slice is 2*pi / 6. Target angle should place the slice at the top (which is -pi/2)
        double sliceAngle = (2 * pi) / prizes.length;
        double targetAngle = (prizes.length - targetIndex) * sliceAngle;
        
        // Add multiple full rotations (e.g. 5)
        double totalRotation = (5 * 2 * pi) + targetAngle;

        _spinAnimation = Tween<double>(begin: 0, end: totalRotation).animate(
          CurvedAnimation(parent: _spinController, curve: Curves.easeOutCirc),
        );

        _spinController.forward(from: 0).then((_) {
          setState(() {
            isSpinning = false;
            hasSpun = true;
            coinsWon = won;
          });
          String rewardText = won == 1 ? 'Free Delivery' : (won == 10 ? '10% Discount' : '$won Dishi Coins');
          if (won == 0) rewardText = 'Nothing today!';
          _showWinDialog(rewardText);
        });
      } else {
        setState(() {
          isSpinning = false;
          hasSpun = true;
          errorMessage = data['error'] ?? 'Spin failed.';
        });
      }
    } on TimeoutException {
      setState(() {
        isSpinning = false;
        errorMessage = 'Network timeout. Try again.';
      });
    } catch (e) {
      setState(() {
        isSpinning = false;
        errorMessage = 'Network error. Try again.';
      });
    }
  }

  void _showWinDialog(String rewardText) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Center(child: Text(rewardText == 'Nothing today!' ? 'YOU LOSE' : 'YOU WIN', style: TextStyle(color: rewardText == 'Nothing today!' ? Colors.redAccent : Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2.0))),
        content: Text('You won: $rewardText', style: TextStyle(color: _neonCyan, fontSize: 20)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to hub
            },
            child: const Text('AWESOME', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Daily Spin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Spin the wheel once a day to win free Dishi Coins!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 40),
            
            // Pointer
            Icon(Icons.arrow_drop_down, color: _neonPink, size: 60),
            
            // Wheel
            AnimatedBuilder(
              animation: _spinController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _spinController.isAnimating ? _spinAnimation.value : 0,
                  child: CustomPaint(
                    size: const Size(300, 300),
                    painter: WheelPainter(prizes: prizes),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 60),

            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSpun ? Colors.grey : _neonCyan,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: isSpinning ? 0 : 10,
                shadowColor: _neonCyan.withOpacity(0.5),
              ),
              onPressed: (isSpinning || hasSpun) ? null : _handleSpin,
              child: Text(
                isSpinning ? 'SPINNING...' : (hasSpun ? 'COME BACK TOMORROW' : 'SPIN NOW'),
                style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<int> prizes;
  WheelPainter({required this.prizes});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final sweepAngle = (2 * pi) / prizes.length;

    final colors = [
      const Color(0xFF05D5AA),
      const Color(0xFFF92B60),
      const Color(0xFFFFB800),
      const Color(0xFF6C63FF),
      const Color(0xFF00C2FF),
      const Color(0xFFFF6B6B),
    ];

    for (int i = 0; i < prizes.length; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      // Draw slice. Offset by -pi/2 to start at top.
      canvas.drawArc(rect, (i * sweepAngle) - (pi / 2) - (sweepAngle/2), sweepAngle, true, paint);

      // Draw text
      String label = '${prizes[i]}';
      if (prizes[i] == 1) label = 'Free\nDeliv';
      if (prizes[i] == 10) label = '10%\nOff';
      if (prizes[i] == 0) label = 'Try\nAgain';
      if (prizes[i] > 10) label = '${prizes[i]}\nCoins';

      final textPainter = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate((i * sweepAngle) - (pi / 2));
      canvas.translate(size.width / 3, 0); // move out from center
      canvas.rotate(pi / 2); // rotate text so it's readable
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
    
    // Draw center dot
    canvas.drawCircle(Offset(size.width/2, size.height/2), 15, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
