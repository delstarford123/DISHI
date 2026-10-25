import 'package:flutter/material.dart';
import '../../../shared/presentation/profile_hub_sheet.dart';
import 'package:swapeat/features/student/presentation/gift_meal_dialog.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/user_model.dart';
import '../../admin/presentation/admin_dashboard_view.dart';
import '../../auth/presentation/login_view.dart';
import '../../match/presentation/match_hub_view.dart';
import '../../deliv/presentation/deliv_driver_dashboard.dart';
import '../../deliv/presentation/deliv_registration_view.dart';
import '../../../core/security/secure_storage_service.dart';
import 'student_ledger_view.dart';
import 'student_preorders_view.dart';
import 'student_transfers_view.dart';
import 'vendor_directory_view.dart';
import 'campus_employment_hub.dart';
import 'split_bill_view.dart';
import 'okoa_food_view.dart';
import 'all_features_view.dart';
import 'virtual_card_view.dart';
import 'request_funds_view.dart';
import '../../marketplace/presentation/escrow_market_view.dart';
import 'student_profile_settings.dart';
import '../../games/presentation/games_hub_view.dart';
import '../../games/presentation/redeem_store_view.dart';
import '../../games/presentation/daily_spin_game.dart';
import '../../housing/presentation/housing_dashboard_view.dart';
import '../../smartimer/presentation/timetable_view.dart';
import '../../smartimer/presentation/smarti_chatbot_view.dart';
import '../../../shared/presentation/universal_support_widget.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/location_service.dart';
import 'campus_map_view.dart';
import '../../fundi/presentation/fundi_dashboard_view.dart';
import '../../fundi/presentation/fundi_registration_view.dart';
import '../../fundi/presentation/fundi_marketplace_view.dart';

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

