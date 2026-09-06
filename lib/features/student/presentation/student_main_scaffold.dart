import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:swapeat/core/models/user_model.dart';
import 'package:swapeat/features/student/presentation/student_dashboard.dart';
import 'package:swapeat/features/student/presentation/all_features_view.dart';
import 'package:swapeat/features/student/presentation/student_profile_settings.dart';
import 'package:swapeat/features/match/presentation/match_hub_view.dart';

class StudentMainScaffold extends StatefulWidget {
  final Map<String, dynamic> user;

  const StudentMainScaffold({super.key, required this.user});

  @override
  State<StudentMainScaffold> createState() => _StudentMainScaffoldState();
}

class _StudentMainScaffoldState extends State<StudentMainScaffold> {
  int _currentIndex = 0;
  
  late final List<Widget> _pages;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // Deep space background
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      extendBody: true, // Allows body to extend behind the bottom nav bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
          color: Colors.transparent, // Base color is transparent for blur
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: const Color(0xFF161B29).withOpacity(0.7), // Semi-transparent card color
              selectedItemColor: const Color(0xFF00FFD1), // Neon cyan
              unselectedItemColor: Colors.white.withOpacity(0.5),
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_outlined),
                  activeIcon: Icon(Icons.grid_view),
                  label: 'Apps',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  activeIcon: Icon(Icons.people),
                  label: 'Social',
                ),
                BottomNavigationBarItem(
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
