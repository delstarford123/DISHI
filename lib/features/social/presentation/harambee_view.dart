import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class HarambeeView extends StatefulWidget {
  final Map<String, dynamic> user;

  const HarambeeView({super.key, required this.user});

  @override
  State<HarambeeView> createState() => _HarambeeViewState();
}

class _HarambeeViewState extends State<HarambeeView> {
  void _donate(DocumentSnapshot campaignDoc) {
    final campaign = campaignDoc.data() as Map<String, dynamic>;
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: Text('Donate to ${campaign['title']}'),
        content: TextField(
          controller: amountController,
          decoration: const InputDecoration(
            labelText: 'Amount (KES)',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: MPesaTheme.primaryGreen)),
          ),
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                try {
                  await FirebaseFirestore.instance.collection('harambee_campaigns').doc(campaignDoc.id).update({
                    'raised': FieldValue.increment(amount),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donation successful!')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            child: const Text('Donate via DISHI', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showCreateCampaignDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final goalController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Create Campaign', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Campaign Title', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.white70)),
              maxLines: 3,
            ),
            TextField(
              controller: goalController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Funding Goal (KES)', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
            onPressed: () async {
              final goalAmount = double.tryParse(goalController.text) ?? 0.0;
              if (titleController.text.isNotEmpty && descController.text.isNotEmpty && goalAmount > 0) {
                try {
                  await FirebaseFirestore.instance.collection('harambee_campaigns').add({
                    'title': titleController.text,
                    'description': descController.text,
                    'goal': goalAmount,
                    'raised': 0.0,
                    'student': widget.user['displayName'] ?? 'A Student',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign created!')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            child: const Text('Publish', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _shareCampaign(String campaignId) {
    final link = 'https://dishi.delstarfordworks.co.ke/fund?campaign_id=$campaignId';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied link: $link\nShare on WhatsApp/Twitter!'))
    );
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
          IconButton(
            icon: const Icon(Icons.add, color: MPesaTheme.primaryGreen),
            onPressed: _showCreateCampaignDialog,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('harambee_campaigns').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading campaigns: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No campaigns active right now.', style: TextStyle(color: Colors.white70)));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final campaignDoc = docs[index];
              final campaign = campaignDoc.data() as Map<String, dynamic>;
              
              final goal = (campaign['goal'] as num).toDouble();
              final raised = (campaign['raised'] as num).toDouble();
              final progress = (raised / goal).clamp(0.0, 1.0);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(campaign['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('By ${campaign['student'] ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 12),
                    Text(campaign['description'] ?? '', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Raised: KES $raised', style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                        Text('Goal: KES $goal', style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      color: MPesaTheme.primaryGreen,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MPesaTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 12)
                            ),
                            onPressed: () => _donate(campaignDoc),
                            icon: const Icon(Icons.volunteer_activism, color: Colors.black),
                            label: const Text('Donate', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: MPesaTheme.primaryGreen),
                              padding: const EdgeInsets.symmetric(vertical: 12)
                            ),
                            onPressed: () => _shareCampaign(campaignDoc.id),
                            icon: const Icon(Icons.share, color: MPesaTheme.primaryGreen),
                            label: const Text('Share Link', style: TextStyle(color: MPesaTheme.primaryGreen)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        }
      ),
    );
  }
}
