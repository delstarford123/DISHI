import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class BookingManagerView extends StatelessWidget {
  const BookingManagerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Booking Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Upcoming Table Bookings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildBookingCard('B-102', 'Group Study Meeting', 'Table 4', 'Today, 2:00 PM', '4 Guests'),
          _buildBookingCard('B-103', 'Birthday Dinner', 'Table 9', 'Tomorrow, 7:00 PM', '8 Guests'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonOrange,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBookingCard(String id, String title, String table, String time, String guests) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#$id', style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.table_restaurant, color: _textSecondary, size: 16),
              const SizedBox(width: 8),
              Text(table, style: const TextStyle(color: _textSecondary, fontSize: 14)),
              const Spacer(),
              const Icon(Icons.group, color: _textSecondary, size: 16),
              const SizedBox(width: 8),
              Text(guests, style: const TextStyle(color: _textSecondary, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
