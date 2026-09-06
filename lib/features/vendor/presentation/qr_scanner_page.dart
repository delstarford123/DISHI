import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'vendor_topup_view.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
    });
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _isProcessing = true;
        _scannerController.stop();
        _handleScannedPayload(barcode.rawValue!);
        break;
      }
    }
  }

  void _handleScannedPayload(String payload) async {
    String? uid;
    
    // Try JSON parsing first
    try {
      final data = jsonDecode(payload);
      uid = data['uid'];
      final type = data['type'];
      if (type != 'student_payment') {
        _showErrorAndResume('Unsupported QR Type');
        return;
      }
    } catch (e) {
      // Fallback to legacy URI parsing
      if (!payload.startsWith('swapeat://pay?uid=')) {
        _showErrorAndResume('Invalid QR Code');
        return;
      }
      final uri = Uri.parse(payload);
      uid = uri.queryParameters['uid'];
    }

    if (uid == null || uid.isEmpty) {
      _showErrorAndResume('Invalid UID');
      return;
    }

    // Check if user is offline
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final isOffline = doc.data()?['isOffline'] ?? false;
        if (isOffline) {
          _promptForOfflinePin(uid);
          return;
        }
      }
    } catch (e) {
      // Ignore and proceed
    }

    _routeToTopup(uid);
  }

  void _promptForOfflinePin(String uid) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Offline Student Auth', style: TextStyle(color: Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This is an offline student account. Please enter their 4-digit PIN to authenticate.', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Student PIN',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isProcessing = false);
              _scannerController.start();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length != 4) return;
              
              // Verify PIN
              try {
                final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                if (doc.exists && doc.data()?['pin'] == pin) {
                  Navigator.pop(context); // close dialog
                  _routeToTopup(uid);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error verifying PIN: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _routeToTopup(String uid) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => VendorTopupView(studentUid: uid)),
    );
  }

  void _showErrorAndResume(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: MPesaTheme.primaryRed));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isProcessing = false);
        _scannerController.start();
      }
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Student QR'),
        backgroundColor: MPesaTheme.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.yellow),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: !_hasPermission 
        ? const Center(child: Text('Camera Permission Required. Please enable it in settings.', style: TextStyle(color: Colors.red)))
        : Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  return const Center(child: Text('Failed to initialize camera.', style: TextStyle(color: Colors.red)));
                },
              ),
              // Scanner Overlay Frame
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: MPesaTheme.primaryGreen, width: 4),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Text(
                  'Align the QR code within the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16, backgroundColor: Colors.black54),
                ),
              ),
            ],
          ),
    );
  }
}
