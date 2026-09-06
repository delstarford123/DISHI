import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class ReceiptOcrScanner extends StatefulWidget {
  const ReceiptOcrScanner({super.key});

  @override
  State<ReceiptOcrScanner> createState() => _ReceiptOcrScannerState();
}

class _ReceiptOcrScannerState extends State<ReceiptOcrScanner> {
  bool _isScanning = false;

  void _scanReceipt() {
    setState(() => _isScanning = true);
    
    // Simulate Vercel OCR endpoint call
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isScanning = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('OCR Success'),
            content: const Text('Extracted Total: KES 850.00\nVendor: Java House\n\nAutomatically logged to your Budget Sankey Diagram.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Great'),
              )
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          // Simulated Camera Preview
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                border: Border.all(color: MPesaTheme.primaryGreen, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white24, size: 100),
                  if (_isScanning)
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: MPesaTheme.primaryGreen,
                        boxShadow: [BoxShadow(color: MPesaTheme.primaryGreen.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  const Text('Align receipt within the frame', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _isScanning ? null : _scanReceipt,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isScanning ? Colors.grey : Colors.white,
                        border: Border.all(color: MPesaTheme.primaryGreen, width: 4),
                      ),
                      child: _isScanning ? const CircularProgressIndicator(color: MPesaTheme.primaryGreen) : null,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
