import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vendor_topup_view.dart';
import '../../../core/services/permission_disclosure_service.dart';
import '../../../core/services/api_config.dart';
import '../../../core/services/secure_http_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF161B29);
const Color _neonCyan = Color(0xFF05D5AA);

class QrScannerPage extends StatefulWidget {
  final bool returnUidOnly;
  const QrScannerPage({super.key, this.returnUidOnly = false});

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestCameraPermission();
    });
  }

  Future<void> _requestCameraPermission() async {
    final granted =
        await PermissionDisclosureService.requestCameraWithDisclosure(context);
    if (mounted) {
      setState(() {
        _hasPermission = granted;
      });
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

  void _handlePickupVerification(String orderId, String token, String pin) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: _neonCyan),
      ),
    );

    try {
      final vendorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final resp = await SecureHttpClient.post(
        ApiConfig.v6ValidatePickupToken,
        body: {
          'order_id': orderId,
          'token': token,
          'pin': pin,
          'vendor_uid': vendorUid,
        },
      );

      Navigator.pop(context); // dismiss loading

      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200 && data['valid'] == true) {
        final studentName = data['student_name'] ?? 'Student';
        final items = (data['items'] as List<dynamic>?) ?? [];
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _neonCyan)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: _neonCyan, size: 28),
                SizedBox(width: 10),
                Text('Order Verified & Released', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: $studentName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Order #$orderId', style: const TextStyle(color: _neonCyan, fontSize: 12)),
                const SizedBox(height: 12),
                const Text('Items to Hand Over:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                ...items.map((it) => Text('• ${it['name']} x${it['quantity'] ?? 1}', style: const TextStyle(color: Colors.white))),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // return to dashboard
                },
                child: const Text('Complete Pickup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        final err = data['error'] ?? 'Token invalid or expired.';
        _showErrorAndResume(err);
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorAndResume('Verification failed: $e');
    }
  }

  void _handleSupermarketSku(String sku) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: _neonCyan)),
    );

    try {
      final resp = await SecureHttpClient.get('${ApiConfig.v6SkuLookup}/$sku');
      Navigator.pop(context); // dismiss loading

      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200 && data['found'] == true) {
        final product = data['product'] as Map<String, dynamic>;
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: _cardColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(product['name'] ?? 'Product', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text('SKU Barcode: $sku', style: const TextStyle(color: _neonCyan, fontSize: 12)),
                const SizedBox(height: 12),
                Text('Price: KES ${product['price']}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Stock Remaining: ${product['stock'] ?? 0} units', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, product);
                    },
                    child: const Text('Add to POS Cart', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        _showErrorAndResume('SKU not found in catalog.');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorAndResume('Error scanning SKU: $e');
    }
  }

  void _handleScannedPayload(String payload) async {
    // 1. Dynamic DISHI Pickup Pass
    if (payload.startsWith('DISHI:PICKUP:')) {
      final parts = payload.split(':');
      if (parts.length >= 5) {
        final orderId = parts[2];
        final token = parts[3];
        final pin = parts[4];
        _handlePickupVerification(orderId, token, pin);
        return;
      }
    }

    // 2. Supermarket SKU Barcode (UPC / EAN-13 / 8-14 numeric digits)
    final trimmed = payload.trim();
    if (RegExp(r'^\d{8,14}$').hasMatch(trimmed)) {
      _handleSupermarketSku(trimmed);
      return;
    }

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
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
            child: const Text('Verify', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _routeToTopup(String uid) {
    if (widget.returnUidOnly) {
      Navigator.pop(context, uid);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => VendorTopupView(studentUid: uid)),
      );
    }
  }

  void _showErrorAndResume(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
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
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Scan Student QR', style: TextStyle(color: Colors.white)),
        backgroundColor: _bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: _neonCyan),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
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
                    border: Border.all(color: _neonCyan, width: 4),
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
