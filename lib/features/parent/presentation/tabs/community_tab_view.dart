import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _textSecondary = Color(0xFF8B9BB4);

class CommunityTabView extends StatelessWidget {
  final Map<String, dynamic> user;
  
  const CommunityTabView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: _neonBlue,
            labelColor: _neonBlue,
            unselectedLabelColor: _textSecondary,
            tabs: [
              Tab(text: 'Forum'),
              Tab(text: 'Calendar'),
              Tab(text: 'P2P Transfer'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildForumView(),
                _buildCalendarView(),
                _buildP2pTransferView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForumView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('forums').orderBy('createdAt', descending: true).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _neonBlue));
        }

        final docs = snapshot.data?.docs ?? [];
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Parent Forum', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _showAddPostDialog(context), 
                  icon: const Icon(Icons.edit, size: 16), 
                  label: const Text('Post'),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonBlue),
                )
              ],
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
               const Text('No forum posts yet. Be the first to start a discussion!', style: TextStyle(color: _textSecondary)),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildForumPost(
                data['title'] ?? 'No Title',
                data['content'] ?? '',
                data['authorName'] ?? 'Anonymous',
                'Recently',
              );
            }).toList(),
          ],
        );
      }
    );
  }

  void _showAddPostDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('New Forum Post', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: const TextStyle(color: _neonCyan),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Content',
                labelStyle: const TextStyle(color: _neonCyan),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty || content.isEmpty) return;
              
              await FirebaseFirestore.instance.collection('forums').add({
                'title': title,
                'content': content,
                'authorUid': FirebaseAuth.instance.currentUser!.uid,
                'authorName': user['name'] ?? user['displayName'] ?? 'Parent',
                'createdAt': FieldValue.serverTimestamp(),
              });
              
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _neonBlue),
            child: const Text('Post', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  Widget _buildForumPost(String title, String content, String author, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$author • $time', style: const TextStyle(color: _neonCyan, fontSize: 12)),
              const Row(
                children: [
                  Icon(Icons.thumb_up_alt_outlined, color: _textSecondary, size: 16),
                  SizedBox(width: 4),
                  Text('0', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  SizedBox(width: 12),
                  Icon(Icons.comment_outlined, color: _textSecondary, size: 16),
                  SizedBox(width: 4),
                  Text('0', style: TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').orderBy('date', descending: false).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _neonCyan));
        }

        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Upcoming Events', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (docs.isEmpty)
               const Text('No upcoming events found.', style: TextStyle(color: _textSecondary)),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildEventCard(
                data['title'] ?? 'Event', 
                data['dateStr'] ?? 'Upcoming', 
                data['location'] ?? 'TBD', 
                data['isSchool'] ?? true
              );
            }).toList(),
          ],
        );
      }
    );
  }

  Widget _buildEventCard(String title, String date, String location, bool isSchool) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: isSchool ? _neonBlue : _neonCyan, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: isSchool ? _neonBlue.withOpacity(0.2) : _neonCyan.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(isSchool ? 'School' : 'Family', style: TextStyle(color: isSchool ? _neonBlue : _neonCyan, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: _textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(date, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, color: _textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildP2pTransferView() {
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isProcessing = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send Funds to Another Parent', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Chip in for gifts, carpools, or cover a friend\'s lunchbox instantly.', style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 24),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Parent Phone Number or Tag ID',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (Ksh)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note (e.g. Teacher Gift)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isProcessing ? null : () async {
                    final phone = phoneController.text.trim();
                    final amountStr = amountController.text.trim();
                    if (phone.isEmpty || amountStr.isEmpty) return;
                    final amount = double.tryParse(amountStr);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
                      return;
                    }
                    
                    setState(() => isProcessing = true);
                    try {
                      final db = FirebaseFirestore.instance;
                      final parentRef = db.collection('users').doc(FirebaseAuth.instance.currentUser!.uid);
                      
                      final targetQuery = await db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
                      if (targetQuery.docs.isEmpty) {
                        setState(() => isProcessing = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipient not found.')));
                        return;
                      }
                      
                      final targetRef = db.collection('users').doc(targetQuery.docs.first.id);
                      
                      await db.runTransaction((transaction) async {
                        final parentSnap = await transaction.get(parentRef);
                        final targetSnap = await transaction.get(targetRef);
                        
                        final parentWallet = (parentSnap.data()?['walletBalance'] ?? 0.0) as num;
                        if (parentWallet < amount) {
                          throw Exception('Insufficient funds');
                        }
                        
                        final targetWallet = (targetSnap.data()?['walletBalance'] ?? 0.0) as num;
                        
                        transaction.update(parentRef, {'walletBalance': parentWallet - amount});
                        transaction.update(targetRef, {'walletBalance': targetWallet + amount});
                        
                        final txRef = db.collection('transactions').doc();
                        transaction.set(txRef, {
                          'type': 'p2p_transfer',
                          'senderUid': parentSnap.id,
                          'receiverUid': targetSnap.id,
                          'amount': amount,
                          'note': noteController.text.trim(),
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                      });
                      
                      if (context.mounted) {
                        phoneController.clear();
                        amountController.clear();
                        noteController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer successful!')));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e')));
                    }
                    setState(() => isProcessing = false);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: isProcessing 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Send Funds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        );
      }
    );
  }
}
