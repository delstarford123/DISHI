import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../qr_scanner_page.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorFinanceTabView extends StatefulWidget {
  final Map<String, dynamic> user;

  const VendorFinanceTabView({super.key, required this.user});

  @override
  State<VendorFinanceTabView> createState() => _VendorFinanceTabViewState();
}

class _VendorFinanceTabViewState extends State<VendorFinanceTabView> {
  // Dishi Agent Portal Controllers
  final _agentStudentIdController = TextEditingController();
  final _agentAmountController = TextEditingController();
  bool _isAgentLoading = false;

  // P2P Transfer Controllers
  final _p2pVendorIdController = TextEditingController();
  final _p2pAmountController = TextEditingController();
  bool _isP2pLoading = false;

  // Supplier Payment Controllers
  final _supplierIdController = TextEditingController();
  final _supplierAmountController = TextEditingController();
  bool _isSupplierLoading = false;

  Future<void> _handleAgentDeposit() async {
    final studentId = _agentStudentIdController.text.trim();
    final amount = double.tryParse(_agentAmountController.text.trim()) ?? 0.0;

    if (studentId.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid Student ID/Dishi ID and Amount.')));
      return;
    }

    setState(() => _isAgentLoading = true);

    try {
      String resolvedUid = studentId;
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('dishiId', isEqualTo: studentId)
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isNotEmpty) {
        resolvedUid = querySnapshot.docs.first.id;
      } else {
        final doc = await FirebaseFirestore.instance.collection('users').doc(studentId).get();
        if (!doc.exists) {
          if (!mounted) return;
          setState(() => _isAgentLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student not found.'), backgroundColor: Colors.red));
          return;
        }
      }

      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_finance/agent/deposit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorUid': widget.user['uid'],
          'studentUid': resolvedUid,
          'amount': amount,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Deposit successful'), backgroundColor: _neonCyan));
        _agentStudentIdController.clear();
        _agentAmountController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Deposit failed'), backgroundColor: Colors.red));
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isAgentLoading = false);
    }
  }

  Future<void> _handleP2PTransfer() async {
    final receiverId = _p2pVendorIdController.text.trim();
    final amount = double.tryParse(_p2pAmountController.text.trim()) ?? 0.0;

    if (receiverId.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid Vendor ID and Amount.')));
      return;
    }

    setState(() => _isP2pLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_finance/p2p_transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderUid': widget.user['uid'],
          'receiverUid': receiverId,
          'amount': amount,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Transfer successful'), backgroundColor: _neonCyan));
        _p2pVendorIdController.clear();
        _p2pAmountController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Transfer failed'), backgroundColor: Colors.red));
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isP2pLoading = false);
    }
  }

  Future<void> _handleSupplierPayment() async {
    final supplierId = _supplierIdController.text.trim();
    final amount = double.tryParse(_supplierAmountController.text.trim()) ?? 0.0;

    if (supplierId.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid Supplier ID and Amount.')));
      return;
    }

    setState(() => _isSupplierLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_finance/supplier/pay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorUid': widget.user['uid'],
          'supplierId': supplierId,
          'amount': amount,
          'invoiceNumber': 'INV-${DateTime.now().millisecondsSinceEpoch}'
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Payment successful'), backgroundColor: _neonCyan));
        _supplierIdController.clear();
        _supplierAmountController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Payment failed'), backgroundColor: Colors.red));
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSupplierLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Dishi Agent Section
        _buildSectionHeader('Dishi Agent Portal', Icons.storefront, _neonCyan),
        const SizedBox(height: 8),
        const Text(
          'Accept physical cash from students and transfer E-Float directly to their wallets. You earn a 0.5% commission on every deposit.',
          style: TextStyle(color: _textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _neonCyan.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _agentStudentIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Student UID or Dishi ID',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: _neonCyan),
                    onPressed: () async {
                      final scannedUid = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QrScannerPage(returnUidOnly: true)),
                      );
                      if (scannedUid != null && scannedUid is String) {
                        _agentStudentIdController.text = scannedUid;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _agentAmountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cash Received (KSH)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isAgentLoading ? null : _handleAgentDeposit,
                  icon: _isAgentLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black)) : const Icon(Icons.sync_alt, color: Colors.black),
                  label: Text(_isAgentLoading ? 'Processing...' : 'Complete Deposit', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // P2P Vendor Transfer Section
        _buildSectionHeader('P2P Vendor Transfer', Icons.swap_horiz, _neonOrange),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              TextField(
                controller: _p2pVendorIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Vendor UID',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _p2pAmountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (KSH)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isP2pLoading ? null : _handleP2PTransfer,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonOrange)),
                  child: _isP2pLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _neonOrange)) 
                      : const Text('Send E-Float', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Supplier Payments Section
        _buildSectionHeader('Supplier Payments', Icons.local_shipping, Colors.white),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              TextField(
                controller: _supplierIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Supplier UID',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _supplierAmountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (KSH)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isSupplierLoading ? null : _handleSupplierPayment,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white)),
                  child: _isSupplierLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Pay Supplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
        
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
