import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/theme/mpesa_theme.dart';

class HarambeeView extends StatefulWidget {
  final Map<String, dynamic> user;

  const HarambeeView({super.key, required this.user});

  @override
  State<HarambeeView> createState() => _HarambeeViewState();
}

class _HarambeeViewState extends State<HarambeeView> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Tuition', 'Medical', 'Projects', 'Emergencies', 'Success Stories'];
  
  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  void _donate(DocumentSnapshot campaignDoc) {
    final campaign = campaignDoc.data() as Map<String, dynamic>;
    final amountController = TextEditingController();
    bool isAnonymous = false;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: Text('Donate to ${campaign['title']}', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount (KES)', labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: MPesaTheme.primaryGreen))),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ActionChip(label: const Text('50 KES'), onPressed: () => amountController.text = '50'),
                  ActionChip(label: const Text('100 KES'), onPressed: () => amountController.text = '100'),
                  ActionChip(label: const Text('500 KES'), onPressed: () => amountController.text = '500'),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Donate Anonymously', style: TextStyle(color: Colors.white, fontSize: 14)),
                activeColor: MPesaTheme.primaryGreen,
                value: isAnonymous,
                onChanged: (v) => setDialogState(() => isAnonymous = v),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount >= 10) {
                  Navigator.pop(context);
                  _processDonation(campaignDoc, amount, isAnonymous);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum amount is 10 KES')));
                }
              },
              child: const Text('Next', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        )
      )
    );
  }

  void _processDonation(DocumentSnapshot campaignDoc, double amount, bool isAnonymous) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Select Payment Method', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wallet, color: MPesaTheme.primaryGreen),
              title: const Text('DISHI Wallet', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _payWithWallet(campaignDoc, amount, isAnonymous);
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android, color: MPesaTheme.primaryGreen),
              title: const Text('M-PESA', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _promptMpesaNumber(campaignDoc, amount, isAnonymous);
              },
            )
          ],
        ),
      )
    );
  }

  Future<void> _payWithWallet(DocumentSnapshot campaignDoc, double amount, bool isAnonymous) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen)));
    try {
      final response = await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v2/social/harambee/donate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'donorId': currentUid,
          'campaignId': campaignDoc.id,
          'amount': amount,
          'donorName': isAnonymous ? 'Anonymous' : (widget.user['displayName'] ?? 'Student')
        }),
      ).timeout(const Duration(seconds: 30));

      if (mounted) Navigator.pop(context); // pop loading
      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donation successful!')));
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Donation failed';
        if (err == 'Insufficient wallet balance' && mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF131A2A),
              title: const Text('Insufficient Balance', style: TextStyle(color: Colors.white)),
              content: const Text('Your DISHI wallet balance is too low to complete this donation. Would you like to use M-PESA directly?', style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                  onPressed: () {
                    Navigator.pop(context);
                    _promptMpesaNumber(campaignDoc, amount, isAnonymous);
                  },
                  child: const Text('Pay with M-PESA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              ],
            )
          );
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // pop loading
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _promptMpesaNumber(DocumentSnapshot campaignDoc, double amount, bool isAnonymous) {
    final phoneController = TextEditingController(text: widget.user['phoneNumber'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('M-PESA Number', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: phoneController,
          decoration: const InputDecoration(labelText: 'Phone (e.g. 2547XXXXXXXX)', labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: MPesaTheme.primaryGreen))),
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () {
              Navigator.pop(context);
              _payWithMpesa(campaignDoc, amount, isAnonymous, phoneController.text.trim());
            },
            child: const Text('Pay', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  Future<void> _payWithMpesa(DocumentSnapshot campaignDoc, double amount, bool isAnonymous, String phone) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen)));
    try {
      final campaign = campaignDoc.data() as Map<String, dynamic>;
      final response = await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v1/mpesa/stkpush'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phone,
          'amount': amount,
          'credit_amount': amount,
          'user_id': currentUid,
          'destination': 'walletBalance',
          'metadata': {
            'action': 'harambee_donate',
            'campaign_id': campaignDoc.id,
            'campaign_title': campaign['title'],
            'donor_name': isAnonymous ? 'Anonymous' : (widget.user['displayName'] ?? 'Student')
          }
        }),
      ).timeout(const Duration(seconds: 30));

      if (mounted) Navigator.pop(context); // pop loading
      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('M-PESA prompt sent to your phone!')));
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to send prompt';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // pop loading
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCreateCampaignDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final goalController = TextEditingController();
    String category = 'Tuition';
    int daysActive = 30;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: const Text('Create Campaign', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Campaign Title', labelStyle: TextStyle(color: Colors.white70))),
                TextField(controller: descController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Rich Description (Why do you need funds?)', labelStyle: TextStyle(color: Colors.white70)), maxLines: 4),
                TextField(controller: goalController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Funding Goal (KES)', labelStyle: TextStyle(color: Colors.white70))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: const Color(0xFF131A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white70)),
                  items: _categories.where((c) => c != 'All' && c != 'Success Stories').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Duration:', style: TextStyle(color: Colors.white)),
                    Expanded(
                      child: Slider(
                        value: daysActive.toDouble(), min: 7, max: 90, divisions: 10,
                        activeColor: MPesaTheme.primaryGreen,
                        label: '$daysActive days',
                        onChanged: (v) => setDialogState(() => daysActive = v.toInt()),
                      ),
                    ),
                    Text('${daysActive}d', style: const TextStyle(color: MPesaTheme.primaryGreen)),
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
              onPressed: () async {
                final goalAmount = double.tryParse(goalController.text) ?? 0.0;
                if (titleController.text.isNotEmpty && descController.text.isNotEmpty && goalAmount > 0) {
                  await FirebaseFirestore.instance.collection('harambee_campaigns').add({
                    'title': titleController.text,
                    'description': descController.text,
                    'goal': goalAmount,
                    'raised': 0.0,
                    'category': category,
                    'studentId': currentUid,
                    'student': widget.user['displayName'] ?? 'A Student',
                    'isVerifiedStudent': true, // Mock logic
                    'createdAt': FieldValue.serverTimestamp(),
                    'deadline': Timestamp.fromDate(DateTime.now().add(Duration(days: daysActive))),
                    'donors': [],
                    'updates': [],
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign created!')));
                  }
                }
              },
              child: const Text('Publish', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        )
      )
    );
  }

  void _addUpdate(DocumentSnapshot doc) {
    final updateController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Post Update', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: updateController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Update message for donors', labelStyle: TextStyle(color: Colors.white70)),
          maxLines: 2,
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              if (updateController.text.isNotEmpty) {
                final updates = List.from((doc.data() as Map)['updates'] ?? []);
                updates.add({'text': updateController.text, 'timestamp': Timestamp.now()});
                await doc.reference.update({'updates': updates});
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Post', style: TextStyle(color: Colors.black)),
          )
        ],
      )
    );
  }

  void _showWithdrawDialog(String campaignId, double raised) {
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.amber, width: 1.5)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Withdraw KES ${raised.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Funds will be sent to your M-PESA number via STK push.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'M-PESA Phone (e.g. 254712345678)',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A2235),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.phone, color: Colors.amber),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty || phone.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid M-PESA number')));
                return;
              }
              Navigator.pop(context);
              // Write withdrawal request — backend processes via M-PESA STK
              await FirebaseFirestore.instance
                  .collection('harambee_withdrawals')
                  .add({
                'campaign_id': campaignId,
                'uid': currentUid,
                'amount': raised,
                'phone': phone,
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          '✅ Withdrawal initiated! You will receive an M-PESA prompt shortly.'),
                      backgroundColor: MPesaTheme.primaryGreen,
                      duration: Duration(seconds: 4)),
                );
              }
            },
            child: const Text('Withdraw via M-PESA',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _shareCampaign(String campaignId) {
    final link = 'https://dishi.delstarfordworks.co.ke/fund?campaign=$campaignId';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied link: $link\nShare on WhatsApp!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Harambee Crowdfunding'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add, color: MPesaTheme.primaryGreen), onPressed: _showCreateCampaignDialog)
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c, style: TextStyle(color: _selectedCategory == c ? Colors.black : Colors.white)),
                  selected: _selectedCategory == c,
                  selectedColor: MPesaTheme.primaryGreen,
                  backgroundColor: Colors.white12,
                  onSelected: (v) => setState(() => _selectedCategory = c),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('harambee_campaigns').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));

                var docs = snapshot.data!.docs;
                
                if (_selectedCategory == 'Success Stories') {
                  docs = docs.where((d) {
                    final data = d.data() as Map;
                    return (data['raised'] as num) >= (data['goal'] as num);
                  }).toList();
                } else if (_selectedCategory != 'All') {
                  docs = docs.where((d) => (d.data() as Map)['category'] == _selectedCategory).toList();
                }

                if (docs.isEmpty) return const Center(child: Text('No campaigns found.', style: TextStyle(color: Colors.white70)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final campaignDoc = docs[index];
                    final campaign = campaignDoc.data() as Map<String, dynamic>;
                    
                    final goal = (campaign['goal'] as num).toDouble();
                    final raised = (campaign['raised'] as num).toDouble();
                    final progress = (raised / goal).clamp(0.0, 1.0);
                    final isMyCampaign = campaign['studentId'] == currentUid;
                    final isFunded = raised >= goal;

                    // Deadline calc
                    String deadlineText = 'No deadline';
                    if (campaign['deadline'] != null) {
                      final deadline = (campaign['deadline'] as Timestamp).toDate();
                      final diff = deadline.difference(DateTime.now());
                      if (diff.isNegative) {
                        deadlineText = 'Ended';
                      } else {
                        deadlineText = '${diff.inDays} days left';
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isFunded ? Colors.amber.withOpacity(0.5) : MPesaTheme.primaryGreen.withOpacity(0.3), width: isFunded ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                                child: Text(campaign['category'] ?? 'General', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.timer, color: deadlineText == 'Ended' ? Colors.red : Colors.white54, size: 14),
                                  const SizedBox(width: 4),
                                  Text(deadlineText, style: TextStyle(color: deadlineText == 'Ended' ? Colors.red : Colors.white54, fontSize: 12)),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(campaign['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('By ${campaign['student'] ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                              if (campaign['isVerifiedStudent'] == true) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                              ]
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Rich Description with Expansion
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(campaign['description'].toString().split('\n').first, style: const TextStyle(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(campaign['description'] ?? '', style: const TextStyle(color: Colors.white70)),
                                )
                              ],
                            ),
                          ),
                          
                          // Social Proof
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.people, color: Colors.blueAccent, size: 16),
                                const SizedBox(width: 8),
                                Text('${(campaign['donors'] as List?)?.length ?? 0} students have donated', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                              ],
                            ),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Raised: KES $raised', style: TextStyle(color: isFunded ? Colors.amber : MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                              Text('Goal: KES $goal', style: const TextStyle(color: Colors.white54)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white12,
                            color: isFunded ? Colors.amber : MPesaTheme.primaryGreen,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          
                          // Top Donors Leaderboard
                          if ((campaign['donors'] as List?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 16),
                            const Text('Top Donors 🏆', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...(campaign['donors'] as List).take(3).map((d) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(d['name'], style: const TextStyle(color: Colors.white70)),
                                  Text('KES ${d['amount']}', style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                            )),
                          ],

                          // Campaign Updates
                          if ((campaign['updates'] as List?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(children: [Icon(Icons.campaign, color: Colors.white54, size: 16), SizedBox(width: 8), Text('Latest Update', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))]),
                                  const SizedBox(height: 8),
                                  Text((campaign['updates'] as List).last['text'], style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                            )
                          ],

                          const SizedBox(height: 24),
                          if (deadlineText != 'Ended')
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 12)),
                                    onPressed: () => _donate(campaignDoc),
                                    icon: const Icon(Icons.volunteer_activism, color: Colors.black),
                                    label: const Text('Donate', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: MPesaTheme.primaryGreen), padding: const EdgeInsets.all(12)),
                                  onPressed: () => _shareCampaign(campaignDoc.id),
                                  child: const Icon(Icons.share, color: MPesaTheme.primaryGreen),
                                ),
                              ],
                            ),
                            
                          if (isMyCampaign && deadlineText != 'Ended') ...[
                            const SizedBox(height: 8),
                            SizedBox(width: double.infinity, child: TextButton(onPressed: () => _addUpdate(campaignDoc), child: const Text('Post Update', style: TextStyle(color: Colors.white54)))),
                          ],
                          // Withdraw button — only for campaign owner when there is raised amount
                          if (isMyCampaign && raised > 0) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade700,
                                    padding: const EdgeInsets.symmetric(vertical: 12)),
                                onPressed: () => _showWithdrawDialog(campaignDoc.id, raised),
                                icon: const Icon(Icons.account_balance_wallet, color: Colors.black),
                                label: const Text('Withdraw Funds',
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}
