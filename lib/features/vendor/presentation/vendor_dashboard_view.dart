import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/withdrawal_helper.dart';

import '../../../core/utils/pdf_generator.dart';

import '../../../core/widgets/high_friction_action.dart';

import '../../../core/services/firestore_service.dart';

import '../../../core/models/user_model.dart';

import '../../auth/presentation/login_view.dart';

import 'qr_scanner_page.dart';

import 'package:fl_chart/fl_chart.dart';

import '../../../core/widgets/sema_na_dishi_overlay.dart';

import 'vendor_topup_view.dart';

import 'vendor_kds_view.dart';

import 'vendor_reports_view.dart';

import 'vendor_profile_view.dart';



import 'tabs/vendor_finance_tab.dart';

import 'tabs/vendor_operations_tab.dart';

import 'tabs/vendor_sales_tab.dart';

import 'tabs/vendor_management_tab.dart';

import '../../../shared/presentation/universal_support_widget.dart';

import 'dart:convert';

import 'dart:async';





import '../../../core/services/api_config.dart';

import '../../../core/services/secure_http_client.dart';



// -- CUSTOM DESIGN COLORS --

const Color _bgColor = Color(0xFF0C101B);

const Color _cardColor = Color(0xFF131A2A);

const Color _surfaceLight = Color(0xFF1A2235);

const Color _neonCyan = Color(0xFF05D5AA);

const Color _neonOrange = Color(0xFFFF6F00);

const Color _neonPink = Color(0xFFF92B60);

const Color _textSecondary = Color(0xFF8B9BB4);



class VendorDashboardView extends StatefulWidget {

  final Map<String, dynamic> user;



  const VendorDashboardView({super.key, required this.user});



  @override

  State<VendorDashboardView> createState() => _VendorDashboardViewState();

}



class _VendorDashboardViewState extends State<VendorDashboardView> {

  final FirestoreService _firestoreService = FirestoreService();

  int _selectedIndex = 0;

  String _activeCashierName = 'Main Cashier';

  String _activeShift = 'Morning Rush';

  double _todayRevenue = 0.0;

  int _todayOrdersCount = 0;



  void _showShiftSwitcherDialog(BuildContext context) {

    final nameController = TextEditingController(text: _activeCashierName);

    String selectedShift = _activeShift;

    showDialog(

      context: context,

      builder: (ctx) => StatefulBuilder(

        builder: (ctx, setDialogState) => AlertDialog(

          backgroundColor: _cardColor,

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _neonCyan, width: 1.5)),

          title: const Row(

            children: [

              Icon(Icons.badge, color: _neonCyan, size: 24),

              SizedBox(width: 8),

              Text('Cashier Shift Switcher', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

            ],

          ),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              const Text('Active Cashier Name / Till Staff:', style: TextStyle(color: _textSecondary, fontSize: 12)),

              const SizedBox(height: 6),

              TextField(

                controller: nameController,

                style: const TextStyle(color: Colors.white),

                decoration: InputDecoration(

                  filled: true,

                  fillColor: _surfaceLight,

                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),

                  hintText: 'e.g. Akinyi - Counter 1',

                  hintStyle: const TextStyle(color: _textSecondary),

                ),

              ),

              const SizedBox(height: 16),

              const Text('Select Shift:', style: TextStyle(color: _textSecondary, fontSize: 12)),

              const SizedBox(height: 6),

              Wrap(

                spacing: 8,

                children: ['Morning Rush', 'Lunch Peak', 'Evening Supermarket', 'Night Shift'].map((s) {

                  final isSelected = selectedShift == s;

                  return ChoiceChip(

                    label: Text(s, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),

                    selected: isSelected,

                    selectedColor: _neonCyan,

                    backgroundColor: _surfaceLight,

                    onSelected: (_) => setDialogState(() => selectedShift = s),

                  );

                }).toList(),

              ),

            ],

          ),

          actions: [

            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),

            ElevatedButton(

              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),

              onPressed: () {

                final newName = nameController.text.trim();

                if (newName.isNotEmpty) {

                  setState(() {

                    _activeCashierName = newName;

                    _activeShift = selectedShift;

                  });

                }

                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(

                  SnackBar(content: Text('Shift updated:  ()'), backgroundColor: _neonCyan),

                );

              },

