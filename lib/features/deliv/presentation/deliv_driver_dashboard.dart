import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';
import '../../../core/widgets/high_friction_action.dart';
import 'deliv_active_route_view.dart';
import 'driver_scanner_view.dart';
import '../../auth/presentation/login_view.dart';
import '../../../shared/presentation/universal_support_widget.dart';
import '../../../shared/presentation/profile_hub_sheet.dart';
import 'dart:math';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

final List<Map<String, dynamic>> gigCategories = [
  {'name': 'All', 'icon': '🎯', 'color': Colors.white},
  {'name': 'Food Delivery', 'icon': '🍔', 'color': Colors.orange},
  {'name': 'Grocery Run', 'icon': '🛒', 'color': Colors.green},
  {'name': 'Parcel Pickup', 'icon': '📦', 'color': Colors.blue},
  {'name': 'Laundry Pickup & Drop', 'icon': '🧺', 'color': Colors.purple},
  {'name': 'Printing & Photocopy', 'icon': '🖨️', 'color': Colors.cyan},
  {'name': 'Library Book Return', 'icon': '📚', 'color': Colors.brown},
  {'name': 'Campus Errand', 'icon': '🏃', 'color': Colors.yellow},
  {'name': 'Phone Top-up', 'icon': '📱', 'color': Colors.pink},
  {'name': 'Notes/Docs Delivery', 'icon': '📄', 'color': Colors.indigo},
  {'name': 'Boda-Boda Ride', 'icon': '🛵', 'color': Colors.redAccent},
  {'name': 'Walker Escort', 'icon': '🚶', 'color': Colors.teal},
  {'name': 'Event Set-up Help', 'icon': '🎪', 'color': Colors.amber},
  {'name': 'Tutoring Session', 'icon': '🎓', 'color': Colors.blueAccent},
  {'name': 'Tech Repair', 'icon': '🔧', 'color': Colors.grey},
  {'name': 'Lost & Found', 'icon': '🔍', 'color': Colors.lightGreenAccent},
  {'name': 'Hostel Move Help', 'icon': '🏠', 'color': Colors.deepOrangeAccent},
  {'name': 'Pharmacy Run', 'icon': '💊', 'color': Colors.red},
  {'name': 'Market Run', 'icon': '🏪', 'color': Colors.lime},
  {'name': 'Water/Drinks', 'icon': '💧', 'color': Colors.lightBlueAccent},
  {'name': 'Custom Gig', 'icon': '✨', 'color': _neonCyan},
];

class DelivDriverDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const DelivDriverDashboard({super.key, required this.user});

  @override
  State<DelivDriverDashboard> createState() => _DelivDriverDashboardState();
}

