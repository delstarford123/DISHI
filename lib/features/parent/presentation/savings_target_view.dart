import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class SavingsTargetView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final List<Map<String, dynamic>> linkedStudents;

  const SavingsTargetView({
    super.key,
    required this.parentUser,
    required this.linkedStudents,
  });

  @override
  State<SavingsTargetView> createState() => _SavingsTargetViewState();
}

class _SavingsTargetViewState extends State<SavingsTargetView> {
  String? _selectedStudentUid;
  final _goalNameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _matchPercentageController = TextEditingController();

  bool _isSaving = false;

  Future<void> _createSavingsPledge() async {
    final goalName = _goalNameController.text.trim();
    final targetAmount = double.tryParse(_targetAmountController.text.trim());
    final matchPercentage = double.tryParse(_matchPercentageController.text.trim());

    if (goalName.isEmpty || targetAmount == null || targetAmount <= 0 || matchPercentage == null || matchPercentage <= 0 || matchPercentage > 100 || _selectedStudentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid details and select a student. Match % must be between 1 and 100.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('savings_targets').add({
        'parentUid': widget.parentUser['uid'],
        'studentUid': _selectedStudentUid,
        'goalName': goalName,
        'targetAmount': targetAmount,
        'matchPercentage': matchPercentage,
        'currentSaved': 0.0,
        'status': 'Active', // Active, Achieved
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Savings Matcher Pledge Created!'), backgroundColor: MPesaTheme.primaryGreen),
        );
        _goalNameController.clear();
        _targetAmountController.clear();
        _matchPercentageController.clear();
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
        title: const Text('Savings Matcher'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.savings, color: MPesaTheme.primaryGreen, size: 32),
                SizedBox(width: 12),
                Text(
                  'Encourage Good Habits',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pledge to match a percentage of your student\'s savings when they reach a specific goal (e.g., a new laptop).',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            if (widget.linkedStudents.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedStudentUid,
                dropdownColor: const Color(0xFF131A2A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Select Student',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF131A2A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: widget.linkedStudents.map((s) {
                  return DropdownMenuItem<String>(
                    value: s['uid'],
                    child: Text(s['name'] ?? 'Unknown Student'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedStudentUid = val),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _goalNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Goal Name (e.g., New Laptop)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.flag, color: MPesaTheme.primaryGreen),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _targetAmountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Target Amount (Ksh)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF131A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.attach_money, color: MPesaTheme.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _matchPercentageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Match %',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF131A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.percent, color: MPesaTheme.primaryGreen),
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
                onPressed: _isSaving ? null : _createSavingsPledge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Create Pledge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Active Pledges',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('savings_targets')
                    .where('parentUid', isEqualTo: widget.parentUser['uid'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No active savings pledges.', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'Active';

                      final student = widget.linkedStudents.firstWhere(
                        (s) => s['uid'] == data['studentUid'],
                        orElse: () => {'name': 'Unknown'},
                      );

                      final progress = data['currentSaved'] / data['targetAmount'];

                      return Card(
                        color: const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(data['goalName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(status, style: TextStyle(color: status == 'Achieved' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Student: ${student['name']} | Match: ${data['matchPercentage']}%', style: const TextStyle(color: Colors.white54)),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                backgroundColor: Colors.white24,
                                valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? Colors.green : MPesaTheme.primaryGreen),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Saved: Ksh ${data['currentSaved']}', style: const TextStyle(color: Colors.white54)),
                                  Text('Target: Ksh ${data['targetAmount']}', style: const TextStyle(color: Colors.white)),
                                ],
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
