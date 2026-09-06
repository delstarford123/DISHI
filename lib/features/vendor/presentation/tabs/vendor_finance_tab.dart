import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorFinanceTabView extends StatelessWidget {
  final Map<String, dynamic> user;

  const VendorFinanceTabView({super.key, required this.user});

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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Student QR ID or Phone',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: const Icon(Icons.qr_code_scanner, color: _neonCyan),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
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
                  onPressed: () {},
                  icon: const Icon(Icons.sync_alt, color: Colors.black),
                  label: const Text('Complete Deposit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Vendor ID',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
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
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonOrange)),
                  child: const Text('Send E-Float', style: TextStyle(color: _neonOrange)),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Supplier ID or Name',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
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
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white)),
                  child: const Text('Pay Supplier', style: TextStyle(color: Colors.white)),
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
