import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/mpesa_theme.dart';

class SubscriptionManagerView extends StatefulWidget {
  final UserModel userModel;

  const SubscriptionManagerView({super.key, required this.userModel});

  @override
  State<SubscriptionManagerView> createState() => _SubscriptionManagerViewState();
}

class _SubscriptionManagerViewState extends State<SubscriptionManagerView> {
  void _toggleSubscription(String subId, bool value, String merchant) async {
    try {
      await FirebaseFirestore.instance.collection('subscriptions').doc(subId).update({
        'active': value,
      });
      final status = value ? 'Activated' : 'Paused';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$merchant $status')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update subscription')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Subscriptions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recurring Payments',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your recurring campus payments and external subscriptions in one place.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('subscriptions').where('uid', isEqualTo: widget.userModel.uid).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF05D5AA)));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No active subscriptions', style: TextStyle(color: Colors.white54)));
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final subData = docs[index].data() as Map<String, dynamic>;
                      final subId = docs[index].id;
                      final isActive = subData['active'] ?? false;
                      final color = isActive ? Colors.blue : Colors.grey;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131A2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isActive ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.payment, color: color),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(subData['merchant'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('${subData['cycle'] ?? 'Monthly'} • Ksh ${subData['amount']}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isActive,
                                  onChanged: (val) => _toggleSubscription(subId, val, subData['merchant'] ?? 'Subscription'),
                                  activeColor: const Color(0xFF05D5AA),
                                )
                              ],
                            ),
                            if (isActive) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(color: Colors.white12),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Next Billing Date:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                  Text(subData['nextBilling'] ?? 'TBD', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ]
                          ],
                        ),
                      );
                    },
                  );
                }
              ),
            )
          ],
        ),
      ),
    );
  }
}
