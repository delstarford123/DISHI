import '../../../main.dart';
import '../../../core/security/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/widgets/high_friction_action.dart';
import '../../student/presentation/student_main_scaffold.dart';
import '../../vendor/presentation/vendor_dashboard_view.dart';
import '../../auth/presentation/login_view.dart';
import 'fraud_velocity_view.dart';
import 'admin_support_tickets_view.dart';
import 'admin_transactions_view.dart';
import 'admin_settings_view.dart';
import 'admin_moderation_view.dart';
import 'admin_onboarding_view.dart';
import 'admin_payouts_view.dart';
import 'admin_delivery_security_view.dart';
import 'admin_match_safety_view.dart';
import 'admin_users_view.dart';
import 'admin_database_indexes_view.dart';
import 'admin_emergency_security_view.dart';
import 'admin_housing_view.dart';
import 'admin_employee_payroll_view.dart';
import 'admin_b2b_finance_view.dart';
import 'admin_c2b_collections_view.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM EXECUTIVE THEME COLORS --
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
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  int _activeUsers = 0;
  int _activeVendors = 0;
  double _systemFloat = 0.0;
  double _totalEscrow = 0.0;
  int _flaggedTransactions = 0;
  bool _isMaintenance = false;

  @override
  void initState() {
    super.initState();
    _fetchAdminStats();
    _listenToPlatformConfig();
  }

  void _listenToPlatformConfig() {
    FirebaseFirestore.instance.collection('system_settings').doc('platform_config').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMaintenance = snap.data()?['maintenance_mode'] == true;
        });
      }
    });
  }

  Future<void> _fetchAdminStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _adminService.getSystemOverview();
      final escrow = await _adminService.getEscrowSummary().catchError((_) => {'total_escrow': 0.0});

      if (mounted) {
        setState(() {
          _activeUsers = stats['usersCount'] ?? 0;
          _activeVendors = stats['vendorsCount'] ?? 0;
          _systemFloat = (stats['floatSum'] ?? 0.0).toDouble();
          _flaggedTransactions = stats['flaggedTransactions'] ?? 0;
          _totalEscrow = (escrow['total_escrow'] ?? 0.0).toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Graceful fallback to Firestore direct queries
      try {
        final usersSnap = await FirebaseFirestore.instance.collection('users').get();
        final vendorsCount = usersSnap.docs.where((d) => d.data()['role'] == 'vendor').length;
        double floatSum = 0.0;
        for (var doc in usersSnap.docs) {
          floatSum += (doc.data()['walletBalance'] as num?)?.toDouble() ?? 0.0;
        }
        if (mounted) {
          setState(() {
            _activeUsers = usersSnap.docs.length;
            _activeVendors = vendorsCount;
            _systemFloat = floatSum;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processMassPayouts() async {
    try {
      await _adminService.triggerManualPayout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mass B2C Payouts queued successfully!'), backgroundColor: _neonCyan),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payout Error: $e'), backgroundColor: _neonRed),
        );
      }
    }
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 1.5)),
        title: const Text('Admin Console Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin: ${widget.user['name'] ?? widget.user['displayName'] ?? "Super Admin"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('UID: ${widget.user['uid'] ?? ""}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.security, color: _neonCyan),
              title: const Text('Emergency Security Center', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminEmergencySecurityView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.storage, color: _neonBlue),
              title: const Text('Database & Indexes Telemetry', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDatabaseIndexesView()));
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.logout, color: _neonRed),
              title: const Text('Sign Out', style: TextStyle(color: _neonRed, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: _textSecondary))),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    final adminName = widget.user['name'] ?? widget.user['displayName'] ?? 'Super Admin';
    final profileImageUrl = widget.user['profileImageUrl'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B29).withOpacity(0.9),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
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
                  child: profileImageUrl == null ? const Icon(Icons.admin_panel_settings, color: _neonCyan, size: 20) : null,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isMaintenance ? _neonRed : Colors.greenAccent,
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
                Row(
                  children: [
                    Text(_getGreeting(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _neonCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SUPER ADMIN', style: TextStyle(color: _neonCyan, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(
                  adminName,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined, color: Colors.white70, size: 20),
            tooltip: 'Send Broadcast',
            onPressed: _showSendNotificationSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan, size: 20),
            tooltip: 'Refresh Telemetry',
            onPressed: _fetchAdminStats,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      resizeToAvoidBottomInset: false,
      drawer: _buildRoleSwitcherDrawer(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _neonCyan))
            : RefreshIndicator(
                color: _neonCyan,
                backgroundColor: _cardColor,
                onRefresh: _fetchAdminStats,
                child: CustomScrollView(
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
                          // System Status Pill Banner
                          if (_isMaintenance)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _neonRed.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _neonRed),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: _neonRed, size: 24),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('PLATFORM IN LOCKDOWN MODE', style: TextStyle(color: _neonRed, fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('Only administrators currently have access.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminEmergencySecurityView())),
                                    child: const Text('Manage', style: TextStyle(color: _neonRed, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),

                          // Total System Float Card
                          InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTransactionsView())),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF131A2A),
                                    const Color(0xFF162238),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _neonCyan.withOpacity(0.4), width: 1.5),
                                boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.account_balance, color: _neonCyan, size: 20),
                                          SizedBox(width: 8),
                                          Text('Total System Float (Live Ledger)', style: TextStyle(color: _textSecondary, fontSize: 13)),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                        child: const Row(
                                          children: [
                                            Text('Reconcile', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                            SizedBox(width: 4),
                                            Icon(Icons.arrow_forward_ios, color: _neonCyan, size: 10),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'KES ${_systemFloat.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.lock_clock, color: Colors.amberAccent, size: 14),
                                      const SizedBox(width: 6),
                                      Text('Platform Escrow: KES ${_totalEscrow.toStringAsFixed(2)}', style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Executive Quick Dock Buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildExecutiveActionTile(
                                  label: 'Users & Roles',
                                  subtitle: 'Manage UIDs',
                                  icon: Icons.people_alt,
                                  color: _neonCyan,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersView())),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildExecutiveActionTile(
                                  label: 'M-PESA Resolver',
                                  subtitle: 'Ledger Audit',
                                  icon: Icons.receipt_long,
                                  color: _neonBlue,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTransactionsView())),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildExecutiveActionTile(
                                  label: 'Firestore Health',
                                  subtitle: 'Indexes & Telemetry',
                                  icon: Icons.storage_rounded,
                                  color: Colors.greenAccent,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDatabaseIndexesView())),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildExecutiveActionTile(
                                  label: 'Security & Circuit',
                                  subtitle: 'Kill Switch',
                                  icon: Icons.shield,
                                  color: _neonRed,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminEmergencySecurityView())),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildExecutiveActionTile(
                                  label: 'Staff & Payroll',
                                  subtitle: 'B2C Salary Engine',
                                  icon: Icons.badge_outlined,
                                  color: _neonCyan,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminEmployeePayrollView())),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildExecutiveActionTile(
                                  label: 'B2B & C2B Hub',
                                  subtitle: 'Paybill & Tills',
                                  icon: Icons.swap_horiz_rounded,
                                  color: Colors.amberAccent,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminB2BFinanceView())),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Key Metrics Deck
                          const Text('Executive Metrics Overview', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersView())),
                                  child: _buildSystemStat('Active Users', '$_activeUsers', Icons.people, _neonCyan),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersView())),
                                  child: _buildSystemStat('Vendors POS', '$_activeVendors', Icons.storefront, _neonOrange),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Management Command Modules
                          const Text('System Management Modules', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),

                          // 1. Fraud Radar
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: _flaggedTransactions > 0 ? _neonRed : Colors.transparent),
                            ),
                            leading: Badge(
                              isLabelVisible: _flaggedTransactions > 0,
                              label: Text('$_flaggedTransactions'),
                              child: const Icon(Icons.radar_rounded, color: _neonRed),
                            ),
                            title: const Text('Fraud & Velocity Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Wash trading & suspicious volume flags', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FraudVelocityView())),
                          ),
                          const SizedBox(height: 10),

                          // 2. Disputes Center
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.gavel, color: Colors.amberAccent),
                            title: const Text('Disputes & Escrow Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Refund students or release merchant funds', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSupportTicketsView())),
                          ),
                          const SizedBox(height: 10),

                          // 3. Vendor & Fundi Onboarding
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.how_to_reg, color: _neonCyan),
                            title: const Text('Merchant & Fundi Onboarding', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Verify cafeteria kiosks, stores, and fundis', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminOnboardingView())),
                          ),
                          const SizedBox(height: 10),

                          // 4. Housing Oversight
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.home_work_outlined, color: _neonBlue),
                            title: const Text('Hostel & Housing Oversight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Approve campus listings & manage bookings', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminHousingView())),
                          ),
                          const SizedBox(height: 10),

                          // 5. Delivery Drivers & Live Tracking
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.two_wheeler, color: _neonCyan),
                            title: const Text('Campus Delivery Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Driver verification, active rides & manual dispatch', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDeliverySecurityView())),
                          ),
                          const SizedBox(height: 10),

                          // 6. Match Safety & SOS
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.emergency, color: _neonRed),
                            title: const Text('Match Safety Response (SOS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Emergency dispatch, security alerts & safe vouchers', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminMatchSafetyView())),
                          ),
                          const SizedBox(height: 10),

                          // 7. Community Moderation
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.security, color: _neonOrange),
                            title: const Text('Community Moderation Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Moderate campus feeds, confessions & reports', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminModerationView())),
                          ),
                          const SizedBox(height: 10),

                          // 8. Platform Config & Feature Flags
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.tune, color: _neonCyan),
                            title: const Text('Platform Config & Live Flags', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Commission percentages, CBK limits, feature toggles', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsView())),
                          ),
                          const SizedBox(height: 10),

                          // 9. Employee Management & B2C Payroll
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.badge, color: _neonCyan),
                            title: const Text('Staff & Employee Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Onboard staff, statutory deductions, B2C salary runs', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminEmployeePayrollView())),
                          ),
                          const SizedBox(height: 10),

                          // 10. B2B Commercial Payouts
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.swap_horiz, color: _neonBlue),
                            title: const Text('B2B Commercial Liquidity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Vendor BuyGoods tills, utility paybills, supplier payouts', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminB2BFinanceView())),
                          ),
                          const SizedBox(height: 10),

                          // 11. C2B Paybill Collections
                          ListTile(
                            tileColor: _surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: const Icon(Icons.arrow_downward, color: Colors.greenAccent),
                            title: const Text('C2B Paybill Collections (4050545)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Live customer deposit stream & instant wallet crediting', style: TextStyle(color: _textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminC2BCollectionsView())),
                          ),
                          const SizedBox(height: 28),

                          // High-Friction Payout Action
                          const Text('Financial Liquidity Operations', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _surfaceLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.shield_outlined, color: _neonCyan, size: 18),
                                    SizedBox(width: 8),
                                    Text('Automated Safaricom Daraja B2C Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Release accumulated vendor earnings into Safaricom B2C queue. Hold action for 2 seconds to initiate.',
                                  style: TextStyle(color: _textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                                HighFrictionAction(
                                  label: 'Hold for Mass B2C Payouts',
                                  onActionCompleted: _processMassPayouts,
                                  baseColor: _neonCyan,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildExecutiveActionTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          )
        ],
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
                    decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.admin_panel_settings, size: 36, color: _neonCyan),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.user['name'] ?? widget.user['displayName'] ?? 'Super Admin',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(widget.user['email'] ?? 'admin@dishi.com', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('COMMAND SECTIONS', style: TextStyle(fontWeight: FontWeight.bold, color: _textSecondary, fontSize: 11, letterSpacing: 1.5)),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.dashboard, color: _neonCyan),
                    title: const Text('Home Overview', style: TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people, color: Colors.white70),
                    title: const Text('User & Identity Command', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersView()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long, color: Colors.white70),
                    title: const Text('Ledger & M-PESA Reconciler', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTransactionsView()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.storage, color: Colors.white70),
                    title: const Text('Database & Firestore Indexes', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDatabaseIndexesView()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.shield, color: _neonRed),
                    title: const Text('Security & Circuit Breakers', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminEmergencySecurityView()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.gavel, color: Colors.white70),
                    title: const Text('Disputes & Escrow Center', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSupportTicketsView()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, color: Colors.white70),
                    title: const Text('Platform Config & Flags', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsView()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.badge, color: _neonCyan),
                    title: const Text('Staff & Payroll (B2C)', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminEmployeePayrollView()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz, color: _neonBlue),
                    title: const Text('B2B Commercial Payouts', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminB2BFinanceView()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.arrow_downward, color: Colors.greenAccent),
                    title: const Text('C2B Paybill (4050545)', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminC2BCollectionsView()));
                    },
                  ),
                  const Divider(color: _surfaceLight),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('CONSOLE SIMULATION', style: TextStyle(fontWeight: FontWeight.bold, color: _textSecondary, fontSize: 11, letterSpacing: 1.5)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.school, color: Colors.white70),
                    title: const Text('Switch to Student Dashboard', style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => StudentMainScaffold(user: widget.user))),
                  ),
                  ListTile(
                    leading: const Icon(Icons.storefront, color: Colors.white70),
                    title: const Text('Switch to Vendor POS', style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VendorDashboardView(user: widget.user))),
                  ),
                  const Divider(color: _surfaceLight),
                  ListTile(
                    leading: const Icon(Icons.logout, color: _neonRed),
                    title: const Text('Sign Out', style: TextStyle(color: _neonRed, fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView())),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              const Text('Send Notification via FCM', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Notification Title',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notification Body',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: targetIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target User UID (Optional)',
                  helperText: 'Leave empty to broadcast to entire campus network',
                  helperStyle: const TextStyle(color: _neonCyan),
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              isSending
                  ? const Center(child: CircularProgressIndicator(color: _neonCyan))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) return;
                        setSheetState(() => isSending = true);
                        try {
                          await _adminService.sendBroadcastNotification(
                            titleController.text.trim(),
                            messageController.text.trim(),
                            targetUserId: targetIdController.text.trim().isEmpty ? null : targetIdController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification Broadcast Sent'), backgroundColor: _neonCyan));
                          }
                        } catch (e) {
                          setSheetState(() => isSending = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send Failed: $e'), backgroundColor: _neonRed));
                          }
                        }
                      },
                      child: const Text('Dispatch Notification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
