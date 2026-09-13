import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFFF2A5F);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorSalesTabView extends StatefulWidget {
  final Map<String, dynamic> user;

  const VendorSalesTabView({super.key, required this.user});

  @override
  State<VendorSalesTabView> createState() => _VendorSalesTabViewState();
}

class _VendorSalesTabViewState extends State<VendorSalesTabView> {
  // Flash Sale Controllers
  final _flashItemController = TextEditingController();
  final _flashDiscountController = TextEditingController();
  bool _isFlashLoading = false;

  // Loyalty Controllers
  final _loyaltyStudentController = TextEditingController();
  bool _isLoyaltyLoading = false;

  Future<void> _handleFlashSale() async {
    final item = _flashItemController.text.trim();
    final msg = _flashDiscountController.text.trim();

    if (item.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Item Name and Discount Message')));
      return;
    }

    setState(() => _isFlashLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_sales/sales/flash_sale'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorUid': widget.user['uid'],
          'itemName': item,
          'discountMsg': msg,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Flash sale broadcasted!'), backgroundColor: _neonCyan));
        _flashItemController.clear();
        _flashDiscountController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Broadcast failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isFlashLoading = false);
    }
  }

  Future<void> _handleLoyaltyStamp() async {
    final studentId = _loyaltyStudentController.text.trim();

    if (studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Student UID')));
      return;
    }

    setState(() => _isLoyaltyLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_sales/loyalty/stamp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorUid': widget.user['uid'],
          'studentUid': studentId,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Stamp added!'), backgroundColor: data['rewardUnlocked'] == true ? _neonPink : _neonCyan));
        _loyaltyStudentController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Failed to add stamp'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoyaltyLoading = false);
    }
  }

  Future<void> _markOrderFulfilled(String orderId) async {
    try {
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_sales/preorders/fulfill'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked fulfilled'), backgroundColor: _neonCyan));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fulfill order'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Flash Sale Broadcaster
        _buildSectionHeader('Flash Sale Broadcaster', Icons.bolt, _neonOrange),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _neonOrange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Push a discount notification to nearby students.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _flashItemController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _flashDiscountController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Discount Message (e.g. 50% Off!)',
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
                  onPressed: _isFlashLoading ? null : _handleFlashSale,
                  icon: _isFlashLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black)) : const Icon(Icons.campaign, color: Colors.black),
                  label: Text(_isFlashLoading ? 'Broadcasting...' : 'Broadcast Sale', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Digital Loyalty Scanner
        _buildSectionHeader('Digital Loyalty Cards', Icons.loyalty, _neonPink),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Enter student UID to award a loyalty stamp. (Buy 10, get 1 free)', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _loyaltyStudentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Student UID',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: const Icon(Icons.qr_code_scanner, color: _neonPink),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoyaltyLoading ? null : _handleLoyaltyStamp,
                  icon: _isLoyaltyLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _neonPink)) : const Icon(Icons.star, color: _neonPink),
                  label: Text(_isLoyaltyLoading ? 'Processing...' : 'Award Stamp', style: const TextStyle(color: _neonPink)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonPink), padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Pre-Order KDS Queue
        _buildSectionHeader('Pre-Orders (KDS)', Icons.kitchen, _neonCyan),
        const SizedBox(height: 8),
        const Text('Meals pre-paid by parents or students that need to be fulfilled today.', style: TextStyle(color: _textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('orders')
            .where('vendorUid', isEqualTo: widget.user['uid'])
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: false)
            .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _neonCyan));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No pending pre-orders.', style: TextStyle(color: _textSecondary)),
              );
            }
            
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final orderId = doc.id;
                
                final dt = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();
                final timeStr = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                
                // Build a nice items string
                final itemsList = data['items'] as List<dynamic>? ?? [];
                final itemsStr = itemsList.map((item) => '${item['quantity'] ?? 1}x ${item['name'] ?? 'Item'}').join(', ');
                
                final orderSource = (data['isParentOrder'] == true) ? 'Parent Pre-Order' : 'Student Pre-Order';
                final studentName = data['studentName'] ?? 'Student';

                return _buildKdsTicket(orderId, studentName, itemsStr, timeStr, orderSource);
              }).toList(),
            );
          }
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

  Widget _buildKdsTicket(String orderId, String studentName, String items, String time, String orderSource) {
    bool isParent = orderSource == 'Parent Pre-Order';
    Color sourceColor = isParent ? _neonCyan : _neonOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: sourceColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Order #${orderId.substring(0, 5)}', style: TextStyle(color: sourceColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: sourceColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text(orderSource, style: TextStyle(color: sourceColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Text(time, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          if (items.isNotEmpty) Text(items, style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _markOrderFulfilled(orderId),
              style: ElevatedButton.styleFrom(backgroundColor: _bgColor, side: const BorderSide(color: _neonCyan)),
              child: const Text('Mark Fulfilled', style: TextStyle(color: _neonCyan)),
            ),
          )
        ],
      ),
    );
  }
}
