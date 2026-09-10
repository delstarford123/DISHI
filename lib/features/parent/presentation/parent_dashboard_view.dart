import 'package:flutter/material.dart';
import '../../../core/widgets/shared_savings_view.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../auth/presentation/login_view.dart';
import 'offline_child_qr_view.dart';

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'auto_funding_settings.dart';
import 'nutrition_settings.dart';
import 'lunchbox_planner.dart';
import 'security_settings.dart';
import 'scheduled_allowances_view.dart';
import 'dispute_resolution_view.dart';
import 'spending_analytics_view.dart';
import 'bounties_view.dart';
import 'vendor_restrictions_view.dart';
import 'academic_rewards_view.dart';
import 'co_parenting_view.dart';
import 'emergency_alerts_view.dart';
import 'geofence_alerts_view.dart';
import 'medical_lock_view.dart';
import 'transport_allowance_view.dart';
import 'health_stats_view.dart';
import 'housing_payments_view.dart';
import 'tuition_payments_view.dart';
import 'savings_target_view.dart';
import 'graduation_fund_view.dart';
import 'subscription_manager_view.dart';

import 'tabs/growth_tab_view.dart';
import '../presentation/tabs/community_tab_view.dart';
import '../presentation/tabs/settings_tab_view.dart';
import '../../../shared/presentation/universal_support_widget.dart';
import 'parent_profile_settings.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class ParentDashboardView extends StatefulWidget {
  final Map<String, dynamic> user;

  const ParentDashboardView({super.key, required this.user});

  @override
  State<ParentDashboardView> createState() => _ParentDashboardViewState();
}

