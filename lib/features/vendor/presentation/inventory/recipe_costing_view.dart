import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class RecipeCostingView extends StatelessWidget {
  const RecipeCostingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Recipe Costing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRecipeCard('Beef Pilau', 120, 250),
          _buildRecipeCard('Chapati Beans', 40, 100),
          _buildRecipeCard('Chips Masala', 80, 150),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _neonOrange,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRecipeCard(String recipeName, double cost, double sellingPrice) {
    double profit = sellingPrice - cost;
    double margin = (profit / sellingPrice) * 100;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipeName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Divider(color: _surfaceLight),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ingredient Cost:', style: TextStyle(color: _textSecondary)),
              Text('KES ${cost.toStringAsFixed(0)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Selling Price:', style: TextStyle(color: _textSecondary)),
              Text('KES ${sellingPrice.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: _surfaceLight),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gross Profit:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('KES ${profit.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Margin:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('${margin.toStringAsFixed(1)}%', style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
