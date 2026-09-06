import 'package:flutter/material.dart';
import '../../../../core/widgets/high_friction_action.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonGreen = Color(0xFF00E676);
const Color _textSecondary = Color(0xFF8B9BB4);

class PayoutHubView extends StatelessWidget {
  const PayoutHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Payout Hub (Withdrawals)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Available Balance
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _neonGreen.withOpacity(0.4), width: 2),
                boxShadow: [BoxShadow(color: _neonGreen.withOpacity(0.15), blurRadius: 30, spreadRadius: 5)],
              ),
              child: Column(
                children: [
                  const Text('Available to Withdraw', style: TextStyle(color: _textSecondary, fontSize: 16)),
                  const SizedBox(height: 16),
                  const Text('KES 14,850.00', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 48),

            const Text('Select Payout Destination', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            _buildDestinationSelector('M-PESA Personal (B2C)', '0712 *** 890', true),
            _buildDestinationSelector('Buy Goods Till (B2B)', 'Till: 123456', false),
            _buildDestinationSelector('Paybill (B2B)', 'Paybill: 222222', false),
            
            const SizedBox(height: 48),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20)),
              child: HighFrictionAction(
                label: 'Hold to Withdraw KES 14,850',
                baseColor: _neonGreen,
                onActionCompleted: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal Initiated to M-PESA!'), backgroundColor: _neonGreen));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationSelector(String title, String detail, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? _neonOrange.withOpacity(0.1) : _surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? _neonOrange : Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? _neonOrange : _textSecondary),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(detail, style: const TextStyle(color: _textSecondary, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
