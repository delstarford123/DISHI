import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/mpesa_theme.dart';

class VirtualCardView extends StatefulWidget {
  final UserModel userModel;

  const VirtualCardView({super.key, required this.userModel});

  @override
  State<VirtualCardView> createState() => _VirtualCardViewState();
}

class _VirtualCardViewState extends State<VirtualCardView> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFront = true;
  bool _showDetails = false;
  bool _isLoading = true;

  late String _pan;
  late String _expiry;
  late String _cvv;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeCard();
  }

  Future<void> _initializeCard() async {
    if (widget.userModel.virtualCard != null) {
      final card = widget.userModel.virtualCard!;
      _pan = card['pan'];
      _expiry = card['expiry'];
      _cvv = card['cvv'];
      setState(() {
        _isLoading = false;
      });
    } else {
      // Generate a new random card
      final random = Random();
      _pan = "4512 ${random.nextInt(9000) + 1000} ${random.nextInt(9000) + 1000} ${random.nextInt(9000) + 1000}";
      _expiry = "${(DateTime.now().month + random.nextInt(12)) % 12 + 1}/${DateTime.now().year % 100 + 4}";
      _cvv = "${random.nextInt(900) + 100}";
      
      await FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).update({
        'virtualCard': {
          'pan': _pan,
          'expiry': _expiry,
          'cvv': _cvv,
        }
      });
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  Widget _buildFrontCard() {
    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF00FFD1), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFD1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DISHI VIRTUAL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
              Icon(Icons.wifi, color: Colors.black),
            ],
          ),
          Text(
            _isLoading ? '**** **** **** ****' : (_showDetails ? _pan : '**** **** **** ${_pan.substring(_pan.length - 4)}'),
            style: const TextStyle(color: Colors.black, fontSize: 24, letterSpacing: 4, fontFamily: 'monospace', fontWeight: FontWeight.w600),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CARDHOLDER', style: TextStyle(color: Colors.black54, fontSize: 10, letterSpacing: 1)),
                  Text(widget.userModel.displayName?.toUpperCase() ?? 'DISHI USER', style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('EXPIRES', style: TextStyle(color: Colors.black54, fontSize: 10, letterSpacing: 1)),
                  Text(_isLoading ? '**/**' : _expiry, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBackCard() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF00FFD1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              height: 40,
              width: double.infinity,
              color: Colors.black87,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      color: Colors.white.withOpacity(0.8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        _isLoading ? '***' : (_showDetails ? _cvv : '***'),
                        style: const TextStyle(color: Colors.black, fontStyle: FontStyle.italic, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'This card is issued by DISHI Wallet. Use for online payments only.',
                style: TextStyle(color: Colors.black54, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Virtual Card'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Virtual Card',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use this card to pay for Netflix, Spotify, or online shopping using your DISHI wallet balance.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 40),
            
            GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_animation.value * pi);
                    
                  return Transform(
                    transform: transform,
                    alignment: Alignment.center,
                    child: _animation.value < 0.5 
                      ? _buildFrontCard()
                      : _buildBackCard(),
                  );
                }
              ),
            ),
            
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showDetails = !_showDetails;
                    });
                  },
                  icon: Icon(_showDetails ? Icons.visibility_off : Icons.visibility, color: Colors.black),
                  label: Text(_showDetails ? 'Hide Details' : 'Show Details', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFD1),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    if (!_isLoading) Clipboard.setData(ClipboardData(text: _pan));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card number copied!')));
                  },
                  icon: const Icon(Icons.copy, color: Color(0xFF00FFD1)),
                  label: const Text('Copy', style: TextStyle(color: Color(0xFF00FFD1))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00FFD1)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
