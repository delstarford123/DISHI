import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';

import 'package:swapeat/core/models/user_model.dart';

import 'package:swapeat/features/student/presentation/student_dashboard.dart';

import 'package:swapeat/features/student/presentation/all_features_view.dart';

import 'package:swapeat/features/student/presentation/student_profile_settings.dart';

import 'package:swapeat/features/match/presentation/match_hub_view.dart';

import 'package:swapeat/features/match/presentation/match_discovery_view.dart';

import 'package:swapeat/features/match/presentation/match_matches_hub.dart';

import 'student_preorders_view.dart';

import 'campus_supermarket_view.dart';

import 'student_ledger_view.dart';

import 'campus_employment_hub.dart';

import '../../../core/security/secure_storage_service.dart';

import '../../admin/presentation/admin_dashboard_view.dart';

import '../../../core/widgets/sema_na_dishi_overlay.dart';

import 'package:flutter/services.dart';



class StudentMainScaffold extends StatefulWidget {

  final Map<String, dynamic> user;



  const StudentMainScaffold({super.key, required this.user});



  @override

  State<StudentMainScaffold> createState() => _StudentMainScaffoldState();

}



class _StudentMainScaffoldState extends State<StudentMainScaffold> {

  int _currentIndex = 0;

  

  late final List<Widget> _pages;



  void _handleScaffoldVoiceAction(String intent, Map<String, dynamic> data) {

    switch (intent) {

      case 'OPEN_UNIUPTOWN':

        Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchHubView()));

        break;

