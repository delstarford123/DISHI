import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class MedicalLockView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const MedicalLockView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<MedicalLockView> createState() => _MedicalLockViewState();
}

class _MedicalLockViewState extends State<MedicalLockView> {
  final _amountController = TextEditingController();
  bool _isSaving = false;

  Future<void> _setMedicalLock() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0 || widget.selectedStudentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount and select a student.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Create a medical lock configuration document
      await FirebaseFirestore.instance.collection('medical_locks').doc(widget.selectedStudentUid).set({
        'parentUid': widget.parentUser['uid'],
        'studentUid': widget.selectedStudentUid,
        'lockedAmount': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical Emergency Lock applied!'), backgroundColor: MPesaTheme.primaryGreen),
        );
        _amountController.clear();
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
        title: const Text('Medical Emergency Lock'),
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
                Icon(Icons.local_hospital, color: MPesaTheme.neonCyan, size: 32),
                SizedBox(width: 12),
                Text(
                  'Ring-fence Funds',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Lock a specific portion of your student\'s wallet so that it can ONLY be spent at registered campus clinics or pharmacies.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            if (widget.selectedStudentUid == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No student selected in Dependents tab.', style: TextStyle(color: MPesaTheme.primaryRed, fontWeight: FontWeight.bold)),
              ),
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
                prefixIcon: const Icon(Icons.lock, color: MPesaTheme.neonCyan),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _setMedicalLock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.neonCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
                    : const Text('Apply Lock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Active Locks',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medical_locks')
                    .where('parentUid', isEqualTo: widget.parentUser['uid'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No active medical locks.', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final studentName = 'Selected Student';

                      return Card(
                        color: const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.shield, color: MPesaTheme.neonCyan),
                          title: Text(studentName, style: const TextStyle(color: Colors.white)),
                          subtitle: const Text('Locked for Pharmacy / Clinic use only', style: TextStyle(color: Colors.white54)),
                          trailing: Text('Ksh ${data['lockedAmount']}', style: const TextStyle(color: MPesaTheme.neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
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
