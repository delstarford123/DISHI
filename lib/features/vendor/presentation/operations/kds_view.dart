import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class KdsView extends StatefulWidget {
  const KdsView({super.key});

  @override
  State<KdsView> createState() => _KdsViewState();
}

class _KdsViewState extends State<KdsView> {
  final List<Map<String, dynamic>> _tickets = [
    {
      'id': 'T-8812',
      'student': 'John Doe',
      'items': ['1x Beef Pilau', '1x Soda (Fanta)'],
      'time': '2 mins ago',
      'status': 'New',
    },
    {
      'id': 'T-8813',
      'student': 'Jane Doe',
      'items': ['2x Chapati', '1x Ndengu'],
      'time': '5 mins ago',
      'status': 'Cooking',
    },
  ];

  void _markAsReady(int index) {
    setState(() {
      _tickets.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as Ready. Notification sent!'), backgroundColor: _neonOrange));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('KDS - Kitchen Display', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _tickets.isEmpty
          ? const Center(child: Text('No active preorders in the queue.', style: TextStyle(color: _textSecondary)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Assuming tablet view for KDS
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: _tickets.length,
              itemBuilder: (context, index) {
                final ticket = _tickets[index];
                return Container(
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ticket['status'] == 'New' ? Colors.redAccent : _neonOrange, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: (ticket['status'] == 'New' ? Colors.redAccent : _neonOrange).withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ]
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('#${ticket['id']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                              child: Text(ticket['time'], style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Student: ${ticket['student']}', style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Divider(color: _surfaceLight),
                        Expanded(
                          child: ListView.builder(
                            itemCount: (ticket['items'] as List).length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('• ${ticket['items'][i]}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _markAsReady(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _neonOrange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Mark Ready & Notify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
