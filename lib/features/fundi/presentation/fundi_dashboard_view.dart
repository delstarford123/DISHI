import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'widgets/fundi_payout_dialog.dart';
import 'widgets/fundi_invoice_generator_dialog.dart';
import 'widgets/fundi_service_manager_dialog.dart';
import 'widgets/fundi_profile_sheet.dart';
import '../../student/presentation/student_main_scaffold.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A26);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _textSecondary = Color(0xFF8B9BB4);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _neonBlue = Color(0xFF2979FF);

class FundiDashboardView extends StatefulWidget {
  final Map<String, dynamic> user;

  const FundiDashboardView({super.key, required this.user});

  @override
  State<FundiDashboardView> createState() => _FundiDashboardViewState();
}

class _FundiDashboardViewState extends State<FundiDashboardView>
    with SingleTickerProviderStateMixin {
  int _currentTabIndex = 0;
  bool _isSearching = false;
  String _searchQuery = '';
  String _gigsFilter = 'all'; // 'all', 'pending', 'active', 'completed', 'declined'
  String _marketCategoryFilter = 'All';

  bool _isAvailable = true;

  final List<String> _marketCategories = [
    'All',
    'Tech & Digital',
    'Academic Support',
    'Daily Errands',
    'Lifestyle & Grooming',
    'Hardware & Repairs',
    'Housing Maintenance',
  ];

  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ??
      widget.user['uid'] ??
      '';

  String get _fundiName =>
      widget.user['displayName'] ??
      widget.user['name'] ??
      'Comrade Fundi';

  String get _fundiPhone =>
      widget.user['phoneNumber'] ??
      widget.user['phone'] ??
      '';

  @override
  void initState() {
    super.initState();
    _ensureFundiProfile();
  }

  /// Ensure fundi profile document exists so dashboard can track earnings & balance
  Future<void> _ensureFundiProfile() async {
    if (_currentUid.isEmpty) return;
    try {
      final profileRef = FirebaseFirestore.instance.collection('fundi_profiles').doc(_currentUid);
      final profileSnap = await profileRef.get();
      if (!profileSnap.exists) {
        await profileRef.set({
          'uid': _currentUid,
          'name': _fundiName,
          'phone': _fundiPhone,
          'totalEarnings': 0.0,
          'completedJobs': 0,
          'rating': 5.0,
          'isAvailable': true,
          'is_available': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final data = profileSnap.data();
        if (data != null && data.containsKey('isAvailable')) {
          setState(() {
            _isAvailable = data['isAvailable'] == true;
          });
        }
      }

      // Also ensure users document has fundiBalance initialized
      final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUid);
      final userSnap = await userRef.get();
      if (userSnap.exists) {
        final uData = userSnap.data();
        if (uData != null && !uData.containsKey('fundiBalance')) {
          await userRef.set({'fundiBalance': 0.0}, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('Error ensuring fundi profile: $e');
    }
  }

  Future<void> _toggleAvailability() async {
    final next = !_isAvailable;
    setState(() => _isAvailable = next);
    try {
      await FirebaseFirestore.instance.collection('fundi_profiles').doc(_currentUid).set({
        'isAvailable': next,
        'is_available': next,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('campus_gig_workers').doc(_currentUid).set({
        'is_available': next,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next ? '🟢 You are Online & accepting campus gigs!' : '⏸️ You are Offline / on break.'),
            backgroundColor: next ? _neonCyan : _neonPink,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to toggle availability: $e');
    }
  }

  Future<void> _launchWhatsApp(String phone, {String? customMessage}) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final msg = customMessage ??
        'Hello! I am $_fundiName from DISHI Fundi. I am contacting you regarding your campus gig request.';
    final encoded = Uri.encodeComponent(msg);
    final url = Uri.parse('https://wa.me/$clean?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('tel:$clean');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
    }
  }

  Future<void> _acceptJob(String jobId) async {
    try {
      await FirebaseFirestore.instance.collection('fundi_jobs').doc(jobId).update({
        'status': 'accepted',
        'fundi_id': _currentUid,
        'fundi_name': _fundiName,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gig accepted! Client notified. Check My Gigs to contact client.'),
            backgroundColor: _neonCyan,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept gig: $e')),
        );
      }
    }
  }

  Future<void> _updateJobProgress(String jobId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('fundi_jobs').doc(jobId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to: ${newStatus.toUpperCase()}'),
            backgroundColor: _neonCyan,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _rejectJob(String jobId) async {
    try {
      await FirebaseFirestore.instance.collection('fundi_jobs').doc(jobId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job declined.'), backgroundColor: _neonPink),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining gig: $e')),
        );
      }
    }
  }

  Future<void> _markJobComplete(String jobId, double amount) async {
    final escrowFee = amount * 0.015;
    final netCredit = amount - escrowFee;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: _neonCyan, size: 24),
            SizedBox(width: 10),
            Expanded(child: Text('Complete Gig?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm that the service is fully delivered to the client’s satisfaction.',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _confirmRow('Gross Amount', 'KES ${amount.toStringAsFixed(2)}'),
                  const SizedBox(height: 4),
                  _confirmRow('DISHI Escrow Fee (1.5%)', '- KES ${escrowFee.toStringAsFixed(2)}', color: _neonPink),
                  const Divider(color: Colors.white12, height: 14),
                  _confirmRow('Net Credited to Wallet', 'KES ${netCredit.toStringAsFixed(2)}', isBold: true, color: _neonCyan),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonCyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Completion', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('fundi_jobs').doc(jobId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'escrow_fee': escrowFee,
        'net_amount': netCredit,
      });

      // Increment fundi profile stats
      await FirebaseFirestore.instance.collection('fundi_profiles').doc(_currentUid).set({
        'completedJobs': FieldValue.increment(1),
        'totalEarnings': FieldValue.increment(netCredit),
      }, SetOptions(merge: true));

      // Increment users fundiBalance for instant M-PESA withdrawal support
      await FirebaseFirestore.instance.collection('users').doc(_currentUid).set({
        'fundiBalance': FieldValue.increment(netCredit),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Gig completed! KES ${netCredit.toStringAsFixed(2)} credited to your wallet.'),
            backgroundColor: _neonCyan,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update job: $e')),
        );
      }
    }
  }

  Widget _confirmRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color ?? _textSecondary, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openPayoutDialog(double balance) {
    showDialog(
      context: context,
      builder: (_) => FundiPayoutDialog(
        currentBalance: balance,
        fundiId: _currentUid,
        fundiPhone: _fundiPhone,
        onPayoutSuccess: () => setState(() {}),
      ),
    );
  }

  void _openInvoiceDialog() {
    showDialog(
      context: context,
      builder: (_) => FundiInvoiceGeneratorDialog(
        fundiId: _currentUid,
        fundiName: _fundiName,
        fundiPhone: _fundiPhone,
      ),
    );
  }

  void _openServiceManagerDialog() {
    showDialog(
      context: context,
      builder: (_) => FundiServiceManagerDialog(fundiId: _currentUid),
    );
  }

  void _openProfileSheet(Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FundiProfileSheet(
        fundiId: _currentUid,
        fundiName: _fundiName,
        fundiPhone: _fundiPhone,
        initialProfile: profile,
        onAvailabilityChanged: (v) => setState(() => _isAvailable = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildWorkspaceOverviewTab(),
                  _buildMyGigsHubTab(),
                  _buildCampusLeadsMarketTab(),
                  _buildRateCardServicesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCustomAppBar() {
    if (_isSearching) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: _cardColor,
        child: Row(
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
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search gigs, clients, campus hostels...',
                  hintStyle: TextStyle(color: _textSecondary, fontSize: 13),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                onPressed: () => setState(() => _searchQuery = ''),
              ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _currentUid.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance.collection('fundi_profiles').doc(_currentUid).snapshots(),
      builder: (context, snap) {
        final profile = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final bool isOnline = profile['isAvailable'] ?? profile['is_available'] ?? _isAvailable;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _cardColor.withOpacity(0.95),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            children: [
              // Return / Back to Student Dashboard Button
              IconButton(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => StudentMainScaffold(user: widget.user)),
                    );
                  }
                },
                tooltip: 'Student Dashboard',
              ),
              const SizedBox(width: 8),

              // Avatar with Online Indicator Dot
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _surfaceLight,
                    child: Text(
                      _fundiName.isNotEmpty ? _fundiName[0].toUpperCase() : 'F',
                      style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOnline ? _neonCyan : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: _cardColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),

              // Title & Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${_getGreeting()},',
                            style: const TextStyle(color: _textSecondary, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: _neonCyan, size: 12),
                      ],
                    ),
                    Text(
                      _fundiName,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Quick Online / Offline Switch Pill
              InkWell(
                onTap: _toggleAvailability,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline ? _neonCyan.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOnline ? _neonCyan.withOpacity(0.5) : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnline ? _neonCyan : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: isOnline ? _neonCyan : Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Search Icon
              IconButton(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.search, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _isSearching = true),
                tooltip: 'Search Gigs',
              ),
              const SizedBox(width: 4),

              // Settings / Profile Sheet
              IconButton(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.tune, color: Colors.white70, size: 20),
                onPressed: () => _openProfileSheet(profile),
                tooltip: 'Fundi Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BOTTOM NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _neonCyan,
        unselectedItemColor: Colors.white54,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Workspace',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in_outlined),
            activeIcon: Icon(Icons.assignment_turned_in),
            label: 'My Gigs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Campus Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.price_change_outlined),
            activeIcon: Icon(Icons.price_change),
            label: 'Rate Card',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 1: WORKSPACE / OVERVIEW TAB
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildWorkspaceOverviewTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _currentUid.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance.collection('fundi_profiles').doc(_currentUid).snapshots(),
      builder: (context, profileSnap) {
        final profile = (profileSnap.data?.data() as Map<String, dynamic>?) ?? {};
        final double earnings = (profile['totalEarnings'] as num?)?.toDouble() ?? 0.0;
        final int completedJobs = (profile['completedJobs'] as num?)?.toInt() ?? 0;
        final double rating = (profile['rating'] as num?)?.toDouble() ?? 5.0;

        return StreamBuilder<QuerySnapshot>(
          stream: _currentUid.isEmpty
              ? const Stream.empty()
              : FirebaseFirestore.instance
                  .collection('fundi_jobs')
                  .where('fundi_id', isEqualTo: _currentUid)
                  .snapshots(),
          builder: (context, gigsSnap) {
            final docs = gigsSnap.data?.docs ?? [];
            final gigs = docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();

            final activeGigs = gigs.where((g) => g['status'] == 'accepted' || g['status'] == 'in_progress').toList();
            final pendingRequests = gigs.where((g) => g['status'] == 'open').toList();

            // Calculate funds in Escrow (all currently active jobs waiting for completion)
            double inEscrow = 0.0;
            for (var g in activeGigs) {
              inEscrow += (g['amount'] as num?)?.toDouble() ?? 0.0;
            }

            return RefreshIndicator(
              color: _neonCyan,
              backgroundColor: _cardColor,
              onRefresh: () async => setState(() {}),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Financial Hero Card
                    _buildWalletCommandCard(earnings, inEscrow),
                    const SizedBox(height: 16),

                    // 4 Quick Operational Metrics
                    _buildMetricsGrid(completedJobs, rating, activeGigs.length, pendingRequests.length),
                    const SizedBox(height: 20),

                    // Quick Action Tools
                    _buildQuickActionButtons(earnings),
                    const SizedBox(height: 24),

                    // Active Ongoing Job Spotlight (If any job is currently in progress)
                    if (activeGigs.isNotEmpty) ...[
                      _buildActiveJobSpotlight(activeGigs.first),
                      const SizedBox(height: 24),
                    ],

                    // Action Needed: Incoming Gig Requests Tray
                    if (pendingRequests.isNotEmpty) ...[
                      _buildIncomingRequestsSection(pendingRequests),
                      const SizedBox(height: 24),
                    ],

                    // DISHI Escrow & Comrade Trust Guarantee Banner
                    _buildTrustEscrowBanner(),
                    const SizedBox(height: 24),

                    // Recent Completed Gigs Ledger
                    _buildRecentEarningsLedger(gigs.where((g) => g['status'] == 'completed').take(5).toList()),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWalletCommandCard(double balance, double inEscrow) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF131A26),
            const Color(0xFF1E283D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _neonCyan.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _neonCyan.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: MPesaTheme.primaryGreen.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: MPesaTheme.primaryGreen, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Withdrawable Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('M-PESA Instant', style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'KES ${balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Locked in DISHI Escrow', style: TextStyle(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('KES ${inEscrow.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: balance >= 50 ? () => _openPayoutDialog(balance) : null,
                icon: const Icon(Icons.bolt, color: Colors.black, size: 15),
                label: const Text('Withdraw M-PESA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.primaryGreen,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(int completed, double rating, int active, int pending) {
    return Row(
      children: [
        Expanded(child: _metricCard('Active Gigs', '$active', Icons.work, _neonCyan)),
        const SizedBox(width: 6),
        Expanded(child: _metricCard('Pending', '$pending', Icons.notifications_active, pending > 0 ? _neonOrange : _textSecondary)),
        const SizedBox(width: 6),
        Expanded(child: _metricCard('Completed', '$completed', Icons.task_alt, MPesaTheme.primaryGreen)),
        const SizedBox(width: 6),
        Expanded(child: _metricCard('Rating', rating.toStringAsFixed(1), Icons.star, Colors.amber)),
      ],
    );
  }

  Widget _metricCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(val, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 10),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(double balance) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            'Smart Quote',
            Icons.receipt_long,
            _neonCyan,
            _openInvoiceDialog,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            'My Services',
            Icons.handyman,
            _neonBlue,
            _openServiceManagerDialog,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            'Cash Out',
            Icons.account_balance,
            MPesaTheme.primaryGreen,
            () => _openPayoutDialog(balance),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveJobSpotlight(Map<String, dynamic> job) {
    final title = job['title'] ?? 'Ongoing Gig';
    final amount = (job['amount'] as num?)?.toDouble() ?? 0.0;
    final clientName = job['payer_name'] ?? job['poster_name'] ?? 'Client';
    final phone = job['phone']?.toString() ?? '';
    final status = job['status'] ?? 'accepted';
    final jobId = job['id'] as String;
    final location = job['location'] ?? 'Hostel Room';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonCyan.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _neonCyan.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _neonCyan,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('CURRENT TASK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'KES ${amount.toStringAsFixed(0)}',
                style: const TextStyle(color: _neonCyan, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person, color: _textSecondary, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text('Client: $clientName', style: const TextStyle(color: _textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.location_on, color: _textSecondary, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(location, style: const TextStyle(color: _textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action buttons: Call, WhatsApp, Complete
          Row(
            children: [
              if (phone.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _neonCyan),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _callPhone(phone),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone, size: 14, color: _neonCyan),
                          SizedBox(width: 4),
                          Text('Call', style: TextStyle(color: _neonCyan, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _launchWhatsApp(phone, customMessage: 'Hi $clientName! I am on my way for your DISHI gig: $title.'),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (status == 'accepted')
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonBlue,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _updateJobProgress(jobId, 'in_progress'),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, color: Colors.black, size: 15),
                          SizedBox(width: 4),
                          Text('Start', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  flex: phone.isNotEmpty ? 1 : 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _markJobComplete(jobId, amount),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.black, size: 15),
                          SizedBox(width: 4),
                          Text('Complete', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsSection(List<Map<String, dynamic>> requests) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: _neonOrange, size: 18),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Action Needed: New Gig Requests',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _neonOrange, borderRadius: BorderRadius.circular(10)),
              child: Text('${requests.length}', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...requests.map((r) => _buildPendingRequestCard(r)),
      ],
    );
  }

  Widget _buildPendingRequestCard(Map<String, dynamic> r) {
    final title = r['title'] ?? 'Gig Request';
    final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
    final client = r['payer_name'] ?? r['poster_name'] ?? 'Client';
    final desc = r['description'] ?? '';
    final jobId = r['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonOrange.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Text('KES ${amount.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Client: $client', style: const TextStyle(color: _textSecondary, fontSize: 12)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectJob(jobId),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Decline', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _acceptJob(jobId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Accept Gig & Start', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustEscrowBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _neonCyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonCyan.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.shield, color: _neonCyan, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DISHI Escrow Guaranteed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 2),
                Text(
                  'Client funds are locked upon hire and disbursed straight to your wallet immediately when you mark the gig complete.',
                  style: TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEarningsLedger(List<Map<String, dynamic>> completedGigs) {
    if (completedGigs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Completed Earnings', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...completedGigs.map((g) {
          final title = g['title'] ?? 'Completed Gig';
          final amount = (g['amount'] as num?)?.toDouble() ?? 0.0;
          final net = (g['net_amount'] as num?)?.toDouble() ?? (amount * 0.985);
          final client = g['payer_name'] ?? 'Client';
          final ts = g['completedAt'] as Timestamp?;
          final dateStr = ts != null ? DateFormat('d MMM, h:mm a').format(ts.toDate()) : 'Recently';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: MPesaTheme.primaryGreen.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: MPesaTheme.primaryGreen, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1),
                      const SizedBox(height: 2),
                      Text('$client • $dateStr', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('+ KES ${net.toStringAsFixed(0)}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontSize: 14, fontWeight: FontWeight.bold)),
                    const Text('Escrow Released', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 2: MY GIGS HUB TAB
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMyGigsHubTab() {
    return Column(
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _filterChip('all', 'All Gigs'),
              const SizedBox(width: 8),
              _filterChip('pending', 'Action Needed'),
              const SizedBox(width: 8),
              _filterChip('active', 'In Progress'),
              const SizedBox(width: 8),
              _filterChip('completed', 'Completed'),
              const SizedBox(width: 8),
              _filterChip('declined', 'Declined'),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _currentUid.isEmpty
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('fundi_jobs')
                    .where('fundi_id', isEqualTo: _currentUid)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _neonCyan));
              }
              final docs = snapshot.data?.docs ?? [];
              var list = docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();

              // Sort newest first
              list.sort((a, b) {
                final aT = a['createdAt'] as Timestamp?;
                final bT = b['createdAt'] as Timestamp?;
                if (aT == null || bT == null) return 0;
                return bT.compareTo(aT);
              });

              // Apply status filter
              if (_gigsFilter == 'pending') {
                list = list.where((g) => g['status'] == 'open').toList();
              } else if (_gigsFilter == 'active') {
                list = list.where((g) => g['status'] == 'accepted' || g['status'] == 'in_progress').toList();
              } else if (_gigsFilter == 'completed') {
                list = list.where((g) => g['status'] == 'completed').toList();
              } else if (_gigsFilter == 'declined') {
                list = list.where((g) => g['status'] == 'rejected').toList();
              }

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                list = list.where((g) {
                  final title = (g['title'] ?? '').toString().toLowerCase();
                  final desc = (g['description'] ?? '').toString().toLowerCase();
                  final client = (g['payer_name'] ?? g['poster_name'] ?? '').toString().toLowerCase();
                  return title.contains(q) || desc.contains(q) || client.contains(q);
                }).toList();
              }

              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 56, color: _textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text('No ${_gigsFilter == "all" ? "" : _gigsFilter} gigs found', style: const TextStyle(color: _textSecondary, fontSize: 15)),
                      const SizedBox(height: 6),
                      const Text('When students or staff hire you, they appear here.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, index) => _buildGigLifecycleCard(list[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String code, String label) {
    final isSelected = _gigsFilter == code;
    return InkWell(
      onTap: () => setState(() => _gigsFilter = code),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _neonCyan.withOpacity(0.18) : _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _neonCyan : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _neonCyan : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildGigLifecycleCard(Map<String, dynamic> job) {
    final jobId = job['id'] as String;
    final title = job['title'] ?? 'Untitled Gig';
    final amount = (job['amount'] as num?)?.toDouble() ?? 0.0;
    final status = job['status'] ?? 'open';
    final clientName = job['payer_name'] ?? job['poster_name'] ?? 'Client';
    final phone = job['phone']?.toString() ?? '';
    final category = job['category'] ?? 'General';
    final desc = job['description'] ?? '';
    final location = job['location'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'accepted' || status == 'in_progress'
              ? _neonCyan.withOpacity(0.5)
              : (status == 'completed' ? MPesaTheme.primaryGreen.withOpacity(0.4) : Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Text(
                'KES ${amount.toStringAsFixed(0)}',
                style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (desc.isNotEmpty) ...[
            Text(desc, style: const TextStyle(color: _textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(category, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('• $clientName', style: const TextStyle(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, color: _textSecondary, size: 12),
                const SizedBox(width: 4),
                Text(location, style: const TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Action rows based on lifecycle state
          if (status == 'open') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectJob(jobId),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Decline', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _acceptJob(jobId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Accept Gig', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ] else if (status == 'accepted' || status == 'in_progress') ...[
            Row(
              children: [
                if (phone.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone, size: 14, color: _neonCyan),
                      label: const Text('Call', style: TextStyle(color: _neonCyan, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _neonCyan),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _callPhone(phone),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat, size: 14, color: Colors.white),
                      label: const Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _launchWhatsApp(phone),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (status == 'accepted')
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow, color: Colors.black, size: 15),
                      label: const Text('Start Work', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _updateJobProgress(jobId, 'in_progress'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.black, size: 15),
                      label: const Text('Complete', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonCyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _markJobComplete(jobId, amount),
                    ),
                  ),
              ],
            ),
          ] else if (status == 'completed') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MPesaTheme.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: MPesaTheme.primaryGreen, size: 16),
                  const SizedBox(width: 8),
                  const Text('Gig Completed • Payment Released to Profile', style: TextStyle(color: MPesaTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 3: CAMPUS LEADS / OPEN JOB MARKET TAB
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCampusLeadsMarketTab() {
    return Column(
      children: [
        // Category Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: _marketCategories.map((c) {
              final isSel = _marketCategoryFilter == c;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _marketCategoryFilter = c),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel ? _neonCyan.withOpacity(0.18) : _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSel ? _neonCyan : Colors.white12),
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        color: isSel ? _neonCyan : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('fundi_jobs')
                .where('status', isEqualTo: 'open')
                .limit(40)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _neonCyan));
              }
              final docs = snapshot.data?.docs ?? [];
              var list = docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();

              // Filter out jobs already assigned to someone else
              list = list.where((g) => g['fundi_id'] == null || g['fundi_id'] == '' || g['fundi_id'] == _currentUid).toList();

              // Category filter
              if (_marketCategoryFilter != 'All') {
                list = list.where((g) => g['category'] == _marketCategoryFilter).toList();
              }

              // Search query
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                list = list.where((g) {
                  final title = (g['title'] ?? '').toString().toLowerCase();
                  final desc = (g['description'] ?? '').toString().toLowerCase();
                  return title.contains(q) || desc.contains(q);
                }).toList();
              }

              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore_off_outlined, size: 56, color: _textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      const Text('No open campus requests right now', style: TextStyle(color: _textSecondary, fontSize: 15)),
                      const SizedBox(height: 6),
                      const Text('New gigs posted by comrades will appear here live.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final job = list[index];
                  final jobId = job['id'] as String;
                  final title = job['title'] ?? 'Open Campus Request';
                  final amount = (job['amount'] as num?)?.toDouble() ?? 0.0;
                  final category = job['category'] ?? 'Service';
                  final desc = job['description'] ?? '';
                  final location = job['location'] ?? 'Campus';
                  final client = job['payer_name'] ?? 'Comrade Student';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _neonCyan.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text(category, style: const TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            Text(
                              'Budget: KES ${amount.toStringAsFixed(0)}',
                              style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(desc, style: const TextStyle(color: _textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.person_pin, color: Colors.white38, size: 14),
                            const SizedBox(width: 4),
                            Text('Posted by $client', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(width: 12),
                            const Icon(Icons.location_on, color: Colors.white38, size: 14),
                            const SizedBox(width: 4),
                            Text(location, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openInvoiceDialog(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _neonCyan),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Send Quote / Bid', style: TextStyle(color: _neonCyan, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _acceptJob(jobId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MPesaTheme.primaryGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Claim Gig', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 4: RATE CARD & SERVICES TAB
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildRateCardServicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.price_check, color: _neonCyan, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Public Rate Card', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text(
                        'Services visible to students hiring you.',
                        style: TextStyle(color: _textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _openServiceManagerDialog,
                  icon: const Icon(Icons.add, size: 14, color: Colors.black),
                  label: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Live services list from Firestore
          StreamBuilder<QuerySnapshot>(
            stream: _currentUid.isEmpty
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('fundi_profiles')
                    .doc(_currentUid)
                    .collection('services')
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _neonCyan));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.handyman_outlined, color: Colors.white24, size: 48),
                        const SizedBox(height: 12),
                        const Text('No custom services listed yet.', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                          'Add services like "Laptop Repair", "Screen Replacement", "Room Cleaning", or "Calculus Tutoring" with your custom pricing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _openServiceManagerDialog,
                          style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
                          child: const Text('Setup Services & Rates', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: docs.map((d) {
                  final s = d.data() as Map<String, dynamic>;
                  final title = s['title'] ?? 'Service';
                  final price = (s['price'] as num?)?.toDouble() ?? 0.0;
                  final category = s['category'] ?? 'General';
                  final duration = s['duration'] ?? '';
                  final desc = s['description'] ?? '';
                  final isActive = s['isActive'] ?? true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isActive ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.03)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _categoryColor(category).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_categoryIcon(category), color: _categoryColor(category), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        color: isActive ? Colors.white : Colors.white38,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        decoration: isActive ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'KES ${price.toStringAsFixed(0)}',
                                    style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(category, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                                  if (duration.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text('• $duration', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                                  ],
                                ],
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return _neonCyan;
      case 'accepted':
      case 'in_progress':
        return MPesaTheme.primaryGreen;
      case 'completed':
        return Colors.amber;
      case 'rejected':
      case 'cancelled':
        return _neonPink;
      default:
        return _textSecondary;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Academic Support':
        return const Color(0xFF3B82F6);
      case 'Tech & Digital':
        return const Color(0xFF10B981);
      case 'Daily Errands':
        return _neonOrange;
      case 'Lifestyle & Grooming':
        return _neonPink;
      case 'Hardware & Repairs':
        return const Color(0xFFF59E0B);
      default:
        return _neonCyan;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Academic Support':
        return Icons.school;
      case 'Tech & Digital':
        return Icons.computer;
      case 'Daily Errands':
        return Icons.shopping_bag;
      case 'Lifestyle & Grooming':
        return Icons.content_cut;
      case 'Hardware & Repairs':
        return Icons.build;
      default:
        return Icons.handyman;
    }
  }
}
