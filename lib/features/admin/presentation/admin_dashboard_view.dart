import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/high_friction_action.dart';
import '../../student/presentation/student_main_scaffold.dart';
import '../../vendor/presentation/vendor_dashboard_view.dart';
import '../../auth/presentation/login_view.dart';
import 'fraud_velocity_view.dart';
import 'admin_support_tickets_view.dart';
import 'admin_transactions_view.dart';
import '../../../core/services/firestore_service.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminDashboardView extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminDashboardView({super.key, required this.user});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  bool _isLoading = true;
  int _activeUsers = 0;
  int _activeVendors = 0;
  double _systemFloat = 0.0;
  int _flaggedTransactions = 0;

  @override
  void initState() {
    super.initState();
    _fetchAdminStats();
  }

  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _fetchAdminStats() async {
    try {
      final usersCount = await _firestoreService.getCollectionCount('users', whereField: 'role', isEqualTo: 'student');
      final vendorsCount = await _firestoreService.getCollectionCount('users', whereField: 'role', isEqualTo: 'vendor');
      final floatSum = await _firestoreService.getCollectionSum('users', 'walletBalance');
      
      if (mounted) {
        setState(() {
          _activeUsers = usersCount;
          _activeVendors = vendorsCount;
          _systemFloat = floatSum;
          _flaggedTransactions = 0; // Keeping 0 for now until fraud logic is live
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading stats: $e'), backgroundColor: _neonRed));
      }
    }
  }

  Future<void> _processMassPayouts() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mass Payouts queued successfully!'), backgroundColor: _neonCyan),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payout Error: ${e.toString()}'), backgroundColor: _neonRed),
        );
      }
    }
  }

  bool _isSearching = false;
  String _searchQuery = '';

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _showProfileMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonRed, width: 2)),
        title: const Text('Profile Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: _neonRed),
              title: const Text('My Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile coming soon')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: _neonRed),
              title: const Text('Logout', style: TextStyle(color: _neonRed)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: _neonRed))),
        ],
      ),
    );
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
                hintText: 'Search...',
                hintStyle: TextStyle(color: _textSecondary),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
      );
    }

    final adminName = widget.user['name'] ?? widget.user['displayName'] ?? 'Super Admin';
    final profileImageUrl = widget.user['profileImageUrl'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B29).withOpacity(0.8),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => _showProfileMenu(context),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : const AssetImage('assets/img/dishi_logo.png') as ImageProvider,
                  backgroundColor: _surfaceLight,
                  child: profileImageUrl == null ? const Icon(Icons.admin_panel_settings, color: _neonRed, size: 20) : null,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bgColor, width: 2),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_getGreeting(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  adminName, 
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
      drawer: _buildRoleSwitcherDrawer(),
      body: SafeArea(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: _neonRed))
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 80,
                    floating: true,
                    pinned: false,
                    backgroundColor: _bgColor,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Padding(
                        padding: const EdgeInsets.only(left: 60, right: 16, top: 16),
                        child: _buildCustomAppBar(),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // System Float Summary
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTransactionsView())),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _neonRed.withOpacity(0.4), width: 1.5),
                              boxShadow: [BoxShadow(color: _neonRed.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.account_balance, color: _neonRed, size: 20),
                                    SizedBox(width: 8),
                                    Text('Total System Float (Tap for Ledger)', style: TextStyle(color: _textSecondary, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'KSH ${_systemFloat.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
    
                        // Key Metrics
                        const Text('System Overview', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildSystemStat('Active Users', '$_activeUsers', Icons.people, _neonCyan)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSystemStat('Vendors', '$_activeVendors', Icons.storefront, _neonOrange)),
                          ],
                        ),
                        const SizedBox(height: 32),
    
                        // Quick Actions
                        const Text('Admin Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        ListTile(
                          tileColor: _surfaceLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _flaggedTransactions > 0 ? _neonRed : _surfaceLight)
                          ),
                          leading: Badge(
                            isLabelVisible: _flaggedTransactions > 0,
                            label: Text('$_flaggedTransactions'),
                            child: const Icon(Icons.security, color: _neonRed),
                          ),
                          title: const Text('Fraud & Wash Trading Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Review velocity limit flags', style: TextStyle(color: _textSecondary)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const FraudVelocityView()));
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        ListTile(
                          tileColor: _surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.notifications_active, color: _neonCyan),
                          title: const Text('Send Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Broadcast or direct messages', style: TextStyle(color: _textSecondary)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white),
                          onTap: _showSendNotificationSheet,
                        ),
                        const SizedBox(height: 12),
                        
                        ListTile(
                          tileColor: _surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.support_agent, color: _neonBlue),
                          title: const Text('Dispute Resolution', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Manage escrow & offline disputes', style: TextStyle(color: _textSecondary)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white),
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSupportTicketsView()));
                          },
                        ),
                        const SizedBox(height: 32),
                        
                        const Text('Financial Operations', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: HighFrictionAction(
                            label: 'Hold for Mass B2C Payouts',
                            onActionCompleted: _processMassPayouts,
                            baseColor: _neonRed,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRoleSwitcherDrawer() {
    final roles = List<String>.from(widget.user['roles'] ?? ['admin']);
    
    return Drawer(
      backgroundColor: _cardColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: _surfaceLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _neonRed.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.admin_panel_settings, size: 40, color: _neonRed),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.user['name'] ?? 'Super Admin', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(widget.user['email'] ?? 'admin@swapeat.com', style: const TextStyle(color: _textSecondary)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('SWITCH CONSOLE', style: TextStyle(fontWeight: FontWeight.bold, color: _textSecondary, fontSize: 12, letterSpacing: 1.5)),
            ),
            if (roles.contains('admin'))
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: _neonRed),
                title: const Text('Admin Console', style: TextStyle(color: _neonRed, fontWeight: FontWeight.bold)),
                selected: true,
                onTap: () => Navigator.pop(context),
              ),
            if (roles.contains('student'))
              ListTile(
                title: const Text('Simulate Student Dashboard', style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => StudentMainScaffold(user: widget.user))),
              ),
            if (roles.contains('vendor'))
              ListTile(
                leading: const Icon(Icons.storefront, color: Colors.white70),
                title: const Text('Vendor POS', style: TextStyle(color: Colors.white70)),
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VendorDashboardView(user: widget.user))),
              ),
            const Spacer(),
            const Divider(color: _surfaceLight),
            ListTile(
              leading: const Icon(Icons.logout, color: _neonRed),
              title: const Text('Sign Out', style: TextStyle(color: _neonRed)),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStat(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          )
        ],
      ),
    );
  }

  void _showSendNotificationSheet() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final targetIdController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Send Notification', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target User ID (Optional)',
                  helperText: 'Leave blank to broadcast to everyone',
                  helperStyle: const TextStyle(color: _neonCyan),
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              isSending
                  ? const Center(child: CircularProgressIndicator(color: _neonCyan))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonCyan,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (titleController.text.isEmpty || messageController.text.isEmpty) return;
                        setSheetState(() => isSending = true);
                        try {
                          await FirebaseFirestore.instance.collection('notifications').add({
                            'title': titleController.text.trim(),
                            'message': messageController.text.trim(),
                            'targetUserId': targetIdController.text.trim().isEmpty ? null : targetIdController.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                            'readBy': [],
                            'dismissedBy': [],
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification Sent'), backgroundColor: _neonCyan));
                          }
                        } catch (e) {
                          setSheetState(() => isSending = false);
                        }
                      },
                      child: const Text('Send', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
