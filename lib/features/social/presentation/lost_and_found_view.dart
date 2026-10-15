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
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: Text(bounty['type'] == 'Lost' ? 'Found this item?' : 'Is this yours?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bounty['type'] == 'Lost' 
                  ? 'Notify ${bounty['student']} that you have found their item. Once they verify, any bounty will be released directly to your DISHI Wallet via Escrow.'
                  : 'Notify ${bounty['student']} to claim your item. Please provide verification details below.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: bounty['type'] == 'Lost' ? 'Where is the item currently?' : 'Proof of ownership / details',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  hintText: 'e.g. Left at Library Security or meet at cafeteria',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                  filled: true,
                  fillColor: Colors.black26,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('DISHI Escrow Guaranteed. Safe campus returns.', style: TextStyle(color: Colors.orangeAccent, fontSize: 11))),
                  ],
                ),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              Navigator.pop(context);
              final note = noteController.text.trim();
              
              await FirebaseFirestore.instance.collection('lost_and_found').doc(doc.id).update({
                'status': 'Claim Pending',
                'claimedBy': currentUid,
                'claimerName': widget.user['displayName'] ?? 'A Student',
                'claimerPhone': widget.user['phoneNumber'] ?? '',
                'claimNote': note,
                'claimedAt': FieldValue.serverTimestamp(),
              });

              final ownerId = bounty['studentId'] as String?;
              if (ownerId != null && ownerId.isNotEmpty) {
                await FirebaseFirestore.instance.collection('notifications').add({
                  'targetUserId': ownerId,
                  'userId': ownerId,
                  'title': bounty['type'] == 'Lost' ? '🎉 Someone Found Your Item!' : '📦 Item Claim Submitted',
                  'body': '${widget.user['displayName'] ?? 'A student'} reported finding "${bounty['item']}". Open Lost & Found to verify and release bounty.',
                  'type': 'lost_and_found_claim',
                  'itemId': doc.id,
                  'createdAt': FieldValue.serverTimestamp(),
                  'readBy': [],
                });
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim submitted! The owner has been notified.')));
              }
            },
            child: Text(bounty['type'] == 'Lost' ? 'Submit Claim' : 'Claim Item', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _resolveBounty(DocumentSnapshot doc) async {
    final bounty = doc.data() as Map<String, dynamic>;
    final bountyAmount = double.tryParse('${bounty['bounty']}') ?? 0.0;
    final claimerUid = bounty['claimedBy'] as String?;
    final claimerName = bounty['claimerName'] as String? ?? 'Finder';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Verify & Release Escrow 🤝', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          bountyAmount > 0 
            ? 'Confirm you have received your item? KES $bountyAmount will be automatically credited from Escrow to $claimerName\'s DISHI Wallet.'
            : 'Confirm that this item has been returned and resolved?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              Navigator.pop(context);

              // 1. Mark item resolved
              await FirebaseFirestore.instance.collection('lost_and_found').doc(doc.id).update({
                'status': 'Resolved',
                'resolvedAt': FieldValue.serverTimestamp(),
              });

              // 2. Transfer bounty via Escrow if applicable
              if (bountyAmount > 0 && claimerUid != null && claimerUid.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance.collection('wallets').doc(claimerUid).set({
                    'balance': FieldValue.increment(bountyAmount),
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  await FirebaseFirestore.instance.collection('transactions').add({
                    'userId': claimerUid,
                    'amount': bountyAmount,
                    'type': 'bounty_reward',
                    'description': 'Bounty reward for returning "${bounty['item']}"',
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'completed',
                  });
                } catch (_) {}
              }

              // 3. Notify claimer
              if (claimerUid != null && claimerUid.isNotEmpty) {
                await FirebaseFirestore.instance.collection('notifications').add({
                  'targetUserId': claimerUid,
                  'userId': claimerUid,
                  'title': 'Bounty Rewarded! 💰',
                  'body': 'Your claim on "${bounty['item']}" was verified! ${bountyAmount > 0 ? "KES $bountyAmount has been credited to your DISHI Wallet." : "Thank you for being a campus Good Samaritan!"}',
                  'type': 'lost_and_found_reward',
                  'itemId': doc.id,
                  'createdAt': FieldValue.serverTimestamp(),
                  'readBy': [],
                });
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item marked as Resolved! Escrow released.')));
              }
            },
            child: const Text('Confirm & Release', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _rejectClaim(DocumentSnapshot doc) async {
    await FirebaseFirestore.instance.collection('lost_and_found').doc(doc.id).update({
      'status': 'Active',
      'claimedBy': FieldValue.delete(),
      'claimerName': FieldValue.delete(),
      'claimerPhone': FieldValue.delete(),
      'claimNote': FieldValue.delete(),
      'claimedAt': FieldValue.delete(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim dismissed. Item returned to active listings.')));
    }
  }

  void _deleteItem(DocumentSnapshot doc) async {
    await FirebaseFirestore.instance.collection('lost_and_found').doc(doc.id).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item removed.')));
    }
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
                    final double bountyAmount = double.tryParse('${bounty['bounty'] ?? 0}') ?? 0.0;
                    final String status = bounty['status'] as String? ?? 'Active';
                    final bool isPendingClaim = status == 'Claim Pending';
                    final bool isResolved = status == 'Resolved';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isResolved 
                              ? Colors.green.withOpacity(0.5)
                              : (isPendingClaim ? Colors.amber.withOpacity(0.6) : Colors.orangeAccent.withOpacity(0.3)),
                        ),
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
                              const SizedBox(width: 14),
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
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isResolved 
                                      ? Colors.green.withOpacity(0.2)
                                      : (isPendingClaim ? Colors.amber.withOpacity(0.2) : Colors.white12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isResolved 
                                        ? Colors.green 
                                        : (isPendingClaim ? Colors.amber : Colors.white24),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: isResolved ? Colors.greenAccent : (isPendingClaim ? Colors.amberAccent : Colors.white70),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(icon: const Icon(Icons.share, color: Colors.white54, size: 20), onPressed: () => _exportPoster(bounty))
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
                          
                          if (_viewMode == 'Lost' && bountyAmount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: MPesaTheme.primaryGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.attach_money, color: MPesaTheme.primaryGreen, size: 16),
                                  Text('Bounty Reward: KES ${bountyAmount.toStringAsFixed(0)}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Owner Claim Management Section
                          if (isMine) ...[
                            if (isPendingClaim) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.announcement, color: Colors.amberAccent, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Claim by: ${bounty['claimerName'] ?? 'A student'} (${bounty['claimerPhone'] ?? 'No phone'})',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (bounty['claimNote'] != null && (bounty['claimNote'] as String).isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Details: "${bounty['claimNote']}"', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                            onPressed: () => _rejectClaim(doc),
                                            child: const Text('Reject', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                                            onPressed: () => _resolveBounty(doc),
                                            child: Text(
                                              bountyAmount > 0 ? 'Release KES ${bountyAmount.toStringAsFixed(0)}' : 'Verify & Close',
                                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ] else if (isResolved) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Text('Item Resolved & Handed Over', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                                    TextButton(onPressed: () => _deleteItem(doc), child: const Text('Delete Post', style: TextStyle(color: Colors.white54, fontSize: 12))),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  const Text('Your listing is Active', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                  const Spacer(),
                                  TextButton(onPressed: () => _deleteItem(doc), child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 13))),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                    onPressed: () => _resolveBounty(doc),
                                    child: const Text('Mark Found', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ],

                          // Non-Owner View
                          if (!isMine) ...[
                            if (isPendingClaim) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.hourglass_top, color: Colors.amberAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        bounty['claimedBy'] == currentUid
                                            ? 'Your claim is currently pending owner verification.'
                                            : 'A claim has been filed for this item. Under review.',
                                        style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isResolved) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.done_all, color: Colors.greenAccent, size: 16),
                                    SizedBox(width: 8),
                                    Text('This item has been safely returned.', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ] else ...[
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
                              ),
                            ],
                          ],
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
