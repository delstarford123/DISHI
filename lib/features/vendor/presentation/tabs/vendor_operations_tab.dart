import 'package:flutter/material.dart';
import '../../../../core/services/api_config.dart';
import '../../../../core/services/secure_http_client.dart';
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

  // Supplier Bidding Controllers
  final _bidItemController = TextEditingController();
  final _bidQtyController = TextEditingController();
  final _bidPriceController = TextEditingController();
  bool _isBidLoading = false;

  // Predictive Prep Future
  late Future<List<dynamic>> _predictivePrepFuture;
  
  // Dynamic Pricing State
  bool _isDynamicPricingLoading = false;

  // Delivery Optimization State
  bool _isOptimizingRoute = false;
  Map<String, dynamic>? _optimizedRoute;
  final _deliveryDriverIdController = TextEditingController();
  final _deliveryOrderIdsController = TextEditingController();

  @override
  void dispose() {
    _wasteItemController.dispose();
    _wasteQtyController.dispose();
    _bidItemController.dispose();
    _bidQtyController.dispose();
    _bidPriceController.dispose();
    _deliveryDriverIdController.dispose();
    _deliveryOrderIdsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _predictivePrepFuture = _fetchPredictions();
  }

  Future<List<dynamic>> _fetchPredictions() async {
    try {
      final response = await SecureHttpClient.get(
        '${ApiConfig.baseUrl}/api/v1/vendor_operations/predictive_prep?vendorUid=${widget.user['uid']}',
      );
      
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
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_operations/inventory/costing',
        body: {
          'sellingPrice': 180.0,
          'ingredients': [
            {'name': 'Rice (200g)', 'cost': 30},
            {'name': 'Beef (100g)', 'cost': 60},
            {'name': 'Cooking Oil / Gas', 'cost': 15}
          ]
        },
      );

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
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_operations/waste/log',
        body: {
          'vendorUid': widget.user['uid'],
          'itemName': item,
          'quantity': qty,
        },
      );

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

  Future<void> _handleSupplierBidRequest() async {
    final item = _bidItemController.text.trim();
    final qty = _bidQtyController.text.trim();
    final maxPrice = double.tryParse(_bidPriceController.text.trim()) ?? 0.0;

    if (item.isEmpty || qty.isEmpty || maxPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields for the bid request')));
      return;
    }

    setState(() => _isBidLoading = true);
    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_operations/supplier_bidding/post_request',
        body: {
          'vendorUid': widget.user['uid'],
          'itemName': item,
          'quantity': qty,
          'maxPrice': maxPrice,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Bidding Opened!'), backgroundColor: _neonCyan));
        _bidItemController.clear();
        _bidQtyController.clear();
        _bidPriceController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Failed to open bidding'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isBidLoading = false);
    }
  }

  Future<void> _handleDynamicPricing() async {
    setState(() => _isDynamicPricingLoading = true);
    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_operations/inventory/dynamic_pricing',
        body: {
          'vendorUid': widget.user['uid'],
          'discountPercentage': 20.0,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Dynamic Pricing Applied!'), backgroundColor: _neonCyan));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Failed to apply dynamic pricing'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isDynamicPricingLoading = false);
    }
  }

  Future<void> _handleOptimizeRoute() async {
    final driverId = _deliveryDriverIdController.text.trim();
    final ordersText = _deliveryOrderIdsController.text.trim();

    if (driverId.isEmpty || ordersText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Driver ID and Order IDs')));
      return;
    }

    final orderIds = ordersText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    setState(() => _isOptimizingRoute = true);
    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_operations/delivery/optimize',
        body: {
          'vendorUid': widget.user['uid'],
          'driverId': driverId,
          'orderIds': orderIds,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _optimizedRoute = data['data'];
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Route Optimized!'), backgroundColor: _neonCyan));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Failed to optimize route'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isOptimizingRoute = false);
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

        const SizedBox(height: 32),

        // Automated Supplier Bidding
        _buildSectionHeader('Automated Supplier Bidding', Icons.gavel, Colors.deepOrangeAccent),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.deepOrangeAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Post an ingredient request and let suppliers bid for your business.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _bidItemController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ingredient (e.g. Flour)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bidQtyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Qty (e.g. 50kg)',
                        labelStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _bgColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _bidPriceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Max Price (KSH)',
                        labelStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _bgColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isBidLoading ? null : _handleSupplierBidRequest,
                  icon: _isBidLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.campaign, color: Colors.white),
                  label: Text(_isBidLoading ? 'Posting...' : 'Open Bidding', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrangeAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Dynamic Pricing
        _buildSectionHeader('Smart Dynamic Pricing', Icons.price_change, Colors.purpleAccent),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Automatically apply a 20% discount to all menu items with high stock nearing closing time to clear inventory and reduce waste.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDynamicPricingLoading ? null : _handleDynamicPricing,
                  icon: _isDynamicPricingLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.flash_on, color: Colors.white),
                  label: Text(_isDynamicPricingLoading ? 'Applying...' : 'Trigger Flash Sale (20% Off)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Smart Route Planning
        _buildSectionHeader('Smart Route Planning', Icons.alt_route, Colors.lightBlueAccent),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Optimize delivery sequence for multiple orders to save time and fuel.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _deliveryDriverIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Driver ID',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deliveryOrderIdsController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Order IDs (Comma-separated)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isOptimizingRoute ? null : _handleOptimizeRoute,
                  icon: _isOptimizingRoute ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.route, color: Colors.white),
                  label: Text(_isOptimizingRoute ? 'Optimizing...' : 'Optimize Route', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              if (_optimizedRoute != null) ...[
                const SizedBox(height: 16),
                const Divider(color: _textSecondary),
                const SizedBox(height: 8),
                const Text('Optimized Sequence:', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List.generate(_optimizedRoute!['optimizedSequence'].length, (i) {
                  return Text('${i + 1}. Order ${_optimizedRoute!['optimizedSequence'][i]}', style: const TextStyle(color: Colors.white));
                }),
                const SizedBox(height: 8),
                Text('Estimated Time: ${_optimizedRoute!['estimatedTimeMinutes']} mins', style: const TextStyle(color: _neonCyan)),
                Text('Total Distance: ${_optimizedRoute!['totalDistanceKm']} km', style: const TextStyle(color: _neonCyan)),
              ]
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
