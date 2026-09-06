import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/widgets/animated_food_background.dart';
import '../../../core/theme/glass_card.dart';
import 'trust_onboarding_view.dart';
import 'dart:ui';

class RoleSelectionView extends StatefulWidget {
  final List<String>? initialRoles;
  final bool isEditing;

  const RoleSelectionView({super.key, this.initialRoles, this.isEditing = false});

  @override
  State<RoleSelectionView> createState() => _RoleSelectionViewState();
}

class _RoleSelectionViewState extends State<RoleSelectionView> {
  late PageController _pageController;
  int _currentIndex = 0;
  final TextEditingController _phoneController = TextEditingController();

  final List<Map<String, dynamic>> _roles = [
    {
      'id': 'student',
      'title': 'Student',
      'desc': 'Order food, split bills, and find matches on campus.',
      'icon': Icons.school,
      'color': Colors.blueAccent,
    },
    {
      'id': 'parent',
      'title': 'Parent',
      'desc': 'Fund student wallets and monitor their expenses securely.',
      'icon': Icons.family_restroom,
      'color': Colors.purpleAccent,
    },
    {
      'id': 'vendor',
      'title': 'Vendor',
      'desc': 'Sell food, manage pre-orders, and grow your campus business.',
      'icon': Icons.storefront,
      'color': Colors.orangeAccent,
    },
    {
      'id': 'driver',
      'title': 'Driver',
      'desc': 'Earn money by delivering food to students across campus.',
      'icon': Icons.delivery_dining,
      'color': MPesaTheme.primaryGreen,
    },
    {
      'id': 'house_owner',
      'title': 'House Owner',
      'desc': 'List properties and connect with student tenants easily.',
      'icon': Icons.apartment,
      'color': Colors.tealAccent,
    },
    {
      'id': 'fundi',
      'title': 'Fundi',
      'desc': 'Offer repair and maintenance services to the campus community.',
      'icon': Icons.build,
      'color': Colors.brown,
    },
  ];

  @override
  void initState() {
    super.initState();
    String initialRole = (widget.initialRoles != null && widget.initialRoles!.isNotEmpty) 
        ? widget.initialRoles!.first 
        : 'student';
        
    _currentIndex = _roles.indexWhere((r) => r['id'] == initialRole);
    if (_currentIndex == -1) _currentIndex = 0;

    _pageController = PageController(initialPage: _currentIndex, viewportFraction: 0.75);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitRoles() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your phone number.')));
      return;
    }
    
    String selectedRole = _roles[_currentIndex]['id'];

    // Save to Firestore if authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'roles': [selectedRole],
        'phoneNumber': _phoneController.text.trim(),
      });
    }

    if (widget.isEditing) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TrustOnboardingView(role: selectedRole)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.isEditing ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ) : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedFoodBackground(),
          
          // Dark gradient overlay to make cards pop
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  widget.isEditing ? 'Change Role' : 'Choose Your Path',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Swipe to explore available roles',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                
                // Carousel
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemCount: _roles.length,
                    itemBuilder: (context, index) {
                      return _buildRoleCard(index);
                    },
                  ),
                ),
                
                const Spacer(),
                
                // Phone Number and Submit
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            labelStyle: TextStyle(color: Colors.white70),
                            hintText: 'e.g. 0712345678',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.phone, color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _submitRoles,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MPesaTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                            shadowColor: MPesaTheme.primaryGreen.withOpacity(0.5),
                          ),
                          child: Text(
                            widget.isEditing ? 'Save Role' : 'Continue as ${_roles[_currentIndex]['title']}', 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(int index) {
    final role = _roles[index];
    final bool isActive = index == _currentIndex;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuint,
      margin: EdgeInsets.symmetric(
        horizontal: 12, 
        vertical: isActive ? 0 : 30
      ),
      decoration: BoxDecoration(
        color: isActive ? role['color'].withOpacity(0.15) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isActive ? role['color'] : Colors.white12,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive ? [
          BoxShadow(
            color: role['color'].withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.all(isActive ? 24 : 16),
                  decoration: BoxDecoration(
                    color: isActive ? role['color'].withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    role['icon'], 
                    size: isActive ? 80 : 50, 
                    color: isActive ? role['color'] : Colors.white54
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  role['title'],
                  style: TextStyle(
                    fontSize: isActive ? 28 : 20,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.white70,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(height: 16),
                  Text(
                    role['desc'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
