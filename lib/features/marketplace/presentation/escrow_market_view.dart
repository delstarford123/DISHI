import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/mpesa_theme.dart';

class EscrowMarketView extends StatefulWidget {
  final Map<String, dynamic> user;

  const EscrowMarketView({super.key, required this.user});

  @override
  State<EscrowMarketView> createState() => _EscrowMarketViewState();
}

class _EscrowMarketViewState extends State<EscrowMarketView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Books & Study',
    'Tech & Gadgets',
    'Fashion & Clothes',
    'Hostel & Furniture',
    'Food & Snacks',
    'Other'
  ];

  final List<Map<String, dynamic>> _cart = [];
  bool _isProcessing = false;

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? widget.user['uid'] ?? '';
  String get currentUserName => widget.user['displayName'] ?? widget.user['name'] ?? 'Student';
  String get currentUserPhone => widget.user['phoneNumber'] ?? widget.user['phone'] ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(Map<String, dynamic> item) {
    if (_cart.any((element) => element['id'] == item['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item is already in your cart!')),
      );
      return;
    }
    setState(() => _cart.add(item));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item['title']} added to Escrow Cart!'),
        backgroundColor: MPesaTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _contactSeller(Map<String, dynamic> item) async {
    final sellerName = item['seller_name'] ?? 'Campus Seller';
    final rawContact = (item['contact'] ?? item['phone'] ?? '').toString();
    final title = item['title'] ?? 'item';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF10B981),
                  child: Icon(Icons.person, color: Colors.black, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sellerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Selling: $title', style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (rawContact.isNotEmpty) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.chat),
                label: const Text('Chat on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  String phone = rawContact.replaceAll(RegExp(r'[^0-9]'), '');
                  if (phone.startsWith('0')) phone = '254${phone.substring(1)}';
                  final msg = Uri.encodeComponent("Hi $sellerName, I'm interested in buying your '$title' on DISHI Campus Market.");
                  final url = Uri.parse("https://wa.me/$phone?text=$msg");
                  try {
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.phone),
                label: Text('Call $rawContact', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final url = Uri.parse("tel:$rawContact");
                  try {
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  } catch (_) {}
                },
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('No direct phone number provided by seller.', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _buySingleItem(Map<String, dynamic> item) async {
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final String title = item['title'] ?? 'Item';
    final String itemId = item['id'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: MPesaTheme.primaryGreen),
            SizedBox(width: 8),
            Text('Lock in Escrow', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item: $title', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Price: KES ${price.toStringAsFixed(0)}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2235),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                '🔒 Your money stays protected in Campus Escrow. The seller is only paid after you inspect and accept the item.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Escrow', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('escrow_items').doc(itemId).update({
        'status': 'In Escrow',
        'buyerId': currentUid,
        'buyerName': currentUserName,
        'escrowCreatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order locked in Escrow! View progress under "My Orders".'),
            backgroundColor: MPesaTheme.primaryGreen,
          ),
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to lock order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmDelivery(Map<String, dynamic> item) async {
    final String itemId = item['id'];
    final String sellerId = item['sellerId'] ?? '';
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;

    setState(() => _isProcessing = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Mark item delivered
      final itemRef = db.collection('escrow_items').doc(itemId);
      batch.update(itemRef, {
        'status': 'Delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      // 2. Release funds to seller wallet
      if (sellerId.isNotEmpty && price > 0) {
        final sellerRef = db.collection('users').doc(sellerId);
        batch.update(sellerRef, {
          'walletBalance': FieldValue.increment(price),
        });

        // 3. Record transaction for seller
        final txRef = db.collection('transactions').doc();
        batch.set(txRef, {
          'type': 'escrow_payout',
          'studentId': sellerId,
          'buyerId': currentUid,
          'itemId': itemId,
          'amount': price,
          'status': 'completed',
          'description': 'Escrow payout released for: ${item['title']}',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Receipt confirmed! Escrow funds released to seller.'),
            backgroundColor: MPesaTheme.primaryGreen,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delivery confirmation error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showCartSheet() {
    double total = _cart.fold(0.0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0));

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Escrow Cart', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${_cart.length} item(s)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                if (_cart.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Text('Your cart is empty', style: TextStyle(color: Colors.white38)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _cart.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                      itemBuilder: (_, idx) {
                        final it = _cart[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(it['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text('KES ${it['price']}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () {
                              setState(() => _cart.removeAt(idx));
                              setModalState(() {});
                              if (_cart.isEmpty) Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(color: Colors.white24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Escrow Lock:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text('KES ${total.toStringAsFixed(0)}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MPesaTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _cart.isEmpty
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            setState(() => _isProcessing = true);
                            try {
                              final batch = FirebaseFirestore.instance.batch();
                              for (var item in _cart) {
                                final docRef = FirebaseFirestore.instance.collection('escrow_items').doc(item['id']);
                                batch.update(docRef, {
                                  'status': 'In Escrow',
                                  'buyerId': currentUid,
                                  'buyerName': currentUserName,
                                  'escrowCreatedAt': FieldValue.serverTimestamp(),
                                });
                              }
                              await batch.commit();

                              setState(() => _cart.clear());
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('All items locked in Escrow!'),
                                    backgroundColor: MPesaTheme.primaryGreen,
                                  ),
                                );
                                _tabController.animateTo(1);
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Checkout failed: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isProcessing = false);
                            }
                          },
                    child: const Text('Lock in Escrow & Order', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSellItemModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final contactCtrl = TextEditingController(text: currentUserPhone);
    String selectedCat = 'Books & Study';
    String condition = 'Like New';
    File? selectedImageFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('List Item on Campus Market', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Item Image Picker Box
                GestureDetector(
                  onTap: () async {
                    try {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                      if (picked != null) {
                        setModalState(() {
                          selectedImageFile = File(picked.path);
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
                    }
                  },
                  child: Container(
                    height: 125,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2235),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selectedImageFile != null ? MPesaTheme.primaryGreen : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: selectedImageFile != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.file(selectedImageFile!, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setModalState(() => selectedImageFile = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Change Photo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: MPesaTheme.primaryGreen, size: 34),
                              const SizedBox(height: 8),
                              const Text('Upload Item Photo', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              const Text('Clear photos help sell 3x faster', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildModalTextField('Item Title', 'e.g. Calculus 8th Edition, HP Charger...', controller: titleCtrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Category', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2235),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: DropdownButton<String>(
                              value: selectedCat,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF131A2A),
                              underline: const SizedBox(),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) {
                                if (v != null) setModalState(() => selectedCat = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Condition', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2235),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: DropdownButton<String>(
                              value: condition,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF131A2A),
                              underline: const SizedBox(),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: ['Brand New', 'Like New', 'Good', 'Fair'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) {
                                if (v != null) setModalState(() => condition = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildModalTextField('Price (KES)', 'e.g. 500', isNumber: true, controller: priceCtrl),
                const SizedBox(height: 12),
                _buildModalTextField('Phone or WhatsApp', '07XX XXX XXX', isNumber: true, controller: contactCtrl),
                const SizedBox(height: 12),
                _buildModalTextField('Description (Optional)', 'Notes, hostel pickup location, etc.', maxLines: 2, controller: descCtrl),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MPesaTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      if (title.isEmpty || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid title and price')),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      setState(() => _isProcessing = true);
                      try {
                        String? uploadedImageUrl;
                        if (selectedImageFile != null) {
                          final imgId = const Uuid().v4();
                          final storageRef = FirebaseStorage.instance
                              .ref()
                              .child('marketplace')
                              .child('$imgId.jpg');
                          await storageRef.putFile(selectedImageFile!);
                          uploadedImageUrl = await storageRef.getDownloadURL();
                        }

                        await FirebaseFirestore.instance.collection('escrow_items').add({
                          'title': title,
                          'description': descCtrl.text.trim(),
                          'price': price,
                          'contact': contactCtrl.text.trim(),
                          'category': selectedCat,
                          'condition': condition,
                          'imageUrl': uploadedImageUrl ?? '',
                          'sellerId': currentUid,
                          'seller_name': currentUserName,
                          'status': 'Available',
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Item posted live to Campus Marketplace!'),
                              backgroundColor: MPesaTheme.primaryGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to post item: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
                    child: const Text('Post Item Live', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalTextField(String label, String hint, {bool isNumber = false, int maxLines = 1, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1A2235),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0C101B);
    const cardColor = Color(0xFF131A2A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: const Text(
          'Campus Marketplace',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MPesaTheme.primaryGreen,
          labelColor: MPesaTheme.primaryGreen,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Browse Market'),
            Tab(text: 'My Orders'),
            Tab(text: 'My Listings'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sell Item',
            icon: const Icon(Icons.add_circle, color: MPesaTheme.primaryGreen),
            onPressed: _showSellItemModal,
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMarketTab(),
                _buildOrdersTab(),
                _buildListingsTab(),
              ],
            ),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCartSheet,
              backgroundColor: MPesaTheme.primaryGreen,
              icon: const Icon(Icons.shopping_bag, color: Colors.black),
              label: Text(
                'Escrow Cart (${_cart.length})',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _showSellItemModal,
              backgroundColor: const Color(0xFF10B981),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Sell an Item', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildMarketTab() {
    return Column(
      children: [
        // ─── Escrow Trust Banner ───
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '100% Escrow Protection: Seller is paid only after you inspect and accept the item.',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // ─── Search Bar ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search books, electronics, calculators, keja gear...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1A2235),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),

        // ─── Category Chips ───
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  selected: isSelected,
                  selectedColor: MPesaTheme.primaryGreen,
                  backgroundColor: const Color(0xFF1A2235),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),

        // ─── Live Market Items Stream ───
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('escrow_items')
                .where('status', isEqualTo: 'Available')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));
              }

              List<Map<String, dynamic>> items = (snap.data?.docs ?? [])
                  .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                  .toList();

              // Sort by createdAt descending in memory (avoids requiring missing composite index)
              items.sort((a, b) {
                final aTs = a['createdAt'] as Timestamp?;
                final bTs = b['createdAt'] as Timestamp?;
                if (aTs == null || bTs == null) return 0;
                return bTs.compareTo(aTs);
              });

              // Apply Search Filter
              if (_searchQuery.isNotEmpty) {
                items = items.where((it) {
                  final title = (it['title'] ?? '').toString().toLowerCase();
                  final desc = (it['description'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) || desc.contains(_searchQuery);
                }).toList();
              }

              // Apply Category Filter
              if (_selectedCategory != 'All') {
                items = items.where((it) => it['category'] == _selectedCategory).toList();
              }

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_outlined, size: 64, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No items match "$_searchQuery"'
                            : 'No items in this category yet',
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                        onPressed: _showSellItemModal,
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text('Post the First Item', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {},
                color: MPesaTheme.primaryGreen,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _buildMarketItemCard(items[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMarketItemCard(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Untitled Item';
    final desc = item['description'] ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final sellerName = item['seller_name'] ?? 'Student';
    final category = item['category'] ?? 'Campus';
    final condition = item['condition'] ?? 'Good';
    final isMyOwnItem = item['sellerId'] == currentUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item['imageUrl'] != null && (item['imageUrl'] as String).isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: item['imageUrl'],
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 58,
                        height: 58,
                        color: const Color(0xFF1A2235),
                        child: const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen, strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 58,
                        height: 58,
                        color: const Color(0xFF1A2235),
                        child: Icon(_getCategoryIcon(category), color: MPesaTheme.primaryGreen, size: 26),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2235),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Center(
                      child: Icon(
                        _getCategoryIcon(category),
                        color: MPesaTheme.primaryGreen,
                        size: 26,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: MPesaTheme.primaryGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.4)),
                            ),
                            child: Text(
                              'KES ${NumberFormat("#,##0").format(price)}',
                              style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(category, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(condition, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 14),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      isMyOwnItem ? 'You (Seller)' : 'Seller: $sellerName',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                if (!isMyOwnItem)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.chat, size: 14),
                        label: const Text('Contact', style: TextStyle(fontSize: 11)),
                        onPressed: () => _contactSeller(item),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MPesaTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.lock, size: 14, color: Colors.black),
                        label: const Text('Buy Escrow', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _buySingleItem(item),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Your Listing', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('escrow_items')
          .where('buyerId', isEqualTo: currentUid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));
        }

        final orders = (snap.data?.docs ?? [])
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();

        if (orders.isEmpty) {
          return const Center(
            child: Text('No orders in Escrow yet', style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: orders.length,
          itemBuilder: (ctx, idx) {
            final order = orders[idx];
            final status = order['status'] ?? 'In Escrow';
            final isDelivered = status == 'Delivered';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDelivered ? MPesaTheme.primaryGreen.withOpacity(0.3) : Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          order['title'] ?? 'Item',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDelivered ? MPesaTheme.primaryGreen : Colors.amber).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: isDelivered ? MPesaTheme.primaryGreen : Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Price: KES ${order['price']}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (!isDelivered)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MPesaTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle, color: Colors.black, size: 18),
                        label: const Text('Confirm Receipt & Release Funds', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => _confirmDelivery(order),
                      ),
                    )
                  else
                    const Row(
                      children: [
                        Icon(Icons.done_all, color: MPesaTheme.primaryGreen, size: 16),
                        SizedBox(width: 4),
                        Text('Delivered & Settled', style: TextStyle(color: MPesaTheme.primaryGreen, fontSize: 12)),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildListingsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('escrow_items')
          .where('sellerId', isEqualTo: currentUid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));
        }

        final listings = (snap.data?.docs ?? [])
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();

        if (listings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 56, color: Colors.white24),
                const SizedBox(height: 12),
                const Text('You have no active listings', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                  onPressed: _showSellItemModal,
                  child: const Text('Post Something to Sell', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: listings.length,
          itemBuilder: (ctx, idx) {
            final it = listings[idx];
            final status = it['status'] ?? 'Available';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  if (it['imageUrl'] != null && (it['imageUrl'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: it['imageUrl'],
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.inventory_2, color: MPesaTheme.primaryGreen),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('KES ${it['price']} · Status: $status', style: const TextStyle(color: MPesaTheme.primaryGreen, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('escrow_items').doc(it['id']).delete();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Books & Study':
        return Icons.menu_book;
      case 'Tech & Gadgets':
        return Icons.laptop_mac;
      case 'Fashion & Clothes':
        return Icons.checkroom;
      case 'Hostel & Furniture':
        return Icons.chair;
      case 'Food & Snacks':
        return Icons.fastfood;
      default:
        return Icons.inventory_2;
    }
  }
}