class _DelivDriverDashboardState extends State<DelivDriverDashboard> {
  bool _isOnline = false;
  double _earnings = 0.0;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  void _fetchEarnings() {
    // Mock earnings for visual effect
    setState(() {
      _earnings = 240.0;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _toggleStatus(bool value) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('drivers').doc(uid).set(
        {'isOnline': value, 'lastUpdated': FieldValue.serverTimestamp()},
        SetOptions(merge: true)
      );
    }
    setState(() => _isOnline = value);
  }

  Future<void> _postGig(String type, String pay, String pickup, String dropoff) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('deliv_requests').add({
        'type': type,
        'pay': pay,
        'pickup': pickup,
        'dropoff': dropoff,
        'status': 'open',
        'postedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gig Posted!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post gig: $e')));
    }
  }

  void _showPostGigSheet() {
    String selectedType = 'Food Delivery';
    final payController = TextEditingController();
    final pickupController = TextEditingController();
    final dropoffController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Campus Job', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: _cardColor,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Gig Type',
                    labelStyle: const TextStyle(color: _textSecondary),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _textSecondary), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _neonCyan), borderRadius: BorderRadius.circular(12)),
                  ),
                  items: gigCategories.where((g) => g['name'] != 'All').map((g) {
                    return DropdownMenuItem<String>(
                      value: g['name'],
                      child: Row(
                        children: [
                          Text(g['icon'], style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(g['name']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setSheetState(() => selectedType = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pickupController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Pickup Location',
                    labelStyle: const TextStyle(color: _textSecondary),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _textSecondary), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _neonCyan), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dropoffController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Dropoff Location',
                    labelStyle: const TextStyle(color: _textSecondary),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _textSecondary), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _neonCyan), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: payController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Pay (KES)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _textSecondary), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _neonCyan), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _postGig(selectedType, 'KES ${payController.text}', pickupController.text, dropoffController.text);
                      Navigator.pop(context);
                    },
                    child: const Text('Post Gig', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          }
        ),
      ),
    );
  }


  Future<void> _cashOutEarnings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mpesa/driver_withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driver_id': uid,
          'amount': _earnings,
          'method': 'M-PESA Number',
          'destination': widget.user['phoneNumber'] ?? '0700000000'
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cash out successful! Check M-PESA.')));
        setState(() => _earnings = 0);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cash out failed: ${response.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _acceptGig(String gigId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('deliv_requests').doc(gigId).update({
        'status': 'accepted',
        'driverId': uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gig Accepted!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _rejectGig(String gigId) async {
    try {
      await FirebaseFirestore.instance.collection('deliv_requests').doc(gigId).update({
        'rejectedBy': FieldValue.arrayUnion([FirebaseAuth.instance.currentUser?.uid])
      });
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] ?? widget.user['displayName'] ?? 'Driver';
    final firstName = name.split(' ')[0];
    
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => ProfileHubSheet(user: widget.user),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: _cardColor,
                                  backgroundImage: widget.user['photoUrl'] != null ? NetworkImage(widget.user['photoUrl']) : null,
                                  child: widget.user['photoUrl'] == null ? const Icon(Icons.person, color: Colors.white54, size: 30) : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${_getGreeting()} $firstName', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    const Text('Boda · ★ 4.9 · 312 trips', style: TextStyle(color: _textSecondary, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isOnline ? _neonCyan.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _isOnline ? _neonCyan.withValues(alpha: 0.5) : Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Icon(_isOnline ? Icons.play_arrow : Icons.stop, size: 16, color: _isOnline ? _neonCyan : Colors.redAccent),
                              const SizedBox(width: 4),
                              Text(_isOnline ? 'ONLINE' : 'OFFLINE', style: TextStyle(color: _isOnline ? _neonCyan : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // --- EARNINGS STRIP ---
                    Row(
                      children: [
                        _buildEarningsCard('Today', 'KES 240', _neonCyan),
                        const SizedBox(width: 12),
                        _buildEarningsCard('Week', 'KES 1,800', _neonBlue),
                        const SizedBox(width: 12),
                        _buildEarningsCard('All Time', 'KES 18k', _neonOrange),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // --- CASH OUT SLIDER ---
                    HighFrictionAction(
                      label: 'Hold to Cash Out Earnings',
                      baseColor: _neonCyan,
                      onActionCompleted: () {
                         _cashOutEarnings();
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // --- STATS ROW ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn('Rating', '★ 4.9'),
                          _buildStatColumn('Deliveries', '312'),
                          _buildStatColumn('Acceptance', '94%'),
                          _buildStatColumn('Level', 'Pro'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // --- POST GIG FAB ---
                    InkWell(
                      onTap: _showPostGigSheet,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_neonBlue, _neonCyan]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _neonCyan.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle, color: Colors.black87),
                            SizedBox(width: 8),
                            Text('+ Create Campus Job', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // --- GIG CATEGORIES ---
                    const Text('Categories', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: gigCategories.map((g) {
                          final isSelected = _selectedCategory == g['name'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Row(
                                children: [
                                  Text(g['icon']),
                                  const SizedBox(width: 4),
                                  Text(g['name'], style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 16)),
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: g['color'],
                              backgroundColor: _cardColor,
                              onSelected: (val) => setState(() => _selectedCategory = g['name']),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // --- AVAILABLE GIGS FEED ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Available Gigs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Switch(
                          value: _isOnline,
                          onChanged: _toggleStatus,
                          activeThumbColor: _neonCyan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('deliv_requests')
                          .where('status', isEqualTo: 'open')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error loading gigs: ${snapshot.error}', style: const TextStyle(color: _neonRed))));
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _neonCyan));
                        
                        var docs = snapshot.data!.docs.toList();
                        docs.sort((a, b) {
                          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                          if (aTime == null || bTime == null) return 0;
                          return bTime.compareTo(aTime);
                        });
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          docs = docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final rejectedBy = List.from(data['rejectedBy'] ?? []);
                            return !rejectedBy.contains(uid);
                          }).toList();
                        }
                        
                        if (_selectedCategory != 'All') {
                          docs = docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            return data['type'] == _selectedCategory;
                          }).toList();
                        }
                        
                        if (docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('No gigs available in this category.', style: TextStyle(color: _textSecondary)),
                            ),
                          );
                        }
                        
                        return Column(
                          children: docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final catInfo = gigCategories.firstWhere((g) => g['name'] == data['type'], orElse: () => gigCategories.last);
                            final color = catInfo['color'] as Color;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: color.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(catInfo['icon'], style: const TextStyle(fontSize: 24)),
                                          const SizedBox(width: 8),
                                          Text(data['type'] ?? 'Gig', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                        ],
                                      ),
                                      Text(data['pay']?.toString() ?? 'KES -', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.storefront, size: 16, color: _textSecondary),
                                      const SizedBox(width: 8),
                                      Flexible(child: Text('Pickup: ${data['pickup']}', style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 16, color: _neonRed),
                                      const SizedBox(width: 8),
                                      Flexible(child: Text('Dropoff: ${data['dropoff']}', style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _rejectGig(doc.id),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _textSecondary)),
                                            alignment: Alignment.center,
                                            child: const Text('Reject', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _acceptGig(doc.id),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                                            alignment: Alignment.center,
                                            child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard(String title, String amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(bottom: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: _textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 14)),
      ],
    );
  }
}
