import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../core/models/user_model.dart';
import '../../../core/services/api_config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/call_service.dart';
import 'package:uuid/uuid.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorDirectoryView extends StatefulWidget {
  const VendorDirectoryView({super.key});

  @override
  State<VendorDirectoryView> createState() => _VendorDirectoryViewState();
}

class _VendorDirectoryViewState extends State<VendorDirectoryView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedCountry = 'All';
  String _searchQuery = '';
  bool _sortByNearest = false;
  Position? _currentPosition;
  bool _isLocating = false;

  final List<Map<String, String>> _countries = [
    {'name': 'All', 'flag': '🌍'},
    {'name': 'Kenya', 'flag': '🇰🇪'},
    {'name': 'Uganda', 'flag': '🇺🇬'},
    {'name': 'Tanzania', 'flag': '🇹🇿'},
    {'name': 'Rwanda', 'flag': '🇷🇼'},
    {'name': 'Nigeria', 'flag': '🇳🇬'},
    {'name': 'Ghana', 'flag': '🇬🇭'},
    {'name': 'South Africa', 'flag': '🇿🇦'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _isLocating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  double? _calculateDistance(Map<String, dynamic> data) {
    if (_currentPosition == null) return null;
    final lat = (data['latitude'] as num?)?.toDouble();
    final lon = (data['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    
    final distMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lon,
    );
    return distMeters / 1000.0;
  }

  String? _formatDistance(double? distKm) {
    if (distKm == null) return null;
    if (distKm < 1.0) {
      return '${(distKm * 1000).toInt()} m away';
    }
    return '${distKm.toStringAsFixed(1)} km away';
  }

  void _showPreorderDialog(UserModel vendor) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _VendorMenuView(vendor: vendor)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Campus Eats & Goods', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Kenya & Pan-African Directory (v6)', style: TextStyle(color: _neonCyan, fontSize: 12)),
          ],
        ),
        backgroundColor: _bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh Location',
            icon: _isLocating 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2))
              : const Icon(Icons.my_location_rounded, color: _neonCyan),
            onPressed: _fetchLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── SEARCH BAR ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search vendors, food, dishes, campus...',
                  hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: _neonCyan),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: _textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),
          ),

          // ─── REGION & NEAREST FILTER ROW ─────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Nearest to Me filter pill
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(Icons.near_me_rounded, size: 16, color: _sortByNearest ? Colors.black : _neonCyan),
                    label: Text(
                      'Nearest to Me',
                      style: TextStyle(
                        color: _sortByNearest ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: _sortByNearest,
                    selectedColor: _neonCyan,
                    backgroundColor: _cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _sortByNearest ? _neonCyan : Colors.white12)),
                    onSelected: (selected) {
                      if (selected && _currentPosition == null) {
                        _fetchLocation();
                      }
                      setState(() => _sortByNearest = selected);
                    },
                  ),
                ),

                // Country Chips
                ..._countries.map((c) {
                  final isSelected = _selectedCountry == c['name'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${c['flag']} ${c['name']}', style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: _neonCyan,
                      backgroundColor: _cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? _neonCyan : Colors.white12)),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCountry = c['name']!);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── VENDOR STREAM ───────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').where('roles', arrayContains: 'vendor').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _neonCyan));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading vendors', style: TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined, size: 64, color: _neonCyan.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        const Text('No vendors found', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Check back soon as merchants onboard across campus.', style: TextStyle(color: _textSecondary, fontSize: 13)),
                      ],
                    ),
                  );
                }

                // Process & filter vendor items
                List<Map<String, dynamic>> processedVendors = [];
                for (var doc in snapshot.data!.docs) {
                  if (doc.data() == null) continue;
                  final data = Map<String, dynamic>.from(doc.data() as Map);
                  final userModel = UserModel.fromJson(data, doc.id);
                  final country = (data['country'] ?? 'Kenya').toString();
                  final campus = (data['campus'] ?? 'MMUST').toString();
                  final county = (data['county'] ?? '').toString();
                  final address = (data['address'] ?? data['venueLocation'] ?? '').toString();
                  final categories = (data['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['Hot Meals'];
                  final preorderEnabled = (data['preorderEnabled'] ?? true) as bool;
                  final isOpen = (data['isOpen'] ?? true) as bool;

                  // Country filter
                  if (_selectedCountry != 'All' && country.toLowerCase() != _selectedCountry.toLowerCase()) {
                    continue;
                  }

                  // Search text filter
                  if (_searchQuery.isNotEmpty) {
                    final searchCorpus = '${userModel.displayName} $campus $county $address ${categories.join(" ")}'.toLowerCase();
                    if (!searchCorpus.contains(_searchQuery)) {
                      continue;
                    }
                  }

                  // Distance
                  final distKm = _calculateDistance(data);

                  processedVendors.add({
                    'model': userModel,
                    'data': data,
                    'distKm': distKm,
                    'distFormatted': _formatDistance(distKm),
                    'country': country,
                    'campus': campus,
                    'preorderEnabled': preorderEnabled,
                    'isOpen': isOpen,
                  });
                }

                // Sort by nearest if active
                if (_sortByNearest && _currentPosition != null) {
                  processedVendors.sort((a, b) {
                    final dA = a['distKm'] as double? ?? 999999;
                    final dB = b['distKm'] as double? ?? 999999;
                    return dA.compareTo(dB);
                  });
                }

                if (processedVendors.isEmpty) {
                  return const Center(
                    child: Text('No vendors match your search filters.', style: TextStyle(color: _textSecondary, fontSize: 15)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: processedVendors.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = processedVendors[index];
                    final vendor = item['model'] as UserModel;
                    final distFormatted = item['distFormatted'] as String?;
                    final campus = item['campus'] as String;
                    final preorderEnabled = item['preorderEnabled'] as bool;

                    return Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _showPreorderDialog(vendor),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar / Cover
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: _neonCyan.withOpacity(0.2),
                                backgroundImage: vendor.profileImageUrl != null ? NetworkImage(vendor.profileImageUrl!) : null,
                                child: vendor.profileImageUrl == null ? const Icon(Icons.storefront_rounded, color: _neonCyan, size: 28) : null,
                              ),
                              const SizedBox(width: 14),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            vendor.displayName,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (distFormatted != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _neonCyan.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.location_on, size: 12, color: _neonCyan),
                                                const SizedBox(width: 2),
                                                Text(distFormatted, style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),

                                    // Campus / Location text
                                    Row(
                                      children: [
                                        const Icon(Icons.school_outlined, size: 13, color: _textSecondary),
                                        const SizedBox(width: 4),
                                        Text(campus, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                        const SizedBox(width: 8),
                                        const Text('•', style: TextStyle(color: _textSecondary)),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                        const SizedBox(width: 2),
                                        const Text('4.8', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Action / Badges
                                    Row(
                                      children: [
                                        if (preorderEnabled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _neonOrange.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text('Preorders Open', style: TextStyle(color: _neonOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        const Spacer(),
                                        InkWell(
                                          onTap: () => DishiCallService.showCallOptions(
                                            context,
                                            targetUserId: vendor.uid,
                                            targetUserName: vendor.displayName,
                                            subtitle: 'Voice or Video call this food stall',
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.phone, size: 12, color: Color(0xFF10B981)),
                                                SizedBox(width: 4),
                                                Text('Call', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('View Menu', style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward_ios_rounded, color: _neonCyan, size: 12),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorMenuView extends StatefulWidget {
  final UserModel vendor;
  const _VendorMenuView({required this.vendor});

  @override
  State<_VendorMenuView> createState() => _VendorMenuViewState();
}

class _VendorMenuViewState extends State<_VendorMenuView> {
  TimeOfDay _pickupTime = const TimeOfDay(hour: 12, minute: 30);
  bool _isSubmitting = false;

  void _submitOrder(Map<String, dynamic> item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final pickupDateTime = DateTime(now.year, now.month, now.day, _pickupTime.hour, _pickupTime.minute);
      final String orderId = const Uuid().v4();
      final double totalCost = (item['price'] as num).toDouble();
      final String timestamp = DateTime.now().toUtc().toIso8601String();

      // Sign request with HMAC matching backend transaction_routes.py
      final rawData = '$uid:$totalCost:${widget.vendor.uid}:$orderId:$timestamp';
      final hmac = Hmac(sha256, utf8.encode('super-secret-vendor-key'));
      final signature = hmac.convert(utf8.encode(rawData)).toString();

      final payload = {
        'uid': uid,
        'amount': totalCost,
        'vendorId': widget.vendor.uid,
        'vendorName': widget.vendor.displayName,
        'mealName': item['name'],
        'txId': orderId,
        'timestamp': timestamp,
        'signature': signature,
        'dayOfWeek': 'Today',
        'pickupTime': pickupDateTime.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(ApiConfig.transactionPreorder),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preorder paid & placed successfully!'),
              backgroundColor: _neonCyan,
            ),
          );
        }
      } else {
        String errMsg = 'Failed to place preorder';
        try {
          final parsed = jsonDecode(response.body);
          errMsg = parsed['error'] ?? 'Server error (${response.statusCode})';
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(widget.vendor.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: _neonCyan),
            tooltip: 'Call Stall',
            onPressed: () => DishiCallService.showCallOptions(
              context,
              targetUserId: widget.vendor.uid,
              targetUserName: widget.vendor.displayName,
              subtitle: 'Voice or Video call this cafeteria',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: _cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Pickup Time:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: _pickupTime);
                    if (picked != null) setState(() => _pickupTime = picked);
                  },
                  child: Text(_pickupTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('vendor_menus').where('vendorId', isEqualTo: widget.vendor.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _neonCyan));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading menu', style: TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No menu items listed yet.', style: TextStyle(color: _textSecondary, fontSize: 16)),
                  );
                }

                final items = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index].data() as Map<String, dynamic>;
                    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                    final imageUrl = item['imageUrl'] as String?;

                    return Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: _neonCyan))
                                : const Icon(Icons.fastfood, color: _neonCyan),
                          ),
                        ),
                        title: Text(item['name'] ?? 'Menu Item', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('KES ${price.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _neonOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isSubmitting ? null : () => _submitOrder(item),
                          child: const Text('Preorder', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
