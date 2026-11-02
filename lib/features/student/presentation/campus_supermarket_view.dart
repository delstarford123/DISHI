import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/services/api_config.dart';
import '../../../core/models/user_model.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class CampusSupermarketView extends StatefulWidget {
  final UserModel? userModel;

  const CampusSupermarketView({super.key, this.userModel});

  @override
  State<CampusSupermarketView> createState() => _CampusSupermarketViewState();
}

class _CampusSupermarketViewState extends State<CampusSupermarketView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();

  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSpeaking = false;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'name': 'All', 'icon': '🌟'},
    {'id': 'supermarket', 'name': 'Supermarket', 'icon': '🛒'},
    {'id': 'food', 'name': 'Cafeteria', 'icon': '🍕'},
    {'id': 'electronics', 'name': 'Tech & Lab', 'icon': '💻'},
    {'id': 'stationery', 'name': 'Stationery', 'icon': '📚'},
    {'id': 'pharmacy', 'name': 'Pharmacy', 'icon': '💊'},
  ];

  final Map<String, int> _cart = {}; // itemId -> quantity
  final Map<String, Map<String, dynamic>> _cartItems = {}; // itemId -> itemData

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    _flutterTts.setLanguage("en-KE");
    _flutterTts.setSpeechRate(0.45);
    _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speakAccessibilityGuide() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    final text = "Welcome to DISHI Campus Supermarket and Technology Hub. "
        "Here you can order fresh groceries, hot meals, calculators, lab coats, and electronics with 14-day warranty. "
        "You can also buy on installments, scan product barcodes, or ask your parent to sponsor your cart.";
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _showBarcodeScannerModal() {
    final barcodeController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _neonCyan.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.qr_code_scanner, color: _neonCyan, size: 24),
                ),
                const SizedBox(width: 12),
                const Text('Supermarket SKU & Barcode Lookup', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter the product barcode (EAN-13/UPC) or SKU code found on the supermarket packaging to fetch instant pricing and stock.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: barcodeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'e.g. 6161101234567',
                hintStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.barcode_reader, color: _neonCyan),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final code = barcodeController.text.trim();
                if (code.isEmpty) return;
                Navigator.pop(ctx);
                _performBarcodeQuery(code);
              },
              child: const Text('Lookup Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performBarcodeQuery(String barcode) async {
    try {
      final url = Uri.parse('${ApiConfig.v6BarcodeLookup}/$barcode');
      final resp = await http.get(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final item = data['item'] as Map<String, dynamic>;
        _showProductDetailModal(item);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product barcode $barcode not found in campus database.'), backgroundColor: _neonPink),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lookup error: $e'), backgroundColor: _neonPink),
      );
    } finally {}
  }

  void _showProductDetailModal(Map<String, dynamic> item) {
    String selectedVariant = '';
    double currentPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
    final variants = item['variants'] as List<dynamic>? ?? [];

    if (variants.isNotEmpty) {
      selectedVariant = variants.first['name'] ?? '';
      currentPrice = (variants.first['price'] as num?)?.toDouble() ?? currentPrice;
    }

    final isTech = (item['category'] == 'electronics' || item['vendorType'] == 'electronics');
    final stock = (item['stock'] as num?)?.toInt() ?? 10;
    final isAvailable = (item['isAvailable'] as bool? ?? true) && stock > 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(14)),
                    child: Center(
                      child: Text(
                        isTech ? '💻' : (item['category'] == 'food' ? '🍕' : '🛒'),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? item['title'] ?? 'Campus Item',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['vendorName'] ?? item['businessName'] ?? 'Campus Mini-Supermarket',
                          style: const TextStyle(color: _textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isAvailable ? Colors.green.withAlpha(30) : _neonPink.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAvailable ? 'In Stock ($stock left)' : 'Out of Stock',
                            style: TextStyle(
                              color: isAvailable ? Colors.greenAccent : _neonPink,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 14-Day Warranty Shield Badge for Electronics
              if (isTech)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _neonCyan.withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: _neonCyan, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '14-Day DISHI Guarantee: Payout held in escrow until inspected.',
                          style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Variants Selector
              if (variants.isNotEmpty) ...[
                const Text('Choose Specification / Size:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: variants.map((v) {
                    final vName = v['name'] as String? ?? '';
                    final isSel = (vName == selectedVariant);
                    return ChoiceChip(
                      label: Text(vName, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 12)),
                      selected: isSel,
                      selectedColor: _neonCyan,
                      backgroundColor: _surfaceLight,
                      onSelected: (val) {
                        if (val) {
                          setModalState(() {
                            selectedVariant = vName;
                            currentPrice = (v['price'] as num?)?.toDouble() ?? currentPrice;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Price Display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Price:', style: TextStyle(color: _textSecondary, fontSize: 14)),
                  Text(
                    'KES ${currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(color: _neonCyan, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  // Add to Cart
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAvailable ? _neonCyan : Colors.grey,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isAvailable
                          ? () {
                              final itemId = item['id'] ?? item['barcode'] ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
                              setState(() {
                                _cart[itemId] = (_cart[itemId] ?? 0) + 1;
                                _cartItems[itemId] = item;
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added ${item['name'] ?? 'Item'} to cart!'), duration: const Duration(seconds: 2)),
                              );
                            }
                          : null,
                      child: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  if (isTech && currentPrice >= 2000) ...[
                    const SizedBox(width: 10),
                    // Installment Layaway Button
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _neonOrange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _createInstallmentPlan(item, currentPrice);
                        },
                        child: const Text('Layaway 3x', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createInstallmentPlan(Map<String, dynamic> item, double price) async {
    final studentUid = FirebaseAuth.instance.currentUser?.uid;
    if (studentUid == null) return;

    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6InstallmentsCreate),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_uid': studentUid,
          'vendor_id': item['vendorId'] ?? item['vendor_id'] ?? 'campus_tech_hub',
          'item_id': item['id'] ?? item['barcode'],
          'item_name': item['name'] ?? item['title'] ?? 'Tech Equipment',
          'total_price': price,
          'milestones': 3,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: _neonCyan, duration: const Duration(seconds: 4)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not create plan'), backgroundColor: _neonPink),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e'), backgroundColor: _neonPink),
      );
    }
  }

  double get _cartTotal {
    double total = 0;
    _cart.forEach((id, qty) {
      final item = _cartItems[id];
      if (item != null) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        total += price * qty;
      }
    });
    return total;
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setCartState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('DISHI Supermarket Cart', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${_cart.length} items', style: const TextStyle(color: _textSecondary, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              if (_cart.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Your cart is empty', style: TextStyle(color: _textSecondary))),
                )
              else ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView(
                    shrinkWrap: true,
                    children: _cart.entries.map((entry) {
                      final item = _cartItems[entry.key];
                      final name = item?['name'] ?? 'Item';
                      final price = (item?['price'] as num?)?.toDouble() ?? 0.0;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text('KES ${price.toStringAsFixed(2)} each', style: const TextStyle(color: _textSecondary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: _neonPink, size: 20),
                              onPressed: () {
                                setCartState(() {
                                  if (entry.value > 1) {
                                    _cart[entry.key] = entry.value - 1;
                                  } else {
                                    _cart.remove(entry.key);
                                    _cartItems.remove(entry.key);
                                  }
                                });
                                setState(() {});
                              },
                            ),
                            Text('${entry.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: _neonCyan, size: 20),
                              onPressed: () {
                                setCartState(() => _cart[entry.key] = entry.value + 1);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(color: Colors.white24, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(color: Colors.white70, fontSize: 15)),
                    Text('KES ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                // Ask Parent to Pay Button (Feature 10)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _neonCyan),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.volunteer_activism, color: _neonCyan, size: 18),
                  label: const Text('Ask Parent to Sponsor Cart', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _generateParentCartLink();
                  },
                ),
                const SizedBox(height: 10),
                // Chama Cart Pool with Roommates (Feature 7)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _neonOrange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.group_work_outlined, color: _neonOrange, size: 18),
                  label: const Text('Chama Cart: Split with Roommates', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _createChamaPoolCart();
                  },
                ),
                const SizedBox(height: 10),
                // Direct Checkout with Student Wallet
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showFulfillmentSelectionModal();
                  },
                  child: const Text('Pay with DISHI Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateParentCartLink() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _cart.isEmpty) return;

    try {
      final itemsList = _cart.entries.map((e) => {
        'id': e.key,
        'quantity': e.value,
        'name': _cartItems[e.key]?['name'] ?? 'Item',
        'price': _cartItems[e.key]?['price'] ?? 0.0,
      }).toList();

      final resp = await http.post(
        Uri.parse(ApiConfig.v6CartPaylink),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_uid': uid,
          'items': itemsList,
          'total_amount': _cartTotal,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 201) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardColor,
            title: const Row(children: [Icon(Icons.check_circle, color: _neonCyan), SizedBox(width: 8), Text('Parent Link Sent!', style: TextStyle(color: Colors.white))]),
            content: Text(
              'Your parent received an SMS & push notification to sponsor your KES ${_cartTotal.toStringAsFixed(0)} cart.\n\nLink: ${data['pay_link']}',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done', style: TextStyle(color: _neonCyan))),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
    }
  }

  Future<void> _createChamaPoolCart() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _cart.isEmpty) return;

    try {
      final itemsList = _cart.entries.map((e) => {
        'id': e.key,
        'quantity': e.value,
        'name': _cartItems[e.key]?['name'] ?? 'Item',
        'price': _cartItems[e.key]?['price'] ?? 0.0,
      }).toList();

      final resp = await http.post(
        Uri.parse(ApiConfig.v6PoolCreate),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'creator_uid': uid,
          'title': 'Dorm Wholesale Bulk Cart',
          'target_amount': _cartTotal,
          'items': itemsList,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 201) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardColor,
            title: const Row(children: [Icon(Icons.group_work, color: _neonOrange), SizedBox(width: 8), Text('Chama Cart Created!', style: TextStyle(color: Colors.white))]),
            content: Text(
              'Share this deep-link with your roommates so each one can contribute:\n\n${data['deep_link']}',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: _neonOrange))),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
    }
  }

  void _showFulfillmentSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.delivery_dining, color: _neonCyan, size: 28),
                SizedBox(width: 10),
                Text('Choose Delivery Method', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('How would you like to receive your food & goods?', style: TextStyle(color: _textSecondary, fontSize: 13)),
            const SizedBox(height: 20),

            // Option 1: Self Counter Pickup
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              tileColor: _surfaceLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _neonCyan.withAlpha(50))),
              leading: const CircleAvatar(backgroundColor: Color(0xFF0C101B), child: Icon(Icons.storefront, color: _neonCyan)),
              title: const Text('Store Counter Pickup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Collect directly at counter with dynamic QR pass', style: TextStyle(color: _textSecondary, fontSize: 12)),
              trailing: const Text('FREE', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(bCtx);
                _checkoutWithStudentWallet();
              },
            ),
            const SizedBox(height: 12),

            // Option 2: Request DeLiv Courier
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              tileColor: _surfaceLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _neonOrange.withAlpha(80))),
              leading: const CircleAvatar(backgroundColor: Color(0xFF0C101B), child: Icon(Icons.two_wheeler, color: _neonOrange)),
              title: const Text('DeLiv Courier to Dorm / Seat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Campus rider picks up & brings to your hostel room', style: TextStyle(color: _textSecondary, fontSize: 12)),
              trailing: const Text('+ KES 50', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(bCtx);
                _showCourierDropoffModal();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCourierDropoffModal() {
    final locationController = TextEditingController(text: 'Hall 4, Room B12');
    final List<String> campusLandmarks = [
      'Hall 1', 'Hall 2', 'Hall 3', 'Hall 4', 'Hall 5',
      'Science Complex', 'Main Library', 'Engineering Labs', 'Postgrad Hostel'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: _neonOrange, size: 26),
                  SizedBox(width: 10),
                  Text('DeLiv Drop-off Location', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Where should the courier bring your items?', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 14),

              // Quick Campus Landmark Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: campusLandmarks.map((lm) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: _surfaceLight,
                      label: Text(lm, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: () {
                        setModalState(() {
                          locationController.text = '$lm, Room ';
                        });
                      },
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: locationController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Dorm / Hostel / Building & Room',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  prefixIcon: const Icon(Icons.home, color: _neonCyan),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Fee Breakdown
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items Subtotal:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                        Text('KES ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DeLiv Courier Fee (Escrow):', style: TextStyle(color: _textSecondary, fontSize: 13)),
                        Text('KES 50.00', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total from Wallet:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('KES ${(_cartTotal + 50.0).toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.two_wheeler),
                  label: const Text('Confirm & Dispatch Courier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: () {
                    final dropoff = locationController.text.trim();
                    if (dropoff.isEmpty) return;
                    Navigator.pop(dCtx);
                    _checkoutWithStudentWallet(dropoffLocation: dropoff);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkoutWithStudentWallet({String? dropoffLocation}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final isCourier = dropoffLocation != null && dropoffLocation.isNotEmpty;
    final deliveryFee = isCourier ? 50.0 : 0.0;
    final totalPayable = _cartTotal + deliveryFee;

    final balance = widget.userModel?.walletBalance ?? 0.0;
    if (balance < totalPayable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient balance. Need KES ${totalPayable.toStringAsFixed(2)}, Available: KES ${balance.toStringAsFixed(2)}'), backgroundColor: _neonPink),
      );
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final orderRef = db.collection('orders').doc();
      final itemsList = _cart.entries.map((e) => {
        'id': e.key,
        'quantity': e.value,
        'name': _cartItems[e.key]?['name'] ?? 'Item',
        'price': _cartItems[e.key]?['price'] ?? 0.0,
      }).toList();

      final rand = Random();
      final vendorPickupPin = (1000 + rand.nextInt(9000)).toString();
      final studentDeliveryPin = (1000 + rand.nextInt(9000)).toString();
      final gigId = 'DELIV_${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

      await db.runTransaction((tx) async {
        final uRef = db.collection('users').doc(uid);
        final uSnap = await tx.get(uRef);
        final curBal = (uSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        if (curBal < totalPayable) throw Exception('Insufficient balance');

        tx.update(uRef, {
          'walletBalance': curBal - totalPayable,
          'wallet_balance': curBal - totalPayable,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final orderData = {
          'studentUid': uid,
          'student_id': uid,
          'items': itemsList,
          'totalAmount': totalPayable,
          'subtotal': _cartTotal,
          'deliveryFee': deliveryFee,
          'fulfillmentType': isCourier ? 'deliv_courier' : 'counter_pickup',
          'dropoffLocation': isCourier ? dropoffLocation : null,
          'vendorPickupPin': vendorPickupPin,
          'studentDeliveryPin': studentDeliveryPin,
          'deliv_request_id': isCourier ? gigId : null,
          'status': 'Queued',
          'prep_status': 'Queued',
          'deliveryStatus': isCourier ? 'courier_requested' : 'counter_ready',
          'type': 'supermarket_checkout',
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        };

        tx.set(orderRef, orderData);

        if (isCourier) {
          final gigRef = db.collection('deliv_requests').doc(gigId);
          tx.set(gigRef, {
            'id': gigId,
            'orderId': orderRef.id,
            'order_id': orderRef.id,
            'type': 'Parcel Pickup',
            'status': 'open',
            'stage': 'en_route_pickup',
            'pay': 'KES 50',
            'deliveryFee': 50.0,
            'pickup': 'Campus Supermarket & Tech Store',
            'vendorName': 'Campus Supermarket & Tech Store',
            'dropoff': dropoffLocation,
            'dropoffLocation': dropoffLocation,
            'studentUid': uid,
            'postedBy': uid,
            'studentName': widget.userModel?.displayName ?? 'Student',
            'studentPhone': widget.userModel?.phoneNumber ?? '',
            'itemsSummary': itemsList.map((i) => "${i['quantity']}x ${i['name']}").join(', '),
            'vendorPickupPin': vendorPickupPin,
            'studentDeliveryPin': studentDeliveryPin,
            'escrow_status': 'HELD',
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      });

      setState(() {
        _cart.clear();
        _cartItems.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCourier
              ? '🎉 Order placed & DeLiv courier requested! Track live in Pre-Orders.'
              : '🎉 Supermarket order placed successfully! Show your QR pass at counter.'),
          backgroundColor: _neonCyan,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e'), backgroundColor: _neonPink),
      );
    } finally {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        title: const Text('Campus Supermarket & Tech', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          // Accessibility Voice Reader (Feature 29)
          IconButton(
            icon: Icon(_isSpeaking ? Icons.volume_off : Icons.record_voice_over, color: _isSpeaking ? _neonPink : _neonCyan),
            tooltip: 'Audio Guide (Accessibility)',
            onPressed: _speakAccessibilityGuide,
          ),
          // Barcode Scanner Action (Feature 2)
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: _neonCyan),
            tooltip: 'Scan Barcode / SKU',
            onPressed: _showBarcodeScannerModal,
          ),
          // Cart with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                onPressed: _showCartSheet,
              ),
              if (_cart.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: _neonPink, shape: BoxShape.circle),
                    child: Text('${_cart.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: _cardColor,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search groceries, laptops, calculators, lab coats...',
                    hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Icon(Icons.search, color: _neonCyan),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                // Categories Horizontal Scroll (Feature 1)
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final cat = _categories[i];
                      final isSelected = (_selectedCategory == cat['id']);
                      return InkWell(
                        onTap: () => setState(() => _selectedCategory = cat['id']),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? _neonCyan : _surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(cat['icon'], style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                cat['name'],
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Happy Hour / Okoa Surplus Banner (Feature 6)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _neonOrange.withAlpha(25),
            child: const Row(
              children: [
                Icon(Icons.bolt, color: _neonOrange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Campus Happy Hour Active: Evening surplus markdowns (30-50% off)!',
                    style: TextStyle(color: _neonOrange, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Live Supermarket Items Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('supermarket_skus').limit(50).snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _neonCyan));
                }

                var docs = snapshot.data?.docs ?? [];
                
                // Fallback items if database is freshly initialized
                if (docs.isEmpty) {
                  return _buildFallbackCatalog();
                }

                // Filter by category and search
                var filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final cat = (data['category'] ?? '').toString().toLowerCase();
                  final matchesCat = (_selectedCategory == 'all' || cat == _selectedCategory);
                  final matchesSearch = (_searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase()));
                  return matchesCat && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront_outlined, size: 56, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No items found matching "$_searchQuery"'
                              : 'No items in this category currently.',
                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try selecting "All" or searching for groceries, calculators or food.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final data = filtered[i].data() as Map<String, dynamic>;
                    data['id'] = filtered[i].id;
                    return _buildProductCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    final name = item['name'] ?? item['title'] ?? 'Campus Item';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final stock = (item['stockQuantity'] as num?)?.toInt() ?? (item['stock'] as num?)?.toInt() ?? 10;
    final isAvailable = ((item['inStock'] as bool?) ?? (item['isAvailable'] as bool?) ?? true) && stock > 0;
    final category = (item['category'] ?? '').toString().toLowerCase();

    String iconEmoji = '🛒';
    if (category == 'electronics') {
      iconEmoji = '💻';
    } else if (category == 'food') {
      iconEmoji = '🍕';
    } else if (category == 'pharmacy') {
      iconEmoji = '💊';
    } else if (category == 'stationery') {
      iconEmoji = '📚';
    }

    return InkWell(
      onTap: () => _showProductDetailModal(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail / Icon
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text(
                    iconEmoji,
                    style: const TextStyle(fontSize: 42),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KES ${price.toStringAsFixed(0)}',
                  style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  isAvailable ? '$stock left' : 'Out of stock',
                  style: TextStyle(color: isAvailable ? Colors.greenAccent : _neonPink, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAvailable ? _neonCyan : Colors.grey[800],
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isAvailable ? () => _showProductDetailModal(item) : null,
                child: Text(isAvailable ? 'View & Buy' : 'Sold Out', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

