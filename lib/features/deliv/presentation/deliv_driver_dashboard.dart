import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/widgets/high_friction_action.dart';
import 'deliv_active_route_view.dart';
import 'deliv_registration_view.dart';
import 'driver_scanner_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/presentation/login_view.dart';
import '../../../shared/presentation/universal_support_widget.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class DelivDriverDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const DelivDriverDashboard({super.key, required this.user});

  @override
  State<DelivDriverDashboard> createState() => _DelivDriverDashboardState();
}

class _DelivDriverDashboardState extends State<DelivDriverDashboard> {
  bool _isOnline = false;
  double _earnings = 3450.0;

  final List<Map<String, dynamic>> _gigs = [
    {
      'id': 'GIG-101',
      'type': 'Food Delivery',
      'pickup': 'Mama Njeri Kiosk',
      'dropoff': 'Hostel Block B',
      'pay': 'KES 50',
      'distance': '1.2 km',
      'color': _neonOrange,
    },
    {
      'id': 'GIG-102',
      'type': 'Mtu wa Mkono (Moving)',
      'pickup': 'Main Gate',
      'dropoff': 'Room 404, Qwetu',
      'pay': 'KES 250',
      'distance': '3.4 km',
      'color': _neonBlue,
    },
  ];

  void _toggleStatus(bool value) {
    setState(() {
      _isOnline = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? 'You are now Online and visible on the map.' : 'You are now Offline.'),
        backgroundColor: value ? _neonCyan : _neonOrange,
      ),
    );
  }

  void _cashOut() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Processing Driver Withdrawal to M-PESA...'),
        backgroundColor: _neonCyan,
      ),
    );
    setState(() {
      _earnings = 0;
    });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 2)),
        title: const Text('Profile Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: _neonCyan),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: _neonCyan))),
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

    final driverName = widget.user['name'] ?? widget.user['displayName'] ?? 'Driver';
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
                  child: profileImageUrl == null ? const Icon(Icons.two_wheeler, color: _textSecondary, size: 20) : null,
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
                  driverName, 
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
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16, top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _isOnline ? _neonCyan : _textSecondary)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_isOnline ? 'ONLINE' : 'OFFLINE', style: TextStyle(color: _isOnline ? _neonCyan : _textSecondary, fontWeight: FontWeight.bold, fontSize: 10)),
                      Switch(
                        value: _isOnline,
                        activeColor: _neonCyan,
                        inactiveThumbColor: _textSecondary,
                        inactiveTrackColor: _surfaceLight,
                        onChanged: _toggleStatus,
                      ),
                    ],
                  ),
                )
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.only(top: 16, bottom: 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Earnings Banner
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _neonCyan.withOpacity(0.3), width: 1.5),
                      boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)]
                    ),
                    child: Column(
                      children: [
                        const Text('Total Earnings', style: TextStyle(color: _textSecondary, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          'KES ${_earnings.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 24),
                        HighFrictionAction(
                          label: 'Slide to Cash Out',
                          baseColor: _neonCyan,
                          onActionCompleted: _cashOut,
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DelivActiveRouteView())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _surfaceLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _neonBlue.withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map, color: _neonBlue),
                                  SizedBox(width: 8),
                                  Text('Live Map', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Maintenance Hub...')));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _surfaceLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _neonOrange.withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.build, color: _neonOrange),
                                  SizedBox(width: 8),
                                  Text('Maintenance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverScannerView())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _surfaceLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_scanner, color: Colors.greenAccent),
                                  SizedBox(width: 8),
                                  Text('Scanner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Available Gigs Feed
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    decoration: const BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Gigs', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (!_isOnline)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_off, size: 64, color: _textSecondary.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  const Text('Go online to receive gig requests.', style: TextStyle(color: _textSecondary, fontSize: 16)),
                                ],
                              ),
                            ),
                          )
                        else
                          Column(
                            children: _gigs.map((gig) {
                              final color = gig['color'] as Color;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _surfaceLight,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: color.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(gig['type'], style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                        Text(gig['pay'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Icon(Icons.storefront, size: 16, color: _textSecondary),
                                        const SizedBox(width: 8),
                                        Text('Pickup: ${gig['pickup']}', style: const TextStyle(color: Colors.white70)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16, color: _neonRed),
                                        const SizedBox(width: 8),
                                        Text('Dropoff: ${gig['dropoff']}', style: const TextStyle(color: Colors.white70)),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () {},
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _cardColor,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: _textSecondary),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text('Reject', style: TextStyle(color: _textSecondary, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DelivActiveRouteView())),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  UniversalSupportWidget(userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown', userRole: 'driver'),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
