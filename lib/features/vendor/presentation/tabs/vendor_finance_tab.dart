import 'package:flutter/material.dart';
import '../../../../core/services/api_config.dart';
import '../../../../core/services/secure_http_client.dart';
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
  bool _autoPaySupplier = false;

  // Auto-Withdrawal State
  bool _autoWithdrawal = false;

  // Escrow Controllers
  final _escrowPhoneController = TextEditingController();
  final _escrowAmountController = TextEditingController();
  final _escrowEventController = TextEditingController();
  bool _isEscrowLoading = false;

  // Tax Export State
  bool _isTaxExporting = false;
  bool _isAdvancedReporting = false;
  
  // Refund Controllers
  final _refundStudentIdController = TextEditingController();
  final _refundAmountController = TextEditingController();
  final _refundReasonController = TextEditingController();
  bool _isRefunding = false;

  @override
  void dispose() {
    _agentStudentIdController.dispose();
    _agentAmountController.dispose();
    _p2pVendorIdController.dispose();
    _p2pAmountController.dispose();
    _supplierIdController.dispose();
    _supplierAmountController.dispose();
    _escrowPhoneController.dispose();
    _escrowAmountController.dispose();
    _escrowEventController.dispose();
    _refundStudentIdController.dispose();
    _refundAmountController.dispose();
    _refundReasonController.dispose();
    super.dispose();
  }

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

      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_finance/agent/deposit',
        body: {
          'vendorUid': widget.user['uid'],
          'studentUid': resolvedUid,
          'amount': amount,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Deposit successful'), backgroundColor: _neonCyan));
        _agentStudentIdController.clear();
        _agentAmountController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Deposit failed'), backgroundColor: Colors.red));
      }
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
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_finance/p2p_transfer',
        body: {
          'senderUid': widget.user['uid'],
          'receiverUid': receiverId,
          'amount': amount,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Transfer successful'), backgroundColor: _neonCyan));
        _p2pVendorIdController.clear();
        _p2pAmountController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Transfer failed'), backgroundColor: Colors.red));
      }
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
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_finance/supplier/pay',
        body: {
          'vendorUid': widget.user['uid'],
          'supplierId': supplierId,
          'amount': amount,
          'invoiceNumber': 'INV-${DateTime.now().millisecondsSinceEpoch}'
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Payment successful'), backgroundColor: _neonCyan));
        _supplierIdController.clear();
        _supplierAmountController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Payment failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSupplierLoading = false);
    }
  }

  Future<void> _handleEscrowRequest() async {
    final phone = _escrowPhoneController.text.trim();
    final amount = double.tryParse(_escrowAmountController.text.trim()) ?? 0.0;
    final event = _escrowEventController.text.trim();

    if (phone.isEmpty || amount <= 0 || event.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Phone, Amount, and Event Name.')));
      return;
    }

    setState(() => _isEscrowLoading = true);

    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_finance/escrow/request',
        body: {
          'vendorUid': widget.user['uid'],
          'parentPhone': phone,
          'amount': amount,
          'eventName': event,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Escrow requested successfully'), backgroundColor: _neonCyan));
        _escrowPhoneController.clear();
        _escrowAmountController.clear();
        _escrowEventController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Escrow request failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isEscrowLoading = false);
    }
  }

  Future<void> _handleTaxExport() async {
    setState(() => _isTaxExporting = true);

    try {
      final response = await SecureHttpClient.get(
        '${ApiConfig.baseUrl}/api/v1/vendor_finance/tax_export?vendorUid=${widget.user['uid']}',
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final summary = data['data'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Tax report generated'), backgroundColor: _neonCyan));
        
        // Show summary dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('KRA Tax Report Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: _cardColor,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gross Revenue: Ksh ${summary['grossRevenue']}'),
                Text('VAT Collected: Ksh ${summary['vatCollected']}'),
                Text('Transactions: ${summary['transactionsCount']}'),
                Text('KRA PIN: ${summary['kraPin']}'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Tax export failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isTaxExporting = false);
    }
  }

  Future<void> _handleAdvancedReport() async {
    setState(() => _isAdvancedReporting = true);
    try {
      final response = await SecureHttpClient.get(
        '${ApiConfig.baseUrl}/api/v1/vendor_finance/advanced_export?vendorUid=${widget.user['uid']}&format=csv',
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final metrics = data['data']['metrics'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Advanced report generated'), backgroundColor: _neonCyan));
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Advanced Financial Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: _cardColor,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Sales: Ksh ${metrics['totalSales']}'),
                Text('Total Refunds: Ksh ${metrics['totalRefunds']}'),
                Text('Escrow Held: Ksh ${metrics['escrowHeld']}'),
                Text('Top Selling: ${metrics['topSellingItem']}'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Report failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isAdvancedReporting = false);
    }
  }

  Future<void> _handleRefund() async {
    final studentId = _refundStudentIdController.text.trim();
    final amount = double.tryParse(_refundAmountController.text.trim()) ?? 0.0;
    final reason = _refundReasonController.text.trim();

    if (studentId.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid Student ID and Amount.')));
      return;
    }

    setState(() => _isRefunding = true);
    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_finance/refund',
        body: {
          'vendorUid': widget.user['uid'],
          'studentUid': studentId,
          'amount': amount,
          'reason': reason.isNotEmpty ? reason : 'Customer requested refund',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Refund successful'), backgroundColor: _neonCyan));
        _refundStudentIdController.clear();
        _refundAmountController.clear();
        _refundReasonController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Refund failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isRefunding = false);
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
          'Accept physical cash from students and transfer E-Float directly to their wallets. You earn commission on every deposit (0.5% + 7 KSh).',
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
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Auto-Pay', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Automatically pay this supplier when balance > 10,000 KSH', style: TextStyle(color: _textSecondary, fontSize: 12)),
                activeColor: _neonCyan,
                value: _autoPaySupplier,
                onChanged: (val) {
                  setState(() => _autoPaySupplier = val);
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),

        // Escrow for Bulk Catering Orders
        _buildSectionHeader('Bulk Catering Escrow', Icons.handshake, Colors.deepPurpleAccent),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request a secure escrow payment from a parent for large events (e.g., Birthday Party). Funds are held until fulfillment.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _escrowEventController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Event Name (e.g., John Birthday)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _escrowPhoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Parent Phone',
                        labelStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _bgColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _escrowAmountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Amount (KSH)',
                        labelStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _bgColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isEscrowLoading ? null : _handleEscrowRequest,
                  icon: _isEscrowLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.security, color: Colors.white),
                  label: Text(_isEscrowLoading ? 'Requesting...' : 'Request Escrow Payment', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Auto-Withdrawal Section
        _buildSectionHeader('E-Float Auto-Withdrawal', Icons.schedule, _neonCyan),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Schedule your e-float to automatically withdraw to your M-PESA Till every night at 9:00 PM.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable 9 PM Auto-Withdrawal', style: TextStyle(color: Colors.white, fontSize: 14)),
                activeColor: _neonCyan,
                value: _autoWithdrawal,
                onChanged: (val) {
                  setState(() => _autoWithdrawal = val);
                  if (val) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-withdrawal scheduled for 9:00 PM'), backgroundColor: _neonCyan));
                  }
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),

        // Tax & Revenue Export Section
        _buildSectionHeader('Automated Tax & Revenue Export', Icons.receipt_long, Colors.greenAccent),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Generate compliant tax reports and revenue summaries for KRA filings.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isTaxExporting ? null : _handleTaxExport,
                  icon: _isTaxExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black)) : const Icon(Icons.download, color: Colors.black),
                  label: Text(_isTaxExporting ? 'Generating Report...' : 'Download KRA Tax Report', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isAdvancedReporting ? null : _handleAdvancedReport,
                  icon: _isAdvancedReporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.greenAccent)) : const Icon(Icons.analytics, color: Colors.greenAccent),
                  label: Text(_isAdvancedReporting ? 'Analyzing...' : 'Advanced Financial Analysis', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.greenAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        
        // Automated Vendor Refunds
        _buildSectionHeader('Automated Refunds', Icons.money_off, Colors.redAccent),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Instantly refund a student from your E-Float for cancelled or problematic orders.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _refundStudentIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Student UID',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _refundAmountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Refund Amount (KSH)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _refundReasonController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Reason (Optional)',
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
                  onPressed: _isRefunding ? null : _handleRefund,
                  icon: _isRefunding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.settings_backup_restore, color: Colors.white),
                  label: Text(_isRefunding ? 'Processing...' : 'Issue Refund', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
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
