import 'package:flutter/material.dart';
import '../theme/mpesa_theme.dart';

class SystemAnnouncementsBanner extends StatelessWidget {
  final String announcement;
  final VoidCallback onDismiss;

  const SystemAnnouncementsBanner({
    super.key,
    required this.announcement,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: MPesaTheme.primaryGreen,
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              announcement,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
