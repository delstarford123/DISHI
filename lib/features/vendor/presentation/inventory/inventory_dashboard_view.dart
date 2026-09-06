import 'package:flutter/material.dart';
import 'recipe_costing_view.dart';
import 'supplier_orders_view.dart';
import 'waste_log_view.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class InventoryDashboardView extends StatelessWidget {
  const InventoryDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Inventory Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Stock & Resources', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            _buildActionCard(
              context, 
              title: 'Recipe Costing', 
              subtitle: 'Calculate margins & profits', 
              icon: Icons.receipt_long, 
              destination: const RecipeCostingView()
            ),
            _buildActionCard(
              context, 
              title: 'Supplier Orders', 
              subtitle: 'Track incoming produce', 
              icon: Icons.local_shipping, 
              destination: const SupplierOrdersView()
            ),
            _buildActionCard(
              context, 
              title: 'Detailed Waste Logs', 
              subtitle: 'Track shrinkage and expired items', 
              icon: Icons.delete_sweep, 
              destination: const WasteLogView()
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Widget destination}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _surfaceLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _neonOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _neonOrange, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