class _StudentDashboardViewState extends State<StudentDashboardView>
    with SingleTickerProviderStateMixin {
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
  bool _sosActive = false;
  bool _isBroadcasting = false;
  String? _activeSosAlertId; // Firestore doc ID for the current active SOS alert
  late AnimationController _sosPulseController;
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.user['uid'] as String? ?? '';
    _userProfileStream = uid.isNotEmpty
        ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
        : const Stream.empty();
    _loadFeatureOrder();
    
    // Initialize FCM
    FCMService.initialize();

    // SOS animation controller
    _sosPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  List<String> _featureOrder = ['Fundi Juaji Market', 'UniUptown', 'Study Companion', 'Keja Yangu'];

  Future<void> _loadFeatureOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('dashboard_feature_order');
    if (savedOrder != null && savedOrder.length == _featureOrder.length) {
      if (mounted) {
        setState(() {
          _featureOrder = savedOrder.map((f) => f == 'Find Your Match' ? 'UniUptown' : f).toList();
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
    _sosPulseController.dispose();
    // Stop broadcasting if the student leaves the dashboard
    final uid = widget.user['uid'] as String?;
    if (_isBroadcasting && uid != null) {
      LocationService.stopBroadcasting(studentUid: uid);
    }
    super.dispose();
  }

  Future<void> _activateSOS(String uid) async {
    setState(() {
      _sosActive = true;
      _isBroadcasting = true;
    });
    _sosPulseController.repeat(reverse: true);

    // High-frequency SOS broadcast
    await LocationService.startBroadcasting(uid, context: context, sosMode: true);

    // Mark SOS in Firestore (immediate, even before backend call)
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'sosActive': true, 'shareLocationWithParents': true},
      SetOptions(merge: true),
    );

    // Get current display name for the notification
    final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final studentName = userSnap.data()?['displayName'] as String? ?? 'Your Student';

    // Get current GPS location for the SOS payload
    double? lat;
    double? lng;
    try {
      final pos = await LocationService.getCurrentLocation(context: context);
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    // Notify parents via backend → FCM
    final alertId = await FCMService.sendSOSToParents(
      studentUid:  uid,
      studentName: studentName,
      lat:         lat,
      lng:         lng,
    );
    if (alertId != null) {
      setState(() => _activeSosAlertId = alertId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFF92B60),
          content: Text(
            '🚨 SOS ACTIVE — Parents are being notified and your location is live.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _deactivateSOS(String uid) async {
    setState(() {
      _sosActive = false;
      _isBroadcasting = false;
    });
    _sosPulseController.stop();
    _sosPulseController.reset();
    await LocationService.stopBroadcasting(studentUid: uid);
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'sosActive': false},
      SetOptions(merge: true),
    );

    // Notify parents that SOS is resolved
    final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final studentName = userSnap.data()?['displayName'] as String? ?? 'Your Student';
    await FCMService.sendSOSResolved(
      studentUid:  uid,
      studentName: studentName,
      alertId:     _activeSosAlertId,
    );
    setState(() => _activeSosAlertId = null);
  }

  Future<void> _toggleBroadcast(String uid) async {
    if (_isBroadcasting) {
      setState(() => _isBroadcasting = false);
      await LocationService.stopBroadcasting(studentUid: uid);
    } else {
      setState(() => _isBroadcasting = true);
      await LocationService.startBroadcasting(uid, context: context);
    }
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
            
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: _neonCyan));
            }

            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
              userModel = UserModel.fromJson(
                Map<String, dynamic>.from(snapshot.data!.data() as Map), 
                snapshot.data!.id,
              );
            } else {
              userModel = UserModel.fromJson(widget.user, widget.user['uid'] ?? 'offline_user');
            }

            return Stack(
              children: [
                RefreshIndicator(
                  color: _neonCyan,
                  backgroundColor: _cardColor,
                  onRefresh: () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.user['uid'] as String? ?? '';
                    if (uid.isNotEmpty) {
                      try {
                        await FirebaseFirestore.instance.collection('users').doc(uid).get(const GetOptions(source: Source.server));
                      } catch (_) {}
                    }
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
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
                            // 1. AVAILABLE BALANCE AT THE VERY TOP
                            const SizedBox(height: 12),
                            _buildBalancePageView(userModel),
                            const SizedBox(height: 8),
                            _buildPaginationDots(),

                            // 2. LIVE ACTIVE PREORDER STREAM (Order Ahead & Food Connection)
                            const SizedBox(height: 16),
                            _buildLiveActiveOrderStream(userModel),

                            // 3. CLEAN QUICK ACTIONS (High-priority shortcuts)
                            const SizedBox(height: 20),
                            _buildQuickActions(userModel),

                            // 4. CAMPUS CAFETERIAS SPOTLIGHT (Food stalls)
                            const SizedBox(height: 24),
                            _buildCampusVendorsSpotlight(userModel),

                            // 5. FLASH SALES & TODAY'S DEALS TICKER
                            const SizedBox(height: 20),
                            _buildFlashSalesTicker(userModel),

                            // 6. UP NEXT CLASS & TIMETABLE CARD
                            const SizedBox(height: 20),
                            _buildUpNextClassCard(userModel),

                            // 7. STREAK, REWARDS & SOCIAL TRAY
                            const SizedBox(height: 18),
                            _buildStreakAndRewardsBar(userModel),
                            const SizedBox(height: 16),
                            _buildSendAgainTray(userModel),

                            // 8. CAMPUS SERVICES & LIVING HUB
                            const SizedBox(height: 22),
                            _buildCampusEcosystemHub(userModel),

                            // 9. SMART CAMPUS CONTEXT
                            const SizedBox(height: 18),
                            _buildSmartCampusContextBar(),
                            const SizedBox(height: 14),
                            _buildDriverModeToggle(userModel),
                            const SizedBox(height: 14),
                            _buildFundiModeToggle(userModel),

                            // 10. DISHI STUDENT ID & SAFETY CARD
                            const SizedBox(height: 20),
                            _buildDishiIdCard(userModel),
                            const SizedBox(height: 16),
                            _buildSafetyCard(userModel),
                            const SizedBox(height: 16),
                            UniversalSupportWidget(userId: userModel.uid, userRole: 'student'),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                // Existing context-aware FAB
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton.extended(
                    heroTag: 'student_main_fab',
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
                ),


                // Location broadcast indicator
                if (_isBroadcasting && !_sosActive)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: const Color(0xFF05D5AA).withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, color: Color(0xFF05D5AA), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Location broadcasting — Parents can see you',
                            style: TextStyle(
                              color: Color(0xFF05D5AA),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

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
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ProfileHubSheet(user: widget.user),
                  );
                },
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
          .limit(40)
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
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final currentList = List<DocumentSnapshot>.from(notifications);
          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.92,
            minChildSize: 0.35,
            expand: false,
            builder: (_, scrollController) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          if (currentList.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: _neonCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: Text('${currentList.length}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                      if (currentList.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: _neonPink,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          label: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () async {
                            final docsToClear = List<DocumentSnapshot>.from(currentList);
                            setSheetState(() => currentList.clear());
                            for (var doc in docsToClear) {
                              try {
                                final data = Map<String, dynamic>.from(doc.data() as Map);
                                if (data['targetUserId'] == uid) {
                                  await FirebaseFirestore.instance.collection('notifications').doc(doc.id).delete();
                                } else {
                                  await FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({
                                    'dismissedBy': FieldValue.arrayUnion([uid])
                                  });
                                }
                              } catch (_) {}
                            }
                            if (mounted) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('All notifications cleared'), backgroundColor: _neonCyan),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Swipe left to delete specific notifications', style: TextStyle(color: _textSecondary, fontSize: 11)),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: currentList.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_off_outlined, color: _textSecondary, size: 48),
                                SizedBox(height: 12),
                                Text('No notifications right now', style: TextStyle(color: _textSecondary, fontSize: 14)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: currentList.length,
                            separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                            itemBuilder: (context, index) {
                              final doc = currentList[index];
                              final data = Map<String, dynamic>.from(doc.data() as Map);
                              final readBy = List<String>.from(data['readBy'] ?? []);
                              final isRead = readBy.contains(uid);

                              return Dismissible(
                                key: Key(doc.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: _neonPink,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                      SizedBox(width: 6),
                                      Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                onDismissed: (_) async {
                                  setSheetState(() => currentList.removeAt(index));
                                  try {
                                    if (data['targetUserId'] == uid) {
                                      await FirebaseFirestore.instance.collection('notifications').doc(doc.id).delete();
                                    } else {
                                      await FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({
                                        'dismissedBy': FieldValue.arrayUnion([uid])
                                      });
                                    }
                                  } catch (_) {}
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Notification removed'), duration: Duration(seconds: 1)),
                                    );
                                  }
                                },
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isRead ? _surfaceLight : _neonCyan.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isRead ? Colors.transparent : _neonCyan, width: 1),
                                    ),
                                    child: Icon(
                                      data['type'] == 'broadcast' ? Icons.campaign : Icons.notifications,
                                      color: isRead ? _textSecondary : _neonCyan,
                                      size: 22,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          data['title'] ?? '',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (data['type'] == 'broadcast')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: _neonBlue.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('BROADCAST', style: TextStyle(color: _neonBlue, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(data['message'] ?? '', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                  ),
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
          );
        },
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
            activeThumbColor: _neonBlue,
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

  Widget _buildFundiModeToggle(UserModel userModel) {
    final bool isFundi = userModel.roles.any((r) => r.toLowerCase() == 'fundi');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF05D5AA).withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF05D5AA).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF05D5AA).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.handyman_rounded, color: Color(0xFF05D5AA), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFundi ? 'Comrade Fundi Workspace' : 'Become a Comrade Fundi',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  isFundi ? 'Manage live campus gigs, escrow & rates' : 'Earn from repairs, tech & campus gigs',
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF05D5AA),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () {
              if (isFundi) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FundiDashboardView(user: userModel.toJson())),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FundiRegistrationView(userModel: userModel)),
                );
              }
            },
            child: Text(
              isFundi ? 'Open Hub' : 'Register',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
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
      height: 275,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonCyan.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _neonCyan.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          )
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
                    const Icon(Icons.account_balance_wallet, color: _neonCyan, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Active Student Wallet',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _isBalanceVisible ? 'Ksh. ${userModel.walletBalance.toStringAsFixed(2)}' : 'Ksh. ****',
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              if (userModel.isFrozen) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _neonPink.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _neonPink),
                  ),
                  child: const Text('FROZEN', style: TextStyle(color: _neonPink, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                height: 6,
                width: (userModel.dailyLimit != null && userModel.dailyLimit! > 0)
                    ? MediaQuery.of(context).size.width * (userModel.walletBalance / userModel.dailyLimit!).clamp(0.0, 1.0)
                    : MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: _neonCyan,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: _neonCyan.withOpacity(0.6), blurRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isBalanceVisible 
              ? ((userModel.dailyLimit != null && userModel.dailyLimit! > 0) 
                  ? '${((userModel.walletBalance / userModel.dailyLimit!) * 100).toStringAsFixed(0)}% remaining of Ksh ${userModel.dailyLimit?.toStringAsFixed(0)} daily cap'
                  : 'Upkeep & cafeteria account balance')
              : 'Upkeep & cafeteria account balance', 
            style: const TextStyle(color: _neonCyan, fontSize: 11),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView())),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _neonOrange.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _neonOrange.withOpacity(0.5)),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant, color: _neonOrange, size: 14),
                            SizedBox(width: 3),
                            Text('Pre-order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => _showTopUpBottomSheet(userModel),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _neonCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _neonCyan.withOpacity(0.4)),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: _neonCyan, size: 14),
                            SizedBox(width: 3),
                            Text('Top Up', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentTransfersView(userModel: userModel))),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _neonPink.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _neonPink.withOpacity(0.4)),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded, color: _neonPink, size: 14),
                            SizedBox(width: 3),
                            Text('Send', style: TextStyle(color: _neonPink, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VirtualCardView(userModel: userModel))),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.credit_card, color: Colors.white70, size: 14),
                            SizedBox(width: 3),
                            Text('Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
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

  Widget _buildFundMeBanner(UserModel userModel) {
    final String currentDishiId = (userModel.dishiId != null && userModel.dishiId!.isNotEmpty) 
        ? userModel.dishiId! 
        : userModel.uid;
    final String fundLink = 'https://dishi.delstarfordworks.co.ke/fund?dishi_id=$currentDishiId';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF131A2A),
            _neonCyan.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _neonCyan.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: _neonCyan.withOpacity(0.08),
            blurRadius: 15,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _neonPink.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: _neonPink, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Fund Me • Campus Upkeep',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MPesaTheme.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MPesaTheme.primaryGreen.withOpacity(0.4)),
                ),
                child: const Text(
                  '0% Fee',
                  style: TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Share your link with parents or friends. Money sent lands in your wallet instantly.',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: fundLink));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fund Me link copied to clipboard!'),
                        backgroundColor: _neonCyan,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _surfaceLight,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.white12),
                    ),
                  ),
                  icon: const Icon(Icons.copy, size: 16, color: _neonCyan),
                  label: const Text('Copy Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RequestFundsView(userModel: userModel)));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.qr_code, size: 16),
                  label: const Text('Open Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFundMeDialog(UserModel userModel) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RequestFundsView(userModel: userModel)));
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
              const Text('To join UniUptown, we strictly match opposite genders. What is your gender?', style: TextStyle(color: Colors.white70)),
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

  Widget _buildSmartCampusContextBar() {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    String message = 'Breakfast specials & hot tea at Cafeteria ☕';
    String rushStatus = 'Low Rush · Fast Pickup 🟢';
    Color rushColor = const Color(0xFF10B981);
    IconData icon = Icons.wb_sunny_rounded;

    if (hour >= 11 && hour <= 14) {
      greeting = 'Peak Lunch Rush';
      message = 'High queue times (~15m). Pre-order ahead to skip line!';
      rushStatus = 'Peak Rush Hour ⏱️';
      rushColor = _neonPink;
      icon = Icons.local_fire_department_rounded;
    } else if (hour >= 15 && hour <= 18) {
      greeting = 'Afternoon Study & Gigs';
      message = '3 new campus gigs posted today. Study pods open.';
      rushStatus = 'Snack Time · Moderate 🟡';
      rushColor = _neonOrange;
      icon = Icons.menu_book_rounded;
    } else if (hour >= 18 || hour < 6) {
      greeting = 'Campus Night Life';
      message = 'Safe-Walk active. Hostels dinner delivery online.';
      rushStatus = 'Night Corridor Active 🛡️';
      rushColor = _neonBlue;
      icon = Icons.nightlight_round;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rushColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: rushColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: rushColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: rushColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: rushColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rushStatus,
                        style: TextStyle(color: rushColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendAgainTray(UserModel userModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt, color: _neonCyan, size: 18),
                SizedBox(width: 6),
                Text('Send Again', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => StudentTransfersView(userModel: userModel)));
              },
              child: Text('New Transfer +', style: TextStyle(color: _neonCyan.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('transactions')
              .where('senderUid', isEqualTo: userModel.uid)
              .where('type', isEqualTo: 'p2p_transfer')
              .limit(16)
              .snapshots(),
          builder: (context, snapshot) {
            final Map<String, Map<String, dynamic>> recipients = {};
            if (snapshot.hasData && snapshot.data != null) {
              final docs = List<DocumentSnapshot>.from(snapshot.data!.docs);
              docs.sort((a, b) {
                final rawA = a.data() as Map<String, dynamic>?;
                final rawB = b.data() as Map<String, dynamic>?;
                final tA = rawA?['timestamp'];
                final tB = rawB?['timestamp'];
                if (tA is Timestamp && tB is Timestamp) return tB.compareTo(tA);
                return 0;
              });
              for (var doc in docs) {
                final raw = doc.data();
                if (raw == null) continue;
                final d = Map<String, dynamic>.from(raw as Map);
                final recUid = d['receiverUid'] as String?;
                final recName = d['receiverName'] as String? ?? 'Peer';
                if (recUid != null && recUid.isNotEmpty && !recipients.containsKey(recUid)) {
                  recipients[recUid] = {
                    'uid': recUid,
                    'name': recName,
                  };
                }
              }
            }

            final recipientList = recipients.values.toList();

            return SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recipientList.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => StudentTransfersView(userModel: userModel)));
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _neonCyan.withOpacity(0.5), width: 1.5),
                              color: _neonCyan.withOpacity(0.12),
                            ),
                            child: const Icon(Icons.add, color: _neonCyan, size: 24),
                          ),
                          const SizedBox(height: 6),
                          const Text('Anyone', style: TextStyle(color: _textSecondary, fontSize: 11)),
                        ],
                      ),
                    );
                  }

                  final rec = recipientList[index - 1];
                  final name = rec['name'] as String;
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
                  final firstName = name.split(' ').first;

                  return InkWell(
                    onTap: () => _showQuickPeerTransferSheet(userModel, rec['uid'] as String, name),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _surfaceLight, width: 1.5),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 60,
                          child: Text(
                            firstName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _showQuickPeerTransferSheet(UserModel userModel, String recUid, String recName) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentTransfersView(
          userModel: userModel,
          prefilledRecipientId: recUid,
        ),
      ),
    );
  }

  Widget _buildUpNextClassCard(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _neonBlue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _neonBlue.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _neonBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _neonBlue.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.school, color: _neonBlue, size: 13),
                    SizedBox(width: 4),
                    Text('Up Next · Class', style: TextStyle(color: _neonBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableView()));
                },
                child: Text('Timetable >', style: TextStyle(color: _neonCyan.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: _neonBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('CS 312: Distributed Systems', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('11:00 AM – 1:00 PM · Science Complex Hall B4', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('In 25m', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartiChatbotView()));
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.smart_toy, color: Colors.purpleAccent, size: 14),
                        SizedBox(width: 6),
                        Text('Study with Smarti AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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

  Widget _buildFlashSalesTicker(UserModel userModel) {
    final flashDeals = [
      {
        'stall': 'Mama Oliech Kitchen',
        'deal': '25% Off Pilau Combo',
        'price': 'KES 120',
        'oldPrice': 'KES 160',
        'timeLeft': '35m left',
        'icon': Icons.rice_bowl,
        'color': _neonOrange,
      },
      {
        'stall': 'Campus Fresh Juices',
        'deal': 'Passion + Chapati Deal',
        'price': 'KES 70',
        'oldPrice': 'KES 90',
        'timeLeft': '50m left',
        'icon': Icons.local_drink,
        'color': _neonCyan,
      },
      {
        'stall': 'Student Cafe 1',
        'deal': 'Beef Burger + Fries',
        'price': 'KES 180',
        'oldPrice': 'KES 220',
        'timeLeft': '1h left',
        'icon': Icons.lunch_dining,
        'color': _neonPink,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt, color: _neonOrange, size: 18),
                SizedBox(width: 6),
                Text('Campus Flash Sales', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView()));
              },
              child: Text('All Deals >', style: TextStyle(color: _neonCyan.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: flashDeals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final d = flashDeals[index];
              final color = d['color'] as Color;

              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView()));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              d['timeLeft'] as String,
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(d['icon'] as IconData, color: color, size: 18),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['deal'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            d['stall'] as String,
                            style: const TextStyle(color: _textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            d['price'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            d['oldPrice'] as String,
                            style: const TextStyle(color: _textSecondary, fontSize: 10, decoration: TextDecoration.lineThrough),
                          ),
                          const Spacer(),
                          Text(
                            'Claim >',
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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
      ],
    );
  }

  Widget _buildWeeklyBurnRateCard(UserModel userModel) {
    final dailyLimit = userModel.dailyLimit ?? 300.0;
    final weeklyTarget = dailyLimit * 7;
    final double weeklySpend = (userModel.walletBalance < 1000) ? 1450.0 : 880.0;
    final double safeDailyPace = ((weeklyTarget - weeklySpend) / 4).clamp(50.0, 500.0);
    final bool isHealthy = weeklySpend <= (weeklyTarget * 0.7);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surfaceLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
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
                  Icon(Icons.pie_chart_outline, color: _neonCyan, size: 18),
                  SizedBox(width: 8),
                  Text('Weekly Spend Health', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHealthy ? const Color(0xFF10B981).withOpacity(0.15) : _neonOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isHealthy ? const Color(0xFF10B981).withOpacity(0.5) : _neonOrange.withOpacity(0.5)),
                ),
                child: Text(
                  isHealthy ? '🟢 Safe Pace' : '🟠 High Burn Rate',
                  style: TextStyle(color: isHealthy ? const Color(0xFF10B981) : _neonOrange, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spent This Week', style: TextStyle(color: _textSecondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('KES ${weeklySpend.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Safe Daily Pace', style: TextStyle(color: _textSecondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('KES ${safeDailyPace.toStringAsFixed(0)} / day', style: const TextStyle(color: _neonCyan, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: const [
                  Expanded(flex: 65, child: ColoredBox(color: _neonOrange)),
                  SizedBox(width: 2),
                  Expanded(flex: 20, child: ColoredBox(color: _neonCyan)),
                  SizedBox(width: 2),
                  Expanded(flex: 15, child: ColoredBox(color: _neonBlue)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _SpendLegendItem(color: _neonOrange, label: 'Meals (65%)'),
              _SpendLegendItem(color: _neonCyan, label: 'Transfers (20%)'),
              _SpendLegendItem(color: _neonBlue, label: 'Keja/WiFi (15%)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKejaDueTracker(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
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
                  Icon(Icons.home_work_outlined, color: Color(0xFF6366F1), size: 18),
                  SizedBox(width: 8),
                  Text('Keja Roommate Due Alert', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Due in 3 Days', style: TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Hostel High-Speed WiFi Split', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 2),
                    Text('3 of 4 roommates paid · Your share KES 350', style: TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 0,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => HousingDashboardView(user: userModel.toJson())));
                },
                child: const Text('Pay Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakAndRewardsBar(UserModel userModel) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userModel.uid).snapshots(),
      builder: (context, snapshot) {
        int coins = 150;
        int streak = 5;
        if (snapshot.hasData && snapshot.data!.exists) {
          final rawData = snapshot.data!.data();
          final data = rawData != null ? Map<String, dynamic>.from(rawData as Map) : null;
          coins = (data?['dishiCoins'] as num?)?.toInt() ?? 150;
          streak = (data?['streakDays'] as num?)?.toInt() ?? 5;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _surfaceLight),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _neonOrange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department, color: _neonOrange, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('$streak Day Streak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 4),
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Text('🪙 $coins DISHI Coins', style: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DailySpinGame(userModel: userModel)));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _neonPink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _neonPink.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.casino, color: _neonPink, size: 14),
                      SizedBox(width: 4),
                      Text('Spin', style: TextStyle(color: _neonPink, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RedeemStoreView(userModel: userModel)));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _neonCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _neonCyan.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.redeem, color: _neonCyan, size: 14),
                      SizedBox(width: 4),
                      Text('Rewards', style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveActiveOrderStream(UserModel userModel) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('preorders')
          .where('studentId', isEqualTo: userModel.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildOrderAheadBanner(userModel);
        }

        final activeDocs = snapshot.data!.docs.where((doc) {
          final raw = doc.data();
          if (raw == null) return false;
          final data = Map<String, dynamic>.from(raw as Map);
          final status = (data['status'] ?? 'pending').toString().toLowerCase();
          return status != 'fulfilled' && status != 'cancelled';
        }).toList();

        if (activeDocs.isEmpty) {
          return _buildOrderAheadBanner(userModel);
        }

        final firstOrder = activeDocs.first;
        final rawFirst = firstOrder.data();
        final data = rawFirst != null ? Map<String, dynamic>.from(rawFirst as Map) : <String, dynamic>{};
        final String vendorName = data['vendorName'] ?? 'Campus Cafeteria';
        final String mealName = data['mealName'] ?? 'Meal Order';
        final double price = (data['price'] as num?)?.toDouble() ?? 0.0;
        final String status = (data['status'] ?? 'pending').toString().toLowerCase();
        final String orderId = firstOrder.id;

        String statusLabel = 'Order Confirmed · In Kitchen';
        Color statusColor = _neonOrange;
        IconData statusIcon = Icons.hourglass_top_rounded;

        if (status == 'preparing') {
          statusLabel = 'Chef is Preparing 🍳';
          statusColor = _neonBlue;
          statusIcon = Icons.soup_kitchen_rounded;
        } else if (status == 'ready' || status == 'ready_for_pickup') {
          statusLabel = 'Ready for Pickup at Stall! 🛎️';
          statusColor = _neonCyan;
          statusIcon = Icons.check_circle_outline;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.12),
                blurRadius: 18,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentPreordersView()));
                    },
                    child: Text('All Orders >', style: TextStyle(color: _neonCyan.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(Icons.restaurant, color: _neonCyan, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vendorName,
                          style: const TextStyle(color: _textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'KES ${price.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(
                        'Paid with Wallet',
                        style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonCyan,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('Pickup QR & Token', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _showOrderPickupSheet(orderId, mealName, vendorName),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderAheadBanner(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _neonOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fastfood_rounded, color: _neonOrange, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Skip Campus Lunch Lines!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 2),
                Text('Preorder hot meals directly from stalls.', style: TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonCyan.withOpacity(0.2),
              foregroundColor: _neonCyan,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: _neonCyan.withOpacity(0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView()));
            },
            child: const Text('Order >', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showOrderPickupSheet(String orderId, String mealName, String vendorName) {
    final token = orderId.length >= 6 ? orderId.substring(orderId.length - 6).toUpperCase() : orderId.toUpperCase();
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Present at Stall Counter', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$mealName · $vendorName', style: const TextStyle(color: _textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                data: 'dishi:preorder:$orderId',
                version: QrVersions.auto,
                size: 160.0,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _neonCyan.withOpacity(0.3)),
              ),
              child: Text(
                'TOKEN: #$token',
                style: const TextStyle(color: _neonCyan, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cashier or Vendor will scan this QR or input the token to hand over your meal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(UserModel userModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt, color: _neonCyan, size: 20),
                SizedBox(width: 8),
                Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllFeaturesView(userModel: userModel))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _neonCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _neonCyan.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Text('View All', style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, color: _neonCyan, size: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
          children: [
            _buildGridActionItem(
              icon: Icons.restaurant,
              label: 'Pre-order',
              glowColor: _neonOrange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView())),
            ),
            _buildGridActionItem(
              icon: Icons.shopping_bag_outlined,
              label: 'My Orders',
              glowColor: _neonCyan,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentPreordersView())),
            ),
            _buildGridActionItem(
              icon: Icons.credit_card,
              label: 'VCC Card',
              glowColor: const Color(0xFF3B82F6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VirtualCardView(userModel: userModel))),
            ),
            _buildGridActionItem(
              icon: Icons.fastfood,
              label: 'Okoa Food',
              glowColor: const Color(0xFFEF4444),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OkoaFoodView())),
            ),
            _buildGridActionItem(
              icon: Icons.call_split,
              label: 'Split Bill',
              glowColor: const Color(0xFF06B6D4),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SplitBillView(userModel: userModel))),
            ),
            _buildGridActionItem(
              icon: Icons.send_rounded,
              label: 'Send',
              glowColor: MPesaTheme.primaryGreen,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentTransfersView(userModel: userModel))),
            ),
            _buildGridActionItem(
              icon: Icons.calendar_month,
              label: 'Timetable',
              glowColor: const Color(0xFFF59E0B),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableView())),
            ),
            _buildGridActionItem(
              icon: Icons.grid_view_rounded,
              label: 'More (20+)',
              glowColor: const Color(0xFFA855F7),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllFeaturesView(userModel: userModel))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridActionItem({
    required IconData icon,
    required String label,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: glowColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glowColor.withOpacity(0.35)),
            ),
            child: Icon(icon, color: glowColor, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCampusEcosystemHub(UserModel userModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Campus Ecosystem', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllFeaturesView(userModel: userModel))),
              child: Text('Explore All Apps >', style: TextStyle(color: _neonCyan.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildEcosystemTile(
              title: 'Marketplace',
              subtitle: 'Escrow Buy & Sell',
              icon: Icons.storefront,
              accentColor: MPesaTheme.primaryGreen,
              badge: 'Campus Shop',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EscrowMarketView(user: userModel.toJson()))),
            ),
            _buildEcosystemTile(
              title: 'Fund Me',
              subtitle: 'M-PESA Student Upkeep',
              icon: Icons.favorite_rounded,
              accentColor: _neonPink,
              badge: '0% Fee',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestFundsView(userModel: userModel))),
            ),
            _buildEcosystemTile(
              title: 'Food Stalls',
              subtitle: 'Menus & Pre-orders',
              icon: Icons.restaurant_menu,
              accentColor: _neonOrange,
              badge: 'Skip Queue',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView())),
            ),
            _buildEcosystemTile(
              title: 'Send Money',
              subtitle: '0% P2P Student Transfer',
              icon: Icons.send_rounded,
              accentColor: _neonCyan,
              badge: 'Instant',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentTransfersView(userModel: userModel))),
            ),
            _buildEcosystemTile(
              title: 'Keja Housing',
              subtitle: 'Hostels & Roommates',
              icon: Icons.apartment,
              accentColor: _neonBlue,
              badge: 'Keja Yangu',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HousingDashboardView(user: userModel.toJson()))),
            ),
            _buildEcosystemTile(
              title: 'Comrade Fundi',
              subtitle: 'Repairs, Tech & Services',
              icon: Icons.handyman_rounded,
              accentColor: const Color(0xFF05D5AA),
              badge: 'Campus Gigs',
              onTap: () {
                final bool isFundi = userModel.roles.any((r) => r.toLowerCase() == 'fundi');
                if (isFundi) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FundiDashboardView(user: userModel.toJson())));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FundiMarketplaceView(userModel: userModel)));
                }
              },
            ),
            _buildEcosystemTile(
              title: 'Campus Gigs',
              subtitle: 'Freelance & Earn KES',
              icon: Icons.work_outline,
              accentColor: const Color(0xFF10B981),
              badge: 'Jobs',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusEmploymentHubView())),
            ),
            _buildEcosystemTile(
              title: 'DeLiv Courier',
              subtitle: 'Campus Parcel Dispatch',
              icon: Icons.delivery_dining,
              accentColor: const Color(0xFFE11D48),
              badge: 'Errands',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DelivDriverDashboard(user: userModel.toJson()))),
            ),
            _buildEcosystemTile(
              title: 'Arcade Hub',
              subtitle: 'Play Games & Win Deals',
              icon: Icons.sports_esports,
              accentColor: const Color(0xFFA855F7),
              badge: 'Win Coins',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamesHubView(userModel: userModel))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEcosystemTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampusVendorsSpotlight(UserModel userModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.storefront, color: _neonCyan, size: 20),
                SizedBox(width: 8),
                Text('Popular Campus Cafeterias', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView())),
              child: Text('All Stalls >', style: TextStyle(color: _neonCyan.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('roles', arrayContains: 'vendor')
              .limit(6)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _surfaceLight),
                ),
                child: const Text('Campus stalls opening soon for lunch & dinner.', style: TextStyle(color: _textSecondary)),
              );
            }

            final vendors = snapshot.data!.docs
                .where((d) => d.data() != null)
                .map((d) => UserModel.fromJson(Map<String, dynamic>.from(d.data() as Map), d.id))
                .toList();

            return SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: vendors.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final v = vendors[index];
                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView())),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _surfaceLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: _neonCyan.withOpacity(0.2),
                                backgroundImage: v.profileImageUrl != null ? NetworkImage(v.profileImageUrl!) : null,
                                child: v.profileImageUrl == null ? const Icon(Icons.store, color: _neonCyan, size: 18) : null,
                              ),
                              const Spacer(),
                              const Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 14),
                                  SizedBox(width: 2),
                                  Text('4.8', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            v.displayName.isNotEmpty ? v.displayName : 'Campus Vendor',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Pre-order Meals',
                            style: TextStyle(color: _textSecondary, fontSize: 11),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: _neonCyan.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('View Menu', style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  /// A compact Safety card containing the safe-walk status chip and the SOS
  /// panic button — both grouped under a single labelled section so the top
  /// app bar area stays clean.
  Widget _buildSafetyCard(UserModel userModel) {
    final bool isNight = DateTime.now().hour >= 18 || DateTime.now().hour < 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: _neonPink, size: 20),
            SizedBox(width: 8),
            Text('Safety', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _neonPink.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(color: _neonPink.withOpacity(0.06), blurRadius: 16, spreadRadius: 2)
            ],
          ),
          child: Column(
            children: [
              // ── Safe-Walk row ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.nightlight_round, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNight ? 'Night Mode · Active' : 'Safe-Walk Mode',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          isNight
                              ? 'Safe-walk corridor active · Follow green path'
                              : 'Activates after 6 PM — stays on till 6 AM',
                          style: TextStyle(
                            color: isNight ? const Color(0xFF10B981) : _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CampusMapView(studentUid: userModel.uid),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, color: Color(0xFF10B981), size: 14),
                          SizedBox(width: 4),
                          Text('Map', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(color: Colors.white10, height: 28),

              // ── SOS row ────────────────────────────────────────────
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _sosActive ? _sosPulseController : kAlwaysCompleteAnimation,
                    builder: (_, __) {
                      final scale = _sosActive ? 1.0 + 0.12 * _sosPulseController.value : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _sosActive ? _neonPink : _neonPink.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _neonPink, width: 1.5),
                            boxShadow: _sosActive
                                ? [BoxShadow(color: _neonPink.withOpacity(0.5), blurRadius: 16, spreadRadius: 3)]
                                : [],
                          ),
                          child: Icon(Icons.emergency, color: _sosActive ? Colors.white : _neonPink, size: 22),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sosActive ? '🚨 SOS ACTIVE' : 'Emergency SOS',
                          style: TextStyle(
                            color: _sosActive ? _neonPink : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _sosActive
                              ? 'Broadcasting live location to parents'
                              : 'Hold button for 2 seconds to activate',
                          style: const TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onLongPress: () {
                      final uid = userModel.uid;
                      if (_sosActive) {
                        _deactivateSOS(uid);
                      } else {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: _cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber, color: _neonPink, size: 28),
                                SizedBox(width: 8),
                                Expanded(child: Text('Activate SOS?', style: TextStyle(color: Colors.white))),
                              ],
                            ),
                            content: const Text(
                              'This will override all privacy settings and broadcast your live location to all linked parents immediately.',
                              style: TextStyle(color: _textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
                              ),
                              ElevatedButton(
                                onPressed: () { Navigator.pop(ctx); _activateSOS(uid); },
                                style: ElevatedButton.styleFrom(backgroundColor: _neonPink, foregroundColor: Colors.white),
                                child: const Text('ACTIVATE SOS'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _sosActive ? _neonPink : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _neonPink, width: 2),
                      ),
                      child: Text(
                        _sosActive ? 'DEACTIVATE' : 'HOLD · SOS',
                        style: TextStyle(
                          color: _sosActive ? Colors.white : _neonPink,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
            if (widget.user['isGhostMode'] == true || roles.contains('admin'))
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _neonCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _neonCyan.withOpacity(0.4)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: _neonCyan),
                  title: Text(
                    widget.user['isGhostMode'] == true ? 'Exit Ghost Mode & Return' : 'Admin Console',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: widget.user['isGhostMode'] == true
                      ? const Text('Restore Super Admin session', style: TextStyle(color: _neonCyan, fontSize: 11))
                      : null,
                  trailing: const Icon(Icons.arrow_forward_ios, color: _neonCyan, size: 12),
                  onTap: () async {
                    Navigator.pop(context); // Close drawer
                    if (widget.user['isGhostMode'] == true) {
                      await _exitGhostSession(context);
                    } else {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminDashboardView(user: widget.user)));
                    }
                  },
                ),
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

  Future<void> _exitGhostSession(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _neonCyan),
      ),
    );

    try {
      final adminToken = await SecureStorageService.getGhostAdminReturnToken();
      final adminUserMap = await SecureStorageService.getGhostAdminUserMap() ??
          (widget.user['adminUser'] as Map<String, dynamic>?);

      if (adminToken != null && adminToken.isNotEmpty) {
        await FirebaseAuth.instance.signInWithCustomToken(adminToken);
      }

      await SecureStorageService.endGhostSession();

      if (context.mounted) {
        Navigator.pop(context); // dismiss progress dialog
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardView(
                user: adminUserMap ?? {'roles': ['admin']},
              ),
            ),
            (route) => false,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ghost Mode exited. Super Admin session restored.'),
            backgroundColor: _neonCyan,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to exit ghost mode: $e'), backgroundColor: _neonPink),
        );
      }
    }
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

class _SpendLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _SpendLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: _textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}
