import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto/crypto.dart';
import '../../../core/theme/mpesa_theme.dart';

class DynamicQrDialog extends StatefulWidget {
  final String dishiId;
  final String purpose;

  const DynamicQrDialog({
    super.key,
    required this.dishiId,
    required this.purpose,
  });

  @override
  State<DynamicQrDialog> createState() => _DynamicQrDialogState();
}

class _DynamicQrDialogState extends State<DynamicQrDialog> {
  Timer? _timer;
  String _qrData = '';
  
  @override
  void initState() {
    super.initState();
    _generateTOTP();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _generateTOTP();
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  void _generateTOTP() {
    // Generate a TOTP based on 5 second intervals
    final timeWindow = DateTime.now().millisecondsSinceEpoch ~/ 5000;
    
    // Hash the ID, purpose, and time window
    final dataString = '${widget.dishiId}|${widget.purpose}|$timeWindow';
    final bytes = utf8.encode(dataString);
    final digest = sha256.convert(bytes);
    
    setState(() {
      _qrData = '${widget.dishiId}|${widget.purpose}|${digest.toString().substring(0, 8)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF131A2A),
      title: const Text('Dynamic QR Entry', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Anti-Screenshot Active',
            style: TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'This code refreshes every 5 seconds.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
        )
      ],
    );
  }
}
