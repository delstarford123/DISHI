import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class LiveReceiptsFeed extends StatelessWidget {
  const LiveReceiptsFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Live POS Receipts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReceiptCard('Highland Cafe', '12:45 PM Today', 'KES 250', ['1x Burger', '1x Coke']),
          _buildReceiptCard('Student Mess', '08:30 AM Today', 'KES 60', ['2x Mandazi', '1x Tea']),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(String vendor, String time, String total, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(vendor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(total, style: const TextStyle(color: _neonPink, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          const Divider(color: _surfaceLight),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(item, style: const TextStyle(color: Colors.white)),
          )),
        ],
      ),
    );
  }
}
