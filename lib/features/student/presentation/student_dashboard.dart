import 'package:flutter/material.dart';
import 'package:swapeat/features/student/presentation/gift_meal_dialog.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/user_model.dart';
import '../../housing/presentation/housing_dashboard_view.dart';
import '../../admin/presentation/admin_dashboard_view.dart';
import '../../vendor/presentation/vendor_dashboard_view.dart';
import '../../auth/presentation/login_view.dart';
import '../../smartimer/ui/home_page.dart';
import '../../smartimer/presentation/daily_focus_view.dart';
import '../../match/presentation/match_discovery_view.dart';
import '../../match/presentation/match_hub_view.dart';
import '../../deliv/presentation/deliv_driver_dashboard.dart';
import '../../deliv/presentation/deliv_registration_view.dart';
import '../../../core/services/secure_storage_service.dart';
import 'student_ledger_view.dart';
import 'student_preorders_view.dart';
import '../../auth/presentation/role_selection_view.dart';
import '../../fundi/presentation/fundi_marketplace_view.dart';
import 'okoa_food_view.dart';
import 'all_features_view.dart';
import 'virtual_card_view.dart';
import 'student_profile_settings.dart';
import '../../../shared/presentation/universal_support_widget.dart';
import '../../../core/services/fcm_service.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/api_config.dart';
import '../../../core/utils/pdf_generator.dart';
import 'package:flutter/services.dart';
// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFF92B60);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _textSecondary = Color(0xFF8B9BB4);

class StudentDashboardView extends StatefulWidget {
  final Map<String, dynamic> user;

  const StudentDashboardView({super.key, required this.user});

  @override
  State<StudentDashboardView> createState() => _StudentDashboardViewState();
}

