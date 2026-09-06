import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfGenerator {
  static Future<void> printStudentQR({
    required String dishiId,
    required String qrData,
  }) async {
    final pdf = pw.Document();
    
    // Load logo if possible, or just use text
    pw.MemoryImage? logoImage;
    try {
      logoImage = pw.MemoryImage(
        (await rootBundle.load('assets/img/dishi_logo.png')).buffer.asUint8List(),
      );
    } catch (e) {
      // Ignored
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) pw.Image(logoImage, width: 100, height: 100),
                pw.SizedBox(height: 20),
                pw.Text('DISHI Student ID', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('DISHI ID: $dishiId', style: pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 40),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 250,
                  height: 250,
                ),
                pw.SizedBox(height: 40),
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Instructions for Student:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                      pw.Text('1. Present this QR code to the vendor when purchasing food.'),
                      pw.Text('2. If you are an offline student, provide your 4-digit PIN to the vendor.'),
                      pw.SizedBox(height: 10),
                      pw.Text('Instructions for Vendor:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                      pw.Text('1. Use the DISHI Vendor App to scan this QR Code.'),
                      pw.Text('2. If scanning fails, enter the DISHI ID ($dishiId) manually.'),
                      pw.Text('3. Ask for the student\'s PIN if they are an offline student.'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'DISHI_Student_ID_$dishiId',
    );
  }
}
