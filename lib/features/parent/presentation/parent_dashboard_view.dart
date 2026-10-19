import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'subscription_manager_view.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'offline_child_qr_view.dart';
import '../../student/presentation/virtual_card_view.dart';
import '../../../core/models/user_model.dart';

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'auto_funding_settings.dart';
import 'nutrition_settings.dart';
import 'lunchbox_planner.dart';
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
import 'parent_live_tracking_view.dart';

import 'tabs/growth_tab_view.dart';
import '../presentation/tabs/community_tab_view.dart';
import '../presentation/tabs/settings_tab_view.dart';
import '../../../shared/presentation/universal_support_widget.dart';
import 'parent_profile_settings.dart';
import '../../../core/services/fcm_service.dart';

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

class _ParentDashboardViewState extends State<ParentDashboardView> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  double _vaultBalance = 0.0;
  double _totalFamilyWealth = 0.0;
  bool _isVaultBalanceVisible = true;
  List<Map<String, dynamic>> _linkedStudents = [];
  int _selectedIndex = 0;
  String? _globalSelectedStudentUid;
  int _unresolvedSosCount = 0; // Live count of unresolved SOS alerts
  StreamSubscription<QuerySnapshot>? _sosStreamSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final PageController _financialToolsController = PageController(viewportFraction: 1.0);
  Timer? _financialToolsTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(_pulseController);
    
    _financialToolsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_financialToolsController.hasClients) {
        int nextPage = (_financialToolsController.page?.round() ?? 0) + 1;
        if (nextPage >= 2) {
          _financialToolsController.animateToPage(0, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
        } else {
          _financialToolsController.animateToPage(nextPage, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
        }
      }
    });
    
    _fetchParentData();

    // Initialize FCM so this parent gets push notifications
    FCMService.initialize();

    // Handle notification taps — if it's an SOS alert, jump to SOS Alerts screen
    FCMService.onNotificationTap = (message) {
      final type = message.data['type'] as String? ?? '';
      if ((type == 'sos_alert' || type == 'sos_resolved') && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyAlertsView(
              parentUser: widget.user,
              selectedStudentUid: _globalSelectedStudentUid,
            ),
          ),
        );
      }
    };

    // Start listening for unresolved SOS alerts for this parent
    final parentUid = FirebaseAuth.instance.currentUser?.uid;
    if (parentUid != null) {
      _sosStreamSub = FirebaseFirestore.instance
          .collection('safety_alerts')
          .where('parentUids', arrayContains: parentUid)
          .where('status', isEqualTo: 'Unresolved')
          .snapshots()
          .listen((snap) {
        if (mounted) {
          setState(() => _unresolvedSosCount = snap.docs.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _sosStreamSub?.cancel();
    _pulseController.dispose();
    _financialToolsTimer?.cancel();
    _financialToolsController.dispose();
    super.dispose();
  }

  Future<void> _fetchParentData() async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) return;
      
      final parentDoc = await FirebaseFirestore.instance.collection('users').doc(authUser.uid).get();
      if (!parentDoc.exists) return;
      
      final parentData = parentDoc.data()!;
      double parentAvailableVault = 0.0;
      
      if (parentData['savingsBalance'] != null) {
        parentAvailableVault += (parentData['savingsBalance'] as num).toDouble();
      }
      if (parentData['vaultBalance'] != null) {
        parentAvailableVault += (parentData['vaultBalance'] as num).toDouble();
      }
      if (parentData['walletBalance'] != null) {
        parentAvailableVault += (parentData['walletBalance'] as num).toDouble();
      }
      
      double totalFamilyCash = parentAvailableVault;
      
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
          
          totalFamilyCash += bal;
          
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
          _vaultBalance = parentAvailableVault;
          _totalFamilyWealth = totalFamilyCash;
          _linkedStudents = students;
          _isLoading = false;
          
          bool hasSelected = students.any((s) => s['uid'] == _globalSelectedStudentUid);
          if (!hasSelected && students.isNotEmpty) {
            _globalSelectedStudentUid = students.first['uid'];
          } else if (students.isEmpty) {
            _globalSelectedStudentUid = null;
          }
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

  Widget _buildBehaviorAnalyticsWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: _neonCyan),
              SizedBox(width: 8),
              Text('Behavioral Insights', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          // Embedded FlChart Sparkline
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3), FlSpot(1, 1), FlSpot(2, 4), FlSpot(3, 2), FlSpot(4, 5), FlSpot(5, 3), FlSpot(6, 4)
                    ],
                    isCurved: true,
                    color: _neonCyan,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: _neonCyan.withOpacity(0.2)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInsightMetric('Chore Rate', '85%', Colors.greenAccent),
              _buildInsightMetric('Savings', '+12%', _neonCyan),
              _buildInsightMetric('Flags', '0', _neonPink),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInsightMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildCommunityFeedSnippet() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('forums').orderBy('createdAt', descending: true).limit(1).snapshots(),
      builder: (context, snapshot) {
        String content = 'How do you handle lunchbox limits and school meal budgets?';
        String author = 'Sarah N.';
        String timeAgo = 'Recently';
        
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final postTitle = data['title'] as String?;
          final postContent = data['content'] as String?;
          content = (postTitle != null && postTitle.isNotEmpty) ? postTitle : (postContent ?? content);
          author = data['authorName'] ?? 'Parent';
          
          final ts = data['createdAt'];
          if (ts is Timestamp) {
            final diff = DateTime.now().difference(ts.toDate());
            if (diff.inMinutes < 60) {
              timeAgo = '${diff.inMinutes}m ago';
            } else if (diff.inHours < 24) {
              timeAgo = '${diff.inHours}h ago';
            } else {
              timeAgo = '${diff.inDays}d ago';
            }
          }
        }

        return GestureDetector(
          onTap: () => setState(() => _selectedIndex = 3),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_cardColor, _neonBlue.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _neonCyan.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(color: _neonBlue.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.forum_rounded, color: _neonCyan, size: 20),
                        SizedBox(width: 8),
                        Text('Parent Community', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _neonCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _neonCyan.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Text('Open Forum', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded, color: _neonCyan, size: 10),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: _neonBlue.withOpacity(0.3),
                      child: Text(
                        author.isNotEmpty ? author[0].toUpperCase() : 'P',
                        style: const TextStyle(color: _neonCyan, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$author • $timeAgo', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showSavingsMatcher() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavingsTargetView(
          parentUser: widget.user,
          selectedStudentUid: _globalSelectedStudentUid,
        ),
      ),
    );
  }



  void _grantEmergencyOverdraft(Map<String, dynamic> student) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Emergency Overdraft', style: TextStyle(color: MPesaTheme.primaryRed)),
        content: Text('Allow ${student['name']} to go into negative balance (up to Ksh 500) for emergencies?', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection('users').doc(student['uid']).update({
                  'allowOverdraft': true,
                  'overdraftLimit': 500
                });
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Overdraft granted.')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Grant Ksh 500', style: TextStyle(color: MPesaTheme.primaryRed, fontWeight: FontWeight.bold)),
          ),
        ],
      )
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
      builder: (context, snapshot) {
        String parentName = widget.user['name'] ?? widget.user['displayName'] ?? 'Parent';
        String? profileImageUrl = widget.user['profileImageUrl'];
        String parentPhone = widget.user['phoneNumber'] ?? widget.user['phone'] ?? '';

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          parentName = data['name'] ?? data['displayName'] ?? parentName;
          profileImageUrl = data['profileImageUrl'] ?? profileImageUrl;
          parentPhone = data['phone'] ?? data['phone_number'] ?? parentPhone;
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B29).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
                    if (parentPhone.isNotEmpty)
                      Text(
                        parentPhone,
                        style: const TextStyle(color: _neonBlue, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isSearching = true),
                child: _buildIconContainer(Icons.search),
              ),
              const SizedBox(width: 4),
              _unresolvedSosCount > 0
                  ? ScaleTransition(
                      scale: _pulseAnimation,
                      child: _buildParentNotificationBell(FirebaseAuth.instance.currentUser?.uid ?? ''),
                    )
                  : _buildParentNotificationBell(FirebaseAuth.instance.currentUser?.uid ?? ''),
            ],
          ),
        ),
      )));
    });
  }

  Widget _buildIconContainer(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: _surfaceLight, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildParentNotificationBell(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        int unread = 0;
        List<DocumentSnapshot> myNotes = [];
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final targetId = data['targetUserId'] as String?;
            final dismissed = List<String>.from(data['dismissedBy'] ?? []);
            if ((targetId == null || targetId == uid) && !dismissed.contains(uid)) {
              myNotes.add(doc);
              final readBy = List<String>.from(data['readBy'] ?? []);
              if (!readBy.contains(uid)) unread++;
            }
          }
        }
        return GestureDetector(
          onTap: () => _showParentNotificationsSheet(uid, myNotes),
          child: Stack(
            children: [
              _buildIconContainer(Icons.notifications_none),
              if (unread > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: _neonPink, shape: BoxShape.circle),
                    child: Text(unread > 9 ? '9+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showParentNotificationsSheet(String uid, List<DocumentSnapshot> notes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, sc) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.5)))),
              const SizedBox(height: 24),
              const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: notes.isEmpty
                    ? const Center(child: Text('No notifications', style: TextStyle(color: _textSecondary)))
                    : ListView.separated(
                        controller: sc,
                        itemCount: notes.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                        itemBuilder: (_, i) {
                          final doc = notes[i];
                          final data = doc.data() as Map<String, dynamic>;
                          final readBy = List<String>.from(data['readBy'] ?? []);
                          final isRead = readBy.contains(uid);
                          return Dismissible(
                            key: Key(doc.id),
                            direction: DismissDirection.endToStart,
                            background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: _neonPink, child: const Icon(Icons.delete, color: Colors.white)),
                            onDismissed: (_) async {
                              await FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({'dismissedBy': FieldValue.arrayUnion([uid])});
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: isRead ? _surfaceLight : _neonCyan.withOpacity(0.2), shape: BoxShape.circle),
                                child: Icon(Icons.notifications, color: isRead ? _textSecondary : _neonCyan),
                              ),
                              title: Text(data['title'] ?? '', style: TextStyle(color: Colors.white, fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                              subtitle: Text(data['message'] ?? '', style: const TextStyle(color: _textSecondary)),
                              onTap: () async {
                                if (!isRead) {
                                  await FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({'readBy': FieldValue.arrayUnion([uid])});
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Page controller for vault card swipe ──────────────────────────────────
  final PageController _vaultPageController = PageController();
  int _currentVaultPage = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      _buildHomeTab(),
      _buildDependentsTab(),
      _buildVaultTab(),
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
      bottomNavigationBar: _buildPremiumBottomNav(),
    );
  }

  Widget _buildPremiumBottomNav() {
    final items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.people_rounded, Icons.people_outline, 'Dependents'),
      (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Vault'),
      (Icons.public_rounded, Icons.public_outlined, 'Community'),
      (Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E1421).withOpacity(0.75),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07), width: 1)),
            ),
            child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
            children: List.generate(items.length, (i) {
              final isSelected = _selectedIndex == i;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? _neonCyan.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.$1 : item.$2,
                          color: isSelected ? _neonCyan : _textSecondary,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: isSelected ? _neonCyan : _textSecondary,
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ))));
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      color: _neonCyan,
      backgroundColor: _cardColor,
      onRefresh: _fetchParentData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 80,
          floating: true,
          pinned: false,
          automaticallyImplyLeading: false,
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
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 80.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // —— SOS Banner ——
              if (_unresolvedSosCount > 0) ...[_buildSosBanner(), const SizedBox(height: 16)],

              // —— Top Level Child Switcher ——
              if (_linkedStudents.length > 1) _buildChildSwitcher(),
              if (_linkedStudents.length > 1) const SizedBox(height: 16),

              // —— Family Guardian Tier Banner ——
              _buildGuardianBadge(),
              const SizedBox(height: 16),

              // —— Swipeable Vault Cards ——
              _buildVaultPageView(),
              const SizedBox(height: 8),
              _buildVaultPaginationDots(),
              const SizedBox(height: 28),

              // —— Smart Suggestions ——
              _buildSmartSuggestions(),
              const SizedBox(height: 28),

              // —— Quick Actions (icon row, student-style) ——
              _buildParentQuickActions(),
              const SizedBox(height: 28),

              // —— Behavioral Insights ——
              _buildBehaviorAnalyticsWidget(),
              const SizedBox(height: 24),

              // —— Support Widget ——
              UniversalSupportWidget(userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown', userRole: 'parent'),
              const SizedBox(height: 24),

              // —— Community Snippet ——
              _buildCommunityFeedSnippet(),
            ]),
          ),
        ),
      ],
    ));
  }

  Widget _buildGuardianBadge() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubscriptionManagerView(
              parentUser: widget.user,
              selectedStudentUid: _globalSelectedStudentUid,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _neonCyan.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: _neonCyan.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Family Guardian', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Full oversight · All features unlocked', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultPageView() {
    // Build card list: vault overview + one per linked student
    final cards = <Widget>[
      _buildFamilyVaultCard(),
      ..._linkedStudents.map((s) => _buildStudentVaultCard(s)),
    ];
    return SizedBox(
      height: 220,
      child: PageView(
        controller: _vaultPageController,
        onPageChanged: (i) => setState(() => _currentVaultPage = i),
        children: cards,
      ),
    );
  }

  Widget _buildFamilyVaultCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonCyan.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: _neonCyan, size: 18),
              SizedBox(width: 8),
              Text('Shared Family Vault', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'KSH ${_vaultBalance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const Spacer(),
          // Progress bar (family allocation visual)
          Stack(
            children: [
              Container(height: 6, width: double.infinity, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(
                widthFactor: (_linkedStudents.isEmpty || _vaultBalance == 0) ? 0.0 : ((_linkedStudents.fold(0.0, (sum, s) => sum + ((s['balance'] as double?) ?? 0.0))) / _vaultBalance).clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: _neonCyan,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.5), blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showVaultTopUpModal(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _neonCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _neonCyan.withOpacity(0.5)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Top Up', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showBulkFundModal(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _neonCyan,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Fund Students', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentVaultCard(Map<String, dynamic> student) {
    final bool isActive = (student['status'] as String?) == 'Active';
    final Color accent = isActive ? _neonCyan : _neonOrange;
    final double bal = (student['balance'] as double?) ?? 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF141E30), accent.withOpacity(0.25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.12), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: accent.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.school_rounded, color: accent, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(student['name'] as String? ?? 'Student', style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Text(isActive ? 'Active' : 'Low', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'KSH ${bal.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showTopUpModal(context, student['uid'] as String, student['name'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: accent.withOpacity(0.5))),
                    alignment: Alignment.center,
                    child: Text('Fund', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _showKillSwitchDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: _neonPink.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _neonPink.withOpacity(0.5))),
                    alignment: Alignment.center,
                    child: const Text('Controls', style: TextStyle(color: _neonPink, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVaultPaginationDots() {
    final total = 1 + _linkedStudents.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentVaultPage == i ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: _currentVaultPage == i ? _neonCyan : _surfaceLight,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildParentQuickActions() {
    final actions = [
      _buildParentActionIcon(Icons.security_rounded, 'Kill Switch', _neonPink, _showKillSwitchDialog),
      _buildParentActionIcon(Icons.warning_amber_rounded, 'SOS Alerts', MPesaTheme.primaryRed, _showEmergencyAlerts, badge: _unresolvedSosCount),
      _buildParentActionIcon(Icons.gavel_rounded, 'Disputes', const Color(0xFFF59E0B), _showDisputes),
      _buildParentActionIcon(Icons.group_add_rounded, 'Co-Parent', _neonBlue, _showCoParenting),
      _buildParentActionIcon(Icons.handshake_rounded, 'Savings Match', _neonCyan, _showSavingsMatcher),
      _buildParentActionIcon(Icons.my_location_rounded, 'Live Track', Colors.orangeAccent, _showLiveTracking),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 1),
              child: Text('Manage >', style: TextStyle(color: _neonCyan.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: actions.map((a) => Padding(padding: const EdgeInsets.only(right: 16), child: a)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildParentActionIcon(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.25), color.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)],
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
                maxLines: 2,
              ),
            ],
          ),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: _bgColor, width: 1.5)),
                child: Center(child: Text(badge > 9 ? '9+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDependentsTab() {
    final activeStudent = _linkedStudents.firstWhere(
      (s) => s['uid'] == _globalSelectedStudentUid,
      orElse: () => _linkedStudents.isNotEmpty ? _linkedStudents.first : {},
    );

    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: _bgColor,
            elevation: 0,
            pinned: true,
            automaticallyImplyLeading: false,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dependents & Growth', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Unified guardian controls, spend guardrails & incentives', style: TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Link Existing Student',
                icon: const Icon(Icons.person_add_alt_1_rounded, color: _neonCyan),
                onPressed: _showLinkChildDialog,
              ),
              IconButton(
                tooltip: 'Add Offline Child',
                icon: const Icon(Icons.qr_code_2_rounded, color: _neonBlue),
                onPressed: _showAddOfflineChildDialog,
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // --- QUICK ACTION PILLS (LINK / ADD OFFLINE) ---
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _showLinkChildDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _neonCyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _neonCyan.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.link_rounded, color: _neonCyan, size: 18),
                              SizedBox(width: 8),
                              Text('Link Student ID', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _showAddOfflineChildDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _neonBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _neonBlue.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.badge_outlined, color: _neonBlue, size: 18),
                              SizedBox(width: 8),
                              Text('Create Offline Child', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- EMPTY STATE IF NO STUDENTS LINKED ---
                if (_linkedStudents.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _neonCyan.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.family_restroom_rounded, color: _neonCyan, size: 48),
                        ),
                        const SizedBox(height: 16),
                        const Text('No Dependents Linked', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Connect your children in university, high school, or primary school to fund them instantly, set meal budgets, and view live academic rewards.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showLinkChildDialog,
                          icon: const Icon(Icons.add, color: Colors.black),
                          label: const Text('Link First Student', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // --- INTERACTIVE CHILD SELECTOR CAROUSEL ---
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Linked Children', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Tap to focus', style: TextStyle(color: _textSecondary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _linkedStudents.length,
                      itemBuilder: (context, index) {
                        final student = _linkedStudents[index];
                        final isSelected = student['uid'] == _globalSelectedStudentUid;
                        final isFrozen = student['isFrozen'] == true;
                        final isLow = (student['balance'] as double? ?? 0.0) < 200;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _globalSelectedStudentUid = student['uid']);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF16253D) : _cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? _neonCyan
                                    : (isFrozen ? _neonPink.withOpacity(0.5) : Colors.white12),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: _neonCyan.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)]
                                  : [],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isSelected ? _neonCyan.withOpacity(0.25) : _surfaceLight,
                                      child: Text(
                                        (student['name'] as String?)?.isNotEmpty == true ? (student['name'] as String)[0].toUpperCase() : 'S',
                                        style: TextStyle(color: isSelected ? _neonCyan : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        student['name'] as String? ?? 'Child',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: _neonCyan, size: 14),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'KSH ${(student['balance'] as double? ?? 0.0).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: isLow ? _neonOrange : Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isFrozen ? _neonPink : (student['isOffline'] == true ? _neonBlue : _neonCyan)).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isFrozen ? 'FROZEN' : (student['isOffline'] == true ? 'OFFLINE' : 'ONLINE'),
                                        style: TextStyle(
                                          color: isFrozen ? _neonPink : (student['isOffline'] == true ? _neonBlue : _neonCyan),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- ACTIVE CHILD 360° MANAGEMENT CARD ---
                  if (activeStudent.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF131D31), Color(0xFF182238)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _neonCyan.withOpacity(0.35), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: _neonCyan.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [_neonCyan.withOpacity(0.3), _neonBlue.withOpacity(0.3)],
                                  ),
                                  border: Border.all(color: _neonCyan, width: 1.5),
                                ),
                                child: const Icon(Icons.school_rounded, color: _neonCyan, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            activeStudent['name'] as String? ?? 'Student',
                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (activeStudent['isFrozen'] == true)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: _neonPink.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('FROZEN', style: TextStyle(color: _neonPink, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      activeStudent['isOffline'] == true ? 'Offline School Pass · Tap PIN to spend' : 'Connected Mobile Student',
                                      style: const TextStyle(color: _textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white70),
                                color: _cardColor,
                                onSelected: (val) {
                                  if (val == 'unlink') {
                                    _confirmDeleteStudent(activeStudent);
                                  } else if (val == 'qr' && activeStudent['isOffline'] == true) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => OfflineChildQrView(studentName: activeStudent['name'], uid: activeStudent['uid'])));
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  if (activeStudent['isOffline'] == true)
                                    const PopupMenuItem(
                                      value: 'qr',
                                      child: Row(
                                        children: [
                                          Icon(Icons.qr_code, color: _neonCyan, size: 18),
                                          SizedBox(width: 10),
                                          Text('View School QR Pass', style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'unlink',
                                    child: Row(
                                      children: [
                                        Icon(Icons.link_off, color: MPesaTheme.primaryRed, size: 18),
                                        SizedBox(width: 10),
                                        Text('Unlink Dependent', style: TextStyle(color: MPesaTheme.primaryRed)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Live balance row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Available Pocket Money', style: TextStyle(color: _textSecondary, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'KSH ${(activeStudent['balance'] as double? ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () => _showTopUpModal(context, activeStudent['uid'], activeStudent['name']),
                                icon: const Icon(Icons.bolt, color: Colors.black, size: 18),
                                label: const Text('Fund Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _neonCyan,
                                  elevation: 3,
                                  shadowColor: _neonCyan.withOpacity(0.5),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 4 Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    final tempUser = UserModel(
                                      uid: activeStudent['uid'],
                                      displayName: activeStudent['name'],
                                      email: '',
                                      roles: ['student'],
                                      walletBalance: activeStudent['balance'],
                                    );
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => VirtualCardView(userModel: tempUser)));
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: _surfaceLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _neonBlue.withOpacity(0.4)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Column(
                                      children: [
                                        Icon(Icons.credit_card_rounded, color: _neonBlue, size: 18),
                                        SizedBox(height: 4),
                                        Text('Virtual Card', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _grantEmergencyOverdraft(activeStudent),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: MPesaTheme.primaryRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: MPesaTheme.primaryRed.withOpacity(0.4)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Column(
                                      children: [
                                        Icon(Icons.shield_outlined, color: MPesaTheme.primaryRed, size: 18),
                                        SizedBox(height: 4),
                                        Text('Overdraft', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    bool isFrozen = activeStudent['isFrozen'] ?? false;
                                    try {
                                      await FirebaseFirestore.instance.collection('users').doc(activeStudent['uid']).update({
                                        'isFrozen': !isFrozen
                                      });
                                      setState(() {
                                        activeStudent['isFrozen'] = !isFrozen;
                                      });
                                      _fetchParentData();
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('${activeStudent['name']} is now ${!isFrozen ? 'FROZEN' : 'ACTIVE'}.'),
                                        backgroundColor: !isFrozen ? _neonPink : MPesaTheme.primaryGreen,
                                      ));
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: (activeStudent['isFrozen'] == true ? _neonPink : Colors.tealAccent).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: (activeStudent['isFrozen'] == true ? _neonPink : Colors.tealAccent).withOpacity(0.4)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        Icon(activeStudent['isFrozen'] == true ? Icons.lock_open : Icons.lock_outline, color: activeStudent['isFrozen'] == true ? _neonPink : Colors.tealAccent, size: 18),
                                        SizedBox(height: 4),
                                        Text(activeStudent['isFrozen'] == true ? 'Unfreeze' : 'Freeze Card', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: _showLiveTracking,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: Colors.orangeAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Column(
                                      children: [
                                        Icon(Icons.location_on_outlined, color: Colors.orangeAccent, size: 18),
                                        SizedBox(height: 4),
                                        Text('Live Track', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Daily limit strip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _bgColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.speed_rounded, color: _neonOrange, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    activeStudent['dailyLimit'] != null
                                        ? 'Daily Spend Cap: KSH ${activeStudent['dailyLimit']}/day'
                                        : 'No daily limit configured',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _showSetLimitDialog(activeStudent['uid'], activeStudent['name'], activeStudent['dailyLimit']),
                                  child: const Text('Edit Cap >', style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ],

                // --- RULES & SAFEGUARDS GRID ---
                const Text('Smart Safeguards & Budgets', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Establish nutritional safety, transit limits & academic security', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _buildActionGridButton(Icons.restaurant_rounded, 'Nutrition Limits', _neonOrange, _showNutritionSelector),
                    _buildActionGridButton(Icons.block_rounded, 'Vendor Locks', _neonPink, _showVendorRestrictions),
                    _buildActionGridButton(Icons.local_hospital_rounded, 'Medical Lock', MPesaTheme.neonCyan, _showMedicalLock),
                    _buildActionGridButton(Icons.directions_bus_rounded, 'Transport Pass', Colors.amber, _showTransportAllowance),
                    _buildActionGridButton(Icons.home_work_rounded, 'Housing / Boarding', Colors.tealAccent, _showHousingPayments),
                    _buildActionGridButton(Icons.account_balance_rounded, 'Tuition & Fees', Colors.blueAccent, _showTuitionPayments),
                    _buildActionGridButton(Icons.map_rounded, 'Geofence Safety', Colors.lightGreenAccent, _showGeofenceAlerts),
                    _buildActionGridButton(Icons.security_rounded, 'Kill Switch', MPesaTheme.primaryRed, _showKillSwitchDialog),
                  ],
                ),
                const SizedBox(height: 32),

                // --- INTEGRATED FAMILY GROWTH & MOTIVATION SECTION ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Child Growth & Rewards', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Incentivize chores, savings discipline & academic success', style: TextStyle(color: _textSecondary, fontSize: 12)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.school, color: Colors.blueAccent),
                      tooltip: 'Academic SmartI Rewards',
                      onPressed: _showAcademicRewards,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Smart Spender Score Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _neonCyan.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 64,
                        width: 64,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: 0.88,
                              strokeWidth: 6,
                              color: _neonCyan,
                              backgroundColor: Colors.white12,
                            ),
                            const Center(child: Text('88', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Smart Spender Rating: Excellent', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Disciplined spender — 92% of expenses at certified campus meal vendors.', style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Chores & Bounties
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Chores & Tasks', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _showAssignChoreDialog,
                      icon: const Icon(Icons.add_task_rounded, color: _neonOrange, size: 16),
                      label: const Text('+ Assign Task', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bounties')
                      .where('parentUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? widget.user['uid'])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: _neonOrange)));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: _textSecondary, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('No chores assigned yet. Assign a chore to reward your student!', style: TextStyle(color: _textSecondary, fontSize: 13))),
                            TextButton(onPressed: _showAssignChoreDialog, child: const Text('Assign', style: TextStyle(color: _neonCyan))),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final bool isCompleted = data['status'] == 'completed';
                        final double reward = (data['reward'] as num?)?.toDouble() ?? 0.0;
                        final String choreTitle = data['title'] ?? 'Task';
                        final String assignedName = data['studentName'] ?? 'Child';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isCompleted ? _neonCyan.withOpacity(0.3) : _neonOrange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isCompleted ? _neonCyan : _neonOrange).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(isCompleted ? Icons.check_circle_rounded : Icons.pending_actions_rounded, color: isCompleted ? _neonCyan : _neonOrange, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(choreTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('For: $assignedName · Reward: KSH ${reward.toStringAsFixed(0)}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (!isCompleted)
                                ElevatedButton(
                                  onPressed: () => _approveChore(doc),
                                  style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                  child: const Text('Approve & Pay', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('PAID', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Savings Goals & Matching
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Savings Goals & Matching', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: _showSavingsTarget,
                      child: const Text('View All >', style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('savings_goals')
                      .where('parentUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? widget.user['uid'])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: _neonCyan)));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.savings_rounded, color: _textSecondary, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('No active savings goals. Tap to set financial targets.', style: TextStyle(color: _textSecondary, fontSize: 13))),
                            TextButton(onPressed: _showSavingsTarget, child: const Text('Set Goal', style: TextStyle(color: _neonCyan))),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final double current = (data['current'] as num?)?.toDouble() ?? 0.0;
                        final double target = (data['target'] as num?)?.toDouble() ?? 1000.0;
                        final double ratio = (current / (target > 0 ? target : 1)).clamp(0.0, 1.0);
                        final String title = data['title'] ?? 'Savings Goal';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _neonCyan.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('KSH ${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  backgroundColor: Colors.white12,
                                  color: _neonCyan,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${(ratio * 100).toInt()}% Achieved', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                                  OutlinedButton.icon(
                                    onPressed: () => _showMatchSavingsDialog(doc),
                                    icon: const Icon(Icons.handshake_rounded, size: 14, color: _neonCyan),
                                    label: const Text('Match Funds', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: _neonCyan),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultTab() {
    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: _bgColor,
            elevation: 0,
            pinned: true,
            automaticallyImplyLeading: false,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Family Vault & Finance', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Central liquidity, automated allowances & live family ledger', style: TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh Ledger',
                icon: const Icon(Icons.refresh_rounded, color: _neonCyan),
                onPressed: _fetchParentData,
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // --- MASTER VAULT HERO LIQUIDITY CARD ---
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF142C4C), Color(0xFF0E1A2D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _neonCyan.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: _neonCyan.withOpacity(0.12), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 6)),
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), shape: BoxShape.circle),
                                  child: const Icon(Icons.shield_rounded, color: _neonCyan, size: 20),
                                ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Text(
                                    'Central Family Vault',
                                    style: TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  _isVaultBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _isVaultBalanceVisible = !_isVaultBalanceVisible),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: MPesaTheme.primaryGreen.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, color: MPesaTheme.primaryGreen, size: 10),
                                    SizedBox(width: 3),
                                    Text('Encrypted', style: TextStyle(color: MPesaTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text(
                        _isVaultBalanceVisible
                            ? 'KSH ${_vaultBalance.toStringAsFixed(2)}'
                            : 'KSH ••••••••',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isVaultBalanceVisible
                            ? 'Total Family Wealth: KSH ${_totalFamilyWealth.toStringAsFixed(2)}'
                            : 'Total Family Wealth: KSH ••••••••',
                        style: const TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 22),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showVaultTopUpModal(context),
                              icon: const Icon(Icons.add_card_rounded, color: Colors.black, size: 16),
                              label: const Text('Top Up Vault', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _neonCyan,
                                elevation: 3,
                                shadowColor: _neonCyan.withOpacity(0.4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showBulkFundModal(context),
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                              label: const Text('Disburse to Kids', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _neonBlue,
                                elevation: 3,
                                shadowColor: _neonBlue.withOpacity(0.4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: _showAuditStatementSheet,
                            tooltip: 'Statement',
                            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white70),
                            style: IconButton.styleFrom(
                              backgroundColor: _surfaceLight,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- VAULT ALLOCATIONS BREAKDOWN STRIP ---
                if (_linkedStudents.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dependent Wallet Allocations', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${_linkedStudents.length} Children', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 96,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _linkedStudents.length,
                      itemBuilder: (context, index) {
                        final s = _linkedStudents[index];
                        final double bal = (s['balance'] as double? ?? 0.0);
                        return Container(
                          width: 155,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _neonBlue.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: _neonBlue.withOpacity(0.2),
                                    child: Text(
                                      (s['name'] as String?)?.isNotEmpty == true ? (s['name'] as String)[0].toUpperCase() : 'S',
                                      style: const TextStyle(color: _neonBlue, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      s['name'] as String? ?? 'Child',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('KSH ${bal.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.w800, fontSize: 15)),
                                  InkWell(
                                    onTap: () => _showTopUpModal(context, s['uid'], s['name']),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: _neonCyan.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                      child: const Text('+ Fund', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // --- FINANCIAL COMMAND CENTER ---
                const Text('Financial Tools & Automation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Scheduled allowances, auto top-up guardrails & analytics', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 14),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _buildActionGridButton(Icons.schedule_rounded, 'Allowances', _neonOrange, _showScheduledAllowances),
                    _buildActionGridButton(Icons.bolt_rounded, 'Auto Top-Up', _neonCyan, _showAutoTopUpSelector),
                    _buildActionGridButton(Icons.pie_chart_rounded, 'Spending Analytics', _neonBlue, _showSpendingAnalytics),
                    _buildActionGridButton(Icons.bento_rounded, 'Lunchbox Cafeteria', Colors.greenAccent, _showLunchboxSelector),
                    _buildActionGridButton(Icons.savings_rounded, 'Savings Targets', MPesaTheme.primaryGreen, _showSavingsTarget),
                    _buildActionGridButton(Icons.school_rounded, 'Graduation Fund', Colors.purpleAccent, _showGraduationFund),
                    _buildActionGridButton(Icons.autorenew_rounded, 'Bills & Subs', Colors.cyanAccent, _showSubscriptionManager),
                    _buildActionGridButton(Icons.family_restroom_rounded, 'Shared Vault', _neonBlue, _showSharedWalletDialog),
                  ],
                ),
                const SizedBox(height: 32),

                // --- REAL-TIME LIVE FAMILY LEDGER FEED ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: MPesaTheme.primaryGreen, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text('Live Family Ledger', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    TextButton(
                      onPressed: _showAuditStatementSheet,
                      child: const Text('Statement >', style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('senderUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? widget.user['uid'])
                      .orderBy('timestamp', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _neonCyan)));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
                        child: const Row(
                          children: [
                            Icon(Icons.history_rounded, color: _textSecondary),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'No recent transactions. Deposits and student transfers will record automatically in real-time.',
                                style: TextStyle(color: _textSecondary, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                        final String desc = data['description'] ?? 'Vault Transfer';
                        final String type = data['type'] ?? 'parent_transfer';
                        final ts = data['timestamp'] as Timestamp?;
                        final String timeStr = ts != null ? DateFormat('MMM d, h:mm a').format(ts.toDate()) : 'Just now';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: (type == 'deposit' ? MPesaTheme.primaryGreen : _neonBlue).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  type == 'deposit' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: type == 'deposit' ? MPesaTheme.primaryGreen : _neonBlue,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(desc, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(timeStr, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${type == 'deposit' ? '+' : '-'} KSH ${amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: type == 'deposit' ? MPesaTheme.primaryGreen : _neonCyan,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: MPesaTheme.primaryGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('SUCCESS', style: TextStyle(color: MPesaTheme.primaryGreen, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignChoreDialog() {
    if (_linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please link a student first to assign chores.')));
      return;
    }

    final titleController = TextEditingController();
    final rewardController = TextEditingController(text: '100');
    String selectedStudentUid = _globalSelectedStudentUid ?? _linkedStudents.first['uid'];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _neonOrange.withOpacity(0.5))),
          title: const Row(
            children: [
              Icon(Icons.assignment_add, color: _neonOrange),
              SizedBox(width: 10),
              Text('Assign Chore or Bounty', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Dependent:', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedStudentUid,
                  dropdownColor: _surfaceLight,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _linkedStudents.map((s) {
                    return DropdownMenuItem<String>(
                      value: s['uid'],
                      child: Text(s['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStudentUid = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'e.g. Clean bedroom, Score A in Chemistry',
                    labelStyle: const TextStyle(color: _neonOrange),
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: rewardController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Reward Amount (Ksh)',
                    labelStyle: const TextStyle(color: _neonCyan),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Text('KSH', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final reward = double.tryParse(rewardController.text.trim()) ?? 0.0;
                      if (title.isEmpty || reward <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid task title and reward.')));
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final parentUid = FirebaseAuth.instance.currentUser!.uid;
                        final student = _linkedStudents.firstWhere((s) => s['uid'] == selectedStudentUid, orElse: () => {});
                        final studentName = student['name'] ?? 'Child';

                        await FirebaseFirestore.instance.collection('bounties').add({
                          'parentUid': parentUid,
                          'studentUid': selectedStudentUid,
                          'studentName': studentName,
                          'title': title,
                          'reward': reward,
                          'status': 'pending',
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Task assigned to $studentName for KSH ${reward.toStringAsFixed(0)}!'),
                            backgroundColor: _neonOrange,
                          ));
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: _neonOrange),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Assign Task', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveChore(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final double reward = (data['reward'] as num?)?.toDouble() ?? 0.0;
    final String studentUid = data['studentUid'] ?? '';
    final String studentName = data['studentName'] ?? 'Child';
    final parentUid = FirebaseAuth.instance.currentUser!.uid;

    if (_vaultBalance < reward) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Insufficient vault balance to pay reward. Available: KSH ${_vaultBalance.toStringAsFixed(2)}'),
        backgroundColor: _neonPink,
      ));
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      await db.runTransaction((tx) async {
        final parentRef = db.collection('users').doc(parentUid);
        final studentRef = db.collection('users').doc(studentUid);
        final choreRef = doc.reference;

        final pSnap = await tx.get(parentRef);
        final sSnap = await tx.get(studentRef);
        final pData = pSnap.data() ?? {};
        final sData = sSnap.data() ?? {};

        double pSavings = (pData['savingsBalance'] as num?)?.toDouble() ?? 0.0;
        double pVault = (pData['vaultBalance'] as num?)?.toDouble() ?? 0.0;
        double pWallet = (pData['walletBalance'] as num?)?.toDouble() ?? 0.0;
        double avail = pSavings + pVault + pWallet;
        if (avail < reward) throw Exception('Insufficient Vault funds.');

        double rem = reward;
        Map<String, dynamic> pUp = {};
        if (pSavings > 0) { double d = pSavings >= rem ? rem : pSavings; pUp['savingsBalance'] = pSavings - d; rem -= d; }
        if (rem > 0 && pVault > 0) { double d = pVault >= rem ? rem : pVault; pUp['vaultBalance'] = pVault - d; rem -= d; }
        if (rem > 0 && pWallet > 0) { double d = pWallet >= rem ? rem : pWallet; pUp['walletBalance'] = pWallet - d; rem -= d; }
        tx.update(parentRef, pUp);

        double sWallet = (sData['walletBalance'] as num?)?.toDouble() ?? 0.0;
        tx.update(studentRef, {'walletBalance': sWallet + reward});

        tx.update(choreRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        final txRef = db.collection('transactions').doc();
        tx.set(txRef, {
          'type': 'chore_reward',
          'senderUid': parentUid,
          'receiverUid': studentUid,
          'amount': reward,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
          'description': 'Reward: ${data['title']} for $studentName'
        });
      });

      await _fetchParentData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Chore approved! KSH ${reward.toStringAsFixed(0)} deposited to $studentName\'s wallet.'),
          backgroundColor: MPesaTheme.primaryGreen,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error approving chore: $e')));
    }
  }

  void _showMatchSavingsDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String title = data['title'] ?? 'Savings Goal';
    final double target = (data['target'] as num?)?.toDouble() ?? 1000.0;
    final double current = (data['current'] as num?)?.toDouble() ?? 0.0;
    final String studentUid = data['studentUid'] ?? '';
    final matchController = TextEditingController(text: '200');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _neonCyan)),
        title: Text('Match Funds for $title', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target: KSH ${target.toStringAsFixed(0)} · Current: KSH ${current.toStringAsFixed(0)}', style: const TextStyle(color: _textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: matchController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Match Amount from Vault',
                labelStyle: const TextStyle(color: _neonCyan),
                filled: true,
                fillColor: _surfaceLight,
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Text('KSH', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final matchAmt = double.tryParse(matchController.text.trim()) ?? 0.0;
              if (matchAmt <= 0) return;
              if (matchAmt > _vaultBalance) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient vault balance.')));
                return;
              }

              Navigator.pop(context);
              try {
                final parentUid = FirebaseAuth.instance.currentUser!.uid;
                final db = FirebaseFirestore.instance;
                await db.runTransaction((tx) async {
                  final pRef = db.collection('users').doc(parentUid);
                  final pSnap = await tx.get(pRef);
                  final pData = pSnap.data() ?? {};
                  double pSavings = (pData['savingsBalance'] as num?)?.toDouble() ?? 0.0;
                  double pVault = (pData['vaultBalance'] as num?)?.toDouble() ?? 0.0;
                  double pWallet = (pData['walletBalance'] as num?)?.toDouble() ?? 0.0;

                  double rem = matchAmt;
                  Map<String, dynamic> pUp = {};
                  if (pSavings > 0) { double d = pSavings >= rem ? rem : pSavings; pUp['savingsBalance'] = pSavings - d; rem -= d; }
                  if (rem > 0 && pVault > 0) { double d = pVault >= rem ? rem : pVault; pUp['vaultBalance'] = pVault - d; rem -= d; }
                  if (rem > 0 && pWallet > 0) { double d = pWallet >= rem ? rem : pWallet; pUp['walletBalance'] = pWallet - d; rem -= d; }
                  tx.update(pRef, pUp);

                  tx.update(doc.reference, {
                    'current': FieldValue.increment(matchAmt),
                  });

                  if (studentUid.isNotEmpty) {
                    final sRef = db.collection('users').doc(studentUid);
                    tx.update(sRef, {'walletBalance': FieldValue.increment(matchAmt)});
                  }
                });

                await _fetchParentData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Matched KSH ${matchAmt.toStringAsFixed(0)} into $title!'),
                    backgroundColor: MPesaTheme.primaryGreen,
                  ));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
            child: const Text('Match Funds', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAuditStatementSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _neonCyan.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: _neonCyan),
                SizedBox(width: 10),
                Text('Family Vault Audit Summary', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 18),
            _buildAuditRow('Available Vault Liquidity', 'KSH ${_vaultBalance.toStringAsFixed(2)}', _neonCyan),
            const Divider(color: Colors.white12),
            _buildAuditRow('Total Family Wealth (Vault + Kids)', 'KSH ${_totalFamilyWealth.toStringAsFixed(2)}', Colors.white),
            const Divider(color: Colors.white12),
            _buildAuditRow('Linked Dependents', '${_linkedStudents.length}', _neonBlue),
            const Divider(color: Colors.white12),
            _buildAuditRow('Account Security Level', 'Grade A+ (M-PESA Daraja)', MPesaTheme.primaryGreen),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: _cardColor, side: const BorderSide(color: Colors.white12)),
                child: const Text('Close Statement', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
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
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _confirmDeleteStudent(student),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_off, color: MPesaTheme.primaryRed, size: 14),
                        SizedBox(width: 4),
                        Text('Stop Funding', style: TextStyle(color: MPesaTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
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
                    child: const Text('Top Up', style: TextStyle(color: _neonBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    final tempUser = UserModel(
                      uid: student['uid'],
                      displayName: student['name'],
                      email: '',
                      roles: ['student'],
                      walletBalance: student['balance'],
                    );
                    Navigator.push(context, MaterialPageRoute(builder: (context) => VirtualCardView(userModel: tempUser)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _neonCyan,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('VCC Card', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    _grantEmergencyOverdraft(student);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: MPesaTheme.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MPesaTheme.primaryRed),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Overdraft', style: TextStyle(color: MPesaTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _confirmDeleteStudent(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Stop Funding Student', style: TextStyle(color: MPesaTheme.primaryRed)),
        content: Text('Are you sure you want to unlink ${student['name']}? You will no longer be able to fund or manage their account.', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final parentUid = FirebaseAuth.instance.currentUser!.uid;
                final studentUid = student['uid'];
                
                await FirebaseFirestore.instance.collection('users').doc(parentUid).update({
                  'linkedStudents': FieldValue.arrayRemove([studentUid])
                });
                
                await FirebaseFirestore.instance.collection('users').doc(studentUid).update({
                  'linkedParents': FieldValue.arrayRemove([parentUid])
                });
                
                // If the student is offline, we completely delete their account to avoid orphaned data
                if (student['isOffline'] == true) {
                  await FirebaseFirestore.instance.collection('users').doc(studentUid).delete();
                }
                
                if (mounted) {
                  setState(() {
                    _linkedStudents.removeWhere((s) => s['uid'] == studentUid);
                    if (!_linkedStudents.any((s) => s['uid'] == _globalSelectedStudentUid)) {
                      _globalSelectedStudentUid = _linkedStudents.isNotEmpty ? _linkedStudents.first['uid'] : null;
                    }
                  });
                  _fetchParentData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student unlinked successfully.')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryRed),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          )
        ],
      )
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
              const Text('Ask your child for their Name, EMAIL, or DISHI ID (found on their student dashboard or ID card) and enter the DISHI ID below.', style: TextStyle(color: _textSecondary, fontSize: 13)),
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
      'linkedParents': FieldValue.arrayUnion([parentUid])
    });

    if (mounted) {
      Navigator.pop(context);
      _fetchParentData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student linked successfully!')));
    }
  }

  void _showAddOfflineChildDialog() {
    final nameController = TextEditingController();
    final schoolController = TextEditingController();
    final regNumberController = TextEditingController();
    final pinController = TextEditingController();
    bool isCreating = false;
    bool obscurePin = true;
    File? selectedImage;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: _cardColor,
          title: const Text('Add Offline Child', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Create a DISHI profile for a child in primary or secondary school without a phone. They will get a QR code and PIN to use at school.', style: TextStyle(color: _textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    try {
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                      if (image != null) {
                        setState(() => selectedImage = File(image.path));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: _neonBlue.withOpacity(0.2),
                    backgroundImage: selectedImage != null ? FileImage(selectedImage!) : null,
                    child: selectedImage == null ? const Icon(Icons.add_a_photo, color: _neonBlue, size: 30) : null,
                  ),
                ),
                const SizedBox(height: 12),
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
                  controller: schoolController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'School Name',
                    labelStyle: const TextStyle(color: _neonBlue),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonBlue)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: regNumberController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Student Reg Number / KUCCPS',
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
                  obscureText: obscurePin,
                  decoration: InputDecoration(
                    labelText: 'Set 4-Digit PIN',
                    labelStyle: const TextStyle(color: _neonBlue),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonBlue)),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility, color: _neonBlue),
                      onPressed: () {
                        setState(() {
                          obscurePin = !obscurePin;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: isCreating ? null : () async {
                final name = nameController.text.trim();
                final school = schoolController.text.trim();
                final regNumber = regNumberController.text.trim();
                final pin = pinController.text.trim();
                
                if (name.isEmpty || pin.length != 4 || school.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields and set a 4-digit PIN.')));
                  return;
                }

                setState(() => isCreating = true);

                try {
                  final parentUid = FirebaseAuth.instance.currentUser!.uid;
                  final newUid = const Uuid().v4();
                  final shortId = newUid.substring(0, 7).toUpperCase();

                  String? profileImageUrl;
                  if (selectedImage != null) {
                    final fileName = 'profile_${newUid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    final storageRef = FirebaseStorage.instance.ref().child('profile_images').child(fileName);
                    final uploadTask = storageRef.putFile(selectedImage!);
                    final snapshot = await uploadTask;
                    profileImageUrl = await snapshot.ref.getDownloadURL();
                  }

                  await FirebaseFirestore.instance.collection('users').doc(newUid).set({
                    'displayName': name,
                    'roles': ['student'],
                    'isOffline': true,
                    'pin': pin,
                    'schoolName': school,
                    'regNumber': regNumber,
                    'parentUid': parentUid,
                    'linkedParents': [parentUid],
                    'dishiId': shortId,
                    'walletBalance': 0.0,
                    'createdAt': FieldValue.serverTimestamp(),
                    if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
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

  Widget _buildActionGridButton(IconData icon, String label, Color color, VoidCallback onTap, {int badge = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: badge > 0 ? color.withOpacity(0.08) : _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: badge > 0 ? color : color.withOpacity(0.3), width: badge > 0 ? 1.5 : 1),
              boxShadow: badge > 0 ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 1)] : [],
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
          if (badge > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badge > 9 ? '9+' : badge.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSosBanner() {
    return GestureDetector(
      onTap: _showEmergencyAlerts,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.7, end: 1.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        onEnd: () => setState(() {}), // Rebuild to restart animation
        builder: (context, value, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF8B0000).withOpacity(0.9), const Color(0xFFF92B60).withOpacity(0.85 * value)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF92B60), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFFF92B60).withOpacity(0.4 * value), blurRadius: 16, spreadRadius: 2)
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emergency, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚨 SOS ALERT— $_unresolvedSosCount ${_unresolvedSosCount == 1 ? 'student needs' : 'students need'} help!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to view location and acknowledge',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          );
        },
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
                  activeThumbColor: _neonPink,
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
    
    if (_globalSelectedStudentUid != null) {
      final student = _linkedStudents.firstWhere((s) => s['uid'] == _globalSelectedStudentUid);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => NutritionSettings(studentUid: student['uid'], studentName: student['name'])
      ));
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
        ),
      ),
    );
  }

  void _showLiveTracking() {
    if (_globalSelectedStudentUid == null || _linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a student in the Dependents tab first.'),
          backgroundColor: Color(0xFFFF6F00),
        ),
      );
      return;
    }
    final student = _linkedStudents.firstWhere(
      (s) => s['uid'] == _globalSelectedStudentUid,
      orElse: () => _linkedStudents.first,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParentLiveTrackingView(
          studentUid: _globalSelectedStudentUid!,
          studentName: student['name'] as String? ?? 'Student',
          homeZone: widget.user['homeZone'] as Map<String, dynamic>?,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
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
          selectedStudentUid: _globalSelectedStudentUid,
        ),
      ),
    );
  }

  void _showLunchboxSelector() {
    if (_linkedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students linked.')));
      return;
    }
    
    if (_globalSelectedStudentUid != null) {
      final student = _linkedStudents.firstWhere((s) => s['uid'] == _globalSelectedStudentUid);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => LunchboxPlanner(
          studentUid: student['uid'], 
          studentName: student['name'],
          parentUid: FirebaseAuth.instance.currentUser!.uid,
        )
      ));
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
    
    if (_globalSelectedStudentUid != null) {
      final student = _linkedStudents.firstWhere((s) => s['uid'] == _globalSelectedStudentUid);
      _showSetLimitDialog(student['uid'], student['name'], student['dailyLimit']);
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
                  activeThumbColor: _neonBlue,
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

  void _showMpesaPromptSentDialog(String phone, double amount, String studentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: MPesaTheme.primaryGreen.withOpacity(0.5))),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: MPesaTheme.primaryGreen.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.phone_android_rounded, color: MPesaTheme.primaryGreen, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('M-PESA Prompt Sent', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A payment prompt of KSH ${amount.toStringAsFixed(0)} was dispatched to:', style: const TextStyle(color: _textSecondary, fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.3))),
              child: Row(
                children: [
                  const Icon(Icons.sim_card_outlined, color: MPesaTheme.primaryGreen, size: 18),
                  const SizedBox(width: 10),
                  Text(phone, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_clock_outlined, color: _neonCyan, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Enter your Safaricom M-PESA PIN on your handset to credit $studentName\'s wallet instantly.', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchParentData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('OK, Understood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTopUpModal(BuildContext context, String childUid, String childName) {
    final phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    final amountController = TextEditingController();
    bool isProcessing = false;
    String selectedMethod = 'vault'; // 'vault' or 'mpesa'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: (selectedMethod == 'vault' ? _neonBlue : MPesaTheme.primaryGreen).withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 25, offset: const Offset(0, -5)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // Recipient Header Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_neonCyan.withOpacity(0.3), _neonBlue.withOpacity(0.3)],
                          ),
                          border: Border.all(color: _neonCyan, width: 1.5),
                        ),
                        child: const Icon(Icons.school_rounded, color: _neonCyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fund $childName', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            const Text('Student Education Wallet', style: TextStyle(color: _textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _neonCyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _neonCyan.withOpacity(0.4)),
                        ),
                        child: const Text('Verified', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Funding Method Selector Segmented Control
                Container(
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedMethod = 'vault'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'vault' ? _neonBlue.withOpacity(0.25) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: selectedMethod == 'vault' ? _neonBlue : Colors.transparent),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_rounded, size: 16, color: selectedMethod == 'vault' ? _neonBlue : _textSecondary),
                                const SizedBox(width: 6),
                                Text('Family Vault', style: TextStyle(color: selectedMethod == 'vault' ? Colors.white : _textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedMethod = 'mpesa'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'mpesa' ? MPesaTheme.primaryGreen.withOpacity(0.25) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: selectedMethod == 'mpesa' ? MPesaTheme.primaryGreen : Colors.transparent),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_android_rounded, size: 16, color: selectedMethod == 'mpesa' ? MPesaTheme.primaryGreen : _textSecondary),
                                const SizedBox(width: 6),
                                Text('M-PESA STK', style: TextStyle(color: selectedMethod == 'mpesa' ? Colors.white : _textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Method description or balance indicator
                if (selectedMethod == 'vault') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _neonBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _neonBlue.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: _neonBlue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vault Available: KSH ${_vaultBalance.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Zero Fees', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MPesaTheme.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: MPesaTheme.primaryGreen, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Instant Daraja STK Push to your Safaricom line',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Preset Amount Chips
                const Text('Select Quick Amount', style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [100, 200, 500, 1000, 2000].map((amt) {
                    final isSelected = amountController.text == amt.toString();
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() {
                            amountController.text = amt.toString();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected ? (selectedMethod == 'vault' ? _neonBlue.withOpacity(0.25) : MPesaTheme.primaryGreen.withOpacity(0.25)) : _cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? (selectedMethod == 'vault' ? _neonBlue : MPesaTheme.primaryGreen) : Colors.white12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${amt >= 1000 ? '${amt ~/ 1000}k' : amt}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Amount Text Field
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Amount to Fund',
                    labelStyle: const TextStyle(color: _textSecondary),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Text('KSH', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    filled: true,
                    fillColor: _surfaceLight,
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white12), borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: selectedMethod == 'vault' ? _neonBlue : MPesaTheme.primaryGreen, width: 1.5), borderRadius: BorderRadius.circular(14)),
                  ),
                  onChanged: (val) => setModalState(() {}),
                ),
                const SizedBox(height: 16),

                // Phone number input for M-PESA only
                if (selectedMethod == 'mpesa') ...[
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Safaricom Phone Number',
                      labelStyle: const TextStyle(color: _textSecondary),
                      hintText: 'e.g. 0712345678 or 254712345678',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: _surfaceLight,
                      prefixIcon: const Icon(Icons.phone_android_rounded, color: MPesaTheme.primaryGreen),
                      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white12), borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: MPesaTheme.primaryGreen, width: 1.5), borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action Button (Disburse or STK)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : () async {
                      final amtStr = amountController.text.trim();
                      final parsedAmt = double.tryParse(amtStr) ?? 0.0;
                      if (parsedAmt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount greater than 0.')));
                        return;
                      }

                      if (selectedMethod == 'vault') {
                        // --- VAULT FUNDING ---
                        if (parsedAmt > _vaultBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Insufficient vault balance. Available: KSH ${_vaultBalance.toStringAsFixed(2)}')));
                          return;
                        }

                        setModalState(() => isProcessing = true);
                        bool isSuccess = false;
                        String msg = 'Transferred successfully!';

                        try {
                          final parentUid = FirebaseAuth.instance.currentUser!.uid;
                          final response = await http.post(
                            Uri.parse(ApiConfig.transactionParentTransfer),
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({
                              'parentUid': parentUid,
                              'studentUid': childUid,
                              'amount': parsedAmt,
                            }),
                          ).timeout(const Duration(seconds: 30));

                          if (response.statusCode == 200 && !response.body.trim().startsWith('<')) {
                            try {
                              final resData = json.decode(response.body);
                              isSuccess = true;
                              msg = resData['message'] ?? 'Transferred KSH ${parsedAmt.toStringAsFixed(2)} from Family Vault to $childName!';
                            } catch (_) {
                              isSuccess = true;
                            }
                          } else {
                            // Backend returned non-200 or HTML error. Use direct Firestore fallback transaction!
                            final db = FirebaseFirestore.instance;
                            await db.runTransaction((tx) async {
                              final pRef = db.collection('users').doc(parentUid);
                              final sRef = db.collection('users').doc(childUid);
                              final pSnap = await tx.get(pRef);
                              final sSnap = await tx.get(sRef);
                              final pData = pSnap.data() ?? {};
                              final sData = sSnap.data() ?? {};
                              double pSavings = (pData['savingsBalance'] as num?)?.toDouble() ?? 0.0;
                              double pVault = (pData['vaultBalance'] as num?)?.toDouble() ?? 0.0;
                              double pWallet = (pData['walletBalance'] as num?)?.toDouble() ?? 0.0;
                              double avail = pSavings + pVault + pWallet;
                              if (avail < parsedAmt) throw Exception('Insufficient funds in Family Vault (Available: KSH ${avail.toStringAsFixed(2)})');
                              double sWallet = (sData['walletBalance'] as num?)?.toDouble() ?? 0.0;
                              
                              double rem = parsedAmt;
                              Map<String, dynamic> pUp = {};
                              if (pSavings > 0) { double d = pSavings >= rem ? rem : pSavings; pUp['savingsBalance'] = pSavings - d; rem -= d; }
                              if (rem > 0 && pVault > 0) { double d = pVault >= rem ? rem : pVault; pUp['vaultBalance'] = pVault - d; rem -= d; }
                              if (rem > 0 && pWallet > 0) { double d = pWallet >= rem ? rem : pWallet; pUp['walletBalance'] = pWallet - d; rem -= d; }
                              tx.update(pRef, pUp);
                              tx.update(sRef, {'walletBalance': sWallet + parsedAmt});
                              
                              final txRef = db.collection('transactions').doc();
                              tx.set(txRef, {
                                'type': 'parent_transfer',
                                'senderUid': parentUid,
                                'receiverUid': childUid,
                                'amount': parsedAmt,
                                'timestamp': FieldValue.serverTimestamp(),
                                'status': 'completed',
                                'description': 'Family Vault transfer to $childName'
                              });
                            });
                            isSuccess = true;
                            msg = 'Transferred KSH ${parsedAmt.toStringAsFixed(2)} from Family Vault to $childName!';
                          }
                        } on TimeoutException catch (_) {
                          // Direct firestore fallback on timeout
                          try {
                            final parentUid = FirebaseAuth.instance.currentUser!.uid;
                            final db = FirebaseFirestore.instance;
                            await db.runTransaction((tx) async {
                              final pRef = db.collection('users').doc(parentUid);
                              final sRef = db.collection('users').doc(childUid);
                              final pSnap = await tx.get(pRef);
                              final sSnap = await tx.get(sRef);
                              final pData = pSnap.data() ?? {};
                              final sData = sSnap.data() ?? {};
                              double pSavings = (pData['savingsBalance'] as num?)?.toDouble() ?? 0.0;
                              double pVault = (pData['vaultBalance'] as num?)?.toDouble() ?? 0.0;
                              double pWallet = (pData['walletBalance'] as num?)?.toDouble() ?? 0.0;
                              double avail = pSavings + pVault + pWallet;
                              if (avail < parsedAmt) throw Exception('Insufficient funds');
                              double sWallet = (sData['walletBalance'] as num?)?.toDouble() ?? 0.0;
                              double rem = parsedAmt;
                              Map<String, dynamic> pUp = {};
                              if (pSavings > 0) { double d = pSavings >= rem ? rem : pSavings; pUp['savingsBalance'] = pSavings - d; rem -= d; }
                              if (rem > 0 && pVault > 0) { double d = pVault >= rem ? rem : pVault; pUp['vaultBalance'] = pVault - d; rem -= d; }
                              if (rem > 0 && pWallet > 0) { double d = pWallet >= rem ? rem : pWallet; pUp['walletBalance'] = pWallet - d; rem -= d; }
                              tx.update(pRef, pUp);
                              tx.update(sRef, {'walletBalance': sWallet + parsedAmt});
                            });
                            isSuccess = true;
                            msg = 'Transferred KSH ${parsedAmt.toStringAsFixed(2)} from Family Vault to $childName!';
                          } catch (_) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.')));
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer error: $e')));
                        }

                        setModalState(() => isProcessing = false);

                        if (isSuccess && mounted) {
                          Navigator.pop(context);
                          _fetchParentData();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(msg),
                            backgroundColor: MPesaTheme.primaryGreen,
                          ));
                        }
                      } else {
                        // --- M-PESA STK FUNDING ---
                        final phone = phoneController.text.trim();
                        if (phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an M-PESA phone number.')));
                          return;
                        }

                        setModalState(() => isProcessing = true);
                        try {
                          final cleanPhone = phone.startsWith('0') ? '254${phone.substring(1)}' : (phone.startsWith('+') ? phone.substring(1) : phone);
                          final cleanName = childName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
                          
                          final response = await http.post(
                            Uri.parse(ApiConfig.mpesaStkPush),
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({
                              'phone_number': cleanPhone,
                              'amount': parsedAmt.toInt(),
                              'user_id': childUid,
                              'destination': 'walletBalance',
                              'account_reference': cleanName.length > 10 ? cleanName.substring(0, 10) : cleanName,
                              'metadata': {
                                'action': 'fund_student',
                                'funder_phone': cleanPhone,
                                'child_name': childName,
                              }
                            }),
                          ).timeout(const Duration(seconds: 30));

                          setModalState(() => isProcessing = false);

                          if (response.statusCode == 200) {
                            if (mounted) {
                              Navigator.pop(context);
                              _showMpesaPromptSentDialog(cleanPhone, parsedAmt, childName);
                            }
                          } else {
                            String errMsg = 'Failed to initiate M-PESA';
                            if (!response.body.trim().startsWith('<')) {
                              try {
                                final parsed = json.decode(response.body);
                                errMsg = parsed['error'] ?? parsed['message'] ?? errMsg;
                              } catch (_) {}
                            } else {
                              errMsg = 'Payment gateway error (${response.statusCode}). Please check your phone.';
                            }
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: _neonPink));
                          }
                        } on TimeoutException catch (_) {
                          setModalState(() => isProcessing = false);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('M-PESA request timed out. Please check your phone.'), backgroundColor: _neonPink));
                        } catch (e) {
                          setModalState(() => isProcessing = false);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedMethod == 'vault' ? _neonBlue : MPesaTheme.primaryGreen,
                      elevation: 4,
                      shadowColor: (selectedMethod == 'vault' ? _neonBlue : MPesaTheme.primaryGreen).withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isProcessing
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            selectedMethod == 'vault'
                                ? 'Transfer from Family Vault'
                                : 'Send M-PESA STK Prompt 📲',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Share Sponsor Link Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final parentName = widget.user['displayName'] ?? widget.user['name'] ?? 'A Guardian';
                      final inviteLink = 'https://dishi.delstarfordworks.co.ke/support_invite?childUid=$childUid&parentName=${Uri.encodeComponent(parentName)}';
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sponsor link copied to clipboard! Share it with relatives/sponsors.')));
                    },
                    icon: const Icon(Icons.share_rounded, color: Colors.orangeAccent, size: 18),
                    label: const Text('Share Sponsor Contribution Link', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orangeAccent, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
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
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: _neonBlue.withOpacity(0.4), width: 1.5),
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
       final db = FirebaseFirestore.instance;
       
       await db.runTransaction((tx) async {
         final parentRef = db.collection('users').doc(parentUid);
         final pSnap = await tx.get(parentRef);
         final pData = pSnap.data() ?? {};
         double pSavings = (pData['savingsBalance'] as num?)?.toDouble() ?? 0.0;
         double pVault = (pData['vaultBalance'] as num?)?.toDouble() ?? 0.0;
         double pWallet = (pData['walletBalance'] as num?)?.toDouble() ?? 0.0;
         double totalAvail = pSavings + pVault + pWallet;
         if (totalAvail < totalAmount) {
           throw Exception('Insufficient Vault balance. Available: KSH ${totalAvail.toStringAsFixed(2)}');
         }
         
         double rem = totalAmount;
         Map<String, dynamic> pUp = {};
         if (pSavings > 0) { double d = pSavings >= rem ? rem : pSavings; pUp['savingsBalance'] = pSavings - d; rem -= d; }
         if (rem > 0 && pVault > 0) { double d = pVault >= rem ? rem : pVault; pUp['vaultBalance'] = pVault - d; rem -= d; }
         if (rem > 0 && pWallet > 0) { double d = pWallet >= rem ? rem : pWallet; pUp['walletBalance'] = pWallet - d; rem -= d; }
         tx.update(parentRef, pUp);
         
         for (var student in _linkedStudents) {
           final studentRef = db.collection('users').doc(student['uid']);
           tx.update(studentRef, {'walletBalance': FieldValue.increment(amountPerStudent)});
           
           final txRef = db.collection('transactions').doc();
           tx.set(txRef, {
             'type': 'parent_transfer',
             'senderUid': parentUid,
             'receiverUid': student['uid'],
             'amount': amountPerStudent,
             'timestamp': FieldValue.serverTimestamp(),
             'status': 'completed',
             'description': 'Bulk Vault transfer to ${student['name']}'
           });
         }
       });
       
       await _fetchParentData();
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funded all students from Vault successfully!'), backgroundColor: MPesaTheme.primaryGreen));
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vault funding failed: $e'), backgroundColor: _neonPink));
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 24, right: 24, top: 24),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: MPesaTheme.primaryGreen.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.shield_rounded, color: MPesaTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Up Family Vault', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                      Text('Direct Safaricom Daraja STK Push into Family Vault', style: TextStyle(color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'M-PESA Phone Number',
                labelStyle: const TextStyle(color: _textSecondary),
                hintText: 'e.g. 0712345678 or 254712345678',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: _surfaceLight,
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white12), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: MPesaTheme.primaryGreen, width: 1.5), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone_android, color: MPesaTheme.primaryGreen),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Amount to Deposit (Ksh)',
                labelStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white12), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: MPesaTheme.primaryGreen, width: 1.5), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text('KSH', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final phone = phoneController.text.trim();
                  final amount = amountController.text.trim();
                  final parsedAmt = double.tryParse(amount) ?? 0.0;
                  if (phone.isEmpty || parsedAmt <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid phone and amount.')));
                    return;
                  }
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Initiating STK Push to your phone...'), backgroundColor: MPesaTheme.primaryGreen));
                  
                  try {
                    final cleanPhone = phone.startsWith('0') ? '254${phone.substring(1)}' : (phone.startsWith('+') ? phone.substring(1) : phone);
                    final response = await http.post(
                      Uri.parse(ApiConfig.mpesaStkPush),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'phone_number': cleanPhone,
                        'amount': parsedAmt.toInt(),
                        'user_id': FirebaseAuth.instance.currentUser!.uid,
                        'destination': 'savingsBalance',
                        'metadata': {
                          'action': 'fund_vault',
                          'funder_phone': cleanPhone
                        }
                      }),
                    ).timeout(const Duration(seconds: 30));
                    
                    if (response.statusCode == 200) {
                      if (mounted) {
                        _showMpesaPromptSentDialog(cleanPhone, parsedAmt, 'Family Vault');
                      }
                    } else {
                      if (mounted) {
                        String errMsg = 'Failed to initiate STK Push';
                        if (!response.body.trim().startsWith('<')) {
                          try {
                            final parsed = jsonDecode(response.body);
                            errMsg = parsed['error'] ?? parsed['message'] ?? errMsg;
                          } catch (_) {}
                        } else {
                          errMsg = 'Payment server temporary error (${response.statusCode})';
                        }
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: $errMsg'), backgroundColor: _neonPink));
                      }
                    }
                  } on TimeoutException catch (_) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Request timed out. Please check your phone.'), backgroundColor: _neonPink));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.primaryGreen,
                  elevation: 4,
                  shadowColor: MPesaTheme.primaryGreen.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Top Up Family Vault 📲', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  Widget _buildChildSwitcher() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _linkedStudents.length,
        itemBuilder: (context, index) {
          final student = _linkedStudents[index];
          final isSelected = student['uid'] == _globalSelectedStudentUid;
          return GestureDetector(
            onTap: () {
              setState(() => _globalSelectedStudentUid = student['uid']);
              if (_vaultPageController.hasClients) {
                _vaultPageController.animateToPage(index + 1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? _neonCyan : Colors.transparent, width: 2),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: _surfaceLight,
                child: Text((student['name'] as String?)?.isNotEmpty == true ? (student['name'] as String)[0].toUpperCase() : 'S', style: TextStyle(color: isSelected ? _neonCyan : Colors.white)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSmartSuggestions() {
    if (_linkedStudents.isEmpty) return const SizedBox();
    final List<Widget> suggestions = [];
    for (var s in _linkedStudents) {
      if ((s['balance'] as double? ?? 0) < 200) {
        suggestions.add(_buildSuggestionCard(
          icon: Icons.warning_amber_rounded,
          color: _neonOrange,
          text: "${s['name']}'s balance is below Ksh 200. Tap to fund.",
          onTap: () => _showTopUpModal(context, s['uid'] as String, s['name'] as String)
        ));
      }
    }
    if (suggestions.isEmpty) {
      suggestions.add(_buildSuggestionCard(
        icon: Icons.check_circle_outline,
        color: _neonCyan,
        text: "All students are funded. Review chores to release rewards.",
        onTap: () {} // Navigate to bounties/chores
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Smart Suggestions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...suggestions,
      ],
    );
  }

  Widget _buildSuggestionCard({required IconData icon, required Color color, required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }
}
