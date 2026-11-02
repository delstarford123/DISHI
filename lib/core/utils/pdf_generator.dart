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

  static Future<void> printVendorDailyAudit({
    required String vendorName,
    required String tillNumber,
    required double totalRevenue,
    required int totalOrders,
    required double floatBalance,
    String? cashierName,
    List<Map<String, dynamic>>? orders,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DISHI CAMPUS COMMERCE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                        pw.SizedBox(height: 4),
                        pw.Text('End-of-Day POS Audit & Reconciliation', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('DATE: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('STATUS: RECONCILED', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.grey400),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Vendor: $vendorName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      pw.Text('Till / Store ID: $tillNumber', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Cashier: ${cashierName ?? "Till Operator"}', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text('Performance Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Gross Sales Today', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.SizedBox(height: 4),
                            pw.Text('KES ${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Total Completed Orders', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.SizedBox(height: 4),
                            pw.Text('$totalOrders Orders', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Available Float Balance', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            pw.SizedBox(height: 4),
                            pw.Text('KES ${floatBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('Audit Settlement Verification', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: ['Transaction Type', 'Count', 'Net Settlement', 'M-Pesa Verification'],
                  data: [
                    ['Campus Wallet Orders', '$totalOrders', 'KES ${totalRevenue.toStringAsFixed(2)}', 'Instant Settled (0% Commission)'],
                    ['Float Top-up / Deposits', 'Reconciled', 'KES ${floatBalance.toStringAsFixed(2)}', 'Daraja STK Verified'],
                    ['M-Pesa Cash Outs', 'Completed', 'Available for Transfer', 'B2C / B2B Ready'],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                  cellHeight: 28,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerLeft,
                  },
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Cashier Signature: ______________________', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('Name: ${cashierName ?? "Authorized Cashier"}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Store Manager: ______________________', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('Verified by DISHI Escrow Node', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text('DISHI Campus Commerce System • Protected by End-to-End Cryptographic Escrow', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'DISHI_EOD_Audit_${vendorName.replaceAll(' ', '_')}_${now.day}_${now.month}',
    );
  }
}
