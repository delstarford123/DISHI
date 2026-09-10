import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class EscrowMarketView extends StatefulWidget {
  final Map<String, dynamic> user;

  const EscrowMarketView({super.key, required this.user});

  @override
  State<EscrowMarketView> createState() => _EscrowMarketViewState();
}

class _EscrowMarketViewState extends State<EscrowMarketView> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<dynamic> _items = [];
  List<dynamic> _myOrders = [];
  final List<dynamic> _cart = [];
  late TabController _tabController;
  // ─── Search & Filter State ───────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final List<String> _marketCategories = [
    'All', 'Books', 'Electronics', 'Clothes', 'Food', 'Furniture', 'Other'
  ];
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMyOrders(); // only orders need one-time fetch; market uses stream
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _contactController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('escrow_items')
          .where('status', isEqualTo: 'Available')
          .get();
          
      setState(() {
        _items = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMyOrders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('escrow_items')
          .where('buyerId', isEqualTo: widget.user['uid'])
          .get();
          
      setState(() {
        _myOrders = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      });
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    }
  }

  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      if (!_cart.any((element) => element['id'] == item['id'])) {
        _cart.add(item);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Cart!'), backgroundColor: MPesaTheme.primaryGreen)
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item already in Cart'))
        );
      }
    });
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        double total = _cart.fold(0, (sum, item) => sum + item['price']);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Your Cart', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_cart.isEmpty)
                    const Text('Cart is empty', style: TextStyle(color: Colors.white54)),
                  ..._cart.map((item) => ListTile(
                    title: Text(item['title'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text('KES ${item['price']}', style: const TextStyle(color: MPesaTheme.primaryGreen)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                      onPressed: () {
                        setState(() => _cart.remove(item));
                        setModalState(() {});
                        if (_cart.isEmpty) Navigator.pop(context);
                      },
                    ),
                  )),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('KES $total', style: const TextStyle(color: MPesaTheme.primaryGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MPesaTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16)
                      ),
                      onPressed: _cart.isEmpty ? null : () {
                        Navigator.pop(context);
                        _checkoutCart(total);
                      },
                      child: const Text('Checkout with Escrow', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _checkoutCart(double total) async {
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (var item in _cart) {
        final docRef = FirebaseFirestore.instance.collection('escrow_items').doc(item['id']);
        batch.update(docRef, {
          'status': 'In Escrow',
          'buyerId': widget.user['uid'],
          'escrowCreatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      if (mounted) {
        setState(() {
          _myOrders.addAll(_cart.map((item) => {...item, 'status': 'In Escrow'}));
          _items.removeWhere((i) => _cart.any((c) => c['id'] == i['id']));
          _cart.clear();
          _isLoading = false;
          _tabController.animateTo(1);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed! Funds locked in Escrow.'),
            backgroundColor: MPesaTheme.primaryGreen,
          )
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
      }
    }
  }

  Future<void> _confirmDelivery(String itemId) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('escrow_items').doc(itemId).update({
        'status': 'Delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        setState(() {
          final idx = _myOrders.indexWhere((element) => element['id'] == itemId);
          if (idx != -1) {
            _myOrders[idx]['status'] = 'Delivered';
          }
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery confirmed! Funds released to seller.'),
            backgroundColor: MPesaTheme.primaryGreen,
          )
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Confirmation failed: $e')));
      }
    }
  }

  void _showSellItemModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sell an Item', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTextField('Title', 'e.g. Psychology 101 Book', controller: _titleController),
              const SizedBox(height: 12),
              _buildTextField('Description', 'Details about condition...', controller: _descController),
              const SizedBox(height: 12),
              _buildTextField('Price (KES)', '0.00', isNumber: true, controller: _priceController),
              const SizedBox(height: 12),
              _buildTextField('Contact Number', '07...', isNumber: true, controller: _contactController),
              const SizedBox(height: 24),
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, color: Colors.white54),
                    SizedBox(height: 8),
                    Text('Upload Image', style: TextStyle(color: Colors.white54))
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16)
                ),
                onPressed: () async {
                  if (_titleController.text.isEmpty || _priceController.text.isEmpty) return;
                  
                  final newItem = {
                    'title': _titleController.text,
                    'description': _descController.text,
                    'price': double.tryParse(_priceController.text) ?? 0.0,
                    'contact': _contactController.text,
                    'sellerId': widget.user['uid'],
                    'seller_name': widget.user['displayName'] ?? widget.user['name'] ?? 'Student',
                    'status': 'Available',
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                  
                  try {
                    await FirebaseFirestore.instance.collection('escrow_items').add(newItem);
                    _titleController.clear();
                    _descController.clear();
                    _priceController.clear();
                    _contactController.clear();
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Item posted successfully!'), backgroundColor: MPesaTheme.primaryGreen)
                      );
                      _fetchItems(); // Refresh the feed
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error posting item: $e')));
                    }
                  }
                },
                child: const Text('Post Item', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTextField(String label, String hint, {bool isNumber = false, TextEditingController? controller}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: MPesaTheme.primaryGreen), borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Campus Marketplace'),
        backgroundColor: const Color(0xFF131A2A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MPesaTheme.primaryGreen,
          labelColor: MPesaTheme.primaryGreen,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Market'),
            Tab(text: 'My Orders'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business, color: MPesaTheme.primaryGreen),
            onPressed: _showSellItemModal,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildMarketTab(),
              _buildOrdersTab(),
            ],
          ),
      floatingActionButton: _cart.isNotEmpty ? FloatingActionButton.extended(
        onPressed: _showCart,
        backgroundColor: MPesaTheme.primaryGreen,
        icon: const Icon(Icons.shopping_cart, color: Colors.black),
        label: Text('Cart (${_cart.length})', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _buildMarketTab() {
    return Column(
      children: [
        // ─── Search Bar ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search items...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
              filled: true,
              fillColor: const Color(0xFF1A2235),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            ),
          ),
        ),
        // ─── Category Chips ───────────────────────────────────────────────
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _marketCategories.length,
            itemBuilder: (_, i) {
              final cat = _marketCategories[i];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat,
                      style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  selected: isSelected,
                  selectedColor: MPesaTheme.primaryGreen,
                  backgroundColor: const Color(0xFF1A2235),
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        // ─── Live Stream ─────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('escrow_items')
                .where('status', isEqualTo: 'Available')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: MPesaTheme.primaryGreen));
              }
              List<Map<String, dynamic>> items = (snap.data?.docs ?? [])
                  .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                  .toList();

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                items = items
                    .where((it) =>
                        (it['title'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_searchQuery) ||
                        (it['description'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_searchQuery))
                    .toList();
              }
              // Apply category filter
              if (_selectedCategory != 'All') {
                items = items
                    .where((it) => it['category'] == _selectedCategory)
                    .toList();
              }

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store_mall_directory,
                          size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text(
                          _searchQuery.isNotEmpty
                              ? 'No items match "$_searchQuery"'
                              : 'No items in this category',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                          onPressed: _showSellItemModal,
                          icon: const Icon(Icons.add,
                              color: MPesaTheme.primaryGreen),
                          label: const Text('Sell something',
                              style: TextStyle(
                                  color: MPesaTheme.primaryGreen))),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _fetchItems,
                color: MPesaTheme.primaryGreen,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _buildItemCard(items[index], false),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    return RefreshIndicator(
      onRefresh: _fetchMyOrders,
      color: MPesaTheme.primaryGreen,
      child: _myOrders.isEmpty
          ? const Center(child: Text('No orders yet', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myOrders.length,
              itemBuilder: (context, index) {
                final item = _myOrders[index];
                return _buildItemCard(item, true);
              },
            ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isOrder) {
    final String? imageUrl = item['imageUrl'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image header
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            )
          else
            Container(
              height: 100,
              color: const Color(0xFF1A2235),
              child: const Center(
                child: Icon(Icons.inventory_2, size: 40, color: Colors.white24),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(item['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MPesaTheme.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'KES ${item['price']}',
                  style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          if (item['description'] != null) ...[
            const SizedBox(height: 8),
            Text(item['description'], style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white12,
                    child: Icon(Icons.person, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text('Seller: ${item['seller_name']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              if (isOrder)
                if (item['status'] == 'Delivered')
                  const Text('Delivered', style: TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold))
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _confirmDelivery(item['id']),
                    child: const Text('Confirm Receipt', style: TextStyle(color: Colors.white)),
                  )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MPesaTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                  ),
                  onPressed: () => _addToCart(item),
                  icon: const Icon(Icons.add_shopping_cart, color: Colors.black, size: 16),
                  label: const Text('Add to Cart', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
            ],
          )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
