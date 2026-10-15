import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/location_service.dart';
import '../../../core/services/api_config.dart';
import '../../match/presentation/match_chat_view.dart';
import 'dart:convert';
import 'dart:async';
import '../../../core/theme/mpesa_theme.dart';

class CampusEmploymentHubView extends StatefulWidget {
  const CampusEmploymentHubView({Key? key}) : super(key: key);

  @override
  State<CampusEmploymentHubView> createState() => _CampusEmploymentHubViewState();
}

class _CampusEmploymentHubViewState extends State<CampusEmploymentHubView> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  late TabController _tabController;

  final List<Map<String, dynamic>> _gigRoles = [
    {'title': 'Campus Tutor', 'icon': Icons.school, 'color': Colors.blueAccent, 'desc': 'Peer-to-peer tutoring for modules'},
    {'title': 'Laundry Agent', 'icon': Icons.local_laundry_service, 'color': Colors.tealAccent, 'desc': 'Pick up, wash, iron, deliver'},
    {'title': 'Event Promoter', 'icon': Icons.campaign, 'color': Colors.orangeAccent, 'desc': 'Sell event/Harambee tickets'},
    {'title': 'Photographer', 'icon': Icons.camera_alt, 'color': Colors.purpleAccent, 'desc': 'Events & graduation photos'},
    {'title': 'Tech Support', 'icon': Icons.computer, 'color': Colors.cyanAccent, 'desc': 'Laptop & phone repair (Gadget Fundi)'},
    {'title': 'Grocery Shopper', 'icon': Icons.shopping_cart, 'color': Colors.lightGreenAccent, 'desc': 'Bulk fresh produce (Soko Agent)'},
    {'title': 'Barber/Salonist', 'icon': Icons.content_cut, 'color': Colors.pinkAccent, 'desc': 'On-demand grooming'},
    {'title': 'Fitness Buddy', 'icon': Icons.fitness_center, 'color': Colors.deepOrangeAccent, 'desc': 'Spot, train, or guide workouts'},
    {'title': 'Note Taker', 'icon': Icons.edit_note, 'color': Colors.amberAccent, 'desc': 'Sell lecture notes & transcription'},
    {'title': 'Night Owl Guard', 'icon': Icons.security, 'color': Colors.redAccent, 'desc': 'Safe late-night escorts'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRegisterDialog(Map<String, dynamic> role) {
    final descController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        decoration: BoxDecoration(
          color: MPesaTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: MPesaTheme.neonGreen.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(role['icon'], color: role['color'], size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Register as ${role['title']}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              role['desc'],
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: descController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe your experience/offerings...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MPesaTheme.neonGreen.withOpacity(0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MPesaTheme.neonGreen.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MPesaTheme.neonGreen),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.neonGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _registerAsWorker(role['title'], descController.text);
                },
                child: const Text('Become a Provider'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _registerAsWorker(String category, String description) async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Fetch precise location for proximity matching
      double? lat;
      double? lng;
      try {
        final pos = await LocationService.getCurrentLocation();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (e) {
        debugPrint('Could not fetch location: $e');
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v6/campus_gigs/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': user.uid,
          'category': category,
          'description': description,
          'portfolio_images': [],
          'latitude': lat,
          'longitude': lng,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully registered as $category!'),
            backgroundColor: MPesaTheme.neonGreen,
          )
        );
      } else {
        String errMsg = 'Registration failed';
        try {
          final resData = json.decode(response.body);
          if (resData is Map && resData.containsKey('error')) {
            errMsg = resData['error'].toString();
          }
        } catch (_) {}
        throw Exception(errMsg);
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration timed out. Please check your network.'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showRequestDialog(Map<String, dynamic> role) {
    final detailsController = TextEditingController();
    final priceController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        decoration: BoxDecoration(
          color: MPesaTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: role['color'].withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(role['icon'], color: role['color'], size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Request ${role['title']}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: detailsController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What exactly do you need?',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Offer Price (Ksh)',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.black26,
                prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MPesaTheme.neonGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: MPesaTheme.neonGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A 3 KSH platform fee applies upon escrow lock.',
                      style: TextStyle(color: MPesaTheme.neonGreen.withOpacity(0.8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: role['color'],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _submitRequest(role['title'], detailsController.text, priceController.text);
                },
                child: const Text('Post Request to Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest(String category, String details, String priceStr) async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final price = double.tryParse(priceStr) ?? 0;
      if (price <= 0) throw Exception("Please enter a valid price");
      
      // Fetch location for proximity matching
      double? lat;
      double? lng;
      try {
        final pos = await LocationService.getCurrentLocation();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (e) {
        debugPrint('Could not fetch location: $e');
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v6/campus_gigs/request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requester_id': user.uid,
          'category': category,
          'details': details,
          'price_offer': price,
          'latitude': lat,
          'longitude': lng,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request posted for $category!'),
            backgroundColor: MPesaTheme.neonGreen,
          )
        );
      } else {
        String errMsg = 'Failed to post request';
        try {
          final resData = json.decode(response.body);
          if (resData is Map && resData.containsKey('error')) {
            errMsg = resData['error'].toString();
          }
        } catch (_) {}
        throw Exception(errMsg);
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please check network.'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payEscrow(String requestId, double price) async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v6/campus_gigs/pay_escrow'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'request_id': requestId,
          'requester_id': user.uid,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Escrow locked for KSH ${price.toStringAsFixed(0)}! Worker notified.'),
            backgroundColor: MPesaTheme.neonGreen,
          ),
        );
      } else {
        String errMsg = 'Failed to lock escrow';
        try {
          final resData = json.decode(response.body);
          if (resData is Map && resData.containsKey('error')) {
            errMsg = resData['error'].toString();
          }
        } catch (_) {}
        throw Exception(errMsg);
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escrow payment timed out. Please check network.'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Escrow payment failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildRoleCard(Map<String, dynamic> role, bool isOffering) {
    return Container(
      decoration: BoxDecoration(
        color: MPesaTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: role['color'].withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: role['color'].withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => isOffering ? _showRegisterDialog(role) : _showRequestDialog(role),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: role['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(role['icon'], color: role['color'], size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  role['title'],
                  textAlign: TextAlign.center,
                  style: MPesaTheme.headingStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  role['desc'],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MPesaTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Campus Gigs', style: MPesaTheme.headingStyle),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MPesaTheme.neonGreen,
          labelColor: MPesaTheme.neonGreen,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Request'),
            Tab(text: 'Offer'),
            Tab(text: 'Active Gigs'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // Request Services Tab
              GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _gigRoles.length,
                itemBuilder: (context, index) => _buildRoleCard(_gigRoles[index], false),
              ),
              
              // Offer Services Tab
              GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _gigRoles.length,
                itemBuilder: (context, index) => _buildRoleCard(_gigRoles[index], true),
              ),

              // Active Gigs Tab
              _buildActiveGigsTab(),
            ],
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: MPesaTheme.neonGreen),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveGigsTab() {
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text("Not authenticated", style: TextStyle(color: Colors.white)));
    
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('campus_gig_requests')
          .where(Filter.or(
            Filter('requester_id', isEqualTo: user.uid),
            Filter('worker_id', isEqualTo: user.uid),
          ))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonGreen));
        
        // Filter out completed gigs so they don't clutter the active list
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'completed';
        }).toList();
        
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_history_outlined, size: 56, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 12),
                const Text("No active campus gigs right now.", style: TextStyle(color: Colors.grey, fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final escrowStatus = data['escrow_status'] ?? 'PENDING';
            final price = (data['price_offer'] as num?)?.toDouble() ?? 0.0;
            final category = data['category'] ?? 'Campus Gig';
            final bool amIRequester = data['requester_id'] == user.uid;
            
            return Card(
              color: MPesaTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: escrowStatus == 'HELD'
                      ? MPesaTheme.neonGreen.withOpacity(0.5)
                      : Colors.white12,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: amIRequester ? Colors.blue.withOpacity(0.2) : MPesaTheme.neonGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                amIRequester ? 'CLIENT' : 'PROVIDER',
                                style: TextStyle(
                                  color: amIRequester ? Colors.blue : MPesaTheme.neonGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Text(
                          'KSH ${price.toStringAsFixed(0)}',
                          style: const TextStyle(color: MPesaTheme.neonGreen, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['details'] ?? 'No details provided',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: status == 'accepted' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'accepted' ? Colors.green : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: escrowStatus == 'HELD' ? MPesaTheme.neonGreen.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ESCROW: $escrowStatus',
                            style: TextStyle(
                              color: escrowStatus == 'HELD' ? MPesaTheme.neonGreen : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action Buttons depending on role and escrow state
                    if (amIRequester && status == 'accepted' && escrowStatus != 'HELD')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MPesaTheme.neonGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.lock, size: 18),
                          label: Text('Deposit Escrow (KSH ${price.toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _payEscrow(docs[index].id, price),
                        ),
                      )
                    else if (amIRequester && escrowStatus == 'HELD')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MPesaTheme.neonGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Complete & Release Funds', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _showPinDialog(docs[index].id),
                        ),
                      )
                    else if (!amIRequester && escrowStatus == 'HELD')
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: MPesaTheme.neonGreen.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Completion PIN:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              data['completion_pin'] ?? '----',
                              style: const TextStyle(color: MPesaTheme.neonGreen, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 4),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.info_outline, size: 16, color: MPesaTheme.neonGreen),
                        label: const Text('View Full Details & Chat', style: TextStyle(color: MPesaTheme.neonGreen, fontSize: 12)),
                        onPressed: () => _showGigDetails(docs[index]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  void _showGigDetails(DocumentSnapshot gigDoc) async {
    final data = gigDoc.data() as Map<String, dynamic>;
    final user = _auth.currentUser;
    if (user == null) return;
    
    final bool amIRequester = data['requester_id'] == user.uid;
    final otherUserId = amIRequester ? data['worker_id'] : data['requester_id'];
    final price = (data['price_offer'] as num?)?.toDouble() ?? 0.0;
    final status = data['status'] ?? 'pending';
    final escrowStatus = data['escrow_status'] ?? 'PENDING';
    final pin = data['completion_pin']?.toString() ?? '----';
    
    String otherUserName = "Awaiting Provider";
    String? otherUserAvatar;
    
    if (otherUserId != null) {
      try {
        final doc = await _firestore.collection('users').doc(otherUserId).get();
        if (doc.exists) {
          final uData = doc.data()!;
          otherUserName = uData['displayName'] ?? uData['name'] ?? uData['full_name'] ?? 'DISHI User';
          otherUserAvatar = uData['avatar_url'] ?? uData['photo_url'] ?? uData['profile_picture'];
        }
      } catch (_) {}
    }
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MPesaTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: MPesaTheme.neonGreen.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('${data['category']} Gig Details', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                Text('KSH ${price.toStringAsFixed(0)}', style: const TextStyle(color: MPesaTheme.neonGreen, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Details: ${data['details'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            
            // Escrow Status Indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: escrowStatus == 'HELD' ? MPesaTheme.neonGreen.withOpacity(0.4) : Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    escrowStatus == 'HELD' ? Icons.security : Icons.hourglass_top,
                    color: escrowStatus == 'HELD' ? MPesaTheme.neonGreen : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          escrowStatus == 'HELD' ? 'Escrow Protected' : 'Escrow Pending',
                          style: TextStyle(
                            color: escrowStatus == 'HELD' ? MPesaTheme.neonGreen : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          escrowStatus == 'HELD'
                              ? 'Funds are safely held by DISHI until service is completed.'
                              : 'Escrow must be deposited before work starts.',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Worker PIN card if worker
            if (!amIRequester && escrowStatus == 'HELD')
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MPesaTheme.neonGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MPesaTheme.neonGreen),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Completion PIN', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pin,
                          style: const TextStyle(color: MPesaTheme.neonGreen, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6),
                        ),
                        const Icon(Icons.verified, color: MPesaTheme.neonGreen),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Share this PIN with the client once you finish the work to release your payout.', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),

            // Requester deposit or release buttons
            if (amIRequester && status == 'accepted' && escrowStatus != 'HELD')
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MPesaTheme.neonGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.lock),
                    label: Text('Deposit & Lock Escrow (KSH ${price.toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      _payEscrow(gigDoc.id, price);
                    },
                  ),
                ),
              )
            else if (amIRequester && escrowStatus == 'HELD')
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MPesaTheme.neonGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Enter Worker PIN to Complete & Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      _showPinDialog(gigDoc.id);
                    },
                  ),
                ),
              ),
            
            // Chat Partner Info
            if (otherUserId != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: otherUserAvatar != null ? NetworkImage(otherUserAvatar) : null,
                      child: otherUserAvatar == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(amIRequester ? 'Provider' : 'Client', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(otherUserName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MPesaTheme.neonGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        final chatId = 'gig_${gigDoc.id}';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchChatView(
                              chatId: chatId,
                              myUid: user.uid,
                              matchName: otherUserName,
                              matchAvatar: otherUserAvatar,
                              matchId: otherUserId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Chat'),
                    )
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(child: Text('Waiting for a provider to accept this gig. We have notified online workers.', style: TextStyle(color: Colors.white70, fontSize: 13))),
                  ],
                ),
              ),
              
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showPinDialog(String requestId) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MPesaTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Release Escrow Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 4-digit PIN provided by the worker to confirm work completion and release payment.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 6),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '• • • •',
                hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 6),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MPesaTheme.neonGreen)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MPesaTheme.neonGreen, width: 2)),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _releaseEscrow(requestId, pinController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonGreen),
            child: const Text('Release Funds', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _releaseEscrow(String requestId, String pin) async {
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the 4-digit PIN.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v6/campus_gigs/release_escrow'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requester_id': user.uid,
          'request_id': requestId,
          'pin': pin
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funds released to worker successfully!'), backgroundColor: MPesaTheme.neonGreen),
        );
      } else {
        String errMsg = 'Release failed';
        try {
          final resData = json.decode(response.body);
          if (resData is Map && resData.containsKey('error')) {
            errMsg = resData['error'].toString();
          }
        } catch (_) {}
        throw Exception(errMsg);
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Release request timed out. Please check network connection.'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