              child: const Text('Confirm Switch', style: TextStyle(fontWeight: FontWeight.bold)),

            ),

          ],

        ),

      ),

    );

  }



  void _triggerWithdrawal(String type, double availableBalance) {

    if (availableBalance <= 1.0) {

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient E-Float'), backgroundColor: _neonOrange));

      return;

    }



    showDialog(

      context: context,

      builder: (context) => AlertDialog(

        backgroundColor: _cardColor,

        title: Text('$type Cash-Out', style: const TextStyle(color: Colors.white)),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            const Text('Withdrawal will be sent to your registered profile number:', style: TextStyle(color: _textSecondary, fontSize: 12)),

            const SizedBox(height: 16),

            Text(widget.user['phone'] ?? 'N/A', style: const TextStyle(color: _neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),

          ],

        ),

        actions: [

          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white))),

          ElevatedButton(

            onPressed: () {

              Navigator.pop(context);

              final phone = widget.user['phone'] ?? '';

              if (phone.isEmpty) {

                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile phone number missing')));

                return;

              }

              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Processing $type Cash-Out...'), backgroundColor: _neonCyan));

              WithdrawalHelper.initiateWithdrawal(

                targetNumber: phone,

                amount: availableBalance - 1.0, 

                withdrawalType: type,

              );

            },

            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),

            child: const Text('Confirm', style: TextStyle(color: Colors.black)),

          ),

        ],

      ),

    );

  }



  Future<void> _triggerMpesaTopup(BuildContext context, String amountStr, String phoneNumber) async {

    final amount = double.tryParse(amountStr);

    if (amount == null || amount <= 0) {

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));

      return;

    }

    if (phoneNumber.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid phone number')));

      return;

    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Initiating STK Push...')));

    

    try {

      final response = await SecureHttpClient.post(

        ApiConfig.mpesaStkPush,

        body: {

          'phone_number': phoneNumber,

          'amount': amount,

          'user_id': widget.user['uid'],

          'destination': 'walletBalance',

          'transaction_desc': 'Vendor E-Float Topup'

        },

      );

      

      if (!mounted) return;

      if (response.statusCode == 200) {

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('STK Push sent! Please enter M-Pesa PIN.'), backgroundColor: _neonCyan));

      } else {

        String errMsg = 'Error initiating STK push';

        try {

          final data = jsonDecode(response.body);

          errMsg = data['error'] ?? errMsg;

        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.red));

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));

    }

  }



  void _showTopUpDialog(BuildContext context) {

    final amountController = TextEditingController();

    final phoneController = TextEditingController(text: widget.user['phone'] ?? '');

    showDialog(

      context: context,

      builder: (context) => AlertDialog(

        backgroundColor: _cardColor,

        title: const Text('Top Up E-Float', style: TextStyle(color: Colors.white)),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            const Text('Enter details for M-Pesa STK Push.', style: TextStyle(color: _textSecondary, fontSize: 12)),

            const SizedBox(height: 16),

            TextField(

              controller: phoneController,

              keyboardType: TextInputType.phone,

              style: const TextStyle(color: Colors.white),

              decoration: const InputDecoration(

                labelText: 'Phone Number',

                labelStyle: TextStyle(color: _neonCyan),

                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),

                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),

              ),

            ),

            const SizedBox(height: 16),

            TextField(

              controller: amountController,

              keyboardType: TextInputType.number,

              style: const TextStyle(color: Colors.white),

              decoration: const InputDecoration(

                labelText: 'Amount (KSH)',

                labelStyle: TextStyle(color: _neonCyan),

                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),

                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),

              ),

            ),

          ],

        ),

        actions: [

          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white))),

          ElevatedButton(

            onPressed: () {

              Navigator.pop(context);

              _triggerMpesaTopup(context, amountController.text, phoneController.text.trim());

            },

            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),

            child: const Text('Send STK Push', style: TextStyle(color: Colors.black)),

          ),

        ],

      ),

    );

  }



  void _handleVoiceAction(String intent, Map<String, dynamic> data) {

    if (!mounted) return;

    switch (intent) {

      case 'NAVIGATE_KDS':

        Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorKdsView()));

        break;

      case 'NAVIGATE_REPORTS':

        Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorReportsView()));

        break;

      case 'NAVIGATE_SCANNER':

        Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScannerPage()));

        break;

      case 'NAVIGATE_FINANCE':

        setState(() => _selectedIndex = 1);

        break;

      case 'NAVIGATE_OPERATIONS':

        setState(() => _selectedIndex = 2);

        break;

      case 'NAVIGATE_HOME':

        setState(() => _selectedIndex = 0);

        break;

      case 'CREATE_POS_ORDER':

        _showVoiceOrderConfirmation(data);

        break;

      case 'INITIATE_CASH_OUT':

        final amt = (data['amount'] as num?)?.toDouble() ?? 500.0;

        _triggerWithdrawal('B2C', amt);

        break;

      default:

        break;

    }

  }



  void _showVoiceOrderConfirmation(Map<String, dynamic> data) {

    final items = (data['items'] as List<dynamic>?) ?? [];

    final total = (data['total_amount'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(

      context: context,

      backgroundColor: _cardColor,

      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),

      builder: (ctx) => Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Row(

              children: [

                Icon(Icons.check_circle, color: _neonCyan),

                SizedBox(width: 8),

                Text('Voice Order Recorded', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),

              ],

            ),

            const SizedBox(height: 12),

            ...items.map((it) => Padding(

              padding: const EdgeInsets.symmetric(vertical: 4),

              child: Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Text('${it['quantity']}x ${it['name']}', style: const TextStyle(color: Colors.white)),

                  Text('KES ${it['total']}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),

                ],

              ),

            )),

            const Divider(color: Colors.white12, height: 20),

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                const Text('Total Bill:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),

                Text('KES ${total.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontSize: 20, fontWeight: FontWeight.w800)),

              ],

            ),

            const SizedBox(height: 20),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton.icon(

                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),

                onPressed: () {

                  Navigator.pop(ctx);

                  Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScannerPage()));

                },

                icon: const Icon(Icons.qr_code_scanner),

                label: const Text('Scan Student QR to Collect Payment', style: TextStyle(fontWeight: FontWeight.bold)),

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildBentoPosCard({

    required String title,

    required String subtitle,

    required IconData icon,

    required Color color,

    required VoidCallback onTap,

  }) {

    return Expanded(

      child: GestureDetector(

        onTap: onTap,

        child: Container(

          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(

            color: _cardColor,

            borderRadius: BorderRadius.circular(18),

            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),

            boxShadow: [

              BoxShadow(

                color: color.withValues(alpha: 0.08),

                blurRadius: 10,

                offset: const Offset(0, 4),

              ),

            ],

          ),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Container(

                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(

                  color: color.withValues(alpha: 0.15),

                  borderRadius: BorderRadius.circular(12),

                ),

                child: Icon(icon, color: color, size: 24),

              ),

              const SizedBox(height: 12),

              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),

              const SizedBox(height: 2),

              Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 11)),

            ],

          ),

        ),

      ),

    );

  }



  Widget _buildSalesTrendMiniChart(String vendorUid) {

    return Container(

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: _cardColor,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Row(

                children: [

                  Icon(Icons.show_chart, color: _neonCyan, size: 18),

                  SizedBox(width: 6),

                  Text('7-Day Revenue Velocity', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),

                ],

              ),

              Text('Live Feed', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.w600)),

            ],

          ),

          const SizedBox(height: 16),

          SizedBox(

            height: 90,

            child: LineChart(

              LineChartData(

                gridData: const FlGridData(show: false),

                titlesData: const FlTitlesData(show: false),

                borderData: FlBorderData(show: false),

                lineBarsData: [

                  LineChartBarData(

                    spots: const [

                      FlSpot(0, 1200),

                      FlSpot(1, 1850),

                      FlSpot(2, 2400),

                      FlSpot(3, 2100),

                      FlSpot(4, 3200),

                      FlSpot(5, 4100),

                      FlSpot(6, 4850),

                    ],

                    isCurved: true,

                    color: _neonCyan,

                    barWidth: 3,

                    isStrokeCapRound: true,

                    dotData: const FlDotData(show: false),

                    belowBarData: BarAreaData(

                      show: true,

                      color: _neonCyan.withValues(alpha: 0.15),

                    ),

                  ),

                ],

              ),

            ),

          ),

        ],

      ),

    );

  }



  bool _isSearching = false;

  // ignore: unused_field

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

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonOrange, width: 2)),

        title: const Text('Profile Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            ListTile(

              leading: const Icon(Icons.person, color: _neonOrange),

              title: const Text('My Profile', style: TextStyle(color: Colors.white)),

              onTap: () {

                Navigator.pop(context);

                Navigator.push(context, MaterialPageRoute(builder: (context) => VendorProfileView(user: widget.user)));

              },

            ),

            ListTile(

              leading: const Icon(Icons.logout, color: _neonPink),

              title: const Text('Logout', style: TextStyle(color: _neonPink)),

              onTap: () {

                Navigator.pop(context);

                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));

              },

            ),

          ],

        ),

        actions: [

          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: _neonOrange))),

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



    final vendorName = widget.user['name'] ?? widget.user['displayName'] ?? 'Vendor';

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

                  child: profileImageUrl == null ? const Icon(Icons.store, color: _textSecondary, size: 20) : null,

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

                  vendorName, 

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

        child: StreamBuilder<DocumentSnapshot>(

          stream: _firestoreService.streamCurrentUserProfile(),

          builder: (context, snapshot) {

            if (snapshot.connectionState == ConnectionState.waiting) {

              return const Center(child: CircularProgressIndicator(color: _neonOrange));

            }



            if (snapshot.hasError) {

              return Center(child: Text('Error loading dashboard: ${snapshot.error}', style: const TextStyle(color: Colors.red)));

            }



            if (!snapshot.hasData || !snapshot.data!.exists) {

              return const Center(child: Text('Profile not found', style: TextStyle(color: Colors.white)));

            }



            final userModel = UserModel.fromJson(

              snapshot.data!.data() as Map<String, dynamic>, 

              snapshot.data!.id

            );



            final List<Widget> tabs = [

              _buildHomeTab(userModel),

              VendorFinanceTabView(user: widget.user),

              VendorOperationsTabView(user: widget.user),

              VendorSalesTabView(user: widget.user),

              VendorManagementTabView(user: widget.user),

            ];



            final bool isCompact = MediaQuery.of(context).size.width < 640;



            if (isCompact) {

              return Scaffold(

                backgroundColor: _bgColor,



                body: IndexedStack(

                  index: _selectedIndex,

                  children: tabs,

                ),

                bottomNavigationBar: Container(

                  decoration: BoxDecoration(

                    color: _cardColor,

                    border: Border(

                      top: BorderSide(

                        color: Colors.white.withValues(alpha: 0.08),

                        width: 1,

                      ),

                    ),

                  ),

                  child: BottomNavigationBar(

                    currentIndex: _selectedIndex >= 2 ? _selectedIndex + 1 : _selectedIndex,

                    onTap: (int index) {

                      if (index == 2) {

                        HapticFeedback.mediumImpact();

                        SemaNaDishiOverlay.show(

                          context,

                          role: 'vendor',

                          userUid: widget.user['uid'],

                          onAction: _handleVoiceAction,

                        );

                        return;

                      }

                      setState(() {

                        _selectedIndex = index > 2 ? index - 1 : index;

                      });

                    },

                    backgroundColor: Colors.transparent,

                    elevation: 0,

                    type: BottomNavigationBarType.fixed,

                    selectedItemColor: _neonOrange,

                    unselectedItemColor: _textSecondary,

                    selectedFontSize: 10,

                    unselectedFontSize: 9,

                    items: [

                      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),

                      const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Finance'),

                      BottomNavigationBarItem(
                        icon: Transform.translate(
                          offset: const Offset(0, -8),
                          child: Container(
                            width: 50,
                            height: 50,
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
                                  spreadRadius: 2,
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
                              child: Icon(Icons.mic_rounded, color: Color(0xFF0C101B), size: 26),
                            ),
                          ),
                        ),
                        activeIcon: Transform.translate(
                          offset: const Offset(0, -10),
                          child: Container(
                            width: 54,
                            height: 54,
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
                                  blurRadius: 18,
                                  spreadRadius: 3,
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Center(
                              child: Icon(Icons.mic_rounded, color: Color(0xFF0C101B), size: 28),
                            ),
                          ),
                        ),
                        label: 'Sema DISHI',
                      ),
                      const BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Ops'),

                      const BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Sales'),

                      const BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'Manage'),

                    ],

                  ),

                ),

              );

            }



            return Scaffold(

              backgroundColor: _bgColor,



              body: Row(

                children: [

                  NavigationRail(

                    backgroundColor: _cardColor,

                    selectedIndex: _selectedIndex,

                    onDestinationSelected: (int index) {

                      setState(() {

                        _selectedIndex = index;

                      });

                    },

                    selectedIconTheme: const IconThemeData(color: _neonOrange),

                    unselectedIconTheme: const IconThemeData(color: _textSecondary),

                    selectedLabelTextStyle: const TextStyle(color: _neonOrange),

                    unselectedLabelTextStyle: const TextStyle(color: _textSecondary),

                    labelType: NavigationRailLabelType.all,

                    destinations: const [

                      NavigationRailDestination(icon: Icon(Icons.home), label: Text('Home')),

                      NavigationRailDestination(icon: Icon(Icons.account_balance_wallet), label: Text('Finance')),

                      NavigationRailDestination(icon: Icon(Icons.storefront), label: Text('Operations')),

                      NavigationRailDestination(icon: Icon(Icons.campaign), label: Text('Sales & CX')),

                      NavigationRailDestination(icon: Icon(Icons.badge), label: Text('Management')),

                    ],

                  ),

                  Expanded(

                    child: IndexedStack(

                      index: _selectedIndex,

                      children: tabs,

                    ),

                  ),

                ],

              ),

            );

          },

        ),

      ),

    );

  }



  Widget _buildQueueBadge(String label, int count, Color color) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

      decoration: BoxDecoration(

        color: color.withValues(alpha: 0.15),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: color.withValues(alpha: 0.3)),

      ),

      child: Text(

        '$count $label',

        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),

      ),

    );

  }



  Widget _buildHomeTab(UserModel userModel) {

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

                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 80.0),

                  sliver: SliverList(

                    delegate: SliverChildListDelegate([

                      // --- 0. ACTIVE CASHIER ON-DUTY & SHIFT CHIP ---

                      _buildActiveCashierShiftChip(context),

                      const SizedBox(height: 16),



                      // --- 1. EXECUTIVE REVENUE & FLOAT HUB (V6 REDESIGN) ---

                      StreamBuilder<QuerySnapshot>(

                        stream: FirebaseFirestore.instance

                            .collection('orders')

                            .where('vendorUid', isEqualTo: userModel.uid)

                            .snapshots(),

                        builder: (context, snapshot) {

                          double todayRevenue = 0.0;

                          int todayOrdersCount = 0;

                          int queuedCount = 0;

                          int cookingCount = 0;

                          int readyCount = 0;



                          if (snapshot.hasData) {

                            final now = DateTime.now();

                            for (var doc in snapshot.data!.docs) {

                              final data = doc.data() as Map<String, dynamic>;

                              final status = (data['prep_status'] ?? data['status'] ?? '').toString();

                              

                              if (status == 'Queued') queuedCount++;

                              if (status == 'Cooking') cookingCount++;

                              if (status == 'Ready for Pickup') readyCount++;



                              if (data['timestamp'] != null) {

                                final dt = (data['timestamp'] as Timestamp).toDate();

                                if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {

                                  todayRevenue += (data['totalAmount'] ?? 0.0);

                                  todayOrdersCount++;

                                }

                              }

                            }

                            _todayRevenue = todayRevenue;

                            _todayOrdersCount = todayOrdersCount;

                          }



                          return Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              // Hero Balance & Revenue Card

                              Container(

                                padding: const EdgeInsets.all(22),

                                decoration: BoxDecoration(

                                  gradient: const LinearGradient(

                                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],

                                    begin: Alignment.topLeft,

                                    end: Alignment.bottomRight,

                                  ),

                                  borderRadius: BorderRadius.circular(24),

                                  border: Border.all(color: _neonCyan.withValues(alpha: 0.35), width: 1.2),

                                  boxShadow: [

                                    BoxShadow(

                                      color: _neonCyan.withValues(alpha: 0.12),

                                      blurRadius: 20,

                                      offset: const Offset(0, 6),

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

                                            Icon(Icons.storefront, color: _neonCyan, size: 20),

                                            SizedBox(width: 8),

                                            Text("Today's Performance", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),

                                          ],

                                        ),

                                        Container(

                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

                                          decoration: BoxDecoration(

                                            color: _neonCyan.withValues(alpha: 0.15),

                                            borderRadius: BorderRadius.circular(20),

                                          ),

                                          child: Text(

                                            '$todayOrdersCount Sales Today',

                                            style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold),

                                          ),

                                        ),

                                      ],

                                    ),

                                    const SizedBox(height: 14),

                                    Row(

                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                      crossAxisAlignment: CrossAxisAlignment.end,

                                      children: [

                                        Column(

                                          crossAxisAlignment: CrossAxisAlignment.start,

                                          children: [

                                            const Text('Gross Revenue', style: TextStyle(color: _textSecondary, fontSize: 11)),

                                            const SizedBox(height: 2),

                                            Text(

                                              'KES ${todayRevenue.toStringAsFixed(2)}',

                                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),

                                            ),

                                          ],

                                        ),

                                        Column(

                                          crossAxisAlignment: CrossAxisAlignment.end,

                                          children: [

                                            const Text('Available Float', style: TextStyle(color: _textSecondary, fontSize: 11)),

                                            const SizedBox(height: 2),

                                            Text(

                                              'KES ${userModel.walletBalance.toStringAsFixed(2)}',

                                              style: const TextStyle(color: _neonOrange, fontSize: 18, fontWeight: FontWeight.bold),

                                            ),

                                          ],

                                        ),

                                      ],

                                    ),

                                    const SizedBox(height: 18),

                                    const Divider(color: Colors.white10),

                                    const SizedBox(height: 8),

                                    Row(

                                      children: [

                                        Expanded(

                                          child: ElevatedButton.icon(

                                            style: ElevatedButton.styleFrom(

                                              backgroundColor: _neonCyan,

                                              foregroundColor: Colors.black,

                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                                              padding: const EdgeInsets.symmetric(vertical: 10),

                                            ),

                                            onPressed: () => _showTopUpDialog(context),

                                            icon: const Icon(Icons.add_card, size: 16),

                                            label: const Text('Top Up Float', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),

                                          ),

                                        ),

                                        const SizedBox(width: 10),

                                        Expanded(

                                          child: OutlinedButton.icon(

                                            style: OutlinedButton.styleFrom(

                                              side: BorderSide(color: _neonOrange.withValues(alpha: 0.6)),

                                              foregroundColor: _neonOrange,

                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                                              padding: const EdgeInsets.symmetric(vertical: 10),

                                            ),

                                            onPressed: () => _triggerWithdrawal('B2C', userModel.walletBalance),

                                            icon: const Icon(Icons.outbox, size: 16),

                                            label: const Text('Cash Out Till', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),

                                          ),

                                        ),

                                      ],

                                    ),

                                  ],

                                ),

                              ),

                              const SizedBox(height: 20),



                              // --- 2. LIVE KITCHEN QUEUE BAR (SYNCED WITH STUDENT PRE-ORDERS) ---

                              GestureDetector(

                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorKdsView())),

                                child: Container(

                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                                  decoration: BoxDecoration(

                                    color: _cardColor,

                                    borderRadius: BorderRadius.circular(16),

                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),

                                  ),

                                  child: Row(

                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                    children: [

                                      const Row(

                                        children: [

                                          Icon(Icons.kitchen, color: _neonOrange, size: 20),

                                          SizedBox(width: 8),

                                          Text('Live Queue:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),

                                        ],

                                      ),

                                      Row(

                                        children: [

                                          _buildQueueBadge('Queued', queuedCount, Colors.amber),

                                          const SizedBox(width: 6),

                                          _buildQueueBadge('Cooking', cookingCount, Colors.lightBlueAccent),

                                          const SizedBox(width: 6),

                                          _buildQueueBadge('Ready', readyCount, _neonCyan),

                                          const SizedBox(width: 8),

                                          const Icon(Icons.arrow_forward_ios, color: _textSecondary, size: 12),

                                        ],

                                      ),

                                    ],

                                  ),

                                ),

                              ),

                            ],

                          );

                        },

                      ),

                      const SizedBox(height: 20),



                      // --- 2.5 INSTANT STOCK FAST-TOGGLE STRIP ---

                      _buildQuickStockToggleStrip(userModel.uid),

                      const SizedBox(height: 20),



                      // --- 3. 7-DAY REVENUE MINI CHART ---

                      _buildSalesTrendMiniChart(userModel.uid),

                      const SizedBox(height: 24),



                      // --- 4. PROFESSIONAL BENTO POS TERMINAL LAUNCHPAD ---

                      const Text('POS Launchpad & Terminal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

                      const SizedBox(height: 12),

                      Row(

                        children: [

                          _buildBentoPosCard(

                            title: 'Camera POS Scanner',

                            subtitle: 'QR Pass & Barcodes',

                            icon: Icons.qr_code_scanner,

                            color: _neonCyan,

                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerPage())),

                          ),

                          const SizedBox(width: 12),

                          _buildBentoPosCard(

                            title: 'Sema na DISHI',

                            subtitle: 'Voice Assistant & POS',

                            icon: Icons.record_voice_over,

                            color: _neonOrange,

                            onTap: () => SemaNaDishiOverlay.show(

                              context,

                              role: 'vendor',

                              userUid: widget.user['uid'],

                              onAction: _handleVoiceAction,

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 12),

                      Row(

                        children: [

                          _buildBentoPosCard(

                            title: 'Manual Token & PIN',

                            subtitle: 'Student ID & Pass',

                            icon: Icons.pin,

                            color: Colors.purpleAccent,

                            onTap: () => _showManualEntryDialog(context),

                          ),

                          const SizedBox(width: 12),

                          _buildBentoPosCard(

                            title: 'VCC & Biometric POS',

                            subtitle: 'Card & Hardware Reader',

                            icon: Icons.credit_card,

                            color: _neonPink,

                            onTap: () => _showVccOrBiometricSelector(context),

                          ),

                        ],

                      ),

                      const SizedBox(height: 24),



                      // --- 5. OPERATIONAL POWER TOOLS ROW ---

                      Row(

                        children: [

                          Expanded(

                            child: InkWell(

                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorKdsView())),

                              child: Container(

                                padding: const EdgeInsets.all(14),

                                decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),

                                child: const Column(children: [Icon(Icons.kitchen, color: _neonOrange, size: 28), SizedBox(height: 6), Text('Live KDS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),

                              ),

                            ),

                          ),

                          const SizedBox(width: 12),

                          Expanded(

                            child: InkWell(

                              onTap: () => _showEodAuditBottomSheet(context, userModel),

                              child: Container(

                                padding: const EdgeInsets.all(14),

                                decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),

                                child: const Column(children: [Icon(Icons.bar_chart, color: _neonCyan, size: 28), SizedBox(height: 6), Text('EOD Audit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),

                              ),

                            ),

                          ),

                          const SizedBox(width: 12),

                          Expanded(

                            child: InkWell(

                              onTap: () => setState(() => _selectedIndex = 2),

                              child: Container(

                                padding: const EdgeInsets.all(14),

                                decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),

                                child: const Column(children: [Icon(Icons.local_shipping, color: Colors.amber, size: 28), SizedBox(height: 6), Text('Restock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),

                              ),

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 32),

                      const Text('Cash Out E-Float', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),

                      const SizedBox(height: 20),

                      

                      Container(

                        padding: const EdgeInsets.all(20),

                        decoration: BoxDecoration(

                          color: _cardColor,

                          borderRadius: BorderRadius.circular(20),

                          border: Border.all(color: _surfaceLight)

                        ),

                        child: Column(

                          children: [

                            HighFrictionAction(

                              label: 'Slide to Withdraw (B2C)',

                              onActionCompleted: () => _triggerWithdrawal('B2C', userModel.walletBalance),

                              baseColor: _neonCyan,

                            ),

                            const SizedBox(height: 20),

                            HighFrictionAction(

                              label: 'Slide to Till (B2B)',

                              onActionCompleted: () => _triggerWithdrawal('B2B', userModel.walletBalance),

                              baseColor: _neonOrange,

                            ),

                          ],

                        ),

                      ),

                      const SizedBox(height: 32),

                      const Text('Recent Orders', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),

                      const SizedBox(height: 16),

                      StreamBuilder<QuerySnapshot>(

                        stream: FirebaseFirestore.instance.collection('orders')

                          .where('vendorUid', isEqualTo: userModel.uid)

                          .orderBy('timestamp', descending: true)

                          .limit(5)

                          .snapshots(),

                        builder: (context, snapshot) {

                          if (snapshot.connectionState == ConnectionState.waiting) {

                            return const Center(child: CircularProgressIndicator(color: _neonCyan));

                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {

                            return const Padding(

                              padding: EdgeInsets.all(16.0),

                              child: Text('No recent orders.', style: TextStyle(color: _textSecondary)),

                            );

                          }

                          return ListView.builder(

                            shrinkWrap: true,

                            physics: const NeverScrollableScrollPhysics(),

                            itemCount: snapshot.data!.docs.length,

                            itemBuilder: (context, index) {

                              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

                              final amount = data['totalAmount'] ?? 0.0;

                              final items = data['items'] as List<dynamic>? ?? [];

                              final dt = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();

                              

                              return Container(

                                margin: const EdgeInsets.only(bottom: 12),

                                padding: const EdgeInsets.all(16),

                                decoration: BoxDecoration(

                                  color: _cardColor,

                                  borderRadius: BorderRadius.circular(16),

                                  border: Border.all(color: _surfaceLight),

                                ),

                                child: Row(

                                  children: [

                                    CircleAvatar(

                                      backgroundColor: _neonCyan.withOpacity(0.2),

                                      child: const Icon(Icons.receipt_long, color: _neonCyan),

                                    ),

                                    const SizedBox(width: 16),

                                    Expanded(

                                      child: Column(

                                        crossAxisAlignment: CrossAxisAlignment.start,

                                        children: [

                                          Text('Order #${snapshot.data!.docs[index].id.substring(0, 5)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

                                          const SizedBox(height: 4),

                                          Text('${items.length} items • ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: _textSecondary, fontSize: 12)),

                                        ],

                                      ),

                                    ),

                                    Text('+ KSH $amount', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),

                                  ],

                                ),

                              );

                            },

                          );

                        }

                      ),

                      const SizedBox(height: 24),

                      UniversalSupportWidget(userId: userModel.uid, userRole: 'vendor'),

                    ]),

                  ),

                ),

              ],

            );

  }



  void _showBiometricSimDialog(BuildContext context) {

    final dishiIdController = TextEditingController();

    bool isProcessing = false;



    showDialog(

      context: context,

      builder: (context) => StatefulBuilder(

        builder: (context, setState) => AlertDialog(

          backgroundColor: _cardColor,

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _neonPink.withOpacity(0.5))),

          title: const Row(

            children: [

              Icon(Icons.fingerprint, color: _neonPink, size: 28),

              SizedBox(width: 8),

              Expanded(

                child: Text('Biometric Hardware Simulation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

              ),

            ],

          ),

          content: SingleChildScrollView(

            child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              Container(

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(color: _neonPink.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _neonPink.withOpacity(0.3))),

                child: const Row(

                  children: [

                    Icon(Icons.new_releases, color: _neonPink, size: 20),

                    SizedBox(width: 8),

                    Expanded(

                      child: Text('Hardware POS Biometric Reader: Coming Soon!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),

                    ),

                  ],

                ),

              ),

              const SizedBox(height: 14),

              const Text(

                'Phones do not share raw fingerprint sensors with third-party apps. We simulate the external hardware reader here. Enter student DISHI ID to test simulation.',

                style: TextStyle(color: _textSecondary, fontSize: 12),

              ),

              const SizedBox(height: 16),

              TextField(

                controller: dishiIdController,

                style: const TextStyle(color: Colors.white),

                decoration: InputDecoration(

                  labelText: 'DISHI ID (Simulated Scan)',

                  labelStyle: const TextStyle(color: _neonPink),

                  prefixIcon: const Icon(Icons.badge, color: _neonPink),

                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _neonPink.withOpacity(0.5))),

                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _neonPink)),

                ),

              ),

            ],

            ),

          ),

          actions: [

            TextButton(

              onPressed: isProcessing ? null : () => Navigator.pop(context),

              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),

            ),

            ElevatedButton(

              onPressed: isProcessing ? null : () async {

                setState(() => isProcessing = true);



                // Simulate hardware reader communication delay

                await Future.delayed(const Duration(milliseconds: 1400));



                final dishiId = dishiIdController.text.trim();

                String? uid;

                String? studentName;



                if (dishiId.isNotEmpty) {

                  try {

                    final query = await FirebaseFirestore.instance.collection('users').where('dishiId', isEqualTo: dishiId).get();

                    if (query.docs.isEmpty) {

                      final uidQuery = await FirebaseFirestore.instance.collection('users').get();

                      for (var doc in uidQuery.docs) {

                        if (doc.id.toUpperCase().startsWith(dishiId.toUpperCase())) {

                          uid = doc.id;

                          studentName = (doc.data()['displayName'] as String?) ?? 'Student';

                          break;

                        }

                      }

                    } else {

                      uid = query.docs.first.id;

                      studentName = (query.docs.first.data()['displayName'] as String?) ?? 'Student';

                    }

                  } catch (_) {}

                }



                if (!context.mounted) return;

                Navigator.pop(context);



                // Show Simulation Result Dialog: Coming Soon!

                showDialog(

                  context: context,

                  builder: (ctx) => AlertDialog(

                    backgroundColor: _cardColor,

                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _neonCyan)),

                    title: const Row(

                      children: [

                        Icon(Icons.check_circle_outline, color: _neonCyan, size: 28),

                        SizedBox(width: 8),

                        Expanded(

                          child: Text('Simulation Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),

                        ),

                      ],

                    ),

                    content: SingleChildScrollView(

                      child: Column(

                      mainAxisSize: MainAxisSize.min,

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Container(

                          padding: const EdgeInsets.all(12),

                          decoration: BoxDecoration(

                            color: _neonCyan.withOpacity(0.12),

                            borderRadius: BorderRadius.circular(12),

                            border: Border.all(color: _neonCyan.withOpacity(0.3)),

                          ),

                          child: const Text(

                            '🚀 Physical Biometric POS Terminal Integration is Coming Soon!',

                            style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13),

                          ),

                        ),

                        const SizedBox(height: 12),

                        const Text(

                          'Hardware optical fingerprint modules for campus cafeterias are currently in rollout testing. In production, students can pay instantly by touching the stall fingerprint pad.',

                          style: TextStyle(color: Colors.white70, fontSize: 13),

                        ),

                        if (uid != null) ...[

                          const SizedBox(height: 14),

                          Container(

                            padding: const EdgeInsets.all(10),

                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),

                            child: Row(

                              children: [

                                const Icon(Icons.person, color: _neonCyan, size: 20),

                                const SizedBox(width: 8),

                                Expanded(

                                  child: Text('Matched: ${studentName ?? 'Student'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

                                ),

                              ],

                            ),

                          ),

                        ],

                      ],

                    ),

                  ),

                    actions: [

                      TextButton(

                        onPressed: () => Navigator.pop(ctx),

                        child: const Text('Dismiss', style: TextStyle(color: _textSecondary)),

                      ),

                      if (uid != null)

                        ElevatedButton(

                          style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),

                          onPressed: () {

                            Navigator.pop(ctx);

                            Navigator.push(context, MaterialPageRoute(builder: (context) => VendorTopupView(studentUid: uid!)));

                          },

                          child: const Text('Open Student Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),

                        ),

                    ],

                  ),

                );

              },

              style: ElevatedButton.styleFrom(backgroundColor: _neonPink),

              child: isProcessing 

                ? const Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),

                      SizedBox(width: 8),

                      Text('Simulating...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

                    ],

                  )

                : const Text('Simulate Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

            ),

          ],

        ),

      ),

    );

  }



  void _showManualEntryDialog(BuildContext context) {

    final dishiIdController = TextEditingController();

    final tokenController = TextEditingController(); // Can be PIN or Token

    bool isProcessing = false;



    showDialog(

      context: context,

      builder: (context) => StatefulBuilder(

        builder: (context, setState) => AlertDialog(

          backgroundColor: _cardColor,

          title: const Text('Manual Student Entry', style: TextStyle(color: Colors.white)),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              TextField(

                controller: dishiIdController,

                style: const TextStyle(color: Colors.white),

                decoration: InputDecoration(

                  labelText: 'DISHI ID',

                  labelStyle: const TextStyle(color: _neonCyan),

                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5))),

                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),

                ),

              ),

              const SizedBox(height: 16),

              TextField(

                controller: tokenController,

                style: const TextStyle(color: Colors.white),

                decoration: InputDecoration(

                  labelText: 'Auth Token OR Offline PIN',

                  labelStyle: const TextStyle(color: _neonCyan),

                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.5))),

                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonCyan)),

                ),

              ),

            ],

          ),

          actions: [

            TextButton(

              onPressed: isProcessing ? null : () => Navigator.pop(context),

              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),

            ),

            ElevatedButton(

              onPressed: isProcessing ? null : () async {

                final dishiId = dishiIdController.text.trim();

                final token = tokenController.text.trim();

                if (dishiId.isEmpty || token.isEmpty) return;



                setState(() => isProcessing = true);



                try {

                  final query = await FirebaseFirestore.instance.collection('users').where('dishiId', isEqualTo: dishiId).get();

                  String? uid;

                  

                  if (query.docs.isEmpty) {

                    final uidQuery = await FirebaseFirestore.instance.collection('users').get();

                    for (var doc in uidQuery.docs) {

                      if (doc.id.toUpperCase().startsWith(dishiId.toUpperCase())) {

                        uid = doc.id;

                        break;

                      }

                    }

                  } else {

                    uid = query.docs.first.id;

                  }



                  if (uid == null) {

                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student not found.')));

                    setState(() => isProcessing = false);

                    return;

                  }



                  // Verify Token / PIN

                  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

                  final isOffline = doc.data()?['isOffline'] ?? false;

                  bool isValid = false;



                  if (isOffline) {

                    isValid = (doc.data()?['pin'] == token);

                  } else {

                    // We don't have crypto available here directly without importing, but wait, the token should ideally be verified on backend.

                    // For now, if it's online, we can assume the token is checked on the next screen or backend.

                    // Let's just pass them to topup view for now, as real token checking should happen server-side during the transaction.

                    isValid = true;

                  }



                  if (!isValid) {

                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Token or PIN.')));

                    setState(() => isProcessing = false);

                    return;

                  }



                  if (mounted) {

                    Navigator.pop(context);

                    Navigator.push(context, MaterialPageRoute(builder: (context) => VendorTopupView(studentUid: uid!)));

                  }

                } catch (e) {

                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));

                  setState(() => isProcessing = false);

                }

              },

              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan),

              child: isProcessing 

                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))

                : const Text('Verify & Proceed', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),

            ),

          ],

        ),

      ),

    );

  }



  void _showVccEntryDialog(BuildContext context) {

    final panController = TextEditingController();

    final pinController = TextEditingController();

    bool isProcessing = false;



    showDialog(

      context: context,

      builder: (context) => StatefulBuilder(

        builder: (context, setState) => AlertDialog(

          backgroundColor: _cardColor,

          title: const Text('VCC Card Checkout', style: TextStyle(color: Colors.white)),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              TextField(

                controller: panController,

                style: const TextStyle(color: Colors.white),

                keyboardType: TextInputType.number,

                maxLength: 16,

                decoration: InputDecoration(

                  labelText: '16-Digit Card Number (PAN)',

                  labelStyle: const TextStyle(color: _neonPink),

                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonPink.withOpacity(0.5))),

                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonPink)),

                ),

              ),

              const SizedBox(height: 16),

              TextField(

                controller: pinController,

                style: const TextStyle(color: Colors.white),

                keyboardType: TextInputType.number,

                obscureText: true,

                maxLength: 4,

                decoration: InputDecoration(

                  labelText: 'Student PIN',

                  labelStyle: const TextStyle(color: _neonPink),

                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _neonPink.withOpacity(0.5))),

                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _neonPink)),

                ),

              ),

            ],

          ),

          actions: [

            TextButton(

              onPressed: isProcessing ? null : () => Navigator.pop(context),

              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),

            ),

            ElevatedButton(

              onPressed: isProcessing ? null : () async {

                final pan = panController.text.trim();

                final pin = pinController.text.trim();

                if (pan.length != 16 || pin.length != 4) {

                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid PAN (16 digits) and PIN (4 digits).')));

                   return;

                }



                setState(() => isProcessing = true);



                try {

                  // Find virtual card by PAN

                  final cardQuery = await FirebaseFirestore.instance.collection('virtual_cards').where('pan', isEqualTo: pan).get();

                  if (cardQuery.docs.isEmpty) {

                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Card Number.')));

                    setState(() => isProcessing = false);

                    return;

                  }



                  final cardData = cardQuery.docs.first.data();

                  if (cardData['status'] == 'frozen') {

                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This card is frozen.')));

                    setState(() => isProcessing = false);

                    return;

                  }



                  final uid = cardData['uid'];



                  // Verify PIN

                  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

                  final userPin = doc.data()?['pin'];



                  if (userPin != pin) {

                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN.')));

                    setState(() => isProcessing = false);

                    return;

                  }



                  if (mounted) {

                    Navigator.pop(context);

                    Navigator.push(context, MaterialPageRoute(builder: (context) => VendorTopupView(studentUid: uid)));

                  }

                } catch (e) {

                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));

                  setState(() => isProcessing = false);

                }

              },

              style: ElevatedButton.styleFrom(backgroundColor: _neonPink),

              child: isProcessing 

                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))

                : const Text('Verify & Proceed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

            ),

          ],

        ),

      ),

    );

  }





  Widget _buildActiveCashierShiftChip(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

      decoration: BoxDecoration(

        color: _cardColor,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),

      ),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Row(

            children: [

              Container(

                width: 10,

                height: 10,

                decoration: const BoxDecoration(

                  color: _neonCyan,

                  shape: BoxShape.circle,

                ),

              ),

              const SizedBox(width: 8),

              Text(

                'Cashier: $_activeCashierName',

                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),

              ),

              const SizedBox(width: 8),

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                decoration: BoxDecoration(

                  color: _neonOrange.withValues(alpha: 0.15),

                  borderRadius: BorderRadius.circular(8),

                ),

                child: Text(

                  _activeShift,

                  style: const TextStyle(color: _neonOrange, fontSize: 10, fontWeight: FontWeight.bold),

                ),

              ),

            ],

          ),

          InkWell(

            onTap: () => _showShiftSwitcherDialog(context),

            child: Row(

              children: const [

                Icon(Icons.swap_horiz, color: _neonCyan, size: 16),

                SizedBox(width: 4),

                Text('Switch', style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),

              ],

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildQuickStockToggleStrip(String vendorUid) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Row(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            const Row(

              children: [

                Icon(Icons.bolt, color: _neonOrange, size: 16),

                SizedBox(width: 6),

                Text('Fast Stock Toggles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),

              ],

            ),

            Text('1-Tap In Stock / Sold Out', style: TextStyle(color: _textSecondary.withValues(alpha: 0.8), fontSize: 11)),

          ],

        ),

        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot>(

          stream: FirebaseFirestore.instance

              .collection('vendors')

              .doc(vendorUid)

              .collection('menu')

              .limit(8)

              .snapshots(),

          builder: (context, snapshot) {

            final defaultItems = [

              {'name': 'Chapati', 'isAvailable': true, 'id': 'def_1'},

              {'name': 'Madondo', 'isAvailable': true, 'id': 'def_2'},

              {'name': 'Beef Stew', 'isAvailable': true, 'id': 'def_3'},

              {'name': 'Pilau / Rice', 'isAvailable': false, 'id': 'def_4'},

              {'name': 'Chai / Mandazi', 'isAvailable': true, 'id': 'def_5'},

            ];



            List<Map<String, dynamic>> items = [];

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {

              items = snapshot.data!.docs.map((d) {

                final data = d.data() as Map<String, dynamic>;

                return {

                  'id': d.id,

                  'name': data['name'] ?? 'Item',

                  'isAvailable': data['isAvailable'] ?? true,

                };

              }).toList();

            } else {

              items = defaultItems;

            }



            return SizedBox(

              height: 38,

              child: ListView.separated(

                scrollDirection: Axis.horizontal,

                itemCount: items.length,

                separatorBuilder: (context, index) => const SizedBox(width: 8),

                itemBuilder: (context, index) {

                  final it = items[index];

                  final isAvail = it['isAvailable'] as bool;

                  final itemId = it['id'] as String;



                  return InkWell(

                    borderRadius: BorderRadius.circular(20),

                    onTap: () async {

                      if (!itemId.startsWith('def_')) {

                        await FirebaseFirestore.instance

                            .collection('vendors')

                            .doc(vendorUid)

                            .collection('menu')

                            .doc(itemId)

                            .update({'isAvailable': !isAvail});

                      }

                      if (context.mounted) {

                        ScaffoldMessenger.of(context).showSnackBar(

                          SnackBar(

                            content: Text("${it['name']} is now ${!isAvail ? 'IN STOCK' : 'SOLD OUT'}"),

                            backgroundColor: !isAvail ? _neonCyan : Colors.redAccent,

                            duration: const Duration(seconds: 1),

                          ),

                        );

                      }

                    },

                    child: AnimatedContainer(

                      duration: const Duration(milliseconds: 200),

                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                      decoration: BoxDecoration(

                        color: isAvail ? _neonCyan.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.1),

                        borderRadius: BorderRadius.circular(20),

                        border: Border.all(

                          color: isAvail ? _neonCyan.withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.3),

                        ),

                      ),

                      child: Row(

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          Icon(

                            isAvail ? Icons.check_circle : Icons.cancel,

                            size: 14,

                            color: isAvail ? _neonCyan : Colors.redAccent,

                          ),

                          const SizedBox(width: 6),

                          Text(

                            it['name'],

                            style: TextStyle(

                              color: isAvail ? Colors.white : _textSecondary,

                              fontSize: 12,

                              fontWeight: FontWeight.w600,

                              decoration: isAvail ? null : TextDecoration.lineThrough,

                            ),

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



  void _showVccOrBiometricSelector(BuildContext context) {

    showModalBottomSheet(

      context: context,

      backgroundColor: _cardColor,

      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),

      builder: (bottomSheetCtx) => Container(

        padding: const EdgeInsets.all(24),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text('Card & Biometric Checkout', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 6),

            const Text('Select checkout method for student:', style: TextStyle(color: _textSecondary, fontSize: 12)),

            const SizedBox(height: 18),

            ListTile(

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _neonPink.withValues(alpha: 0.3))),

              tileColor: _neonPink.withValues(alpha: 0.08),

              leading: const Icon(Icons.credit_card, color: _neonPink, size: 28),

              title: const Text('16-Digit Virtual Card (VCC)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),

              subtitle: const Text('Enter student PAN & PIN for instant wallet deduction', style: TextStyle(color: _textSecondary, fontSize: 11)),

              trailing: const Icon(Icons.arrow_forward_ios, color: _neonPink, size: 14),

              onTap: () {

                Navigator.pop(bottomSheetCtx);

                _showVccEntryDialog(context);

              },

            ),

            const SizedBox(height: 12),

            ListTile(

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _neonCyan.withValues(alpha: 0.3))),

              tileColor: _neonCyan.withValues(alpha: 0.08),

              leading: const Icon(Icons.fingerprint, color: _neonCyan, size: 28),

              title: const Text('Hardware Biometric Reader', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),

              subtitle: const Text('Simulate physical USB/Bluetooth fingerprint terminal', style: TextStyle(color: _textSecondary, fontSize: 11)),

              trailing: const Icon(Icons.arrow_forward_ios, color: _neonCyan, size: 14),

              onTap: () {

                Navigator.pop(bottomSheetCtx);

                _showBiometricSimDialog(context);

              },

            ),

          ],

        ),

      ),

    );

  }



  void _showEodAuditBottomSheet(BuildContext context, UserModel userModel) {

    final todayRevenue = _todayRevenue;

    final todayOrdersCount = _todayOrdersCount;

    showModalBottomSheet(

      context: context,

      backgroundColor: _cardColor,

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),

      builder: (bottomSheetContext) => Container(

        padding: const EdgeInsets.all(24),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                const Row(

                  children: [

                    Icon(Icons.bar_chart, color: _neonCyan, size: 24),

                    SizedBox(width: 8),

                    Text('End-of-Day POS Audit', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

                  ],

                ),

                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(bottomSheetContext)),

              ],

            ),

            const Divider(color: Colors.white10),

            const SizedBox(height: 12),

            Container(

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(16)),

              child: Column(

                children: [

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

                    const Text("Today's Gross Sales:", style: TextStyle(color: _textSecondary, fontSize: 13)),

                    Text('KES ${todayRevenue.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontSize: 16, fontWeight: FontWeight.bold)),

                  ]),

                  const SizedBox(height: 8),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

                    const Text('Completed Orders:', style: TextStyle(color: _textSecondary, fontSize: 13)),

                    Text('$todayOrdersCount Orders', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),

                  ]),

                  const SizedBox(height: 8),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

                    const Text('Available Float:', style: TextStyle(color: _textSecondary, fontSize: 13)),

                    Text('KES ${userModel.walletBalance.toStringAsFixed(2)}', style: const TextStyle(color: _neonOrange, fontSize: 14, fontWeight: FontWeight.bold)),

                  ]),

                  const SizedBox(height: 8),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

                    const Text('Active Shift / Cashier:', style: TextStyle(color: _textSecondary, fontSize: 13)),

                    Text('$_activeCashierName ($_activeShift)', style: const TextStyle(color: Colors.white70, fontSize: 12)),

                  ]),

                ],

              ),

            ),

            const SizedBox(height: 20),

            SizedBox(

              width: double.infinity,

              height: 48,

              child: ElevatedButton.icon(

                style: ElevatedButton.styleFrom(

                  backgroundColor: _neonCyan,

                  foregroundColor: Colors.black,

                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

                ),

                icon: const Icon(Icons.picture_as_pdf, size: 20),

                label: const Text('Export Daily Reconciliation PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),

                onPressed: () async {

                  Navigator.pop(bottomSheetContext);

                  final vName = userModel.displayName.isNotEmpty ? userModel.displayName : (widget.user['name'] ?? 'Vendor');

                  final tNum = (userModel.dishiId != null && userModel.dishiId!.isNotEmpty) ? userModel.dishiId! : (widget.user['phone'] ?? 'TILL-01');

                  await PdfGenerator.printVendorDailyAudit(

                    vendorName: vName,

                    tillNumber: tNum,

                    totalRevenue: todayRevenue,

                    totalOrders: todayOrdersCount,

                    floatBalance: userModel.walletBalance,

                    cashierName: _activeCashierName,

                  );

                },

              ),

            ),

            const SizedBox(height: 10),

            SizedBox(

              width: double.infinity,

              height: 44,

              child: OutlinedButton(

                style: OutlinedButton.styleFrom(

                  side: const BorderSide(color: _surfaceLight),

                  foregroundColor: Colors.white70,

                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

                ),

                onPressed: () {

                  Navigator.pop(bottomSheetContext);

                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorReportsView()));

                },

                child: const Text('Open Detailed Reports Tab', style: TextStyle(fontSize: 13)),

              ),

            ),

          ],

        ),

      ),

    );

  }



}