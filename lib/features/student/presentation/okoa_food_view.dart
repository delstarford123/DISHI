import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class OkoaFoodView extends StatelessWidget {
  const OkoaFoodView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Okoa Food'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.fastfood, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'Zero Balance? No Problem.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Okoa Food allows you to overdraw your wallet up to KES 500 to grab a meal. The amount will be automatically deducted from your next top-up.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  const Text('Available Limit', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('KES 500.00', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Okoa Food Activated! Wallet overdrawn.')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Activate Okoa Food'),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
