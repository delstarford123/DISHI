import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';

class DriverScannerView extends StatefulWidget {
  const DriverScannerView({super.key});

  @override
  State<DriverScannerView> createState() => _DriverScannerViewState();
}

class _DriverScannerViewState extends State<DriverScannerView> {
  final MobileScannerController _controller = MobileScannerController();
  final List<Map<String, dynamic>> _scannedStudents = [];
  bool _isScannerOpen = false;
  bool _isProcessing = false;
  final String _driverUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final scannedUid = barcode!.rawValue!;
    setState(() => _isProcessing = true);

    try {
      // Fetch the scanned student's profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(scannedUid)
          .get();

      final data = userDoc.data();
      final name = data?['displayName'] ?? data?['firstName'] ?? 'Student $scannedUid';
      final now = DateTime.now();
      final timeStr =
          '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      // Write boarding record to Firestore
      await FirebaseFirestore.instance.collection('transport_sessions').add({
        'student_id': scannedUid,
        'student_name': name,
        'driver_id': _driverUid,
        'status': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'time': timeStr,
      });

      if (mounted) {
        setState(() {
          _isScannerOpen = false;
          _isProcessing = false;
          _scannedStudents.insert(0, {
            'name': name,
            'time': timeStr,
            'status': 'Boarded ✓',
            'uid': scannedUid,
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $name boarded! Parent notified.'),
          backgroundColor: MPesaTheme.primaryGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scan error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Transport Boarding',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isScannerOpen
          ? _buildScanner()
          : _buildHomePanel(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onBarcodeDetected,
        ),
        // Overlay
        Positioned(
          top: 0, left: 0, right: 0, bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: MPesaTheme.primaryGreen.withOpacity(0.4), width: 2),
            ),
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: MPesaTheme.primaryGreen, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner,
                        color: MPesaTheme.primaryGreen.withOpacity(0.8),
                        size: 48),
                    const SizedBox(height: 12),
                    const Text('Point camera at student QR',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                    if (_isProcessing)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: CircularProgressIndicator(
                            color: MPesaTheme.primaryGreen),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Cancel button
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12)),
              onPressed: () => setState(() => _isScannerOpen = false),
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('Cancel Scan',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomePanel() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.directions_bus,
              color: MPesaTheme.primaryGreen, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Transport Boarding',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan student QR codes as they board. Parents receive instant "Safely Boarded" notifications.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // Scan button
          GestureDetector(
            onTap: () => setState(() => _isScannerOpen = true),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF131A2A),
                border: Border.all(color: MPesaTheme.primaryGreen, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: MPesaTheme.primaryGreen.withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 4,
                  )
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner,
                      color: Colors.white, size: 64),
                  SizedBox(height: 8),
                  Text('Tap to Scan',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Recently Boarded',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _scannedStudents.isEmpty
                ? const Center(
                    child: Text('No students scanned yet.',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _scannedStudents.length,
                    itemBuilder: (context, index) {
                      final student = _scannedStudents[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: MPesaTheme.primaryGreen.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Colors.white12,
                                  child: Icon(Icons.person, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(student['name'],
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    Text(student['time'],
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    MPesaTheme.primaryGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                student['status'],
                                style: const TextStyle(
                                    color: MPesaTheme.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
