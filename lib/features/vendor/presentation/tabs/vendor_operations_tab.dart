import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorOperationsTabView extends StatelessWidget {
  final Map<String, dynamic> user;

  const VendorOperationsTabView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // AI Predictive Prep
        _buildSectionHeader('AI Predictive Prep', Icons.auto_awesome, _neonCyan),
        const SizedBox(height: 8),
        const Text(
          'Based on past Tuesday sales and local weather forecasts, here is what you should prepare today.',
          style: TextStyle(color: _textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildPredictionCard('Chapati', 60, 'High demand on Tuesdays'),
        _buildPredictionCard('Beef Stew', 35, 'Cold weather expected'),
        
        const SizedBox(height: 32),

        // Dynamic Recipe Costing
        _buildSectionHeader('Dynamic Costing & Profit Margin', Icons.calculate, _neonOrange),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Current Meal: Beef Stew & Rice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () {}, child: const Text('Change Recipe', style: TextStyle(color: _neonOrange))),
                ],
              ),
              const Divider(color: _textSecondary),
              _buildCostRow('Rice (200g)', 'KSH 30'),
              _buildCostRow('Beef (100g)', 'KSH 60'),
              _buildCostRow('Cooking Oil / Gas', 'KSH 15'),
              const Divider(color: _textSecondary),
              _buildCostRow('Total Cost', 'KSH 105', isBold: true),
              _buildCostRow('Selling Price', 'KSH 180', isBold: true, color: _neonCyan),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _neonCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Profit Margin', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                    Text('41.6%', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Waste Management
        _buildSectionHeader('Waste Management Log', Icons.delete_outline, Colors.white),
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
                  labelText: 'Item Name (e.g., Rice)',
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
                  labelText: 'Quantity (kg/portions)',
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
                  child: const Text('Log Unsold Food', style: TextStyle(color: Colors.white)),
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

  Widget _buildPredictionCard(String item, int qty, String reason) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _neonCyan, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(reason, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: _neonCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('Prep $qty', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value, {bool isBold = false, Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? color : _textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
