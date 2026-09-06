import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class DriverScannerView extends StatefulWidget {
  const DriverScannerView({super.key});

  @override
  State<DriverScannerView> createState() => _DriverScannerViewState();
}

class _DriverScannerViewState extends State<DriverScannerView> {
  final List<Map<String, dynamic>> _scannedStudents = [];
  bool _isScanning = false;

  void _simulateScan() {
    setState(() => _isScanning = true);
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scannedStudents.insert(0, {
            'name': 'Student ID #${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
            'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            'status': 'Boarded',
          });
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tag Scanned Successfully! Push notification sent to parent.'),
            backgroundColor: MPesaTheme.primaryGreen,
          )
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Transport Boarding'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus, color: MPesaTheme.primaryGreen, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Automated Boarding',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan student NFC tags as they board. Parents will receive an instant "Safely Boarded" push notification.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            // Scanner Area
            GestureDetector(
              onTap: _isScanning ? null : _simulateScan,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isScanning ? MPesaTheme.primaryGreen.withOpacity(0.2) : const Color(0xFF131A2A),
                  border: Border.all(color: MPesaTheme.primaryGreen, width: 4),
                  boxShadow: [
                    if (_isScanning)
                      BoxShadow(
                        color: MPesaTheme.primaryGreen.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      )
                  ],
                ),
                child: Center(
                  child: _isScanning
                      ? const CircularProgressIndicator(color: MPesaTheme.primaryGreen)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.nfc, color: Colors.white, size: 64),
                            SizedBox(height: 8),
                            Text('Tap to Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Scanned List
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recently Boarded', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _scannedStudents.isEmpty
                  ? const Center(child: Text('No students scanned yet.', style: TextStyle(color: Colors.white54)))
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
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(student['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      Text(student['time'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: MPesaTheme.primaryGreen.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  student['status'],
                                  style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12),
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
      ),
    );
  }
}
