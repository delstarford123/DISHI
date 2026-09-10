import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/presentation/login_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _textSecondary = Color(0xFF8B9BB4);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);

// 5 Fundi categories
const List<Map<String, dynamic>> _categories = [
  {'label': 'Academic Support', 'icon': Icons.school, 'color': Color(0xFF3B82F6)},
  {'label': 'Tech & Digital', 'icon': Icons.computer, 'color': Color(0xFF10B981)},
  {'label': 'Daily Errands', 'icon': Icons.shopping_bag, 'color': Color(0xFFFF6F00)},
  {'label': 'Lifestyle & Grooming', 'icon': Icons.spa, 'color': Color(0xFFF92B60)},
  {'label': 'Trending Fundi', 'icon': Icons.trending_up, 'color': Color(0xFF9C27B0)},
];

class FundiDashboardView extends StatefulWidget {
  final Map<String, dynamic> user;

  const FundiDashboardView({super.key, required this.user});

  @override
  State<FundiDashboardView> createState() => _FundiDashboardViewState();
}

class _FundiDashboardViewState extends State<FundiDashboardView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';

  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ??
      widget.user['uid'] ??
      '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _ensureFundiProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Ensure fundi profile document exists so dashboard can show earnings
  Future<void> _ensureFundiProfile() async {
    if (_currentUid.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('fundi_profiles')
        .doc(_currentUid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': _currentUid,
        'name': widget.user['name'] ??
            widget.user['displayName'] ??
            'Fundi',
        'totalEarnings': 0.0,
        'completedJobs': 0,
        'rating': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch WhatsApp')));
      }
    }
  }

  Future<void> _acceptJob(String jobId) async {
    await FirebaseFirestore.instance
        .collection('fundi_jobs')
        .doc(jobId)
        .update({'status': 'accepted', 'fundi_id': _currentUid});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Job accepted! Await escrow deposit before starting work.'),
            backgroundColor: _neonCyan),
      );
    }
  }

  Future<void> _rejectJob(String jobId) async {
    await FirebaseFirestore.instance
        .collection('fundi_jobs')
        .doc(jobId)
        .update({'status': 'rejected'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job rejected.'), backgroundColor: _neonPink),
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Widget _buildCustomAppBar() {
    if (_isSearching) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => setState(() {
              _isSearching = false;
              _searchQuery = '';
            }),
          ),
          Expanded(
            child: TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search gigs...',
                hintStyle: TextStyle(color: _textSecondary),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
      );
    }

    final fundiName =
        widget.user['name'] ?? widget.user['displayName'] ?? 'Fundi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B29).withOpacity(0.8),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.handyman, color: _neonCyan, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_getGreeting(),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(fundiName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isSearching = true),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.search, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 80,
              floating: true,
              pinned: true,
              backgroundColor: _bgColor,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, top: 16),
                  child: _buildCustomAppBar(),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: MPesaTheme.primaryGreen,
                    labelColor: MPesaTheme.primaryGreen,
                    unselectedLabelColor: Colors.white54,
                    isScrollable: true,
                    tabs: _categories
                        .map((c) => Tab(
                            icon: Icon(c['icon'] as IconData, size: 18),
                            text: c['label'] as String))
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
          body: Column(
            children: [
              // Earnings Banner — live from fundi_profiles
              StreamBuilder<DocumentSnapshot>(
                stream: _currentUid.isEmpty
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('fundi_profiles')
                        .doc(_currentUid)
                        .snapshots(),
                builder: (context, snap) {
                  final data =
                      snap.data?.data() as Map<String, dynamic>? ?? {};
                  final earnings =
                      (data['totalEarnings'] as num?)?.toDouble() ?? 0.0;
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          MPesaTheme.primaryGreen.withOpacity(0.85),
                          MPesaTheme.primaryGreen.withOpacity(0.45)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.account_balance_wallet,
                              color: Colors.black, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Earnings',
                                  style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold)),
                              Text('KES ${earnings.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _categories.map((cat) {
                    final label = cat['label'] as String;
                    if (label == 'Trending Fundi') {
                      return _buildTrendingFundi();
                    }
                    return _buildCategoryJobList(label);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Category tab: streams fundi_jobs filtered by category and current fundi
  Widget _buildCategoryJobList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fundi_jobs')
          .where('category', isEqualTo: category)
          .where('status', whereIn: ['open', 'accepted', 'completed'])
          .orderBy('createdAt', descending: true)
          .limit(40)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: MPesaTheme.primaryGreen));
        }
        final docs = snapshot.data?.docs ?? [];

        // Apply local search filter
        final filtered = docs.where((doc) {
          final job = doc.data() as Map<String, dynamic>;
          final title = (job['title'] ?? '').toString().toLowerCase();
          return _searchQuery.isEmpty ||
              title.contains(_searchQuery.toLowerCase());
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_outline,
                    size: 56, color: _textSecondary.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text('No $category jobs yet.',
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final job = doc.data() as Map<String, dynamic>;
            final jobId = doc.id;
            final isMine = job['fundi_id'] == _currentUid ||
                job['poster_id'] == _currentUid;
            final isOpen = job['status'] == 'open';
            final isAccepted = job['status'] == 'accepted';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(job['title'] ?? 'Untitled',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      Text('KES ${job['amount'] ?? 0}',
                          style: const TextStyle(
                              color: MPesaTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                  if ((job['description'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(job['description'] ?? '',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: _statusColor(job['status'] ?? '')
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(job['status'] ?? 'open',
                            style: TextStyle(
                                color: _statusColor(
                                    job['status'] ?? ''),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(job['payer_name'] ?? job['poster_name'] ?? '',
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Accept/Reject visible to fundis who haven't yet responded
                  if (isOpen && !isMine)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectJob(jobId),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: _textSecondary)),
                            child: const Text('Reject',
                                style: TextStyle(
                                    color: _textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _acceptJob(jobId),
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    MPesaTheme.primaryGreen),
                            child: const Text('Accept',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  // WhatsApp contact for accepted jobs
                  if (isAccepted && (job['phone'] ?? '').isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _launchWhatsApp(job['phone']),
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF25D366)),
                        icon: const Icon(Icons.chat,
                            color: Colors.white, size: 18),
                        label: const Text('Chat on WhatsApp',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Trending Fundi tab — ordered by completedJobs desc
  Widget _buildTrendingFundi() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fundi_profiles')
          .orderBy('completedJobs', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _neonPink));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No trending fundis yet.',
                style: TextStyle(color: _textSecondary, fontSize: 15)),
          );
        }
        return ListView.builder(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final fundi = docs[index].data() as Map<String, dynamic>;
            final avatar = fundi['profileImageUrl'] as String?;
            final name = fundi['name'] ?? 'Fundi';
            final completedJobs =
                (fundi['completedJobs'] as num?)?.toInt() ?? 0;
            final rating =
                (fundi['rating'] as num?)?.toDouble() ?? 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF9C27B0).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _surfaceLight,
                    backgroundImage:
                        avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? Text(name.isNotEmpty ? name[0] : '?',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12)),
                            const SizedBox(width: 12),
                            const Icon(Icons.check_circle,
                                color: _neonCyan, size: 14),
                            const SizedBox(width: 4),
                            Text('$completedJobs jobs',
                                style: const TextStyle(
                                    color: _neonCyan, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showHireDialog(context, fundi,
                        docs[index].id),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: MPesaTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8)),
                    child: const Text('Hire',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHireDialog(
      BuildContext context, Map<String, dynamic> fundi, String fundiId) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = _categories[0]['label'] as String;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                  color: MPesaTheme.primaryGreen, width: 1.5)),
          title: Text('Hire ${fundi['name'] ?? 'Fundi'}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(titleCtrl, 'Job Title'),
                const SizedBox(height: 12),
                _dialogField(descCtrl, 'Description', maxLines: 3),
                const SizedBox(height: 12),
                _dialogField(amountCtrl, 'Amount (KES)',
                    isNumber: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: _surfaceLight,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle:
                        const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: _categories
                      .where((c) =>
                          c['label'] != 'Trending Fundi')
                      .map((c) => DropdownMenuItem(
                          value: c['label'] as String,
                          child: Text(c['label'] as String)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedCategory = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: _textSecondary))),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    amountCtrl.text.trim().isEmpty) return;
                await FirebaseFirestore.instance
                    .collection('fundi_jobs')
                    .add({
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text.trim()) ?? 0,
                  'category': selectedCategory,
                  'poster_id': _currentUid,
                  'fundi_id': fundiId,
                  'status': 'open',
                  'payer_name': widget.user['name'] ??
                      widget.user['displayName'] ??
                      'Client',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Hire request sent!'),
                        backgroundColor: _neonCyan),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.primaryGreen),
              child: const Text('Send Hire Request',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label,
      {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType:
          isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return _neonCyan;
      case 'accepted':
        return MPesaTheme.primaryGreen;
      case 'completed':
        return Colors.amber;
      case 'rejected':
        return _neonPink;
      default:
        return _textSecondary;
    }
  }
}
