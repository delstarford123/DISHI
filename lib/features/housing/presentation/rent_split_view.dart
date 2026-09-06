import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class RentSplitView extends StatefulWidget {
  const RentSplitView({super.key});

  @override
  State<RentSplitView> createState() => _RentSplitViewState();
}

class _RentSplitViewState extends State<RentSplitView> {
  final double totalRent = 15000;
  final double myShare = 7500;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Roommate Rent Split'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.pie_chart, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text('Total Monthly Rent: KES \$totalRent', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const Text('Your Share', style: TextStyle(color: Colors.grey)),
                  Text('KES \$myShare', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: MPesaTheme.primaryGreen)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Triggering M-PESA STK Push for your share...')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MPesaTheme.primaryGreen,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Pay My Share (M-PESA)'),
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
