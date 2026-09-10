import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class ScheduledAllowancesView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final List<Map<String, dynamic>> linkedStudents;

  const ScheduledAllowancesView({
    super.key,
    required this.parentUser,
    required this.linkedStudents,
  });

  @override
  State<ScheduledAllowancesView> createState() => _ScheduledAllowancesViewState();
}

class _ScheduledAllowancesViewState extends State<ScheduledAllowancesView> {
  final _amountController = TextEditingController();
  String? _selectedStudentUid;
  String _frequency = 'Weekly'; // Daily, Weekly, Monthly

  bool _isSaving = false;

  Future<void> _saveAllowance() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _selectedStudentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount and select a student.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('scheduled_allowances').add({
        'parentUid': widget.parentUser['uid'],
        'studentUid': _selectedStudentUid,
        'amount': amount,
        'frequency': _frequency,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'nextRunAt': _calculateNextRun(_frequency),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled allowance saved!'), backgroundColor: MPesaTheme.primaryGreen),
        );
        _amountController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  DateTime _calculateNextRun(String frequency) {
    final now = DateTime.now();
    switch (frequency) {
      case 'Daily': return now.add(const Duration(days: 1));
      case 'Weekly': return now.add(const Duration(days: 7));
      case 'Monthly': return DateTime(now.year, now.month + 1, now.day);
      default: return now.add(const Duration(days: 7));
    }
  }

  Future<void> _deleteAllowance(String id) async {
    try {
      await FirebaseFirestore.instance.collection('scheduled_allowances').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allowance deleted.'), backgroundColor: MPesaTheme.neonBlue),
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
        title: const Text('Scheduled Allowances'),
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
              'Set Up Auto-Funding',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Automatically top up a student\'s wallet from your Parent Vault on a schedule.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
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
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (Ksh)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.attach_money, color: MPesaTheme.neonCyan),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _frequency,
              dropdownColor: const Color(0xFF131A2A),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Frequency',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.calendar_month, color: MPesaTheme.neonCyan),
              ),
              items: ['Daily', 'Weekly', 'Monthly'].map((f) {
                return DropdownMenuItem<String>(value: f, child: Text(f));
              }).toList(),
              onChanged: (val) => setState(() => _frequency = val!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAllowance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.neonCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
                    : const Text('Save Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Active Schedules',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('scheduled_allowances')
                    .where('parentUid', isEqualTo: widget.parentUser['uid'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No active schedules.', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final student = widget.linkedStudents.firstWhere(
                        (s) => s['uid'] == data['studentUid'],
                        orElse: () => {'name': 'Unknown'},
                      );

                      return Card(
                        color: const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text(student['name'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            'Ksh ${data['amount']} • ${data['frequency']}',
                            style: const TextStyle(color: MPesaTheme.neonCyan),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: MPesaTheme.primaryRed),
                            onPressed: () => _deleteAllowance(doc.id),
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
