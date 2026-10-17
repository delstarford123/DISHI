import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/models/user_model.dart';

class RequestFundsView extends StatefulWidget {
  final UserModel? userModel;

  const RequestFundsView({super.key, this.userModel});

  @override
  State<RequestFundsView> createState() => _RequestFundsViewState();
}

class _RequestFundsViewState extends State<RequestFundsView> {
  bool _isCopied = false;
  String _effectiveUid = '';
  String _displayName = 'Student';
  String _dishiId = '';
  String _fundLink = '';

  @override
  void initState() {
    super.initState();
    _initUserData();
  }

  void _initUserData() {
    final authUser = FirebaseAuth.instance.currentUser;
    _effectiveUid = widget.userModel?.uid ?? authUser?.uid ?? '';
    _displayName = widget.userModel?.displayName ?? authUser?.displayName ?? 'Student';
    _dishiId = (widget.userModel?.dishiId != null && widget.userModel!.dishiId!.isNotEmpty) 
        ? widget.userModel!.dishiId! 
        : _effectiveUid;
    
    _fundLink = 'https://dishi.delstarfordworks.co.ke/fund?dishi_id=$_dishiId';
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _fundLink));
    HapticFeedback.mediumImpact();
    setState(() => _isCopied = true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.black, size: 20),
              SizedBox(width: 8),
              Text(
                'Personal funding link copied to clipboard!',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: MPesaTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _shareViaWhatsApp() async {
    final message = Uri.encodeComponent(
      "Hi! You can support my campus meals and living on DISHI securely via Safaricom M-PESA. Any amount reflects in my student wallet instantly:\n$_fundLink"
    );
    final url = Uri.parse("https://wa.me/?text=$message");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _copyLink();
      }
    } catch (_) {
      _copyLink();
    }
  }

  Future<void> _previewWebPage() async {
    final url = Uri.parse(_fundLink);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not open preview: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0C101B);
    const cardColor = Color(0xFF131A2A);
    const surfaceLight = Color(0xFF1A2235);
    const neonCyan = Color(0xFF05D5AA);
    const neonPink = Color(0xFFF92B60);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fund Me • Upkeep Link',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Preview Web Page',
            icon: const Icon(Icons.open_in_browser, color: neonCyan),
            onPressed: _previewWebPage,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ─── Student Profile & Total Raised Live Stream ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF162033), Color(0xFF0F1726)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: neonCyan.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: neonCyan.withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: neonCyan,
                        child: Text(
                          _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: neonCyan, size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'DISHI ID: ${_dishiId.isNotEmpty ? _dishiId : "Verified Student"}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MPesaTheme.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, color: MPesaTheme.primaryGreen, size: 14),
                            SizedBox(width: 2),
                            Text(
                              'Active',
                              style: TextStyle(
                                color: MPesaTheme.primaryGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 10),

                  // Live total funds received stream
                  StreamBuilder<QuerySnapshot>(
                    stream: _effectiveUid.isNotEmpty
                        ? FirebaseFirestore.instance
                            .collection('transactions')
                            .where(
                              Filter.or(
                                Filter('studentId', isEqualTo: _effectiveUid),
                                Filter('student_id', isEqualTo: _effectiveUid),
                                Filter('user_id', isEqualTo: _effectiveUid),
                              ),
                            )
                            .snapshots()
                        : const Stream.empty(),
                    builder: (context, snapshot) {
                      double totalRaised = 0.0;
                      int supportersCount = 0;

                      if (snapshot.hasData && snapshot.data != null) {
                        for (final doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
                          final status = data['status'] as String? ?? 'completed';
                          if (status == 'completed' || status == 'success') {
                            totalRaised += amt;
                            supportersCount++;
                          }
                        }
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Total Support Received',
                                style: TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'KES ${NumberFormat("#,##0").format(totalRaised)}',
                                style: const TextStyle(
                                  color: neonCyan,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 32, color: Colors.white12),
                          Column(
                            children: [
                              const Text(
                                'Contributions',
                                style: TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$supportersCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Recent Supporters List ───
            StreamBuilder<QuerySnapshot>(
              stream: _effectiveUid.isNotEmpty
                  ? FirebaseFirestore.instance
                      .collection('transactions')
                      .where(
                        Filter.or(
                          Filter('studentId', isEqualTo: _effectiveUid),
                          Filter('student_id', isEqualTo: _effectiveUid),
                          Filter('user_id', isEqualTo: _effectiveUid),
                        ),
                      )
                      .limit(10)
                      .snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final docs = List<DocumentSnapshot>.from(snapshot.data!.docs);
                docs.sort((a, b) {
                  final rawA = a.data() as Map<String, dynamic>?;
                  final rawB = b.data() as Map<String, dynamic>?;
                  final tA = rawA?['timestamp'];
                  final tB = rawB?['timestamp'];
                  if (tA is Timestamp && tB is Timestamp) return tB.compareTo(tA);
                  return 0;
                });

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.favorite, color: neonPink, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Recent Supporters',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length > 5 ? 5 : docs.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final name = data['donor_name'] ?? data['donorName'] ?? data['senderPhone'] ?? 'Supporter';
                          final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
                          final ts = data['timestamp'];
                          String timeStr = 'Recently';
                          if (ts is Timestamp) {
                            timeStr = DateFormat('MMM d, h:mm a').format(ts.toDate());
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: neonCyan.withOpacity(0.15),
                                      child: const Icon(Icons.person, color: neonCyan, size: 14),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  '+ KES ${NumberFormat("#,##0").format(amt)}',
                                  style: const TextStyle(color: neonCyan, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            // ─── Direct Share Link Box ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.link_rounded, color: neonCyan, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Your Personal Web Funding Link',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Anyone who clicks this link can fund your meals & upkeep via M-PESA without downloading the app!',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _fundLink,
                            style: const TextStyle(
                              color: neonCyan,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _isCopied ? Icons.check_circle : Icons.copy_rounded,
                            color: _isCopied ? MPesaTheme.primaryGreen : Colors.white70,
                            size: 22,
                          ),
                          onPressed: _copyLink,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copyLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCopied ? MPesaTheme.primaryGreen : surfaceLight,
                            foregroundColor: _isCopied ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: _isCopied ? MPesaTheme.primaryGreen : Colors.white24),
                            ),
                            elevation: 0,
                          ),
                          icon: Icon(
                            _isCopied ? Icons.check : Icons.copy,
                            size: 18,
                            color: _isCopied ? Colors.black : Colors.white,
                          ),
                          label: Text(
                            _isCopied ? 'Link Copied' : 'Copy Link',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareViaWhatsApp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text(
                            'WhatsApp',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── In-Person QR Code Pass ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  const Text(
                    'In-Person QR Code',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Let friends or sponsors scan this directly with any camera',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: neonCyan.withOpacity(0.15),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _fundLink,
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Scans directly open your personalized page for $_displayName',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Transparency & Instant Settlement Guarantee ───
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '🛡️ How It Works',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  _FeatureBullet(
                    icon: Icons.flash_on,
                    text: 'Instant Credit: Payments via M-PESA reflect into your DISHI wallet immediately.',
                  ),
                  SizedBox(height: 8),
                  _FeatureBullet(
                    icon: Icons.restaurant,
                    text: 'Direct Spending: Tap to pay at all campus cafeteria food stalls & vendors.',
                  ),
                  SizedBox(height: 8),
                  _FeatureBullet(
                    icon: Icons.lock,
                    text: 'Transparent & Secure: 100% of contributions go directly to you without platform cut.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF05D5AA), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
