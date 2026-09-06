import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../student/presentation/dynamic_qr_dialog.dart';

class EventTicketsView extends StatefulWidget {
  final Map<String, dynamic> user;

  const EventTicketsView({super.key, required this.user});

  @override
  State<EventTicketsView> createState() => _EventTicketsViewState();
}

class _EventTicketsViewState extends State<EventTicketsView> {
  final List<Map<String, dynamic>> _events = [
    {
      'id': 'e1',
      'title': 'Freshers Neon Party',
      'date': 'Oct 15, 2026',
      'time': '9:00 PM',
      'location': 'Student Center Main Hall',
      'price': 500.0,
      'isPurchased': false
    },
    {
      'id': 'e2',
      'title': 'Varsity Football Derby',
      'date': 'Oct 18, 2026',
      'time': '3:00 PM',
      'location': 'Main Stadium',
      'price': 200.0,
      'isPurchased': true
    }
  ];

  void _buyTicket(Map<String, dynamic> event, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: Text('Buy Ticket for ${event['title']}?'),
        content: Text('This will deduct KES ${event['price']} from your DISHI Wallet.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _events[index]['isPurchased'] = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket purchased successfully!')));
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
        dishiId: widget.user['dishiId'] ?? 'STU-12345',
        purpose: 'event_ticket_${event['id']}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Campus Events & Tickets'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          final isPurchased = event['isPurchased'] as bool;
          
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
                Container(
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A2235),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                  ),
                  child: Center(child: Icon(Icons.confirmation_num, color: isPurchased ? MPesaTheme.primaryGreen : Colors.white54, size: 48)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
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
                          Text(event['location'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('KES ${event['price']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          isPurchased
                            ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                                onPressed: () => _showTicketQR(event),
                                icon: const Icon(Icons.qr_code, color: Colors.black),
                                label: const Text('Show Entry QR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: MPesaTheme.primaryGreen)),
                                onPressed: () => _buyTicket(event, index),
                                child: const Text('Buy Ticket', style: TextStyle(color: MPesaTheme.primaryGreen)),
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
      ),
    );
  }
}