class _StudentDashboardViewState extends State<StudentDashboardView> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isDriverMode = false;
  final PageController _balancePageController = PageController();
  int _currentBalancePage = 0;
  
  bool _isSearching = false;
  String _searchQuery = '';
  
  String _generateRandomToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
  
  bool _isBalanceVisible = false;
  late Stream<DocumentSnapshot> _userProfileStream;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  void initState() {
    super.initState();
    _userProfileStream = FirebaseAuth.instance.currentUser != null 
        ? _firestoreService.streamCurrentUserProfile() 
        : const Stream.empty();
    _loadFeatureOrder();
    
    // Initialize FCM
    FCMService.initialize();
  }

  List<String> _featureOrder = ['Fundi Juaji Market', 'Find Your Match', 'Study Companion', 'Keja Yangu'];

  Future<void> _loadFeatureOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('dashboard_feature_order');
    if (savedOrder != null && savedOrder.length == _featureOrder.length) {
      if (mounted) {
        setState(() {
          _featureOrder = savedOrder;
        });
      }
    }
  }

  Future<void> _saveFeatureOrder(List<String> newOrder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dashboard_feature_order', newOrder);
  }

  @override
  void dispose() {
    _balancePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      drawer: _buildRoleSwitcherDrawer(),
      body: SafeArea(
        // INJECTED STREAM BUILDER FOR REAL-TIME FIRESTORE DATA
        child: StreamBuilder<DocumentSnapshot>(
          stream: _userProfileStream,
          builder: (context, snapshot) {
            UserModel userModel;
            
            if (FirebaseAuth.instance.currentUser == null || snapshot.hasError || (!snapshot.hasData && snapshot.connectionState != ConnectionState.waiting)) {
              // OFFLINE FALLBACK: Use the user data passed in the constructor
              userModel = UserModel.fromJson(widget.user, widget.user['uid'] ?? 'offline_user');
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _neonCyan));
            } else if (!snapshot.data!.exists) {
              return const Center(child: Text('Profile not found', style: TextStyle(color: Colors.white)));
            } else {
              // Parse live Firestore data into UserModel
              userModel = UserModel.fromJson(
                Map<String, dynamic>.from(snapshot.data!.data() as Map), 
                snapshot.data!.id
              );
            }

            return Stack(
              children: [
                CustomScrollView(
                  physics: const ClampingScrollPhysics(),
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
                          padding: EdgeInsets.only(left: 16, right: 16, top: MediaQuery.of(context).padding.top + 8),
                          child: _buildCustomAppBar(userModel),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 16),
                          _buildDriverModeToggle(userModel),
                          const SizedBox(height: 16),
                          _buildVipBadge(),
                          const SizedBox(height: 16),
                          _buildBalancePageView(userModel),
                          const SizedBox(height: 8),
                          _buildPaginationDots(),
                          const SizedBox(height: 32),
                          _buildQuickActions(userModel),
                          const SizedBox(height: 24),
                          _buildDishiIdCard(userModel),
                          const SizedBox(height: 16),
                          UniversalSupportWidget(userId: userModel.uid, userRole: 'student'),
                        ]),
                      ),
                    ),
                  ],
                ),
                // Context-Aware Floating Action Button
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      final hour = DateTime.now().hour;
                      if (hour >= 11 && hour <= 14) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentPreordersView()));
                      } else {
                        _showDynamicQRDialog(userModel);
                      }
                    },
                    backgroundColor: _neonCyan,
                    icon: Icon(
                      (DateTime.now().hour >= 11 && DateTime.now().hour <= 14) ? Icons.restaurant : Icons.qr_code_scanner, 
                      color: Colors.black87
                    ),
                    label: Text(
                      (DateTime.now().hour >= 11 && DateTime.now().hour <= 14) ? 'Lunch Time' : 'Pay', 
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(UserModel userModel) {
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
              decoration: InputDecoration(
                hintText: 'Search vendors, food, etc...',
                hintStyle: const TextStyle(color: _textSecondary),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
      );
    }

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
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfileSettings(userModel: userModel))),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _neonCyan,
                  backgroundImage: userModel.profileImageUrl != null ? NetworkImage(userModel.profileImageUrl!) : null,
                  child: userModel.profileImageUrl == null ? const Icon(Icons.person, color: Colors.black, size: 24) : null,
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
                  userModel.displayName.isEmpty ? 'Student' : userModel.displayName, 
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
          _buildNotificationBell(userModel.uid),
        ],
      ),
    );
  }

  Widget _buildIconContainer(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: _surfaceLight,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _buildNotificationBell(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        List<DocumentSnapshot> myNotifications = [];
        
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            final targetUserId = data['targetUserId'] as String?;
            final dismissedBy = List<String>.from(data['dismissedBy'] ?? []);
            
            // Filter notifications meant for me or everyone, and not dismissed
            if ((targetUserId == null || targetUserId == uid) && !dismissedBy.contains(uid)) {
              myNotifications.add(doc);
              final readBy = List<String>.from(data['readBy'] ?? []);
              if (!readBy.contains(uid)) {
                unreadCount++;
              }
            }
          }
        }

        return GestureDetector(
          onTap: () => _showNotificationsSheet(uid, myNotifications),
          child: Stack(
            children: [
              _buildIconContainer(Icons.notifications_none),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: _neonPink,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationsSheet(String uid, List<DocumentSnapshot> notifications) {
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
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.5)))),
              const SizedBox(height: 24),
              const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(child: Text('No new notifications', style: TextStyle(color: _textSecondary)))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: notifications.length,
                        separatorBuilder: (context, index) => const Divider(color: Colors.white12),
                        itemBuilder: (context, index) {
                          final doc = notifications[index];
                          final data = Map<String, dynamic>.from(doc.data() as Map);
                          final readBy = List<String>.from(data['readBy'] ?? []);
                          final isRead = readBy.contains(uid);
                          
                          return Dismissible(
                            key: Key(doc.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: _neonPink,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              await FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({
                                'dismissedBy': FieldValue.arrayUnion([uid])
                              });
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isRead ? _surfaceLight : _neonCyan.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.notifications, color: isRead ? _textSecondary : _neonCyan),
                              ),
                              title: Text(data['title'] ?? '', style: TextStyle(color: Colors.white, fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                              subtitle: Text(data['message'] ?? '', style: const TextStyle(color: _textSecondary)),
                              onTap: () async {
                                if (!isRead) {
                                  await FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({
                                    'readBy': FieldValue.arrayUnion([uid])
                                  });
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

  Widget _buildDriverModeToggle(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF162038),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: _neonBlue, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userModel.isDriverVerified ? 'Driver Mode' : 'Become a Driver', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(userModel.isDriverVerified ? (userModel.driverVehicleType == 'Walker' ? 'Switch to Walker Dashboard' : 'Switch to Driver Dashboard') : 'Earn by walking, riding, or driving', style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: _isDriverMode,
            activeColor: _neonBlue,
            onChanged: (val) {
              setState(() => _isDriverMode = val);
              if (val) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (!userModel.isDriverVerified) {
                    setState(() => _isDriverMode = false);
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => const DelivRegistrationView()
                      )
                    );
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => DelivDriverDashboard(user: widget.user))).then((_) {
                      if (mounted) setState(() => _isDriverMode = false); 
                    });
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVipBadge() {
    return InkWell(
      onTap: () => _showPerksDialog(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE65C00), Color(0xFFF9D423)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            const Expanded(
              child: Text('Bronze VIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Text('View Perks', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, decoration: TextDecoration.underline, decorationColor: Colors.white70)),
          ],
        ),
      ),
    );
  }

  void _showPerksDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 2)),
        title: const Text('Bronze VIP Perks', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ListTile(leading: Icon(Icons.fastfood, color: _neonCyan), title: Text('Priority Queue for Pre-orders', style: TextStyle(color: Colors.white))),
            ListTile(leading: Icon(Icons.discount, color: _neonPink), title: Text('0% Purchase Fees', style: TextStyle(color: Colors.white))),
            ListTile(leading: Icon(Icons.support_agent, color: _neonBlue), title: Text('Priority Support Tickets', style: TextStyle(color: Colors.white))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Awesome!', style: TextStyle(color: _neonCyan))),
        ],
      ),
    );
  }

  Widget _buildBalancePageView(UserModel userModel) {
    return SizedBox(
      height: 250,
      child: PageView(
        controller: _balancePageController,
        onPageChanged: (index) {
          setState(() {
            _currentBalancePage = index;
          });
        },
        children: [
          _buildActiveWalletCard(userModel),
          _buildSavingsVaultCard(userModel),
          _buildOkoaCard(userModel),
          _buildDormWalletCard(userModel),
        ],
      ),
    );
  }

  Widget _buildActiveWalletCard(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonCyan.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _neonCyan.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2
          )
        ]
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(_isBalanceVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white70, size: 20),
                onPressed: () {
                  setState(() {
                    _isBalanceVisible = !_isBalanceVisible;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(_isBalanceVisible ? 'Ksh. ${userModel.walletBalance.toStringAsFixed(2)}' : 'Ksh. ****', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1)),
              if (userModel.isFrozen) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _neonPink.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _neonPink),
                  ),
                  child: const Text('FROZEN', style: TextStyle(color: _neonPink, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          const Text('Student Upkeep Account Balance', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                height: 8,
                width: (userModel.dailyLimit != null && userModel.dailyLimit! > 0)
                    ? MediaQuery.of(context).size.width * (userModel.walletBalance / userModel.dailyLimit!).clamp(0.0, 1.0)
                    : MediaQuery.of(context).size.width, // Full width if no limit
                decoration: BoxDecoration(
                  color: _neonCyan,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: _neonCyan.withOpacity(0.6), blurRadius: 6)
                  ]
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isBalanceVisible 
              ? ((userModel.dailyLimit != null && userModel.dailyLimit! > 0) 
                  ? '${((userModel.walletBalance / userModel.dailyLimit!) * 100).toStringAsFixed(1)}% remaining of Ksh ${userModel.dailyLimit}'
                  : 'Ksh ${userModel.walletBalance.toStringAsFixed(2)} available (No limit set)')
              : '**** available', 
            style: const TextStyle(color: _neonCyan, fontSize: 12)
          ),
        ],
      )),
    );
  }

  Widget _buildSavingsVaultCard(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF141E30), Color(0xFF243B55)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonBlue.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: _neonBlue.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)]
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Savings Vault', style: TextStyle(color: _textSecondary, fontSize: 14)),
              Icon(Icons.account_balance, color: _textSecondary, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(_isBalanceVisible ? 'Ksh. ${userModel.vaultBalance.toStringAsFixed(2)}' : 'Ksh. ****', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonBlue.withOpacity(0.2),
                    foregroundColor: _neonBlue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _neonBlue.withOpacity(0.5))),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Deposit'),
                  onPressed: () {
                    _showSavingsDepositBottomSheet(userModel);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonOrange.withOpacity(0.2),
                    foregroundColor: _neonOrange,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _neonOrange.withOpacity(0.5))),
                  ),
                  icon: const Icon(Icons.emergency, size: 18),
                  label: const Text('Withdraw'),
                  onPressed: () {
                    _showSavingsWithdrawBottomSheet(userModel);
                  },
                ),
              ),
            ],
          ),
        ],
      )),
    );
  }

  Widget _buildOkoaCard(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF230707), Color(0xFF4A1010)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonOrange.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: _neonOrange.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)]
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Okoa Food Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Icon(Icons.fastfood, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(_isBalanceVisible ? 'Ksh. ${userModel.okoaBalance.toStringAsFixed(2)}' : 'Ksh. ****', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 32),
          const Text('Ksh 500 Max Limit', style: TextStyle(color: _neonOrange, fontSize: 12)),
        ],
      )),
    );
  }

  Widget _buildDormWalletCard(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E130C), Color(0xFF9A8478)],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)]
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dorm Shared Wallet', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Icon(Icons.house, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(_isBalanceVisible ? 'Ksh. 0.00' : 'Ksh. ****', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 32),
          const Text('Shared groceries & tokens', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
        ],
      )),
    );
  }

  Widget _buildPaginationDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentBalancePage == index ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: _currentBalancePage == index ? _neonCyan : _surfaceLight,
            borderRadius: BorderRadius.circular(3)
          ),
        );
      }),
    );
  }

  void _showFundMeDialog(UserModel userModel) {
    String currentDishiId = userModel.uid;
    final link = 'https://dishi.delstarfordworks.co.ke/fund?dishi_id=$currentDishiId';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _neonPink.withOpacity(0.5))),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: _neonPink, size: 28),
            SizedBox(width: 8),
            Text('Fund Me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this link with your parents, guardians, or friends. They can fund your wallet directly via M-PESA.',
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _surfaceLight),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(color: _neonCyan, fontSize: 13, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Fund Me link copied to clipboard!'), backgroundColor: _neonCyan, duration: Duration(seconds: 3)));
                },
                icon: const Icon(Icons.copy, color: Colors.black),
                label: const Text('Copy Link', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonCyan,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: _textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
  void _showGenderPromptDialog(UserModel userModel) {
    String selectedGender = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _neonPink, width: 2)),
          title: const Text('Set Your Gender 💖', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('To find your perfect match, we strictly match opposite genders. What is your gender?', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => selectedGender = 'male'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: selectedGender == 'male' ? _neonBlue.withOpacity(0.3) : Colors.transparent,
                          border: Border.all(color: selectedGender == 'male' ? _neonBlue : Colors.white24, width: 2),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.male, color: _neonBlue, size: 32),
                            SizedBox(height: 8),
                            Text('Male', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => selectedGender = 'female'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: selectedGender == 'female' ? _neonPink.withOpacity(0.3) : Colors.transparent,
                          border: Border.all(color: selectedGender == 'female' ? _neonPink : Colors.white24, width: 2),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.female, color: _neonPink, size: 32),
                            SizedBox(height: 8),
                            Text('Female', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () async {
                if (selectedGender.isEmpty) return;
                
                try {
                  await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({'gender': selectedGender});
                  await FirebaseFirestore.instance.collection('match_profiles').doc(userModel.uid).set({'gender': selectedGender}, SetOptions(merge: true));
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchHubView()));
                  }
                } catch (e) {
                  debugPrint('Error setting gender: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
              child: const Text('Save & Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        )
      )
    );
  }

  Widget _buildQuickActions(UserModel userModel) {
    // Default actions
    List<Widget> actions = [
      _buildActionIcon(Icons.add_card, 'Top Up', const Color(0xFF10B981), [const Color(0xFF10B981), const Color(0xFF047857)], false, () => _showTopUpBottomSheet(userModel)),
      _buildActionIcon(Icons.credit_card, 'VCC Card', const Color(0xFF3B82F6), [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)], false, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => VirtualCardView(userModel: userModel)));
      }),
      _buildActionIcon(Icons.qr_code_scanner, 'Dynamic QR', const Color(0xFF8B5CF6), [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)], false, () => _showDynamicQRDialog(userModel)),
      _buildActionIcon(Icons.history_edu, 'History', const Color(0xFFF59E0B), [const Color(0xFFF59E0B), const Color(0xFFB45309)], false, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLedgerView()));
      }),
      _buildActionIcon(Icons.favorite, 'Find Match', const Color(0xFFEC4899), [const Color(0xFFEC4899), const Color(0xFFBE185D)], true, () {
        final gender = userModel.gender ?? '';
        if (gender.isEmpty) {
          _showGenderPromptDialog(userModel);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchHubView()));
        }
      }),
    ];

    // 1. Low Balance Logic (Balance < 100 Ksh)
    if (userModel.walletBalance < 100) {
      actions.insert(0, _buildActionIcon(Icons.fastfood, 'Okoa Food', const Color(0xFFEF4444), [const Color(0xFFEF4444), const Color(0xFFB91C1C)], true, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OkoaFoodView()));
      }));
      actions.insert(1, _buildActionIcon(Icons.volunteer_activism, 'Fund Me', const Color(0xFF06B6D4), [const Color(0xFF06B6D4), const Color(0xFF0369A1)], true, () => _showFundMeDialog(userModel)));
    } else {
      // Append normally if they have money
      actions.add(_buildActionIcon(Icons.fastfood, 'Okoa Food', const Color(0xFFEF4444), [const Color(0xFFEF4444), const Color(0xFFB91C1C)], false, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OkoaFoodView()));
      }));
      actions.add(_buildActionIcon(Icons.volunteer_activism, 'Fund Me', const Color(0xFF06B6D4), [const Color(0xFF06B6D4), const Color(0xFF0369A1)], false, () => _showFundMeDialog(userModel)));
    }

    // 2. Time-Based Logic (Lunch time: 11 AM - 2 PM)
    final hour = DateTime.now().hour;
    if (hour >= 11 && hour <= 14) {
      actions.insert(0, _buildActionIcon(Icons.shopping_bag, 'Preorder\nLunch', const Color(0xFF14B8A6), [const Color(0xFF14B8A6), const Color(0xFF0F766E)], true, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentPreordersView()));
      }));
    } else {
      actions.add(_buildActionIcon(Icons.card_giftcard, 'Gift Meal', const Color(0xFFF43F5E), [const Color(0xFFF43F5E), const Color(0xFFBE123C)], false, () {
        showDialog(context: context, builder: (_) => const GiftMealDialog());
      }));
    }

    // Chunk into pages of 4
    List<Widget> pages = [];
    for (int i = 0; i < actions.length; i += 4) {
      List<Widget> pageItems = [];
      for (int j = i; j < i + 4 && j < actions.length; j++) {
        pageItems.add(Expanded(child: actions[j]));
      }
      // Fill the rest of the row with empty Expanded if less than 4
      while (pageItems.length < 4) {
        pageItems.add(const Expanded(child: SizedBox()));
      }
      
      pages.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: pageItems,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllFeaturesView(userModel: userModel))),
              child: Text('View all >', style: TextStyle(color: _neonCyan.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 120,
          child: PageView(
            children: pages,
          ),
        ),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String label, Color glowColor, List<Color> gradientColors, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors.map((c) => c.withOpacity(0.15)).toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isActive ? glowColor : glowColor.withOpacity(0.3), width: isActive ? 2 : 1),
              boxShadow: isActive ? [BoxShadow(color: glowColor.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)] : [],
            ),
            child: Icon(icon, color: glowColor, size: 36),
          ),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.2, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDishiIdCard(UserModel userModel) {
    String currentDishiId = userModel.dishiId ?? (userModel.uid.length >= 7 ? userModel.uid.substring(0, 7).toUpperCase() : userModel.uid.toUpperCase());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your DISHI ID', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(currentDishiId, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: currentDishiId));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DISHI ID copied to clipboard'), duration: Duration(seconds: 2)));
                      },
                      child: const Icon(Icons.copy, color: _neonCyan, size: 20),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showEditDishiIdDialog(userModel, currentDishiId),
                      child: const Icon(Icons.edit, color: _neonCyan, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: () => _showTokenDialog(context, userModel),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _neonCyan,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('SHOW TOKEN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  String currentToken = userModel.authToken ?? '';
                  if (currentToken.isEmpty) {
                    currentToken = _generateRandomToken();
                    await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({'authToken': currentToken});
                  }

                  final qrData = jsonEncode({
                    'uid': userModel.uid,
                    'dishiId': currentDishiId,
                    'token': currentToken,
                    'type': 'student_payment'
                  });

                  await PdfGenerator.printStudentQR(
                    dishiId: currentDishiId,
                    qrData: qrData,
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.print, color: _neonBlue, size: 16),
                    SizedBox(width: 4),
                    Text('Print/PDF', style: TextStyle(color: _neonBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDishiIdDialog(UserModel userModel, String currentId) {
    final TextEditingController controller = TextEditingController(text: currentId);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            title: const Text('Edit DISHI ID', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose a unique, memorable ID to share with vendors and parents.', style: TextStyle(color: _textSecondary, fontSize: 13)),
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
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  final newId = controller.text.trim();
                  if (newId.isEmpty || newId == currentId) {
                    Navigator.pop(context);
                    return;
                  }

                  setState(() => isSaving = true);

                  try {
                    // Check if ID is taken
                    final query = await FirebaseFirestore.instance
                        .collection('users')
                        .where('dishiId', isEqualTo: newId)
                        .get();
                    
                    if (query.docs.isNotEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This DISHI ID is already taken.')));
                      }
                      setState(() => isSaving = false);
                      return;
                    }

                    // Update
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userModel.uid)
                        .update({'dishiId': newId});

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DISHI ID updated successfully.')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                    setState(() => isSaving = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }


  Widget _buildRoleSwitcherDrawer() {
    final roles = List<String>.from(widget.user['roles'] ?? ['student']);
    return Drawer(
      backgroundColor: _bgColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
               padding: const EdgeInsets.all(24),
              color: _cardColor,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: _neonCyan,
                        backgroundImage: widget.user['profileImageUrl'] != null ? NetworkImage(widget.user['profileImageUrl']) : null,
                        child: widget.user['profileImageUrl'] == null ? const Icon(Icons.person, size: 36, color: Colors.black) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user['displayName']?.isNotEmpty == true ? widget.user['displayName'] : 'DISHI Student', 
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.user['email']?.isNotEmpty == true ? widget.user['email'] : 'student@dishi.com', 
                              style: const TextStyle(color: _textSecondary, fontSize: 13)
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _neonCyan.withValues(alpha: 0.15), 
                                borderRadius: BorderRadius.circular(12), 
                                border: Border.all(color: _neonCyan.withValues(alpha: 0.3))
                              ),
                              child: const Text('Verified Member', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (roles.contains('admin'))
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: _textSecondary),
                title: const Text('Admin Console', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminDashboardView(user: widget.user))),
              ),
            const Spacer(),
            const Divider(color: _surfaceLight),
            ListTile(
              leading: const Icon(Icons.logout, color: _neonPink),
              title: const Text('Sign Out', style: TextStyle(color: _neonPink)),
              onTap: () async {
                  await SecureStorageService.clearAll();
                  try {
                    await GoogleSignIn().disconnect();
                  } catch (_) {}
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
                  }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, UserModel userModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.5))),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Change Profile Picture', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                  
                  if (pickedFile != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Uploading profile picture...'),
                      backgroundColor: _neonCyan,
                    ));
                    try {
                      final file = File(pickedFile.path);
                      final url = await StorageService().uploadProfileImage(file);
                      // Append a timestamp to the URL to bust the Image cache and force a Firestore update
                      final urlWithTimestamp = '$url&t=${DateTime.now().millisecondsSinceEpoch}';
                      await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({
                        'profileImageUrl': urlWithTimestamp,
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Profile picture updated successfully!'),
                          backgroundColor: _neonCyan,
                        ));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Failed to update: $e'),
                          backgroundColor: _neonPink,
                        ));
                      }
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text('Log Out', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await SecureStorageService.clearAll();
                  try {
                    await GoogleSignIn().disconnect();
                  } catch (_) {} // Ignore if already disconnected
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: _neonPink),
                title: const Text('Permanently Delete Account', style: TextStyle(color: _neonPink)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteAccountDialog(context, userModel);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  void _showDeleteAccountDialog(BuildContext context, UserModel userModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Delete Account', style: TextStyle(color: _neonPink, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete your account? This action cannot be undone and will erase all your balances and data.', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final idToken = await user.getIdToken();
                  await http.delete(
                    Uri.parse('${ApiConfig.baseUrl}/api/v1/security/${user.uid}/delete_account'),
                    headers: {'Authorization': 'Bearer $idToken'},
                    // 30 seconds timeout
                  ).timeout(const Duration(seconds: 30));
                  
                  // Clear offline storage
                  await SecureStorageService.clearAll();
                  try {
                    await GoogleSignIn().disconnect();
                  } catch (_) {}
                  await FirebaseAuth.instance.signOut();
                }
              } catch (e) {
                debugPrint("Delete failed: $e");
              }
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTokenDialog(BuildContext context, UserModel userModel) async {
    String currentToken = userModel.authToken ?? '';
    if (currentToken.isEmpty) {
      currentToken = _generateRandomToken();
      await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({'authToken': currentToken});
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 2)),
            title: const Text('Your Auth Token', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Use this token for offline payments at vendors.', style: TextStyle(color: _textSecondary, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    currentToken,
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 8),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                     final newToken = _generateRandomToken();
                     await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({'authToken': newToken});
                     setState(() { currentToken = newToken; });
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Change Token', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonPink, foregroundColor: Colors.white),
                )
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showDynamicQRDialog(UserModel userModel) async {
    String currentToken = userModel.authToken ?? '';
    if (currentToken.isEmpty) {
      currentToken = _generateRandomToken();
      await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({'authToken': currentToken});
    }
    
    if (!mounted) return;
    String currentDishiId = userModel.dishiId ?? (userModel.uid.length >= 7 ? userModel.uid.substring(0, 7).toUpperCase() : userModel.uid.toUpperCase());

    final qrData = jsonEncode({
      'uid': userModel.uid,
      'dishiId': currentDishiId,
      'token': currentToken,
      'type': 'student_payment'
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Your Payment QR', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scan this at any DISHI Vendor POS.', style: TextStyle(color: Colors.black54, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            const Text('QR updates automatically for security.', style: TextStyle(color: Colors.black38, fontSize: 12)),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(color: MPesaTheme.primaryGreen, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTopUpBottomSheet(UserModel userModel) {
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Up Wallet via M-PESA', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone_android, color: _neonCyan),
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
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.attach_money, color: _neonCyan),
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
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Initiating STK Push...'), backgroundColor: _neonCyan));
                  
                  try {
                    final response = await http.post(
                      Uri.parse(ApiConfig.mpesaStkPush),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'phone_number': phone,
                        'amount': int.parse(amount),
                        'user_id': userModel.uid,
                      }),
                    ).timeout(const Duration(seconds: 30));
                    
                    if (response.statusCode == 200) {
                      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Check your phone for the M-PESA prompt!'), backgroundColor: Colors.green));
                    } else {
                      if (mounted) {
                        String errMsg = 'Failed to initiate STK Push';
                        try {
                          final parsed = jsonDecode(response.body);
                          errMsg = parsed['error'] ?? response.body;
                        } catch (_) {}
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: $errMsg'), backgroundColor: _neonPink));
                      }
                    }
                  } on TimeoutException {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: _neonPink));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Top Up Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Removed _showDriverRegistrationBottomSheet as it's now handled by RoleSelectionView
  void _showSavingsDepositBottomSheet(UserModel userModel) {
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deposit to Savings Vault', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Enter M-Pesa number and amount. Money will go directly to savings.', style: TextStyle(color: _textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'M-PESA Number (e.g. 2547XXXXXXXX)',
                labelStyle: const TextStyle(color: _textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue), borderRadius: BorderRadius.circular(12)),
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
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonBlue), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.savings, color: _neonBlue),
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
                        'user_id': userModel.uid,
                        'destination': 'vaultBalance',
                      }),
                    ).timeout(const Duration(seconds: 30));
                    
                    if (response.statusCode == 200) {
                      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Check your phone for the M-PESA prompt!'), backgroundColor: Colors.green));
                    } else {
                      if (mounted) {
                        String errMsg = 'Failed to deposit';
                        try {
                          final parsed = jsonDecode(response.body);
                          errMsg = parsed['error'] ?? response.body;
                        } catch (_) {}
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: $errMsg'), backgroundColor: _neonPink));
                      }
                    }
                  } on TimeoutException {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: _neonPink));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Deposit Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showSavingsWithdrawBottomSheet(UserModel userModel) {
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final pinController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Withdraw from Savings Vault', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Enter M-Pesa number, amount, and your DISHI PIN to withdraw.', style: TextStyle(color: _textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'M-PESA Number (e.g. 2547XXXXXXXX)',
                labelStyle: const TextStyle(color: _textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonOrange.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonOrange), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone_android, color: _neonOrange),
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
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonOrange.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonOrange), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.attach_money, color: _neonOrange),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'DISHI PIN',
                labelStyle: const TextStyle(color: _textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonOrange.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonOrange), borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock, color: _neonOrange),
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
                  final pin = pinController.text.trim();
                  if (phone.isEmpty || amount.isEmpty || pin.isEmpty) return;
                  
                  Navigator.pop(context);
                  
                  // Verify PIN first
                  final savedPin = await SecureStorageService.getOfflinePin();
                  if (pin != savedPin) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Incorrect PIN!'), backgroundColor: _neonPink));
                    return;
                  }

                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Processing withdrawal...'), backgroundColor: _neonOrange));
                  
                  try {
                    final response = await http.post(
                      Uri.parse(ApiConfig.mpesaWithdraw),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'phone_number': phone,
                        'amount': amount, // Backend expects string/float
                        'user_id': userModel.uid,
                        'role': 'student',
                        'source': 'vaultBalance',
                      }),
                    ).timeout(const Duration(seconds: 30));
                    
                    if (response.statusCode == 200) {
                      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Withdrawal successful! Check M-PESA.'), backgroundColor: Colors.green));
                    } else {
                      if (mounted) {
                        String errMsg = 'Failed to withdraw';
                        try {
                          final parsed = jsonDecode(response.body);
                          errMsg = parsed['error'] ?? response.body;
                        } catch (_) {}
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: $errMsg'), backgroundColor: _neonPink));
                      }
                    }
                  } on TimeoutException {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: _neonPink));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Withdraw Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

}
