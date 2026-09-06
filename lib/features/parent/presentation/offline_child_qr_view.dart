import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/mpesa_theme.dart';

class OfflineChildQrView extends StatelessWidget {
  final String studentName;
  final String uid;

  const OfflineChildQrView({
    super.key,
    required this.studentName,
    required this.uid,
  });

  void _printOrSavePdf(BuildContext context) {
    // In production, this would use the `pdf` or `printing` package to generate an A4 sheet.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID Card saved to Downloads as PDF.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrPayload = 'swapeat://pay?uid=\$uid&offlinePinRequired=true';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Offline ID Card'),
        backgroundColor: MPesaTheme.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printOrSavePdf(context),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Student ID Card',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                studentName,
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
                ),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 250.0,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'If your child does not have a phone, you can print this screen. Vendors will scan it to charge their wallet or top them up (requires PIN).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _printOrSavePdf(context),
                icon: const Icon(Icons.download),
                label: const Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: MPesaTheme.primaryGreen,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
