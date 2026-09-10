import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class GraduationFundView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final List<Map<String, dynamic>> linkedStudents;

  const GraduationFundView({
    super.key,
    required this.parentUser,
    required this.linkedStudents,
  });

  @override
  State<GraduationFundView> createState() => _GraduationFundViewState();
}

class _GraduationFundViewState extends State<GraduationFundView> {
  String? _selectedStudentUid;
  final _amountController = TextEditingController();
  DateTime? _releaseDate;

  bool _isSaving = false;

  Future<void> _lockGraduationFund() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _releaseDate == null || _selectedStudentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount, select a release date, and select a student.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('graduation_funds').add({
        'parentUid': widget.parentUser['uid'],
        'studentUid': _selectedStudentUid,
        'lockedAmount': amount,
        'releaseDate': Timestamp.fromDate(_releaseDate!),
        'status': 'Locked',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Graduation Fund Locked!'), backgroundColor: MPesaTheme.neonCyan),
        );
        _amountController.clear();
        setState(() => _releaseDate = null);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: MPesaTheme.neonCyan,
              onPrimary: Colors.black,
              surface: Color(0xFF131A2A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _releaseDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Graduation Fund'),
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
                Icon(Icons.school, color: Colors.purpleAccent, size: 32),
                SizedBox(width: 12),
                Text(
                  'Time-Locked Vault',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Securely lock funds for post-graduation life or business capital. The student cannot access this vault until the specified release date.',
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
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount to Lock (Ksh)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.lock, color: Colors.purpleAccent),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.purpleAccent),
                    const SizedBox(width: 16),
                    Text(
                      _releaseDate == null
                          ? 'Select Release Date'
                          : 'Release on: ${_releaseDate!.toLocal().toString().split(' ')[0]}',
                      style: TextStyle(color: _releaseDate == null ? Colors.white54 : Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _lockGraduationFund,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Lock Vault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Active Vaults',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('graduation_funds')
                    .where('parentUid', isEqualTo: widget.parentUser['uid'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No active graduation funds.', style: TextStyle(color: Colors.white54)),
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

                      final releaseDate = (data['releaseDate'] as Timestamp).toDate();
                      final isReleased = releaseDate.isBefore(DateTime.now());

                      return Card(
                        color: const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isReleased ? Colors.green : Colors.transparent),
                        ),
                        child: ListTile(
                          leading: Icon(isReleased ? Icons.lock_open : Icons.lock, color: isReleased ? Colors.green : Colors.purpleAccent),
                          title: Text(student['name'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            isReleased ? 'Funds have been released!' : 'Unlocks on: ${releaseDate.toString().split(' ')[0]}',
                            style: TextStyle(color: isReleased ? Colors.green : Colors.white54),
                          ),
                          trailing: Text('Ksh ${data['lockedAmount']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
