import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../student/presentation/dynamic_qr_dialog.dart';
import 'create_event_view.dart';
import 'event_dashboard_view.dart';

class EventTicketsView extends StatefulWidget {
  final Map<String, dynamic> user;

  const EventTicketsView({super.key, required this.user});

  @override
  State<EventTicketsView> createState() => _EventTicketsViewState();
}

class _EventTicketsViewState extends State<EventTicketsView> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Party', 'Sports', 'Academic', 'Arts', 'Tech', 'Other'];

  void _buyTicket(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: Text('Buy Ticket for ${event['title']}?'),
        content: Text('This will deduct KES ${event['price']} from your DISHI Wallet.\n\n(A 5 KES system fee applies)', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              Navigator.pop(context);
              
              // In a real flow, this triggers STK push via backend. 
              // We'll simulate success here and update Firestore.
              final eventRef = FirebaseFirestore.instance.collection('events').doc(event['id']);
              await eventRef.update({
                'ticketsSold': FieldValue.increment(1),
                'revenue': FieldValue.increment(event['price']),
              });
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket purchased successfully! Check your QR.')));
              }
            },
            child: const Text('Pay with DISHI', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showTicketQR(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (_) => DynamicQrDialog(
        dishiId: widget.user['dishiId'] ?? widget.user['uid'] ?? 'STU-12345',
        purpose: 'event_ticket_${event['id']}',
      ),
    );
  }

  void _setReminder(Map<String, dynamic> event) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder set for ${event['title']}!')));
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
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => EventDashboardView(user: widget.user))
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: MPesaTheme.neonCyan),
            tooltip: 'Create New Event',
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => CreateEventView(user: widget.user))
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('events').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }

          var docs = snapshot.data?.docs ?? [];
          if (_selectedCategory != 'All') {
            docs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == _selectedCategory).toList();
          }

          if (docs.isEmpty) {
            return const Center(child: Text('No events found.', style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final event = docs[index].data() as Map<String, dynamic>;
              // Dummy check for purchase since we don't have personal ticket storage subcollection setup yet.
              final isPurchased = false; 
              
              final capacity = event['capacity'] ?? 0;
              final ticketsSold = event['ticketsSold'] ?? 0;
              final isSoldOut = capacity > 0 && ticketsSold >= capacity;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isPurchased ? MPesaTheme.primaryGreen.withOpacity(0.5) : Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        event['imageUrl'] != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                              child: Image.network(
                                event['imageUrl'],
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              height: 100,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A2235),
                                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                              ),
                              child: Center(child: Icon(Icons.confirmation_num, color: isPurchased ? MPesaTheme.primaryGreen : Colors.white54, size: 48)),
                            ),
                        if (event['category'] != null)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                              child: Text(event['category'], style: const TextStyle(color: MPesaTheme.neonCyan, fontSize: 12)),
                            ),
                          ),
                        if (isSoldOut)
                          Positioned(
                            top: 12,
                            right: 12,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(event['title'] ?? 'Event', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.notification_add, color: Colors.white54),
                                onPressed: () => _setReminder(event),
                                tooltip: 'Remind Me',
                              )
                            ],
                          ),
                          if (event['creatorName'] != null)
                            Text('by ${event['creatorName']}', style: const TextStyle(color: MPesaTheme.neonCyan, fontSize: 12)),
                          
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white54, size: 14),
                              const SizedBox(width: 4),
                              Text('${event['date']} • ${event['time']}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.white54, size: 14),
                              const SizedBox(width: 4),
                              Text(event['location'] ?? 'TBA', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                          
                          if (event['description'] != null && event['description'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              event['description'], 
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 13)
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('KES ${event['price']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  if (event['earlyBirdPrice'] != null)
                                    Text('Early Bird: KES ${event['earlyBirdPrice']}', style: const TextStyle(color: MPesaTheme.neonCyan, fontSize: 12)),
                                ],
                              ),
                              isPurchased
                                ? ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                                    onPressed: () => _showTicketQR(event),
                                    icon: const Icon(Icons.qr_code, color: Colors.black),
                                    label: const Text('Show Entry QR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  )
                                : OutlinedButton(
                                    style: OutlinedButton.styleFrom(side: BorderSide(color: isSoldOut ? Colors.grey : MPesaTheme.primaryGreen)),
                                    onPressed: isSoldOut ? null : () => _buyTicket(event),
                                    child: Text(isSoldOut ? 'Sold Out' : 'Buy Ticket', style: TextStyle(color: isSoldOut ? Colors.grey : MPesaTheme.primaryGreen)),
                                  )
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
