import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFFF2A5F);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorSalesTabView extends StatelessWidget {
  final Map<String, dynamic> user;

  const VendorSalesTabView({super.key, required this.user});

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
                  onPressed: () {},
                  icon: const Icon(Icons.campaign, color: Colors.black),
                  label: const Text('Broadcast Sale', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              const Text('Scan student QR to award a loyalty stamp. (Buy 10, get 1 free)', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.qr_code_scanner, color: _neonPink),
                  label: const Text('Scan & Award Stamp', style: TextStyle(color: _neonPink)),
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
        _buildKdsTicket('Order #142', 'John Doe (Grade 4)', 'Beef Stew & Rice', '12:30 PM', 'Parent Pre-Order'),
        _buildKdsTicket('Order #143', 'Jane Smith (Grade 6)', '2x Chapati & Beans', '12:45 PM', 'Student Pre-Order'),
        
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

  Widget _buildKdsTicket(String orderNumber, String studentName, String items, String time, String orderSource) {
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
                  Text(orderNumber, style: TextStyle(color: sourceColor, fontWeight: FontWeight.bold, fontSize: 16)),
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
          Text(items, style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: _bgColor, side: const BorderSide(color: _neonCyan)),
              child: const Text('Mark Fulfilled', style: TextStyle(color: _neonCyan)),
            ),
          )
        ],
      ),
    );
  }
}
