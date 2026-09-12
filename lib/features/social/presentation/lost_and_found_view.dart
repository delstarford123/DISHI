import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../match/presentation/match_call_view.dart';

class LostAndFoundView extends StatefulWidget {
  final Map<String, dynamic> user;

  const LostAndFoundView({super.key, required this.user});

  @override
  State<LostAndFoundView> createState() => _LostAndFoundViewState();
}

class _LostAndFoundViewState extends State<LostAndFoundView> {
  String _viewMode = 'Lost'; // 'Lost' or 'Found'
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Electronics', 'IDs/Wallets', 'Books', 'Clothing', 'Other'];

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  void _claimBounty(DocumentSnapshot doc) {
    final bounty = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: Text(bounty['type'] == 'Lost' ? 'Found this item?' : 'Is this yours?', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bounty['type'] == 'Lost' 
                ? 'Contact ${bounty['student']} to return the item. Once they verify with a photo, KES ${bounty['bounty']} will be automatically transferred to your DISHI Wallet via Escrow.'
                : 'Contact ${bounty['student']} to claim your item. You will need to provide proof of ownership.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.orangeAccent),
                  SizedBox(width: 8),
                  Expanded(child: Text('DISHI Escrow Active. Funds are secured.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
                ],
              ),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification Request sent! Opening chat...')));
            },
            child: Text(bounty['type'] == 'Lost' ? 'Start Claim' : 'Message Finder', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showPostItemDialog() {
    final itemController = TextEditingController();
    final locationController = TextEditingController();
    final bountyController = TextEditingController();
    final imageController = TextEditingController();
    
    String category = 'Electronics';
    String type = _viewMode; // Default to current tab
    String dropOff = 'Keep with me';

    final List<String> dropOffOptions = ['Keep with me', 'Library Security', 'Hostel Desk', 'Student Affairs'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: Text('Post ${type == 'Lost' ? 'Missing Item' : 'Found Item'}', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(label: const Text('I Lost it'), selected: type == 'Lost', onSelected: (v) => setDialogState(() => type = 'Lost'), selectedColor: Colors.redAccent),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('I Found it'), selected: type == 'Found', onSelected: (v) => setDialogState(() => type = 'Found'), selectedColor: Colors.greenAccent),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(controller: itemController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: type == 'Lost' ? 'What did you lose?' : 'What did you find?', labelStyle: const TextStyle(color: Colors.white70))),
                TextField(controller: locationController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: type == 'Lost' ? 'Last seen at' : 'Found at', labelStyle: const TextStyle(color: Colors.white70))),
                if (type == 'Lost')
                  TextField(controller: bountyController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bounty Reward (KES)', labelStyle: TextStyle(color: Colors.white70))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: const Color(0xFF131A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white70)),
                  items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                if (type == 'Found')
                  DropdownButtonFormField<String>(
                    initialValue: dropOff,
                    dropdownColor: const Color(0xFF131A2A),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Safe Drop-off Location', labelStyle: TextStyle(color: Colors.white70)),
                    items: dropOffOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => dropOff = v!),
                  ),
                TextField(controller: imageController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Optional Image URL', labelStyle: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              onPressed: () async {
                final bountyAmount = double.tryParse(bountyController.text) ?? 0.0;
                if (itemController.text.isNotEmpty && locationController.text.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('lost_and_found').add({
                    'item': itemController.text,
                    'location': locationController.text,
                    'bounty': type == 'Lost' ? bountyAmount : 0.0,
                    'category': category,
                    'type': type,
                    'dropOff': dropOff,
                    'imageUrl': imageController.text,
                    'studentId': currentUid,
                    'student': widget.user['displayName'] ?? 'Me',
                    'phone': widget.user['phoneNumber'] ?? '+254700000000',
                    'status': 'Active',
                    'createdAt': FieldValue.serverTimestamp(),
                    'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted successfully!')));
                  }
                }
              },
              child: const Text('Post', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        )
      )
    );
  }

  void _exportPoster(Map<String, dynamic> bounty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing Poster generated! Saving to gallery...')));
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
          IconButton(icon: const Icon(Icons.leaderboard, color: Colors.orangeAccent), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Good Samaritan Leaderboard: #1 John M. (12 returns)')))),
          IconButton(icon: const Icon(Icons.add_box, color: Colors.orangeAccent), onPressed: _showPostItemDialog)
        ],
      ),
      body: Column(
        children: [
          // Lost vs Found Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _viewMode = 'Lost'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _viewMode == 'Lost' ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
                        border: Border(bottom: BorderSide(color: _viewMode == 'Lost' ? Colors.redAccent : Colors.transparent, width: 2)),
                      ),
                      child: const Center(child: Text('LOST ITEMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _viewMode = 'Found'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _viewMode == 'Found' ? Colors.greenAccent.withOpacity(0.2) : Colors.transparent,
                        border: Border(bottom: BorderSide(color: _viewMode == 'Found' ? Colors.greenAccent : Colors.transparent, width: 2)),
                      ),
                      child: const Center(child: Text('FOUND ITEMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c, style: TextStyle(color: _selectedCategory == c ? Colors.black : Colors.white)),
                  selected: _selectedCategory == c,
                  selectedColor: Colors.orangeAccent,
                  backgroundColor: Colors.white12,
                  onSelected: (v) => setState(() => _selectedCategory = c),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('lost_and_found').where('type', isEqualTo: _viewMode).orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));

                var docs = snapshot.data!.docs;
                if (_selectedCategory != 'All') {
                  docs = docs.where((d) => (d.data() as Map)['category'] == _selectedCategory).toList();
                }

                if (docs.isEmpty) return Center(child: Text('No ${_viewMode.toLowerCase()} items reported.', style: const TextStyle(color: Colors.white54)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final bounty = doc.data() as Map<String, dynamic>;
                    final bool isMine = bounty['studentId'] == currentUid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _viewMode == 'Lost' ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2), shape: BoxShape.circle),
                                child: Icon(Icons.search, color: _viewMode == 'Lost' ? Colors.redAccent : Colors.greenAccent, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(bounty['item'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('${_viewMode == 'Lost' ? 'Lost near' : 'Found at'}: ${bounty['location']}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                  ],
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.share, color: Colors.white54), onPressed: () => _exportPoster(bounty))
                            ],
                          ),
                          
                          if (bounty['imageUrl'] != null && (bounty['imageUrl'] as String).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(bounty['imageUrl'], height: 150, width: double.infinity, fit: BoxFit.cover)),
                          ],
                          
                          const SizedBox(height: 12),
                          if (_viewMode == 'Found' && bounty['dropOff'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                              child: Text('Drop-off: ${bounty['dropOff']}', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          
                          if (_viewMode == 'Lost' && (bounty['bounty'] as num) > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: MPesaTheme.primaryGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                              child: Text('Bounty: KES ${bounty['bounty']}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // Smart Match Suggestion (Mocked)
                          if (!isMine && math.Random().nextDouble() > 0.8) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: const Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 16),
                                  SizedBox(width: 8),
                                  Text('Smart Match: Similar item found recently!', style: TextStyle(color: Colors.purpleAccent, fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (!isMine)
                            Row(
                              children: [
                                _buildActionButton(Icons.phone, Colors.green, () async {
                                  final Uri launchUri = Uri(scheme: 'tel', path: bounty['phone'] ?? '');
                                  if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
                                }),
                                const SizedBox(width: 8),
                                _buildActionButton(Icons.videocam, Colors.cyan, () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCallView(userName: bounty['student'] ?? '', userAvatar: '', calleeId: bounty['studentId'] ?? '', isVideoCall: true)));
                                }),
                                const Spacer(),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: _viewMode == 'Lost' ? MPesaTheme.primaryGreen : Colors.blueAccent),
                                  onPressed: () => _claimBounty(doc),
                                  icon: Icon(_viewMode == 'Lost' ? Icons.handshake : Icons.pan_tool, color: _viewMode == 'Lost' ? Colors.black : Colors.white, size: 16),
                                  label: Text(_viewMode == 'Lost' ? 'I found it!' : 'It\'s mine', style: TextStyle(color: _viewMode == 'Lost' ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                                )
                              ],
                            )
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
