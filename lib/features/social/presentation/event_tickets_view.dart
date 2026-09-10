import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../student/presentation/dynamic_qr_dialog.dart';
import 'create_event_view.dart';
import 'event_dashboard_view.dart';
import 'package:flutter/services.dart';
import '../../match/presentation/match_chat_view.dart';
import '../../community/presentation/ar_campus_map_view.dart';

class EventTicketsView extends StatefulWidget {
  final Map<String, dynamic> user;

  const EventTicketsView({super.key, required this.user});

  @override
  State<EventTicketsView> createState() => _EventTicketsViewState();
}

class _EventTicketsViewState extends State<EventTicketsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Party', 'Sports', 'Academic', 'Arts', 'Tech', 'Other'];
  
  String get currentUid => widget.user['uid'] ?? 'guest';

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

  void _buyTicket(Map<String, dynamic> event, String tier, int price) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: Text('Buy $tier Ticket?'),
        content: Text('This will deduct KES $price from your DISHI Wallet.\n\n(A 5 KES system fee applies. Event Organizer receives KES ${price - 5})', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              Navigator.pop(context);
              
              // Add to My Tickets
              await FirebaseFirestore.instance.collection('users').doc(currentUid).collection('my_tickets').add({
                'eventId': event['id'],
                'eventTitle': event['title'],
                'tier': tier,
                'price': price,
                'purchaseDate': FieldValue.serverTimestamp(),
                'used': false,
              });

              // Update Event Stats
              final eventRef = FirebaseFirestore.instance.collection('events').doc(event['id']);
              
              String tierSoldField = 'regularSold';
              if (tier == 'VIP') tierSoldField = 'vipSold';
              if (tier == 'Early Bird') tierSoldField = 'earlyBirdSold';

              await eventRef.update({
                'ticketsSold': FieldValue.increment(1),
                tierSoldField: FieldValue.increment(1),
                'revenue': FieldValue.increment(price),
                'attendees': FieldValue.arrayUnion([currentUid]),
              });
              
              // Add to Mega Chat
              final chatId = 'event_${event['id']}';
              await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
                'participants': FieldValue.arrayUnion([currentUid]),
                'isGroup': true,
                'groupName': '${event['title']} Hype Chat 🎉',
              }, SetOptions(merge: true));
              
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket purchased successfully! Check your Wallet tab.')));
            },
            child: const Text('Pay with DISHI', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showTicketQR(String ticketId) {
    showDialog(
      context: context,
      builder: (_) => DynamicQrDialog(
        dishiId: widget.user['dishiId'] ?? currentUid,
        purpose: 'ticket_scan_$ticketId',
      ),
    );
  }

  void _bookmarkEvent(Map<String, dynamic> event) async {
    await FirebaseFirestore.instance.collection('users').doc(currentUid).collection('saved_events').doc(event['id']).set({
      'eventId': event['id'],
      'savedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${event['title']} saved!')));
  }

  void _joinWaitlist(Map<String, dynamic> event) async {
    await FirebaseFirestore.instance.collection('events').doc(event['id']).collection('waitlist').doc(currentUid).set({
      'userId': currentUid,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined waitlist! We will notify you if tickets open up.')));
  }

  void _rateEvent(String eventId) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF131A2A),
      title: const Text('Rate Event', style: TextStyle(color: Colors.white)),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) => IconButton(icon: const Icon(Icons.star_border, color: Colors.orange), onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for rating!')));
        })),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Campus Events & Tickets'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard, color: MPesaTheme.neonCyan),
            tooltip: 'My Events Dashboard',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDashboardView(user: widget.user))),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: MPesaTheme.neonCyan),
            tooltip: 'Create New Event',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateEventView(user: widget.user))),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MPesaTheme.neonCyan,
          labelColor: MPesaTheme.neonCyan,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'My Wallet'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          _buildWalletTab(),
          _buildSavedTab(),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: MPesaTheme.neonCyan,
                  labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
                  backgroundColor: const Color(0xFF131A2A),
                  onSelected: (val) => setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('events').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan));
              
              var docs = snapshot.data?.docs ?? [];
              if (_selectedCategory != 'All') {
                docs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == _selectedCategory).toList();
              }
              if (docs.isEmpty) return const Center(child: Text('No events found.', style: TextStyle(color: Colors.white54)));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  data['id'] = docs[index].id;
                  return _buildEventCard(data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final capacity = event['capacity'] ?? 0;
    final ticketsSold = event['ticketsSold'] ?? 0;
    final isSoldOut = capacity > 0 && ticketsSold >= capacity;
    final progress = capacity > 0 ? ticketsSold / capacity : 0.0;
    
    final attendees = (event['attendees'] as List?)?.length ?? ticketsSold;
    final isVerified = event['verifiedOrganizer'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: const Color(0xFF131A2A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              event['imageUrl'] != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    child: Image.network(event['imageUrl'], height: 160, width: double.infinity, fit: BoxFit.cover),
                  )
                : Container(
                    height: 120,
                    decoration: const BoxDecoration(color: Color(0xFF1A2235), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
                    child: const Center(child: Icon(Icons.event, color: Colors.white54, size: 48)),
                  ),
              if (event['category'] != null)
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                    child: Text(event['category'], style: const TextStyle(color: MPesaTheme.neonCyan, fontSize: 12)),
                  ),
                ),
              if (isSoldOut)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                    child: const Text('SOLD OUT', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(event['title'] ?? 'Event', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.bookmark_border, color: Colors.white54), onPressed: () => _bookmarkEvent(event), tooltip: 'Save'),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white54),
                      onPressed: () {
                        final link = 'https://dishi.delstarfordworks.co.ke/event?id=${event['id']}';
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Web Ticket Link copied!')));
                      },
                      tooltip: 'Share',
                    ),
                  ],
                ),
                if (event['creatorName'] != null)
                  Row(
                    children: [
                      Text('by ${event['creatorName']}', style: const TextStyle(color: MPesaTheme.neonCyan, fontSize: 12)),
                      if (isVerified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: Colors.blue, size: 14)),
                    ],
                  ),
                const SizedBox(height: 12),
                
                // Location & Calendar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(event['location'] ?? 'TBA', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArCampusMapView())),
                          child: const Text('View Map', style: TextStyle(color: MPesaTheme.neonCyan, fontSize: 12, decoration: TextDecoration.underline)),
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        const Text('Add to Cal', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 12),
                
                // Hype Indicator & Progress Bar
                if (capacity > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🔥 $attendees going', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('${(progress * 100).toInt()}% Sold', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: progress, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(progress > 0.8 ? Colors.redAccent : MPesaTheme.primaryGreen)),
                  const SizedBox(height: 16),
                ],
                
                // Ticket Tiers
                const Text('Tickets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (event['earlyBirdPrice'] != null)
                      _buildTicketTier(event, 'Early Bird', event['earlyBirdPrice'] ?? 0, (event['earlyBirdSold'] ?? 0) >= (event['earlyBirdCapacity'] ?? 9999)),
                    if (event['earlyBirdPrice'] != null)
                      const SizedBox(width: 8),
                    _buildTicketTier(event, 'Regular', event['price'] ?? 0, (event['regularSold'] ?? 0) >= (event['regularCapacity'] ?? (event['capacity'] ?? 9999))),
                    if (event['vipPrice'] != null)
                      const SizedBox(width: 8),
                    if (event['vipPrice'] != null)
                      _buildTicketTier(event, 'VIP', event['vipPrice'] ?? 0, (event['vipSold'] ?? 0) >= (event['vipCapacity'] ?? 9999)),
                  ],
                ),
                
                if (isSoldOut) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                      onPressed: () => _joinWaitlist(event),
                      child: const Text('Join Waitlist', style: TextStyle(color: Colors.orange)),
                    ),
                  )
                ],
                
                const SizedBox(height: 16),
                // Post-Event Gallery preview (mock)
                if (event['hasGallery'] == true)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: MPesaTheme.neonCyan)),
                    onPressed: () {},
                    icon: const Icon(Icons.photo_library, color: MPesaTheme.neonCyan),
                    label: const Text('View Event Gallery', style: TextStyle(color: MPesaTheme.neonCyan)),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildTicketTier(Map<String, dynamic> event, String tier, dynamic priceValue, bool isSoldOut) {
    int price = 0;
    if (priceValue is num) {
      price = priceValue.toInt();
    } else if (priceValue is String) {
      price = int.tryParse(priceValue) ?? 0;
    }
    
    return Expanded(
      child: GestureDetector(
        onTap: isSoldOut ? null : () => _buyTicket(event, tier, price),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSoldOut ? Colors.grey.withOpacity(0.1) : MPesaTheme.primaryGreen.withOpacity(0.1),
            border: Border.all(color: isSoldOut ? Colors.grey : MPesaTheme.primaryGreen),
            borderRadius: BorderRadius.circular(8)
          ),
          child: Column(
            children: [
              Text(tier, style: TextStyle(color: isSoldOut ? Colors.grey : MPesaTheme.primaryGreen, fontSize: 12)),
              Text('KES $price', style: TextStyle(color: isSoldOut ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              if (isSoldOut)
                const Text('Sold Out', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUid).collection('my_tickets').orderBy('purchaseDate', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No tickets in your wallet yet.', style: TextStyle(color: Colors.white54)));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final ticket = snapshot.data!.docs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF131A2A), Color(0xFF1E293B)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MPesaTheme.neonCyan.withOpacity(0.5))
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_num, color: MPesaTheme.neonCyan, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket['eventTitle'] ?? 'Event Ticket', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${ticket['tier']} Tier', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonCyan),
                        onPressed: () => _showTicketQR(ticket.id),
                        child: const Text('Show QR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.blueAccent),
                            tooltip: 'Live Event Chat',
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
                              chatId: 'event_${ticket['eventId']}',
                              myUid: currentUid,
                              matchName: '${ticket['eventTitle']} Hype Chat',
                              matchAvatar: '',
                              matchId: 'group',
                            ))),
                          ),
                          IconButton(
                            icon: const Icon(Icons.rate_review, color: Colors.orange),
                            tooltip: 'Rate Event',
                            onPressed: () => _rateEvent(ticket['eventId']),
                          ),
                        ],
                      )
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildSavedTab() {
    return const Center(child: Text('Saved Events will appear here.', style: TextStyle(color: Colors.white54)));
  }
}
