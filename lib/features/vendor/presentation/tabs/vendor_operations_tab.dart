import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorOperationsTabView extends StatefulWidget {
  final Map<String, dynamic> user;

  const VendorOperationsTabView({super.key, required this.user});

  @override
  State<VendorOperationsTabView> createState() => _VendorOperationsTabViewState();
}

class _VendorOperationsTabViewState extends State<VendorOperationsTabView> {
  // Waste Management Controllers
  final _wasteItemController = TextEditingController();
  final _wasteQtyController = TextEditingController();
  bool _isWasteLoading = false;

  // Costing State
  bool _isCostingLoading = false;
  Map<String, dynamic>? _costingResult;

  // Predictive Prep Future
  late Future<List<dynamic>> _predictivePrepFuture;

  @override
  void initState() {
    super.initState();
    _predictivePrepFuture = _fetchPredictions();
  }

  Future<List<dynamic>> _fetchPredictions() async {
    try {
      final response = await http.get(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_operations/predictive_prep?vendorUid=${widget.user['uid']}'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['predictions'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<void> _handleDynamicCosting() async {
    setState(() => _isCostingLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_operations/inventory/costing'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sellingPrice': 180.0,
          'ingredients': [
            {'name': 'Rice (200g)', 'cost': 30},
            {'name': 'Beef (100g)', 'cost': 60},
            {'name': 'Cooking Oil / Gas', 'cost': 15}
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _costingResult = jsonDecode(response.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to calculate costing')));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error calculating costing')));
    } finally {
      setState(() => _isCostingLoading = false);
    }
  }

  Future<void> _handleWasteLog() async {
    final item = _wasteItemController.text.trim();
    final qty = double.tryParse(_wasteQtyController.text.trim()) ?? 0.0;

    if (item.isEmpty || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid Item and Quantity')));
      return;
    }

    setState(() => _isWasteLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_operations/waste/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorUid': widget.user['uid'],
          'itemName': item,
          'quantity': qty,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Waste logged successfully'), backgroundColor: _neonCyan));
        _wasteItemController.clear();
        _wasteQtyController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Waste log failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isWasteLoading = false);
    }
  }

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
        FutureBuilder<List<dynamic>>(
          future: _predictivePrepFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _neonCyan));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('No predictions available right now.', style: TextStyle(color: _textSecondary));
            }
            
            return Column(
              children: snapshot.data!.map((pred) {
                return _buildPredictionCard(pred['item'], pred['suggested_prep'], pred['reason']);
              }).toList(),
            );
          },
        ),
        
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
                  TextButton(
                    onPressed: _isCostingLoading ? null : _handleDynamicCosting, 
                    child: _isCostingLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _neonOrange, strokeWidth: 2))
                      : const Text('Calculate', style: TextStyle(color: _neonOrange))
                  ),
                ],
              ),
              const Divider(color: _textSecondary),
              _buildCostRow('Rice (200g)', 'KSH 30'),
              _buildCostRow('Beef (100g)', 'KSH 60'),
              _buildCostRow('Cooking Oil / Gas', 'KSH 15'),
              const Divider(color: _textSecondary),
              
              if (_costingResult != null) ...[
                _buildCostRow('Total Cost', 'KSH ${_costingResult!['totalCost']}', isBold: true),
                _buildCostRow('Selling Price', 'KSH 180.0', isBold: true, color: _neonCyan),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _neonCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Profit Margin', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                      Text('${_costingResult!['marginPercentage']}%', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                )
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text('Tap Calculate to see margins.', style: TextStyle(color: _textSecondary))),
                )
              ]
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
                controller: _wasteItemController,
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
                controller: _wasteQtyController,
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
                  onPressed: _isWasteLoading ? null : _handleWasteLog,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white)),
                  child: _isWasteLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Log Unsold Food', style: TextStyle(color: Colors.white)),
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
        Expanded(
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(reason, style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
