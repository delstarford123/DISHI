import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Costing State - Beef Stew & Rice & Custom Meals
  String _selectedMealName = 'Beef Stew & Rice';
  double _mealSellingPrice = 180.0;
  List<Map<String, dynamic>> _mealIngredients = [
    {'name': 'Rice (Grade 1, 200g)', 'cost': 30.0},
    {'name': 'Beef Cubes (150g)', 'cost': 60.0},
    {'name': 'Cooking Oil / Gas Energy', 'cost': 15.0},
    {'name': 'Tomatoes, Onions & Seasoning', 'cost': 10.0},
  ];
  bool _isCostingLoading = false;
  bool _isSyncingToMenu = false;
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
    _recalculateLocalCosting();
  }

  void _recalculateLocalCosting() {
    final totalCost = _mealIngredients.fold<double>(0.0, (acc, i) => acc + (i['cost'] as num).toDouble());
    final profit = _mealSellingPrice - totalCost;
    final margin = _mealSellingPrice > 0 ? (profit / _mealSellingPrice) * 100 : 0.0;
    _costingResult = {
      'totalCost': totalCost,
      'profit': profit,
      'marginPercentage': margin.toStringAsFixed(1),
      'sellingPrice': _mealSellingPrice,
    };
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
    final totalCost = _mealIngredients.fold<double>(0.0, (acc, i) => acc + (i['cost'] as num).toDouble());
    final profit = _mealSellingPrice - totalCost;
    final margin = _mealSellingPrice > 0 ? (profit / _mealSellingPrice) * 100 : 0.0;

    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_operations/inventory/costing',
        body: {
          'sellingPrice': _mealSellingPrice,
          'ingredients': _mealIngredients.map((i) => {'name': i['name'], 'cost': i['cost']}).toList(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _costingResult = {
              'totalCost': (data['totalCost'] ?? totalCost).toDouble(),
              'profit': (data['profit'] ?? profit).toDouble(),
              'marginPercentage': (data['marginPercentage'] ?? margin.toStringAsFixed(1)).toString(),
              'sellingPrice': _mealSellingPrice,
            };
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _costingResult = {
              'totalCost': totalCost,
              'profit': profit,
              'marginPercentage': margin.toStringAsFixed(1),
              'sellingPrice': _mealSellingPrice,
            };
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _costingResult = {
            'totalCost': totalCost,
            'profit': profit,
            'marginPercentage': margin.toStringAsFixed(1),
            'sellingPrice': _mealSellingPrice,
          };
        });
      }
    } finally {
      if (mounted) setState(() => _isCostingLoading = false);
    }
  }

  Future<void> _handleSyncToMenu() async {
    setState(() => _isSyncingToMenu = true);
    try {
      final vendorId = widget.user['uid'] ?? '';
      final totalCost = _mealIngredients.fold<double>(0.0, (acc, i) => acc + (i['cost'] as num).toDouble());
      final profit = _mealSellingPrice - totalCost;
      final margin = _mealSellingPrice > 0 ? (profit / _mealSellingPrice) * 100 : 0.0;

      final snapshot = await FirebaseFirestore.instance
          .collection('vendor_menus')
          .where('vendorId', isEqualTo: vendorId)
          .where('name', isEqualTo: _selectedMealName)
          .limit(1)
          .get();

      final data = {
        'vendorId': vendorId,
        'name': _selectedMealName,
        'price': _mealSellingPrice,
        'description': 'Hearty tender beef slow-braised in savoury tomato gravy served over fragrant steamed white rice.',
        'imageUrl': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
        'costPerPlate': totalCost,
        'profitMargin': double.parse(margin.toStringAsFixed(1)),
        'isAvailable': true,
        'category': 'Hot Meals',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('vendor_menus').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_selectedMealName synced to Student & Parent Dashboards at KSH ${_mealSellingPrice.toStringAsFixed(0)}!'),
            backgroundColor: _neonCyan,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync to menu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingToMenu = false);
    }
  }

  void _showAddIngredientDialog() {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonOrange)),
        title: const Text('Add Ingredient / Side', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Ingredient (e.g. Potatoes, Packaging)', labelStyle: TextStyle(color: _textSecondary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Cost per Plate (KSH)', labelStyle: TextStyle(color: _textSecondary)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, foregroundColor: Colors.black),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
              if (name.isNotEmpty && cost > 0) {
                setState(() {
                  _mealIngredients.add({'name': name, 'cost': cost});
                  _recalculateLocalCosting();
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

        // Dynamic Recipe Costing - Beef Stew & Rice
        _buildSectionHeader('Dynamic Recipe Costing: $_selectedMealName', Icons.calculate, _neonOrange),
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
              // Meal Header & Calculate trigger
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant_menu, color: _neonCyan, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedMealName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Add Ingredient',
                        icon: const Icon(Icons.add_circle, color: _neonOrange, size: 22),
                        onPressed: _showAddIngredientDialog,
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: _neonOrange.withOpacity(0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isCostingLoading ? null : _handleDynamicCosting, 
                        icon: _isCostingLoading 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: _neonOrange, strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 16, color: _neonOrange),
                        label: const Text('Calculate', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: _textSecondary, height: 20),
              
              // Ingredients List
              const Text('Recipe Ingredients & Cost Breakdown:', style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._mealIngredients.map((ing) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ing['name'],
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'KSH ${(ing['cost'] as num).toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              if (_mealIngredients.length > 1) {
                                setState(() {
                                  _mealIngredients.remove(ing);
                                  _recalculateLocalCosting();
                                });
                              }
                            },
                            child: const Icon(Icons.close, color: Colors.white30, size: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const Divider(color: _textSecondary, height: 20),

              // Selling Price Adjustment Stepper
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selling Price per Plate:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline, color: _neonCyan, size: 22),
                        onPressed: () {
                          if (_mealSellingPrice > 50) {
                            setState(() {
                              _mealSellingPrice -= 10;
                              _recalculateLocalCosting();
                            });
                          }
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _neonCyan.withOpacity(0.5)),
                        ),
                        child: Text('KSH ${_mealSellingPrice.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline, color: _neonCyan, size: 22),
                        onPressed: () {
                          setState(() {
                            _mealSellingPrice += 10;
                            _recalculateLocalCosting();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Profitability & Margin Results
              if (_costingResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _buildCostRow('Total Cost per Plate', 'KSH ${_costingResult!['totalCost']}'),
                      _buildCostRow('Selling Price', 'KSH ${_mealSellingPrice.toStringAsFixed(0)}', color: _neonCyan),
                      _buildCostRow('Net Profit per Plate', 'KSH ${_costingResult!['profit']}', isBold: true, color: Colors.greenAccent),
                      const Divider(color: Colors.white12, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gross Profit Margin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (double.tryParse(_costingResult!['marginPercentage'].toString()) ?? 0) >= 30 
                                  ? Colors.green.withOpacity(0.2) 
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_costingResult!['marginPercentage']}%',
                              style: TextStyle(
                                color: (double.tryParse(_costingResult!['marginPercentage'].toString()) ?? 0) >= 30 
                                    ? Colors.greenAccent 
                                    : Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Sync to Menu & Student Dashboard Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSyncingToMenu ? null : _handleSyncToMenu,
                    icon: _isSyncingToMenu 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.sync_alt, size: 20),
                    label: Text(
                      _isSyncingToMenu ? 'Syncing to Student Hub...' : 'Sync $_selectedMealName to Menu & Student App',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
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
        border: Border.all(color: _neonCyan.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 4,
            height: 36,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _neonCyan,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
          Expanded(child: Text(label, style: TextStyle(color: isBold ? color : _textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
