import 'package:flutter/material.dart';

class SmartLeaseView extends StatelessWidget {
  const SmartLeaseView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Leases'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description, size: 100, color: Colors.grey),
            const SizedBox(height: 24),
            const Text('Smart e-Lease System', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Generate dynamic PDF leases with cryptographic signatures. Integrated with Firebase Storage for secure document retention.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Generate New Lease'),
            )
          ],
        ),
      ),
    );
  }
}
