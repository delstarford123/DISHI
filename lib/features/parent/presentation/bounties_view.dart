import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class BountiesView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const BountiesView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<BountiesView> createState() => _BountiesViewState();
}

class _BountiesViewState extends State<BountiesView> {
    final _taskController = TextEditingController();
  final _rewardController = TextEditingController();

  bool _isSaving = false;

  Future<void> _createBounty() async {
    final task = _taskController.text.trim();
    final reward = double.tryParse(_rewardController.text.trim());

    if (task.isEmpty || reward == null || reward <= 0 || widget.selectedStudentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task, valid reward, and select a student.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('bounties').add({
        'parentUid': widget.parentUser['uid'],
        'studentUid': widget.selectedStudentUid,
        'task': task,
        'reward': reward,
        'status': 'Open', // Open, PendingApproval, Completed
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bounty created!'), backgroundColor: MPesaTheme.primaryGreen),
        );
        _taskController.clear();
        _rewardController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _approveBounty(String docId, double amount, String studentUid) async {
    // In a full implementation, this would trigger a cloud function to securely transfer funds.
    // For now, we update the status and mock the wallet transfer.
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final bountyRef = FirebaseFirestore.instance.collection('bounties').doc(docId);
      batch.update(bountyRef, {'status': 'Completed'});

      // Mock Transfer logic: reduce parent wallet, increase student wallet
      final parentRef = FirebaseFirestore.instance.collection('users').doc(widget.parentUser['uid']);
      final studentRef = FirebaseFirestore.instance.collection('users').doc(studentUid);

      batch.update(parentRef, {'walletBalance': FieldValue.increment(-amount)});
      batch.update(studentRef, {'walletBalance': FieldValue.increment(amount)});

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bounty approved! Ksh $amount transferred.'), backgroundColor: MPesaTheme.neonCyan),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Tasks & Bounties'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a New Task',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set chores or academic goals with attached financial rewards.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            if (widget.selectedStudentUid == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No student selected in Dependents tab.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _taskController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Task Description',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.assignment, color: MPesaTheme.neonOrange),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rewardController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Reward (Ksh)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.star, color: Colors.yellow),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _createBounty,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.neonOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Post Bounty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Active & Pending Bounties',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bounties')
                    .where('parentUid', isEqualTo: widget.parentUser['uid'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonOrange));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No bounties found.', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'Open';
                      
                      final studentName = 'Selected Student';

                      return Card(
                        color: const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text(data['task'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Assignee: $studentName\nStatus: $status',
                            style: TextStyle(
                              color: status == 'PendingApproval' ? Colors.orange : (status == 'Completed' ? Colors.green : Colors.white54),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Ksh ${data['reward']}', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16)),
                              if (status == 'PendingApproval')
                                InkWell(
                                  onTap: () => _approveBounty(doc.id, (data['reward'] as num).toDouble(), data['studentUid']),
                                  child: const Text('APPROVE', style: TextStyle(color: MPesaTheme.neonCyan, fontWeight: FontWeight.bold)),
                                )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