class _ParentDashboardViewState extends State<ParentDashboardView> {
  bool _isLoading = true;
  double _vaultBalance = 15400.0;
  List<Map<String, dynamic>> _linkedStudents = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchParentData();
  }

  Future<void> _fetchParentData() async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) return;
      
      final parentDoc = await FirebaseFirestore.instance.collection('users').doc(authUser.uid).get();
      if (!parentDoc.exists) return;
      
      final parentData = parentDoc.data()!;
      double vaultBalance = 0.0;
      if (parentData['savingsBalance'] != null) {
        vaultBalance = (parentData['savingsBalance'] as num).toDouble();
      }
      
      List<dynamic> linkedUids = parentData['linkedStudents'] ?? [];
      List<Map<String, dynamic>> students = [];
      
      for (String uid in linkedUids) {
        final studentDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (studentDoc.exists) {
          final sData = studentDoc.data()!;
          double bal = 0.0;
          if (sData['walletBalance'] != null) {
            bal = (sData['walletBalance'] as num).toDouble();
          }
          students.add({
            'name': sData['name'] ?? sData['displayName'] ?? 'Student',
            'balance': bal,
            'status': bal < 200 ? 'Low Balance' : 'Active',
            'isOffline': sData['isOffline'] ?? false,
            'uid': uid,
            'isFrozen': sData['isFrozen'] ?? false,
            'dailyLimit': sData['dailyLimit'] != null ? (sData['dailyLimit'] as num).toDouble() : null,
            'useSharedWallet': sData['useSharedWallet'] ?? false,
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _vaultBalance = vaultBalance;
          _linkedStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParentProfileSettings(userMap: widget.user),
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

    final parentName = widget.user['name'] ?? widget.user['displayName'] ?? 'Parent';
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
                  child: profileImageUrl == null ? const Icon(Icons.person, color: _textSecondary, size: 20) : null,
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
                  parentName, 
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
    final List<Widget> tabs = [
      _buildHomeTab(),
      GrowthTabView(user: widget.user),
      CommunityTabView(user: widget.user),
      SettingsTabView(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _neonCyan))
            : IndexedStack(
                index: _selectedIndex,
                children: tabs,
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: _bgColor,
        selectedItemColor: _neonCyan,
        unselectedItemColor: _textSecondary,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Growth'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
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
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              child: _buildCustomAppBar(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // The Shared Vault
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _neonBlue.withOpacity(0.4), width: 1.5),
                  boxShadow: [BoxShadow(color: _neonBlue.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)]
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield, color: _neonBlue, size: 24),
                        SizedBox(width: 8),
                        Text('Shared Family Vault', style: TextStyle(color: _textSecondary, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'KSH ${_vaultBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Text('Linked to: ${widget.user['phone'] ?? '254700000000'}', style: const TextStyle(color: _textSecondary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showVaultTopUpModal(context),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Top Up Vault'),
                            style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, foregroundColor: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showBulkFundModal(context),
                            icon: const Icon(Icons.account_balance_wallet),
                            label: const Text('Fund Students'),
                            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              const Text('Linked Students', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              ..._linkedStudents.map((student) => _buildStudentCard(student)).toList(),
              
              const SizedBox(height: 32),
              const Text('Manage Children', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showLinkChildDialog(),
                      icon: const Icon(Icons.link),
                      label: const Text('Link Student'),
                      style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddOfflineChildDialog(),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Offline'),
                      style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionGridButton(Icons.security, 'Kill Switch', _neonPink, _showKillSwitchDialog),
                  _buildActionGridButton(Icons.restaurant, 'Nutrition Limits', _neonOrange, _showNutritionSelector),
                  _buildActionGridButton(Icons.bento, 'Lunchbox Pre-order', Colors.greenAccent, _showLunchboxSelector),
                  _buildActionGridButton(Icons.account_balance_wallet, 'Auto Top-Up', _neonCyan, _showAutoTopUpSelector),
                  _buildActionGridButton(Icons.family_restroom, 'Shared Wallet', _neonBlue, _showSharedWalletDialog),
                  _buildActionGridButton(Icons.schedule, 'Allowances', _neonOrange, _showScheduledAllowances),
                  _buildActionGridButton(Icons.gavel, 'Disputes', _neonPink, _showDisputes),
                  _buildActionGridButton(Icons.pie_chart, 'Analytics', _neonCyan, _showSpendingAnalytics),
                  _buildActionGridButton(Icons.assignment_turned_in, 'Bounties', Colors.yellow, _showBounties),
                  _buildActionGridButton(Icons.block, 'Vendors', _neonPink, _showVendorRestrictions),
                  _buildActionGridButton(Icons.school, 'SmartI', Colors.blueAccent, _showAcademicRewards),
                  _buildActionGridButton(Icons.group_add, 'Co-Parent', _neonBlue, _showCoParenting),
                  _buildActionGridButton(Icons.warning_amber_rounded, 'SOS Alerts', MPesaTheme.primaryRed, _showEmergencyAlerts),
                  _buildActionGridButton(Icons.location_on, 'Geofence', MPesaTheme.neonOrange, _showGeofenceAlerts),
                  _buildActionGridButton(Icons.local_hospital, 'Medical Lock', MPesaTheme.neonCyan, _showMedicalLock),
                  _buildActionGridButton(Icons.directions_bus, 'Transport', Colors.amber, _showTransportAllowance),
                  _buildActionGridButton(Icons.favorite, 'Health Stats', MPesaTheme.neonPink, _showHealthStats),
                  _buildActionGridButton(Icons.home, 'Housing', Colors.tealAccent, _showHousingPayments),
                  _buildActionGridButton(Icons.account_balance, 'Tuition', Colors.blueAccent, _showTuitionPayments),
                  _buildActionGridButton(Icons.savings, 'Savings', MPesaTheme.primaryGreen, _showSavingsTarget),
                  _buildActionGridButton(Icons.school, 'Grad Fund', Colors.purpleAccent, _showGraduationFund),
                  _buildActionGridButton(Icons.autorenew, 'Bills', Colors.cyanAccent, _showSubscriptionManager),
                ],
              ),
              const SizedBox(height: 24),
              UniversalSupportWidget(userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown', userRole: 'parent'),
              const SizedBox(height: 100), // padding at bottom
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    bool isActive = student['status'] == 'Active';
    Color statusColor = isActive ? _neonCyan : _neonOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(student['status'], style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (student['isOffline'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _neonBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _neonBlue),
                            ),
                            child: const Text('OFFLINE', style: TextStyle(color: _neonBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _neonCyan.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _neonCyan),
                            ),
                            child: const Text('ONLINE', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Wallet', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  Text('KSH ${student['balance'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    _showTopUpModal(context, student['uid'], student['name']);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _neonBlue),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Top Up', style: TextStyle(color: _neonBlue, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OfflineChildQrView(studentName: student['name'], uid: student['uid'])));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _neonBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Get ID Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showLinkChildDialog() {
    final TextEditingController controller = TextEditingController();
    bool isLinking = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: _cardColor,
          title: const Text('Link Student', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ask your child for their DISHI ID (found on their student dashboard) and enter it below.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'DISHI ID',
                  labelStyle: const TextStyle(color: _neonCyan),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLinking ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: isLinking ? null : () async {
                final dishiId = controller.text.trim();
                if (dishiId.isEmpty) return;

                setState(() => isLinking = true);

                try {
                  final query = await FirebaseFirestore.instance.collection('users').where('dishiId', isEqualTo: dishiId).get();
                  if (query.docs.isEmpty) {
                    final uidQuery = await FirebaseFirestore.instance.collection('users').get();
                    String? foundUid;
                    for (var doc in uidQuery.docs) {
                      if (doc.id.toUpperCase().startsWith(dishiId.toUpperCase())) {
                        foundUid = doc.id;
                        break;
                      }
                    }
                    
                    if (foundUid == null) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student not found with this ID.')));
                      setState(() => isLinking = false);
                      return;
                    } else {
                      await _linkStudentUid(foundUid);
                    }
                  } else {
                    await _linkStudentUid(query.docs.first.id);
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error linking: $e')));
                  setState(() => isLinking = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
              child: isLinking 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))
                : const Text('Link', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _linkStudentUid(String studentUid) async {
    final parentUid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(parentUid).update({
      'linkedStudents': FieldValue.arrayUnion([studentUid])
    });
    
    await FirebaseFirestore.instance.collection('users').doc(studentUid).update({
      'parentUid': parentUid
    });

    if (mounted) {
      Navigator.pop(context);
      _fetchParentData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student linked successfully!')));
    }
  }

  void _showAddOfflineChildDialog() {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: _cardColor,
          title: const Text('Add Offline Child', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Create a DISHI profile for a child in primary or secondary school without a phone. They will get a QR code and PIN to use at school.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Child\'s Full Name',
                  labelStyle: const TextStyle(color: _neonBlue),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonBlue)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Set 4-Digit PIN',
                  labelStyle: const TextStyle(color: _neonBlue),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonBlue)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: isCreating ? null : () async {
                final name = nameController.text.trim();
                final pin = pinController.text.trim();
                if (name.isEmpty || pin.length != 4) return;

                setState(() => isCreating = true);

                try {
                  final parentUid = FirebaseAuth.instance.currentUser!.uid;
                  final newUid = const Uuid().v4();
                  final shortId = newUid.substring(0, 7).toUpperCase();

                  await FirebaseFirestore.instance.collection('users').doc(newUid).set({
                    'displayName': name,
                    'roles': ['student'],
                    'isOffline': true,
                    'pin': pin,
                    'parentUid': parentUid,
                    'dishiId': shortId,
                    'walletBalance': 0.0,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  await FirebaseFirestore.instance.collection('users').doc(parentUid).update({
                    'linkedStudents': FieldValue.arrayUnion([newUid])
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    _fetchParentData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline child added successfully!')));
                    Navigator.push(context, MaterialPageRoute(builder: (_) => OfflineChildQrView(studentName: name, uid: newUid)));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating: $e')));
                  setState(() => isCreating = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _neonBlue),
              child: isCreating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGridButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showKillSwitchDialog() {
    if (_linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students linked.')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          title: const Text('Kill Switch (Freeze Account)', style: TextStyle(color: _neonPink)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _linkedStudents.length,
              itemBuilder: (context, index) {
                final student = _linkedStudents[index];
                bool isFrozen = student['isFrozen'] ?? false;
                
                return SwitchListTile(
                  title: Text(student['name'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text(isFrozen ? 'Account is FROZEN' : 'Account is ACTIVE', style: TextStyle(color: isFrozen ? _neonPink : _textSecondary)),
                  value: isFrozen,
                  activeColor: _neonPink,
                  onChanged: (val) async {
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(student['uid']).update({
                        'isFrozen': val
                      });
                      
                      setDialogState(() {
                        student['isFrozen'] = val;
                      });
                      
                      setState(() {
                         _linkedStudents[index]['isFrozen'] = val;
                      });
                      
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('${student['name']}\'s account ${val ? 'frozen' : 'unfrozen'}.')));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: _textSecondary)),
            )
          ],
        ),
      )
    );
  }

  void _showNutritionSelector() {
    if (_linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students linked.')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Select Student for Nutrition', style: TextStyle(color: _neonOrange)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _linkedStudents.length,
            itemBuilder: (context, index) {
              final student = _linkedStudents[index];
              return ListTile(
                title: Text(student['name'], style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.arrow_forward_ios, color: _neonOrange, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NutritionSettings(studentUid: student['uid'], studentName: student['name'])
                  ));
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _textSecondary)),
          )
        ],
      ),
    );
  }

  void _showScheduledAllowances() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduledAllowancesView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showDisputes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DisputeResolutionCenterView(
          parentUser: widget.user,
        ),
      ),
    );
  }

  void _showSpendingAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpendingAnalyticsView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showBounties() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BountiesView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showVendorRestrictions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VendorRestrictionsView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showAcademicRewards() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AcademicRewardsView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showCoParenting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoParentingInviteView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showEmergencyAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyAlertsView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showGeofenceAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeofenceAlertsView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showMedicalLock() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalLockView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showTransportAllowance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransportAllowanceView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showHealthStats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HealthStatsView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showHousingPayments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HousingPaymentsView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showTuitionPayments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TuitionPaymentsView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showSavingsTarget() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavingsTargetView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showGraduationFund() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GraduationFundView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showSubscriptionManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionManagerView(
          parentUser: widget.user,
          linkedStudents: _linkedStudents,
        ),
      ),
    );
  }

  void _showLunchboxSelector() {
    if (_linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students linked.')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Select Student for Lunchbox', style: TextStyle(color: Colors.greenAccent)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _linkedStudents.length,
            itemBuilder: (context, index) {
              final student = _linkedStudents[index];
              return ListTile(
                title: Text(student['name'], style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.greenAccent, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => LunchboxPlanner(
                      studentUid: student['uid'], 
                      studentName: student['name'],
                      parentUid: FirebaseAuth.instance.currentUser!.uid,
                    )
                  ));
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _textSecondary)),
          )
        ],
      ),
    );
  }


  void _showDietaryLimitsDialog() {
    if (_linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students linked.')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Dietary & Spend Limits', style: TextStyle(color: _neonOrange)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _linkedStudents.length,
            itemBuilder: (context, index) {
              final student = _linkedStudents[index];
              return ListTile(
                title: Text(student['name'], style: const TextStyle(color: Colors.white)),
                subtitle: Text(student['dailyLimit'] != null ? 'Daily Limit: Ksh ${student['dailyLimit']}' : 'No Limit Set', style: const TextStyle(color: _textSecondary)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: _neonOrange),
                  onPressed: () {
                    Navigator.pop(context);
                    _showSetLimitDialog(student['uid'], student['name'], student['dailyLimit']);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _textSecondary)),
          )
        ],
      ),
    );
  }

  void _showSetLimitDialog(String uid, String name, double? currentLimit) {
    final limitController = TextEditingController(text: currentLimit?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Set Limit for $name', style: const TextStyle(color: _neonOrange)),
        content: TextField(
          controller: limitController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Daily Limit (Ksh)',
            labelStyle: TextStyle(color: _neonOrange),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonOrange)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonOrange)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'dailyLimit': FieldValue.delete()
                });
                if (mounted) {
                  Navigator.pop(context);
                  _fetchParentData();
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Limit removed.')));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Remove Limit', style: TextStyle(color: _neonPink)),
          ),
          ElevatedButton(
            onPressed: () async {
              final limit = double.tryParse(limitController.text.trim());
              if (limit == null || limit <= 0) return;
              
              try {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'dailyLimit': limit
                });
                if (mounted) {
                  Navigator.pop(context);
                  _fetchParentData();
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Limit updated.')));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange),
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          )
        ],
      )
    );
  }

  void _showAutoTopUpSelector() {
    if (_linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students linked.')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Select Student for Auto Top-Up', style: TextStyle(color: _neonCyan)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _linkedStudents.length,
            itemBuilder: (context, index) {
              final student = _linkedStudents[index];
              return ListTile(
                title: Text(student['name'], style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.arrow_forward_ios, color: _neonCyan, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AutoFundingSettings(studentUid: student['uid'], studentName: student['name'])
                  ));
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _textSecondary)),
          )
        ],
      ),
    );
  }

  void _showSharedWalletDialog() {
    if (_linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students linked.')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          title: const Text('Shared Family Wallet', style: TextStyle(color: _neonBlue)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _linkedStudents.length,
              itemBuilder: (context, index) {
                final student = _linkedStudents[index];
                bool useShared = student['useSharedWallet'] ?? false;
                
                return SwitchListTile(
                  title: Text(student['name'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text(useShared ? 'Using Parent Vault' : 'Using Individual Wallet', style: TextStyle(color: useShared ? _neonBlue : _textSecondary)),
                  value: useShared,
                  activeColor: _neonBlue,
                  onChanged: (val) async {
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(student['uid']).update({
                        'useSharedWallet': val
                      });
                      
                      setDialogState(() {
                        student['useSharedWallet'] = val;
                      });
                      
                      setState(() {
                         _linkedStudents[index]['useSharedWallet'] = val;
                      });
                      
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('${student['name']} is now using ${val ? 'Shared Vault' : 'Individual Wallet'}.')));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: _textSecondary)),
            )
          ],
        ),
      )
    );
  }

  void _showTopUpModal(BuildContext context, String childUid, String childName) {
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    phoneController.text = widget.user['phone'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        decoration: const BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _neonBlue, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Up $childName via M-PESA', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Enter M-Pesa number and amount. A Ksh 1 fee applies.', style: TextStyle(color: _textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'M-PESA Number (e.g. 2547XXXXXXXX)',
                labelStyle: const TextStyle(color: _textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _neonBlue), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone_android, color: _neonBlue),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (Ksh)',
                labelStyle: const TextStyle(color: _textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _neonBlue), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.attach_money, color: _neonBlue),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final phone = phoneController.text.trim();
                  final amount = amountController.text.trim();
                  if (phone.isEmpty || amount.isEmpty) return;
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Initiating STK Push...'), backgroundColor: _neonBlue));
                  
                  try {
                    final response = await http.post(
                      Uri.parse(ApiConfig.mpesaStkPush),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'phone_number': phone,
                        'amount': int.parse(amount),
                        'user_id': childUid,
                        'metadata': {
                          'action': 'fund_student',
                          'funder_phone': phone
                        }
                      }),
                    ).timeout(const Duration(seconds: 30));
                    
                    if (response.statusCode == 200) {
                      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Check your phone for the M-PESA prompt!'), backgroundColor: Colors.green));
                    } else {
                      if (mounted) {
                        String errMsg = 'Failed to initiate STK Push';
                        try {
                          final parsed = jsonDecode(response.body);
                          errMsg = parsed['error'] ?? errMsg;
                        } catch (_) {}
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: $errMsg'), backgroundColor: _neonPink));
                      }
                    }
                  } on TimeoutException catch (_) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: _neonPink));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Top Up Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  void _showBulkFundModal(BuildContext context) {
    if (_linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students linked yet.')));
      return;
    }
    
    final amountController = TextEditingController();
    bool splitEqually = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          decoration: const BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: _neonBlue, width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bulk Fund Students', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Distribute funds to your linked students.', style: TextStyle(color: _textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Total Amount (Ksh)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _neonBlue), borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.attach_money, color: _neonBlue),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: splitEqually,
                    activeColor: _neonCyan,
                    onChanged: (val) {
                      setModalState(() {
                        splitEqually = val ?? true;
                      });
                    },
                  ),
                  const Expanded(child: Text('Split equally among all students', style: TextStyle(color: Colors.white))),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final amountText = amountController.text.trim();
                    if (amountText.isEmpty) return;
                    double totalAmount = double.tryParse(amountText) ?? 0;
                    if (totalAmount <= 0) return;

                    double amountPerStudent = splitEqually ? (totalAmount / _linkedStudents.length) : totalAmount;

                    Navigator.pop(context);
                    
                    _processBulkFunding(amountPerStudent);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Fund from M-PESA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () async {
                     final amountText = amountController.text.trim();
                    if (amountText.isEmpty) return;
                    double totalAmount = double.tryParse(amountText) ?? 0;
                    if (totalAmount <= 0) return;
                    if (totalAmount > _vaultBalance) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient vault balance.')));
                      return;
                    }

                    double amountPerStudent = splitEqually ? (totalAmount / _linkedStudents.length) : totalAmount;

                    Navigator.pop(context);
                    
                    _processVaultBulkFunding(totalAmount, amountPerStudent);
                  },
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonCyan), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Fund from Vault', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processBulkFunding(double amountPerStudent) async {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Initiating STK Push for bulk funding...')));
      final phone = widget.user['phone'] ?? '';
      if (phone.isEmpty) return;
      
      try {
         for (var student in _linkedStudents) {
           final response = await http.post(
             Uri.parse(ApiConfig.mpesaStkPush),
             headers: {'Content-Type': 'application/json'},
             body: jsonEncode({
               'phone_number': phone,
               'amount': amountPerStudent.toInt(),
               'user_id': student['uid'],
               'metadata': {
                 'action': 'fund_student',
                 'funder_phone': phone
               }
             }),
           ).timeout(const Duration(seconds: 30));
           
           if (response.statusCode != 200) {
              String errMsg = 'Failed to fund ${student['name']}';
              try {
                final parsed = jsonDecode(response.body);
                errMsg = parsed['error'] ?? errMsg;
              } catch (_) {}
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
           }
         }
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('M-PESA prompts sent!')));
      } on TimeoutException catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.')));
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }

  Future<void> _processVaultBulkFunding(double totalAmount, double amountPerStudent) async {
     try {
       final parentUid = FirebaseAuth.instance.currentUser!.uid;
       final batch = FirebaseFirestore.instance.batch();
       
       final parentRef = FirebaseFirestore.instance.collection('users').doc(parentUid);
       batch.update(parentRef, {'savingsBalance': FieldValue.increment(-totalAmount)});

       for (var student in _linkedStudents) {
         final studentRef = FirebaseFirestore.instance.collection('users').doc(student['uid']);
         batch.update(studentRef, {'walletBalance': FieldValue.increment(amountPerStudent)});
       }

       await batch.commit();
       _fetchParentData();
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funded successfully from Vault!')));
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vault funding failed: $e')));
     }
  }

  void _showVaultTopUpModal(BuildContext context) {
    final phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        decoration: const BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _neonBlue, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Up Family Vault', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Securely fund your shared vault via M-PESA.', style: TextStyle(color: _textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'M-PESA Number (e.g. 2547XXXXXXXX)',
                labelStyle: const TextStyle(color: _textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _neonBlue), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone_android, color: _neonBlue),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (Ksh)',
                labelStyle: const TextStyle(color: _textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _neonBlue), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.attach_money, color: _neonBlue),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final phone = phoneController.text.trim();
                  final amount = amountController.text.trim();
                  if (phone.isEmpty || amount.isEmpty) return;
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Initiating STK Push...'), backgroundColor: _neonBlue));
                  
                  try {
                    final response = await http.post(
                      Uri.parse(ApiConfig.mpesaStkPush),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'phone_number': phone,
                        'amount': int.parse(amount),
                        'user_id': FirebaseAuth.instance.currentUser!.uid,
                        'metadata': {
                          'action': 'fund_vault',
                          'funder_phone': phone
                        }
                      }),
                    ).timeout(const Duration(seconds: 30));
                    
                    if (response.statusCode == 200) {
                      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Check your phone for the M-PESA prompt!'), backgroundColor: Colors.green));
                    } else {
                      if (mounted) {
                        String errMsg = 'Failed to initiate STK Push';
                        try {
                          final parsed = jsonDecode(response.body);
                          errMsg = parsed['error'] ?? errMsg;
                        } catch (_) {}
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: $errMsg'), backgroundColor: _neonPink));
                      }
                    }
                  } on TimeoutException catch (_) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: _neonPink));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Top Up Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
