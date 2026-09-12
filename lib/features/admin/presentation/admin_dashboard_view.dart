import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../../core/services/firestore_service.dart';
import '../../../core/services/admin_service.dart';

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
  int _selectedIndex = 0;

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
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildUserManagementTab();
      case 2:
        return _buildSystemSettingsTab();
      case 3:
        return _buildDisputesTab();
      case 4:
        return _buildModerationTab();
      case 5:
        return _buildFinancialAuditTab();
      case 6:
        return _buildHarambeeTab();
      case 7:
        return _buildSystemAuditTab();
      default:
        return _buildHomeTab();
    }
  }
  
  Widget _buildUserManagementTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search users by email or name...',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.search, color: _textSecondary),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (val) {
               setState(() {
                 _searchQuery = val.toLowerCase();
               });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _neonCyan));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No users found', style: TextStyle(color: _textSecondary)));
              }

              var users = snapshot.data!.docs;
              if (_searchQuery.isNotEmpty) {
                users = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userDoc = users[index];
                  final data = userDoc.data() as Map<String, dynamic>;
                  final uid = userDoc.id;
                  final name = data['name'] ?? data['displayName'] ?? 'Unknown';
                  final email = data['email'] ?? 'No Email';
                  final role = data['role'] ?? 'user';
                  final status = data['status'] ?? 'active';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _surfaceLight,
                      child: Text(role.substring(0, 1).toUpperCase(), style: const TextStyle(color: _neonCyan)),
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('$email • Role: $role\nStatus: $status', style: TextStyle(color: status == 'suspended' ? _neonRed : _textSecondary)),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: _cardColor,
                      onSelected: (val) async {
                        try {
                           final adminService = AdminService();
                           if (val == 'suspend') {
                             await adminService.suspendUser(uid, 'Admin action');
                             if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User suspended')));
                           } else if (val == 'delete') {
                             await adminService.deleteUser(uid);
                             if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
                           } else if (val == 'impersonate') {
                             final token = await adminService.impersonateUser(uid);
                             await FirebaseAuth.instance.signInWithCustomToken(token);
                             if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ghost Login active')));
                             // App will route out of Admin Dashboard automatically due to AuthState changes
                           }
                        } catch (e) {
                           if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'impersonate', child: Text('Ghost Login (Impersonate)', style: TextStyle(color: Colors.white))),
                        const PopupMenuItem(value: 'suspend', child: Text('Suspend User', style: TextStyle(color: Colors.orange))),
                        const PopupMenuItem(value: 'delete', child: Text('Delete User', style: TextStyle(color: _neonRed))),
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
  
  Widget _buildSystemSettingsTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('system_settings').doc('platform_config').snapshots(),
      builder: (context, snapshot) {
        bool isMaintenance = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          isMaintenance = (snapshot.data!.data() as Map<String, dynamic>)['maintenance_mode'] ?? false;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Platform Controls', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isMaintenance ? _neonRed : Colors.transparent),
              ),
              child: SwitchListTile(
                title: const Text('Maintenance Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Disables the app for all non-admin users immediately.', style: TextStyle(color: _textSecondary)),
                value: isMaintenance,
                activeColor: _neonRed,
                onChanged: (val) async {
                  try {
                    await AdminService().toggleMaintenanceMode(val);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text('Events & Fees', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              tileColor: _surfaceLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.percent, color: _neonCyan),
              title: const Text('Global Commission Rate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () {
                _showUpdateCommissionDialog();
              }
            ),
            const SizedBox(height: 8),
            ListTile(
              tileColor: _surfaceLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.event, color: _neonOrange),
              title: const Text('Make Event Free', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () {
                _showMakeEventFreeDialog();
              }
            )
          ],
        );
      },
    );
  }

  Widget _buildDisputesTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Dispute Resolution Center', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('disputes').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonCyan));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No active disputes', style: TextStyle(color: _textSecondary)));

              var disputes = snapshot.data!.docs;

              return ListView.builder(
                itemCount: disputes.length,
                itemBuilder: (context, index) {
                  final doc = disputes[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  if (status == 'resolved') return const SizedBox.shrink(); // hide resolved
                  
                  return Card(
                    color: _surfaceLight,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dispute: ${doc.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Amount: KES ${data['amount']}', style: const TextStyle(color: _neonOrange)),
                          Text('Reason: ${data['reason'] ?? 'N/A'}', style: const TextStyle(color: _textSecondary)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _neonRed),
                                onPressed: () async {
                                  await AdminService().resolveDispute(doc.id, 'refund_student');
                                },
                                child: const Text('Refund Student', style: TextStyle(color: Colors.white)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
                                onPressed: () async {
                                  await AdminService().resolveDispute(doc.id, 'release_to_vendor');
                                },
                                child: const Text('Release to Vendor', style: TextStyle(color: Colors.black)),
                              ),
                            ],
                          )
                        ],
                      ),
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

  Widget _buildModerationTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Content Moderation (Campus Feed)', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('campus_feed').orderBy('createdAt', descending: true).limit(20).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonCyan));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No posts', style: TextStyle(color: _textSecondary)));

              var posts = snapshot.data!.docs;

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final doc = posts[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  return ListTile(
                    tileColor: _surfaceLight,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(data['content'] ?? 'No content', style: const TextStyle(color: Colors.white)),
                    subtitle: Text('Author: ${data['authorName'] ?? 'Unknown'}', style: const TextStyle(color: _textSecondary)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: _neonRed),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('campus_feed').doc(doc.id).delete();
                      },
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

  void _showMakeEventFreeDialog() {
    final eventIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Make Event Free', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: eventIdController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter Event ID',
            hintStyle: TextStyle(color: _textSecondary),
            filled: true,
            fillColor: _surfaceLight,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange),
            onPressed: () async {
              if (eventIdController.text.isEmpty) return;
              try {
                await AdminService().overrideEvent(eventIdController.text.trim(), true);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event updated!')));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showUpdateCommissionDialog() {
    final rateController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Global Commission Rate', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: rateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new rate (%) e.g. 5.0',
            hintStyle: TextStyle(color: _textSecondary),
            filled: true,
            fillColor: _surfaceLight,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange),
            onPressed: () async {
              if (rateController.text.isEmpty) return;
              try {
                final rate = double.parse(rateController.text);
                await AdminService().updateCommissionRate(rate);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commission rate updated!')));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _processMassPayouts() async {
    try {
      await AdminService().triggerManualPayout();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payouts triggered successfully')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payout Error: $e')));
    }
  }

  Widget _buildFinancialAuditTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Financial Audit Logs', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('transactions').orderBy('timestamp', descending: true).limit(30).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonCyan));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No transactions', style: TextStyle(color: _textSecondary)));

              var txs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: txs.length,
                itemBuilder: (context, index) {
                  final data = txs[index].data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'Unknown';
                  final amount = data['amount'] ?? 0;
                  final status = data['status'] ?? 'pending';
                  
                  return ListTile(
                    tileColor: _surfaceLight,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(
                      type.contains('Refund') ? Icons.keyboard_return : Icons.attach_money,
                      color: type.contains('Refund') ? _neonOrange : _neonCyan,
                    ),
                    title: Text('$type: KES $amount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Status: $status', style: const TextStyle(color: _textSecondary)),
                    trailing: Text(txs[index].id.substring(0, 8), style: const TextStyle(color: Colors.white38)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHarambeeTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Harambee Moderation', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('harambees').where('status', isEqualTo: 'active').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonCyan));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No active campaigns', style: TextStyle(color: _textSecondary)));

              var campaigns = snapshot.data!.docs;
              return ListView.builder(
                itemCount: campaigns.length,
                itemBuilder: (context, index) {
                  final doc = campaigns[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Untitled';
                  final raised = data['raised_amount'] ?? 0;
                  
                  return Card(
                    color: _surfaceLight,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Raised: KES $raised', style: const TextStyle(color: _neonOrange)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                onPressed: () async {
                                  await AdminService().forceHarambeeAction(doc.id, 'pause');
                                },
                                child: const Text('Pause', style: TextStyle(color: Colors.white)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _neonRed),
                                onPressed: () async {
                                  await AdminService().forceHarambeeAction(doc.id, 'cancel_and_refund');
                                },
                                child: const Text('Cancel & Refund', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          )
                        ],
                      ),
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

  Widget _buildSystemAuditTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('System Audit Trail', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: AdminService().getAuditLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonCyan));
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No audit logs available', style: TextStyle(color: _textSecondary)));

              var logs = snapshot.data!;
              return ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final action = log['action'] ?? 'Unknown Action';
                  final adminId = log['admin_id'] ?? 'Unknown Admin';
                  final timestamp = log['timestamp'] ?? '';
                  final details = log['details']?.toString() ?? '';
                  
                  return Card(
                    color: _surfaceLight,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(action, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(timestamp, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Admin: $adminId', style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text('Details: $details', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
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

  Widget _buildHomeTab() {
    return CustomScrollView(
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
                        const SizedBox(height: 12),
                        
                        ListTile(
                          tileColor: _surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.shield, color: _neonOrange),
                          title: const Text('Community Moderation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Review flagged content & bans', style: TextStyle(color: _textSecondary)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white),
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminModerationView()));
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        ListTile(
                          tileColor: _surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.how_to_reg, color: _neonCyan),
                          title: const Text('Vendor Onboarding', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Approve new vendors & fundis', style: TextStyle(color: _textSecondary)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white),
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminOnboardingView()));
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        ListTile(
                          tileColor: _surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.two_wheeler, color: _neonCyan),
                          title: const Text('Campus Delivery Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Approve drivers & view live rides', style: TextStyle(color: _textSecondary)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white),
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDeliverySecurityView()));
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        ListTile(
                          tileColor: _surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.emergency, color: _neonRed),
                          title: const Text('Match Safety Response', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Monitor SOS alerts & dispatch', style: TextStyle(color: _textSecondary)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white),
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminMatchSafetyView()));
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
                  ),
                ],
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
              child: Text('DASHBOARD TABS', style: TextStyle(fontWeight: FontWeight.bold, color: _textSecondary, fontSize: 12, letterSpacing: 1.5)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.white),
              title: const Text('Home / Overview', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 0,
              selectedTileColor: _neonRed.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.white),
              title: const Text('User Management', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 1,
              selectedTileColor: _neonRed.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('System Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.gavel, color: Colors.white),
              title: const Text('Disputes Center', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSupportTicketsView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.white),
              title: const Text('Content Moderation', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminModerationView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.white),
              title: const Text('Vendor Onboarding', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminOnboardingView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.white),
              title: const Text('Financial Audit', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 5,
              selectedTileColor: _neonRed.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment, color: Colors.white),
              title: const Text('Payouts & Escrow', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPayoutsView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.volunteer_activism, color: Colors.white),
              title: const Text('Harambee Moderation', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 6,
              selectedTileColor: _neonRed.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 6);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text('System Audit Trail', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 7,
              selectedTileColor: _neonRed.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 7);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.two_wheeler, color: Colors.white),
              title: const Text('Delivery Security', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDeliverySecurityView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency, color: Colors.white),
              title: const Text('Match Safety', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminMatchSafetyView()));
              },
            ),
            const Divider(color: _surfaceLight),
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
                          await AdminService().sendBroadcastNotification(
                            titleController.text.trim(),
                            messageController.text.trim(),
                            targetUserId: targetIdController.text.trim().isEmpty ? null : targetIdController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification Sent via FCM'), backgroundColor: _neonCyan));
                          }
                        } catch (e) {
                          setSheetState(() => isSending = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
                          }
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
