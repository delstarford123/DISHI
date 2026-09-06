import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class OkoaFoodView extends StatefulWidget {
  const OkoaFoodView({super.key});

  @override
  State<OkoaFoodView> createState() => _OkoaFoodViewState();
}

class _OkoaFoodViewState extends State<OkoaFoodView> {
  double _maxLimit = 50.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLimit();
  }

  Future<void> _fetchLimit() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('app_settings').doc('okoa_config').get();
      if (doc.exists && doc.data()!.containsKey('max_limit')) {
        setState(() {
          _maxLimit = (doc.data()!['max_limit'] as num).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch okoa config: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Okoa Food'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : Padding(
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
            Text(
              'Okoa Food allows you to overdraw your wallet up to KES ${_maxLimit.toStringAsFixed(0)} to grab a meal. The amount will be automatically deducted from your next top-up.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
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
                  Text('KES ${_maxLimit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange)),
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
