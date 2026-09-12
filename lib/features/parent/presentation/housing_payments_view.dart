import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class HousingPaymentsView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const HousingPaymentsView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<HousingPaymentsView> createState() => _HousingPaymentsViewState();
}

class _HousingPaymentsViewState extends State<HousingPaymentsView> {
  final _amountController = TextEditingController();
  final _landlordIdController = TextEditingController();

  bool _isSaving = false;

  Future<void> _initiateHousingPayment() async {
    final amount = double.tryParse(_amountController.text.trim());
    final landlordId = _landlordIdController.text.trim();

    if (amount == null || amount <= 0 || landlordId.isEmpty || widget.selectedStudentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount, landlord ID, and select a student.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('housing_payments').add({
        'parentUid': widget.parentUser['uid'],
        'studentUid': widget.selectedStudentUid,
        'landlordId': landlordId,
        'amount': amount,
        'status': 'Pending Escrow',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Housing Escrow Initiated!'), backgroundColor: MPesaTheme.primaryGreen),
        );
        _amountController.clear();
        _landlordIdController.clear();
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
        title: const Text('Housing Escrow'),
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
                Icon(Icons.home, color: Colors.tealAccent, size: 32),
                SizedBox(width: 12),
                Text(
                  'Direct Rent Payments',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Securely pay rent directly to registered campus landlords. Funds are held in escrow until the student signs the lease.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            if (widget.selectedStudentUid == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No student selected in Dependents tab.', style: TextStyle(color: MPesaTheme.primaryRed, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _landlordIdController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Landlord System ID',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.person, color: Colors.tealAccent),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Rent Amount (Ksh)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.tealAccent),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _initiateHousingPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
                    : const Text('Initiate Escrow Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Recent Housing Escrows',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('housing_payments')
                    .where('parentUid', isEqualTo: widget.parentUser['uid'])
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No housing payments yet.', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'Pending Escrow';

                      final studentName = 'Selected Student';

                      return Card(
                        color: const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text('Landlord: ${data['landlordId']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Student: $studentName\nStatus: $status',
                            style: TextStyle(color: status == 'Completed' ? Colors.green : Colors.white54),
                          ),
                          trailing: Text('Ksh ${data['amount']}', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16)),
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
