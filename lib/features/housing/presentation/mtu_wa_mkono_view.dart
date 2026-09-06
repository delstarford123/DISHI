import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF00E5FF);
const Color _textSecondary = Color(0xFF8B9BB4);

class MtuWaMkonoView extends StatelessWidget {
  const MtuWaMkonoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Mtu wa Mkono (Movers)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _neonBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonBlue)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need help moving?', style: TextStyle(color: _neonBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Hire verified students with handcarts (mkokoteni) or pickups to help you move in/out securely.', style: TextStyle(color: Colors.white, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMoverCard('James O.', 'Pickup Truck', 'KES 1,500 / trip'),
          _buildMoverCard('Kevin M.', 'Mkokoteni', 'KES 300 / trip'),
        ],
      ),
    );
  }

  Widget _buildMoverCard(String name, String type, String rate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: _surfaceLight, child: Icon(Icons.fire_truck, color: _textSecondary)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(type, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _neonBlue, borderRadius: BorderRadius.circular(20)),
                child: const Text('REQUEST', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          )
        ],
      ),
    );
  }
}
