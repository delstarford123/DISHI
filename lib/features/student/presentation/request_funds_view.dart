import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/mpesa_theme.dart';

class RequestFundsView extends StatelessWidget {
  const RequestFundsView({super.key});

  @override
  Widget build(BuildContext context) {
    const String harambeeLink = "https://dishi.delstarfordworks.co.ke/harambee/S-G8XMD";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Harambee (Fund Me)'),
        backgroundColor: MPesaTheme.primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, size: 80, color: Colors.redAccent),
            const SizedBox(height: 24),
            const Text(
              'Invite Friends & Family to Fund You',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Share this custom web link. Anyone who clicks it can instantly fund your campus meals via an M-PESA STK Push directly from their phone, without needing the app!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      harambeeLink,
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: MPesaTheme.primaryGreen),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: harambeeLink));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard!')));
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text('Share via WhatsApp', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
