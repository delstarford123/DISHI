import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/location_service.dart';
import '../../match/presentation/match_chat_view.dart';
import 'dart:convert';
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
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v6/campus_gigs/register'),
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
        throw Exception(json.decode(response.body)['error'] ?? 'Unknown error');
      }
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
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v6/campus_gigs/request'),
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
        throw Exception(json.decode(response.body)['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e'), backgroundColor: Colors.red),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // Filter out completed gigs so they don't clutter the active list
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'completed';
        }).toList();
        
        if (docs.isEmpty) return const Center(child: Text("No active gigs right now.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            final escrowStatus = data['escrow_status'] ?? '';
            final price = data['price_offer'] ?? 0;
            final category = data['category'] ?? '';
            
              return Card(
                color: MPesaTheme.surfaceColor,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text('$category Gig', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Status: $status | Escrow: $escrowStatus\nPrice: KSH $price', style: const TextStyle(color: Colors.grey)),
                  onTap: () => _showGigDetails(docs[index]),
                  trailing: (escrowStatus == 'HELD' && data['requester_id'] == user.uid)
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonGreen),
                        onPressed: () => _showPinDialog(docs[index].id),
                        child: const Text('Complete', style: TextStyle(color: Colors.black)),
                      )
                    : null,
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
            Text('${data['category']} Gig Details', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Text('Status: ${data['status']}', style: const TextStyle(color: Colors.grey)),
            Text('Price Offer: KSH ${data['price_offer']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Details: ${data['details'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            
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
                        Navigator.pop(context); // Close bottom sheet
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
              
            const SizedBox(height: 32),
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
        title: const Text('Complete Gig', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: pinController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter 4-digit Worker PIN',
            hintStyle: TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.black26,
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _releaseEscrow(requestId, pinController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonGreen),
            child: const Text('Release Funds', style: TextStyle(color: Colors.black)),
          )
        ],
      ),
    );
  }

  Future<void> _releaseEscrow(String requestId, String pin) async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v6/campus_gigs/release_escrow'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requester_id': user.uid,
          'request_id': requestId,
          'pin': pin
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funds released!'), backgroundColor: MPesaTheme.neonGreen));
      } else {
        throw Exception(json.decode(response.body)['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
