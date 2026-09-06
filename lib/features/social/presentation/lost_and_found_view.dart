import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../match/presentation/match_call_view.dart';

class LostAndFoundView extends StatefulWidget {
  final Map<String, dynamic> user;

  const LostAndFoundView({super.key, required this.user});

  @override
  State<LostAndFoundView> createState() => _LostAndFoundViewState();
}

class _LostAndFoundViewState extends State<LostAndFoundView> {
  final List<Map<String, dynamic>> _bounties = [
    {
      'id': 'l1',
      'item': 'AirPods Pro (White Case)',
      'bounty': 500.0,
      'location': 'Library 2nd Floor',
      'student': 'David N.',
      'phone': '+254712345678',
      'status': 'Active'
    },
    {
      'id': 'l2',
      'item': 'Calculus Textbook',
      'bounty': 200.0,
      'location': 'Cafeteria Table 4',
      'student': 'Sarah K.',
      'phone': '+254798765432',
      'status': 'Active'
    }
  ];

  void _claimBounty(Map<String, dynamic> bounty) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Found this item?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Contact ${bounty['student']} to return the item. Once they confirm receipt, KES ${bounty['bounty']} will be automatically transferred to your DISHI Wallet.',
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent to owner!')));
            },
            child: const Text('Message Owner', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showPostItemDialog() {
    final itemController = TextEditingController();
    final locationController = TextEditingController();
    final bountyController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Post Lost Item', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Item Name', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: locationController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Location Lost', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: bountyController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bounty Amount (KES)', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () {
              final bountyAmount = double.tryParse(bountyController.text) ?? 0.0;
              if (itemController.text.isNotEmpty && locationController.text.isNotEmpty && bountyAmount > 0) {
                setState(() {
                  _bounties.insert(0, {
                    'id': 'l${_bounties.length + 1}',
                    'item': itemController.text,
                    'bounty': bountyAmount,
                    'location': locationController.text,
                    'student': widget.user['displayName'] ?? 'Me',
                    'status': 'Active'
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lost Item posted successfully!')));
              }
            },
            child: const Text('Post Bounty', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
        title: const Text('Lost & Found Bounties'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box, color: Colors.orangeAccent),
            onPressed: _showPostItemDialog,
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bounties.length,
        itemBuilder: (context, index) {
          final bounty = _bounties[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(color: Colors.orangeAccent.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search, color: Colors.orangeAccent, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bounty['item'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Lost near: ${bounty['location']}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Contact: ${bounty['phone'] ?? 'N/A'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MPesaTheme.primaryGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Bounty: KES ${bounty['bounty']}',
                          style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildActionButton(Icons.phone, Colors.green, () async {
                            final Uri launchUri = Uri(scheme: 'tel', path: bounty['phone']);
                            if (await canLaunchUrl(launchUri)) {
                              await launchUrl(launchUri);
                            }
                          }),
                          const SizedBox(width: 8),
                          _buildActionButton(Icons.message, Colors.blue, () {
                            // Navigate to Chat View
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening chat with ${bounty['student']}...')));
                          }),
                          const SizedBox(width: 8),
                          _buildActionButton(Icons.videocam, Colors.cyan, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCallView(
                              userName: bounty['student'],
                              userAvatar: '',
                              calleeId: bounty['userId'] ?? bounty['id'] ?? '',
                              isVideoCall: true,
                            )));
                          }),
                        ],
                      )
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _claimBounty(bounty),
                  icon: const Icon(Icons.handshake, color: Colors.white),
                  tooltip: 'I found it!',
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
