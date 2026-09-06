import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorAddFloatView extends StatefulWidget {
  const VendorAddFloatView({super.key});

  @override
  State<VendorAddFloatView> createState() => _VendorAddFloatViewState();
}

class _VendorAddFloatViewState extends State<VendorAddFloatView> {
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Inject Initial Float', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.account_balance_wallet, color: _neonOrange, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Add E-Float via M-PESA',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'To act as a DISHI Agent (Human ATM) and earn commissions, you need E-Float to transfer to students. You naturally earn float by selling food, or you can deposit your own cash right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 48),

            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: _neonOrange, fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: _cardColor,
                hintText: '0.00',
                hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
                prefixText: 'KES ',
                prefixStyle: const TextStyle(color: Colors.white, fontSize: 24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: _neonOrange, width: 2)),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Triggering M-PESA STK Push...'), backgroundColor: _neonOrange));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonOrange,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 10,
                shadowColor: _neonOrange.withOpacity(0.5),
              ),
              child: const Text('DEPOSIT VIA M-PESA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            )
          ],
        ),
      ),
    );
  }
}
