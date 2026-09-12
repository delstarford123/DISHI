import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OfflineChildQrView extends StatefulWidget {
  final String studentName;
  final String uid;

  const OfflineChildQrView({
    super.key,
    required this.studentName,
    required this.uid,
  });

  @override
  State<OfflineChildQrView> createState() => _OfflineChildQrViewState();
}

class _OfflineChildQrViewState extends State<OfflineChildQrView> {
  String? _dishiId;
  String? _email;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChildData();
  }

  Future<void> _fetchChildData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _dishiId = data['dishiId'] ?? 'N/A';
          _email = data['email'] ?? 'No email provided';
        });
      }
    } catch (e) {
      debugPrint('Error fetching child data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printOrSavePdf(BuildContext context, String qrPayload) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('DISHI STUDENT ID CARD', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(24),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(widget.studentName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Text('Email: ${_email ?? "N/A"}', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                      pw.Text('DISHI ID: ${_dishiId ?? "N/A"}', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                      pw.SizedBox(height: 24),
                      pw.BarcodeWidget(
                        color: PdfColor.fromHex("#000000"),
                        barcode: pw.Barcode.qrCode(),
                        data: qrPayload,
                        width: 200,
                        height: 200,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 40),
                pw.Text('Instructions for Vendor:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                pw.SizedBox(height: 8),
                pw.Text(
                  '1. Open your Vendor POS Scanner.\n'
                  '2. Scan this QR Code to charge the student.\n'
                  '3. Ask the student for their 4-digit Offline PIN to authorize the transaction.',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 24),
                pw.Text('Instructions for Parent/Student:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Keep this card secure. Vendors will use it to process your meals. '
                  'If you forget your card, vendors can also charge you manually using your DISHI ID or Virtual Card Number.',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey800),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${widget.studentName.replaceAll(' ', '_')}_ID_Card.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrPayload = 'swapeat://pay?uid=\${widget.uid}&offlinePinRequired=true';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Offline ID Card', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF131A2A),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () => _printOrSavePdf(context, qrPayload),
            )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Student ID Card',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.studentName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Email: ${_email ?? "N/A"}',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  Text(
                    'DISHI ID: ${_dishiId ?? "N/A"}',
                    style: const TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold),
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
                      size: 220.0,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Vendor Guide:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        SizedBox(height: 4),
                        Text('Scan this QR code and ask the student for their 4-digit PIN.', style: TextStyle(color: Colors.black54, fontSize: 13)),
                        SizedBox(height: 12),
                        Text('Parent Guide:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        SizedBox(height: 4),
                        Text('Download and print this PDF for your offline child. You can link siblings using the DISHI ID above.', style: TextStyle(color: Colors.black54, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _printOrSavePdf(context, qrPayload),
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Download PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
            ),
          ),
    );
  }
}
