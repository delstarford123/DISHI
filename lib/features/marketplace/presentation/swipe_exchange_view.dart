import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class SwipeExchangeView extends StatefulWidget {
  final Map<String, dynamic> user;

  const SwipeExchangeView({super.key, required this.user});

  @override
  State<SwipeExchangeView> createState() => _SwipeExchangeViewState();
}

class _SwipeExchangeViewState extends State<SwipeExchangeView> {
  int _swipesToTrade = 1;
  final double _exchangeRate = 150.0;
  bool _isLoading = false;

  void _increment() => setState(() => _swipesToTrade++);
  void _decrement() {
    if (_swipesToTrade > 1) setState(() => _swipesToTrade--);
  }

  Future<void> _tradeSwipes() async {
    setState(() => _isLoading = true);
    
    // Simulate backend /swipe_exchange/trade call
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: const Text('Trade Successful! 🎉', style: TextStyle(color: Colors.white)),
          content: Text(
            'You have successfully traded $_swipesToTrade meal swipes for KES ${_swipesToTrade * _exchangeRate}. The funds have been added to your DISHI Wallet.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back
              },
              child: const Text('Awesome', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _swipesToTrade * _exchangeRate;

    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Swipe Exchange'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant, color: Colors.orangeAccent, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Trade Dining Swipes',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Exchange your unused dining hall swipes for DISHI Wallet balance. Current rate: KES 150 per swipe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 48),
            
            // Selector
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('How many swipes to trade?', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _decrement,
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.orangeAccent, size: 40),
                      ),
                      const SizedBox(width: 32),
                      Text('$_swipesToTrade', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 32),
                      IconButton(
                        onPressed: _increment,
                        icon: const Icon(Icons.add_circle_outline, color: Colors.orangeAccent, size: 40),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('You will receive:', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      Text('KES $totalValue', style: const TextStyle(color: MPesaTheme.primaryGreen, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            
            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _tradeSwipes,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Trade Now', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
