import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/mpesa_theme.dart';

class SplitBillView extends StatefulWidget {
  final UserModel userModel;

  const SplitBillView({super.key, required this.userModel});

  @override
  State<SplitBillView> createState() => _SplitBillViewState();
}

class _SplitBillViewState extends State<SplitBillView> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _friendIdController = TextEditingController();
  List<String> _friends = [];
  bool _isSending = false;

  void _addFriend() {
    final id = _friendIdController.text.trim().toUpperCase();
    if (id.isNotEmpty && !_friends.contains(id)) {
      setState(() {
        _friends.add(id);
        _friendIdController.clear();
      });
    }
  }

  void _sendRequests() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || _friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an amount and add at least one friend.')));
      return;
    }
    
    double? totalAmount = double.tryParse(amountText);
    if (totalAmount == null || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount.')));
      return;
    }

    setState(() => _isSending = true);

    try {
      double perPerson = totalAmount / (_friends.length + 1);
      
      final splitBillData = {
        'creatorId': widget.userModel.uid,
        'creatorName': widget.userModel.displayName,
        'totalAmount': totalAmount,
        'perPersonAmount': perPerson,
        'friends': _friends,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance.collection('split_bills').add(splitBillData);

      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Split requests sent successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    double perPerson = totalAmount > 0 ? (totalAmount / (_friends.length + 1)) : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Split the Bill'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group Pay',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Eating out with friends? Pay the vendor and instantly send split requests to your group.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'Ksh ',
                prefixStyle: const TextStyle(color: Color(0xFF05D5AA), fontSize: 32, fontWeight: FontWeight.bold),
                labelText: 'Total Bill Amount',
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF05D5AA))),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _friendIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter Friend\'s DISHI ID',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF131A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF05D5AA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.black),
                    onPressed: _addFriend,
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _friends.isEmpty
                  ? const Center(child: Text('No friends added yet.', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: _friends.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF05D5AA).withOpacity(0.2),
                                    child: const Icon(Icons.person, color: Color(0xFF05D5AA)),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(_friends[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('Ksh ${perPerson.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF05D5AA), fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _friends.removeAt(index);
                                      });
                                    },
                                    child: const Icon(Icons.close, color: Colors.white54, size: 20),
                                  )
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_friends.isNotEmpty && totalAmount > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF05D5AA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF05D5AA).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your Share:', style: TextStyle(color: Colors.white, fontSize: 16)),
                    Text('Ksh ${perPerson.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF05D5AA), fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendRequests,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF05D5AA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSending
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Send Split Requests', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
