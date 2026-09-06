import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class GigBoardView extends StatefulWidget {
  final Map<String, dynamic> user;

  const GigBoardView({super.key, required this.user});

  @override
  State<GigBoardView> createState() => _GigBoardViewState();
}

class _GigBoardViewState extends State<GigBoardView> {
  final List<Map<String, dynamic>> _gigs = [
    {
      'id': 'g1',
      'title': 'Python Tutor Needed',
      'description': 'Need help preparing for my Data Structures midterm.',
      'price': 1000.0,
      'student': 'John M.',
    },
    {
      'id': 'g2',
      'title': 'Hair Braiding',
      'description': 'Looking for someone to do box braids this weekend.',
      'price': 2500.0,
      'student': 'Alice W.',
    }
  ];

  void _acceptGig(Map<String, dynamic> gig) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Accept Gig?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Contact ${gig['student']} to complete the gig. Once done, they will pay you KES ${gig['price']} instantly via DISHI.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent to client!')));
            },
            child: const Text('Message Client', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showPostGigDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Post a Gig', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Gig Title', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.white70)),
              maxLines: 3,
            ),
            TextField(
              controller: priceController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pay Amount (KES)', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              final priceAmount = double.tryParse(priceController.text) ?? 0.0;
              if (titleController.text.isNotEmpty && descController.text.isNotEmpty && priceAmount > 0) {
                setState(() {
                  _gigs.insert(0, {
                    'id': 'g${_gigs.length + 1}',
                    'title': titleController.text,
                    'description': descController.text,
                    'price': priceAmount,
                    'student': widget.user['displayName'] ?? 'Me',
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gig posted successfully!')));
              }
            },
            child: const Text('Post Gig', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Freelance Gig Board'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add, color: Colors.blueAccent),
            onPressed: _showPostGigDialog,
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _gigs.length,
        itemBuilder: (context, index) {
          final gig = _gigs[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.work, color: Colors.blueAccent, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gig['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(gig['description'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('By: ${gig['student']} • Pays: KES ${gig['price']}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _acceptGig(gig),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  tooltip: 'Accept Gig',
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
