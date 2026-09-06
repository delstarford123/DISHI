import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../match/presentation/match_chat_view.dart'; // Assume we can reuse the generic chat view

class GigBoardView extends StatefulWidget {
  final Map<String, dynamic> user;

  const GigBoardView({super.key, required this.user});

  @override
  State<GigBoardView> createState() => _GigBoardViewState();
}

class _GigBoardViewState extends State<GigBoardView> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Tutoring', 'Tech/Design', 'Errands', 'Beauty', 'Events'];

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  void _showPostGigDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final skillsController = TextEditingController();
    final portfolioController = TextEditingController();
    
    String category = 'Tutoring';
    bool isFixed = true;
    bool isRemote = true;
    bool isUrgent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: const Text('Post a Gig', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Gig Title', labelStyle: TextStyle(color: Colors.white70))),
                TextField(controller: descController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.white70)), maxLines: 3),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: priceController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (KES)', labelStyle: TextStyle(color: Colors.white70)))),
                    const SizedBox(width: 8),
                    DropdownButton<bool>(
                      value: isFixed,
                      dropdownColor: const Color(0xFF131A2A),
                      style: const TextStyle(color: Colors.white),
                      items: const [DropdownMenuItem(value: true, child: Text('Fixed')), DropdownMenuItem(value: false, child: Text('/ hr'))],
                      onChanged: (v) => setDialogState(() => isFixed = v!),
                    )
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: const Color(0xFF131A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white70)),
                  items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                TextField(controller: skillsController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Required Skills (comma separated)', labelStyle: TextStyle(color: Colors.white70))),
                TextField(controller: portfolioController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Optional: Reference Link', labelStyle: TextStyle(color: Colors.white70))),
                const SizedBox(height: 12),
                SwitchListTile(title: const Text('Remote Work?', style: TextStyle(color: Colors.white)), activeColor: Colors.blueAccent, value: isRemote, onChanged: (v) => setDialogState(() => isRemote = v)),
                SwitchListTile(title: const Text('Urgent (24h)?', style: TextStyle(color: Colors.redAccent)), activeColor: Colors.redAccent, value: isUrgent, onChanged: (v) => setDialogState(() => isUrgent = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                final priceAmount = double.tryParse(priceController.text) ?? 0.0;
                if (titleController.text.isNotEmpty && descController.text.isNotEmpty && priceAmount > 0) {
                  await FirebaseFirestore.instance.collection('gig_board').add({
                    'title': titleController.text,
                    'description': descController.text,
                    'price': priceAmount,
                    'isFixed': isFixed,
                    'category': category,
                    'skills': skillsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                    'referenceLink': portfolioController.text,
                    'isRemote': isRemote,
                    'isUrgent': isUrgent,
                    'studentId': currentUid,
                    'studentName': widget.user['displayName'] ?? 'A Student',
                    'status': 'Open', // Open, InProgress, Completed
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gig posted successfully!')));
                  }
                }
              },
              child: const Text('Post Gig', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        )
      )
    );
  }

  void _applyToGig(DocumentSnapshot doc) {
    final gig = doc.data() as Map<String, dynamic>;
    final coverLetterController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: Text('Apply: ${gig['title']}', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: coverLetterController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Cover Message (Why hire you?)', labelStyle: TextStyle(color: Colors.white70)),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              if (coverLetterController.text.isNotEmpty) {
                // Send application
                final chatId = 'gig_${doc.id}_${currentUid}';
                await FirebaseFirestore.instance.collection('gig_applications').add({
                  'gigId': doc.id,
                  'applicantId': currentUid,
                  'coverLetter': coverLetterController.text,
                  'chatId': chatId,
                  'timestamp': FieldValue.serverTimestamp()
                });
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MatchChatView(
                    chatId: chatId,
                    myUid: currentUid,
                    matchName: gig['studentName'],
                    matchAvatar: '',
                  )));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent! Chat opened.')));
                }
              }
            },
            child: const Text('Send Application', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _leaveReview(DocumentSnapshot doc) {
    int rating = 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: const Text('Rate Gig', style: TextStyle(color: Colors.white)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => IconButton(
              icon: Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
              onPressed: () => setDialogState(() => rating = index + 1),
            )),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await doc.reference.update({'status': 'Completed', 'rating': rating});
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('Submit Review', style: TextStyle(color: Colors.black)),
            )
          ],
        )
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
          IconButton(icon: const Icon(Icons.post_add, color: Colors.blueAccent), onPressed: _showPostGigDialog)
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c, style: TextStyle(color: _selectedCategory == c ? Colors.black : Colors.white)),
                  selected: _selectedCategory == c,
                  selectedColor: Colors.blueAccent,
                  backgroundColor: Colors.white12,
                  onSelected: (v) => setState(() => _selectedCategory = c),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('gig_board').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                
                var docs = snapshot.data!.docs;
                if (_selectedCategory != 'All') {
                  docs = docs.where((d) => (d.data() as Map)['category'] == _selectedCategory).toList();
                }

                if (docs.isEmpty) return const Center(child: Text('No gigs available in this category.', style: TextStyle(color: Colors.white54)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final gig = doc.data() as Map<String, dynamic>;
                    final isMyGig = gig['studentId'] == currentUid;
                    
                    Color statusColor = Colors.green;
                    if (gig['status'] == 'InProgress') statusColor = Colors.orange;
                    if (gig['status'] == 'Completed') statusColor = Colors.grey;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: gig['isUrgent'] == true ? Colors.redAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.3), width: gig['isUrgent'] == true ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                child: Text(gig['status'] ?? 'Open', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              if (gig['isUrgent'] == true)
                                const Row(children: [Icon(Icons.timer, color: Colors.redAccent, size: 14), SizedBox(width: 4), Text('URGENT', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))]),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), shape: BoxShape.circle),
                                child: Icon(gig['isRemote'] == true ? Icons.computer : Icons.directions_walk, color: Colors.blueAccent, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(gig['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('By: ${gig['studentName']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text('KES ${gig['price']}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(gig['isFixed'] == true ? ' fixed' : '/hr', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(gig['description'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          if ((gig['skills'] as List?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: (gig['skills'] as List).map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                child: Text(s, style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                              )).toList(),
                            )
                          ],
                          if (gig['referenceLink'] != null && (gig['referenceLink'] as String).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(children: [const Icon(Icons.link, color: Colors.blueAccent, size: 16), const SizedBox(width: 4), Expanded(child: Text(gig['referenceLink'], style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis))]),
                          ],
                          const SizedBox(height: 16),
                          if (gig['status'] == 'Open' && !isMyGig)
                            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _applyToGig(doc), style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen), child: const Text('Apply with Cover Message', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
                          if (isMyGig && gig['status'] == 'Open')
                            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => doc.reference.update({'status': 'InProgress'}), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)), child: const Text('Mark In Progress', style: TextStyle(color: Colors.orange)))),
                          if (isMyGig && gig['status'] == 'InProgress')
                            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _leaveReview(doc), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), child: const Text('Mark Completed & Rate', style: TextStyle(color: Colors.white)))),
                          if (gig['status'] == 'Completed' && gig['rating'] != null)
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => Icon(i < gig['rating'] ? Icons.star : Icons.star_border, color: Colors.amber, size: 20))),
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          )
        ],
      ),
    );
  }
}
