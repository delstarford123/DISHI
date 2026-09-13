import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'dart:math';

// For PIN verification
import '../../../core/security/secure_storage_service.dart';

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

class _BountiesViewState extends State<BountiesView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _taskController = TextEditingController();
  final _rewardController = TextEditingController();
  final _penaltyController = TextEditingController();
  
  String _selectedCategory = 'Household';
  String _selectedRecurrence = 'One-Off';
  bool _requiresPhoto = true;
  DateTime? _deadline;
  
  bool _isSaving = false;

  final List<String> _categories = ['Household', 'Academic', 'Behavior', 'Health'];
  final List<String> _recurrenceOptions = ['One-Off', 'Daily', 'Weekly'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskController.dispose();
    _rewardController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() {
          _deadline = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _createBounty() async {
    final task = _taskController.text.trim();
    final reward = double.tryParse(_rewardController.text.trim());
    final penalty = double.tryParse(_penaltyController.text.trim()) ?? 0.0;

    if (task.isEmpty || reward == null || reward <= 0 || widget.selectedStudentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task, valid reward, and select a student.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final studentDoc = await FirebaseFirestore.instance.collection('users').doc(widget.selectedStudentUid).get();
      final studentName = studentDoc.data()?['name'] ?? studentDoc.data()?['displayName'] ?? 'Student';

      await FirebaseFirestore.instance.collection('bounties').add({
        'parentUid': widget.parentUser['uid'],
        'studentUid': widget.selectedStudentUid,
        'studentName': studentName,
        'task': task,
        'reward': reward,
        'penalty': penalty,
        'category': _selectedCategory,
        'recurrence': _selectedRecurrence,
        'requiresPhoto': _requiresPhoto,
        'deadline': _deadline != null ? Timestamp.fromDate(_deadline!) : null,
        'status': 'Open', // Open, PendingApproval, Completed, Rework, Failed
        'createdAt': FieldValue.serverTimestamp(),
        'streakMultiplier': 1.0, // For consecutive completions
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task Assigned!'), backgroundColor: MPesaTheme.primaryGreen),
        );
        _taskController.clear();
        _rewardController.clear();
        _penaltyController.clear();
        setState(() => _deadline = null);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _verifyPinAndApprove(String docId, double amount, String studentUid) async {
    String enteredPin = '';
    final bool? isVerified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Text('Parent PIN Required', style: TextStyle(color: Colors.white)),
        content: TextField(
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
          textAlign: TextAlign.center,
          onChanged: (val) => enteredPin = val,
          decoration: const InputDecoration(
            hintText: '****',
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              // Simplified PIN check logic. Real app hashes enteredPin and checks db/secure_storage
              if (enteredPin.length == 4) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN')));
              }
            },
            child: const Text('Verify'),
          )
        ],
      ),
    );

    if (isVerified == true) {
      await _approveBounty(docId, amount, studentUid);
    }
  }

  Future<void> _approveBounty(String docId, double amount, String studentUid) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final bountyRef = FirebaseFirestore.instance.collection('bounties').doc(docId);
      batch.update(bountyRef, {'status': 'Completed', 'completedAt': FieldValue.serverTimestamp()});

      final parentRef = FirebaseFirestore.instance.collection('users').doc(widget.parentUser['uid']);
      final studentRef = FirebaseFirestore.instance.collection('users').doc(studentUid);

      batch.update(parentRef, {'walletBalance': FieldValue.increment(-amount)});
      batch.update(studentRef, {'walletBalance': FieldValue.increment(amount)});

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payout Approved! Ksh $amount transferred.'), backgroundColor: MPesaTheme.neonCyan),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _denyBounty(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('bounties').doc(docId).update({'status': 'Rework'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task sent back for rework!'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildTaskCreator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.selectedStudentUid == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('⚠️ No student selected in Dependents tab.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          
          TextField(
            controller: _taskController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Task Description (e.g., Clean Room)',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF131A2A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.assignment, color: MPesaTheme.neonOrange),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rewardController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Reward (Ksh)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF131A2A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.star, color: MPesaTheme.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _penaltyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Penalty (Ksh)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF131A2A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.warning, color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF131A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    filled: true,
                    fillColor: const Color(0xFF131A2A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRecurrence,
                  dropdownColor: const Color(0xFF131A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Recurrence',
                    filled: true,
                    fillColor: const Color(0xFF131A2A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _recurrenceOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedRecurrence = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Require Photo Verification', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Student must snap a picture to submit', style: TextStyle(color: Colors.white54, fontSize: 12)),
            activeColor: MPesaTheme.neonCyan,
            value: _requiresPhoto,
            onChanged: (v) => setState(() => _requiresPhoto = v),
          ),
          ListTile(
            title: const Text('Set Deadline', style: TextStyle(color: Colors.white)),
            subtitle: Text(_deadline != null ? _deadline!.toString() : 'No deadline', style: const TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.calendar_today, color: Colors.white),
            onTap: _selectDeadline,
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
                  : const Text('Assign Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalQueue() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bounties')
          .where('parentUid', isEqualTo: widget.parentUser['uid'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonOrange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No active tasks.', style: TextStyle(color: Colors.white54)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Open';
            final studentName = data['studentName'] ?? 'Selected Student';
            final photoUrl = data.containsKey('photoUrl') ? data['photoUrl'] : null;
            final penalty = data.containsKey('penalty') ? data['penalty'] : 0.0;

            return Card(
              color: const Color(0xFF131A2A),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: Text(data['task'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Assignee: $studentName | Status: $status\nReward: Ksh ${data['reward']} ${penalty > 0 ? '| Penalty: -Ksh $penalty' : ''}',
                  style: TextStyle(
                    color: status == 'PendingApproval' ? Colors.orange : (status == 'Completed' ? Colors.green : (status == 'Rework' ? Colors.redAccent : Colors.white54)),
                  ),
                ),
                children: [
                  if (status == 'PendingApproval' && photoUrl != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(photoUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ),
                  if (status == 'PendingApproval')
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            icon: const Icon(Icons.close),
                            label: const Text('Rework'),
                            onPressed: () => _denyBounty(doc.id),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen, foregroundColor: Colors.white),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            onPressed: () => _verifyPinAndApprove(doc.id, (data['reward'] as num).toDouble(), data['studentUid']),
                          ),
                        ],
                      ),
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Household Champions', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildLeaderboardRow(1, 'Alice', 12, 1200, Colors.amber),
        _buildLeaderboardRow(2, 'Bob', 8, 800, Colors.grey.shade300),
        _buildLeaderboardRow(3, 'Charlie', 3, 300, Colors.brown),
      ],
    );
  }

  Widget _buildLeaderboardRow(int rank, String name, int tasks, int earned, Color medalColor) {
    return Card(
      color: const Color(0xFF131A2A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: medalColor.withOpacity(0.2),
          child: Text('#$rank', style: TextStyle(color: medalColor, fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('$tasks Tasks Completed', style: const TextStyle(color: Colors.white54)),
        trailing: Text('Ksh $earned', style: const TextStyle(color: MPesaTheme.neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildAnalytics() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Weekly Overview', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statBox('Completion Rate', '85%', MPesaTheme.primaryGreen),
                  _statBox('Total Paid', 'Ksh 2400', MPesaTheme.neonOrange),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Spending by Category', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _categoryBar('Household', 0.6, Colors.blue),
              _categoryBar('Academic', 0.3, Colors.purple),
              _categoryBar('Behavior', 0.1, Colors.amber),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(String title, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _categoryBar(String label, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(percent * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Smart Parenting Center'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MPesaTheme.neonOrange,
          tabs: const [
            Tab(text: 'Assign Task'),
            Tab(text: 'Queue'),
            Tab(text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskCreator(),
          _buildApprovalQueue(),
          _buildAnalytics(), // Placeholder for now or I can implement it fully
        ],
      ),
    );
  }
}