      case 'START_SWIPING':

        Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchDiscoveryView()));

        break;

      case 'OPEN_MATCHES_CHATS':

        Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchMatchesHub()));

        break;

      case 'OPEN_PREORDERS':

        Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentPreordersView()));

        break;

      case 'OPEN_SUPERMARKET':

      case 'DISCOVER_MEALS':

        Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusSupermarketView()));

        break;

      case 'QUERY_BALANCE':

        Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLedgerView()));

        break;

      case 'CAMPUS_GIGS':

        Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusEmploymentHubView()));

        break;

      default:

        break;

    }

  }



  @override

  void initState() {

    super.initState();

    // Re-create the user model to pass to views that need it

    final userModel = UserModel.fromJson(widget.user, widget.user['uid'] ?? '');

    

    _pages = [

      StudentDashboardView(user: widget.user),

      AllFeaturesView(userModel: userModel),

      const MatchHubView(),

      StudentProfileSettings(userModel: userModel),

    ];

  }



  Future<void> _exitGhostMode(BuildContext context) async {

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (_) => const Center(

        child: CircularProgressIndicator(color: Color(0xFF00FFD1)),

      ),

    );



    try {

      final adminToken = await SecureStorageService.getGhostAdminReturnToken();

      final adminUserMap = await SecureStorageService.getGhostAdminUserMap() ??

          (widget.user['adminUser'] is Map ? Map<String, dynamic>.from(widget.user['adminUser'] as Map) : null);



      if (adminToken != null && adminToken.isNotEmpty) {

        await FirebaseAuth.instance.signInWithCustomToken(adminToken);

      }



      await SecureStorageService.endGhostSession();



      if (context.mounted) {

        Navigator.pop(context); // Dismiss loading dialog

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

            content: Text('Ghost Session Ended. Super Admin console restored.'),

            backgroundColor: Color(0xFF00FFD1),

          ),

        );

      }

    } catch (e) {

      if (context.mounted) {

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Failed to exit ghost mode: $e'), backgroundColor: Colors.red),

        );

      }

    }

  }



  @override

  Widget build(BuildContext context) {

    final bool isGhostMode = widget.user['isGhostMode'] == true;



    return Scaffold(

      backgroundColor: const Color(0xFF0D1117), // Deep space background

      body: Stack(

        children: [

          IndexedStack(

            index: _currentIndex,

            children: _pages,

          ),

          if (isGhostMode)

            Positioned(

              top: 0,

              left: 0,

              right: 0,

              child: SafeArea(

                child: Container(

                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

                  decoration: BoxDecoration(

                    color: const Color(0xFF161B29).withValues(alpha: 0.95),

                    borderRadius: BorderRadius.circular(30),

                    border: Border.all(color: const Color(0xFF00FFD1), width: 1.5),

                    boxShadow: [

                      BoxShadow(

                        color: const Color(0xFF00FFD1).withValues(alpha: 0.25),

                        blurRadius: 14,

                        spreadRadius: 1,

                      ),

                    ],

                  ),

                  child: Row(

                    children: [

                      const Icon(Icons.remove_red_eye, color: Color(0xFF00FFD1), size: 18),

                      const SizedBox(width: 8),

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            const Text(

                              'GHOST INSPECTION MODE',

                              style: TextStyle(color: Color(0xFF00FFD1), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),

                            ),

                            Text(

                              'Viewing as ${widget.user['name'] ?? widget.user['displayName'] ?? 'Student'}',

                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                            ),

                          ],

                        ),

                      ),

                      const SizedBox(width: 8),

                      ElevatedButton.icon(

                        style: ElevatedButton.styleFrom(

                          backgroundColor: const Color(0xFFFF2A6D),

                          foregroundColor: Colors.white,

                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

                          minimumSize: Size.zero,

                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

                        ),

                        icon: const Icon(Icons.exit_to_app, size: 14),

                        label: const Text('Exit to Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),

                        onPressed: () => _exitGhostMode(context),

                      ),

                    ],

                  ),

                ),

              ),

            ),

        ],

      ),

      extendBody: true, // Allows body to extend behind the bottom nav bar

      bottomNavigationBar: Container(

        decoration: BoxDecoration(

          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),

          color: Colors.transparent, // Base color is transparent for blur

        ),

        child: ClipRRect(

          child: BackdropFilter(

            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),

            child: BottomNavigationBar(

              currentIndex: _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex,

              onTap: (index) {

                if (index == 2) {

                  HapticFeedback.mediumImpact();

                  SemaNaDishiOverlay.show(

                    context,

                    role: 'student',

                    userUid: widget.user['uid'] ?? FirebaseAuth.instance.currentUser?.uid,

                    onAction: _handleScaffoldVoiceAction,

                  );

                  return;

                }

                setState(() => _currentIndex = index > 2 ? index - 1 : index);

              },

              backgroundColor: const Color(0xFF161B29).withValues(alpha: 0.85),

              selectedItemColor: const Color(0xFF00FFD1),

              unselectedItemColor: Colors.white.withValues(alpha: 0.5),

              type: BottomNavigationBarType.fixed,

              selectedFontSize: 11,

              unselectedFontSize: 10,

              elevation: 0,

              items: [

                const BottomNavigationBarItem(

                  icon: Icon(Icons.home_outlined),

                  activeIcon: Icon(Icons.home),

                  label: 'Home',

                ),

                const BottomNavigationBarItem(

                  icon: Icon(Icons.grid_view_outlined),

                  activeIcon: Icon(Icons.grid_view),

                  label: 'Apps',

                ),

                BottomNavigationBarItem(

                  icon: Transform.translate(

                    offset: const Offset(0, -8),

                    child: Container(

                      width: 52,

                      height: 52,

                      decoration: BoxDecoration(

                        gradient: const LinearGradient(

                          colors: [Color(0xFFFFF9A6), Color(0xFFFFD700), Color(0xFFE5A910), Color(0xFFB8860B)],

                          begin: Alignment.topLeft,

                          end: Alignment.bottomRight,

                        ),

                        shape: BoxShape.circle,

                        boxShadow: [

                          BoxShadow(

                            color: const Color(0xFFFFD700).withValues(alpha: 0.65),

                            blurRadius: 16,

                            spreadRadius: 3,

                          ),

                          BoxShadow(

                            color: Colors.black.withValues(alpha: 0.35),

                            blurRadius: 8,

                            offset: const Offset(0, 4),

                          ),

                        ],

                        border: Border.all(color: const Color(0xFFFFF7A1), width: 2.2),

                      ),

                      child: const Center(

                        child: Icon(Icons.mic_rounded, color: Color(0xFF0C101B), size: 28),

                      ),

                    ),

                  ),

                  activeIcon: Transform.translate(

                    offset: const Offset(0, -10),

                    child: Container(

                      width: 56,

                      height: 56,

                      decoration: BoxDecoration(

                        gradient: const LinearGradient(

                          colors: [Colors.white, Color(0xFFFFD700), Color(0xFFD4AF37)],

                          begin: Alignment.topLeft,

                          end: Alignment.bottomRight,

                        ),

                        shape: BoxShape.circle,

                        boxShadow: [

                          BoxShadow(

                            color: const Color(0xFFFFD700).withValues(alpha: 0.85),

                            blurRadius: 20,

                            spreadRadius: 4,

                          ),

                          BoxShadow(

                            color: Colors.black.withValues(alpha: 0.45),

                            blurRadius: 10,

                            offset: const Offset(0, 5),

                          ),

                        ],

                        border: Border.all(color: Colors.white, width: 2.5),

                      ),

                      child: const Center(

                        child: Icon(Icons.mic_rounded, color: Color(0xFF0C101B), size: 30),

                      ),

                    ),

                  ),

                  label: 'Sema DISHI',

                ),

                const BottomNavigationBarItem(

                  icon: Icon(Icons.people_outline),

                  activeIcon: Icon(Icons.people),

                  label: 'Socials',

                ),

                const BottomNavigationBarItem(

                  icon: Icon(Icons.person_outline),

                  activeIcon: Icon(Icons.person),

                  label: 'Profile',

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}

