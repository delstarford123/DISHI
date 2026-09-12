import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import 'housing_marketplace_view.dart';
import '../../auth/presentation/login_view.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class HousingDashboardView extends StatefulWidget {
  final Map<String, dynamic> user; // Current student user

  const HousingDashboardView({super.key, required this.user});

  @override
  State<HousingDashboardView> createState() => _HousingDashboardViewState();
}

class _HousingDashboardViewState extends State<HousingDashboardView> {
  final FirestoreService _firestoreService = FirestoreService();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonBlue, width: 2)),
        title: const Text('Profile Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: _neonBlue),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: _neonBlue))),
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

    final housingName = widget.user['name'] ?? widget.user['displayName'] ?? 'Student';
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
                  housingName, 
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

  Future<void> _exitRoom(String roomId, String merchantId) async {
    // ScaffoldMessenger implementation...
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room exit requested.'), backgroundColor: _neonCyan));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: CustomScrollView(
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
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Huge Marketplace Action Button
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => HousingMarketplaceView(user: widget.user)));
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_neonBlue, Color(0xFF1E40AF)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: _neonBlue.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Find a Keja', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              SizedBox(height: 4),
                              Text('Browse verified properties', style: TextStyle(fontSize: 14, color: Colors.white70)),
                            ],
                          ),
                          Icon(Icons.search, size: 40, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'My Leases & Applications',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestoreService.streamCollection(
                      'housing_applications',
                      whereField: 'student_id',
                      isEqualTo: widget.user['uid'] ?? 'MOCK_UID',
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: _neonCyan));
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('You have no active leases.', style: TextStyle(color: _textSecondary)));
                      }

                      final applications = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        data['id'] = doc.id;
                        return data;
                      }).toList();

                      return Column(
                        children: applications.map((app) => _buildApplicationCard(app)).toList(),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final bool isActiveLease = app['status'] == 'Approved';
    final Color statusColor = isActiveLease ? _neonCyan : _neonOrange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  app['room_title'] ?? 'Room Application',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  app['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.payments, color: _textSecondary, size: 16),
              const SizedBox(width: 8),
              Text(
                "Rent: KSH ${app['rent']?.toStringAsFixed(0) ?? '0'} / month",
                style: const TextStyle(fontSize: 15, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isActiveLease)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.payment, size: 18, color: Colors.black),
                    label: const Text('Pay Rent', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exitRoom(app['room_id'], app['merchant_id']),
                    icon: const Icon(Icons.exit_to_app, size: 18, color: _neonRed),
                    label: const Text('Exit Room', style: TextStyle(color: _neonRed, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _neonRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                  ),
                ),
              ],
            )
        ],
      ),
    );
  }
}
