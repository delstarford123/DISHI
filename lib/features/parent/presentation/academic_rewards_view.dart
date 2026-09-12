import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class AcademicRewardsView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const AcademicRewardsView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<AcademicRewardsView> createState() => _AcademicRewardsViewState();
}

class _AcademicRewardsViewState extends State<AcademicRewardsView> {
    final _targetScoreController = TextEditingController();
  final _rewardController = TextEditingController();
  String _unitName = '';

  bool _isSaving = false;

  Future<void> _createAcademicReward() async {
    final reward = double.tryParse(_rewardController.text.trim());
    final targetScore = int.tryParse(_targetScoreController.text.trim());

    if (reward == null || reward <= 0 || targetScore == null || targetScore <= 0 || widget.selectedStudentUid == null || _unitName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields correctly.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('academic_rewards').add({
        'parentUid': widget.parentUser['uid'],
        'studentUid': widget.selectedStudentUid,
        'unitName': _unitName,
        'targetScore': targetScore,
        'rewardAmount': reward,
        'status': 'Active', // Active, Achieved, Failed
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Academic Reward set!'), backgroundColor: MPesaTheme.primaryGreen),
        );
        _rewardController.clear();
        _targetScoreController.clear();
        setState(() => _unitName = '');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('SmartI Academic Rewards'),
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
              'Motivate Your Student',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Link automated financial rewards to the SmartI academic planner. If they hit their target score, the vault releases the bonus!',
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
              onChanged: (val) => _unitName = val,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Unit / Subject Name (e.g. Calculus)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.book, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetScoreController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Target Score (%)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF131A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.score, color: MPesaTheme.neonCyan),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
                      prefixIcon: const Icon(Icons.attach_money, color: Colors.yellow),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _createAcademicReward,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Set SmartI Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Active SmartI Pledges',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('academic_rewards')
                    .where('parentUid', isEqualTo: widget.parentUser['uid'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No academic rewards set.', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'Active';

                      final studentName = 'Selected Student';

                      return Card(
                        color: const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: status == 'Achieved' ? Colors.green : Colors.blueAccent.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          title: Text('${data['unitName']} - Target: ${data['targetScore']}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Student: $studentName\nStatus: $status',
                            style: TextStyle(color: status == 'Achieved' ? Colors.green : Colors.white54),
                          ),
                          trailing: Text('Ksh ${data['rewardAmount']}', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16)),
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

