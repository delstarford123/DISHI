import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/api_config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/high_friction_action.dart';
import 'deliv_active_route_view.dart';
import 'driver_scanner_view.dart';
import 'deliv_heatmap_view.dart';
import 'deliv_analytics_view.dart';
import '../../../shared/presentation/profile_hub_sheet.dart';

// -- MODERN DRIVER PALETTE --
const Color _bgColor = Color(0xFF080C14);
const Color _cardColor = Color(0xFF101726);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF00FFD1);
const Color _neonGreen = Color(0xFF10B981);
const Color _neonBlue = Color(0xFF38BDF8);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

final List<Map<String, dynamic>> gigCategories = [
  {'name': 'All', 'icon': '🎯', 'color': Colors.white},
  {'name': 'Food Delivery', 'icon': '🍔', 'color': Colors.orange},
  {'name': 'Grocery Run', 'icon': '🛒', 'color': Colors.green},
  {'name': 'Parcel Pickup', 'icon': '📦', 'color': Colors.blue},
  {'name': 'Laundry Pickup & Drop', 'icon': '🧺', 'color': Colors.purple},
  {'name': 'Printing & Photocopy', 'icon': '🖨️', 'color': Colors.cyan},
  {'name': 'Library Book Return', 'icon': '📚', 'color': Colors.brown},
  {'name': 'Campus Errand', 'icon': '🏃', 'color': Colors.yellow},
  {'name': 'Boda-Boda Ride', 'icon': '🛵', 'color': Colors.redAccent},
  {'name': 'Pharmacy Run', 'icon': '💊', 'color': Colors.red},
  {'name': 'Market Run', 'icon': '🏪', 'color': Colors.lime},
  {'name': 'Custom Gig', 'icon': '✨', 'color': _neonCyan},
];

class DelivDriverDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const DelivDriverDashboard({super.key, required this.user});

  @override
  State<DelivDriverDashboard> createState() => _DelivDriverDashboardState();
}

class _DelivDriverDashboardState extends State<DelivDriverDashboard> with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  double _todayEarnings = 0.0;
  int _todayTripsCount = 0;
  double _weekEarnings = 0.0;
  int _weekTripsCount = 0;
  double _pendingCashout = 0.0;
  double _driverRating = 5.0;
  int _totalRuns = 0;
  String _driverTier = 'Rookie Courier';
  Map<int, int> _weeklyDayCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
  String _selectedCategory = 'All';
  String _vehicleMode = 'boda'; // 'boda', 'bike', 'foot'
  bool _isCashingOut = false;

  // Student memory cache: studentUid -> student profile map
  final Map<String, Map<String, dynamic>> _rememberedStudents = {};
  final List<Map<String, dynamic>> _recentStudentsList = [];

  late AnimationController _pulseController;
  StreamSubscription? _requestsSub;
  StreamSubscription? _driverSub;
  StreamSubscription? _userSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _syncDriverStatus();
    _listenToLiveDriverEarnings();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _requestsSub?.cancel();
    _driverSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _syncDriverStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // 1. Listen to drivers/{uid} in real-time
      _driverSub?.cancel();
      _driverSub = FirebaseFirestore.instance.collection('drivers').doc(uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          setState(() {
            _isOnline = data['isOnline'] == true;
            _vehicleMode = data['vehicleMode'] ?? 'boda';
            if (data['rating'] != null) {
              _driverRating = (data['rating'] as num).toDouble();
            }
          });
          if (_isOnline) {
            LocationService.startBroadcasting(uid);
          }
        }
      });

      // 2. Listen to users/{uid} for real wallet balance and rating
      _userSub?.cancel();
      _userSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          setState(() {
            if (data['walletBalance'] != null) {
              _pendingCashout = (data['walletBalance'] as num).toDouble();
            } else if (data['balance'] != null) {
              _pendingCashout = (data['balance'] as num).toDouble();
            }
            if (data['driverRating'] != null) {
              _driverRating = (data['driverRating'] as num).toDouble();
            } else if (data['rating'] != null && _driverRating == 5.0) {
              _driverRating = (data['rating'] as num).toDouble();
            }
          });
        }
      });
    }
  }

  void _listenToLiveDriverEarnings() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Listen to real completed requests for this driver
    _requestsSub?.cancel();
    _requestsSub = FirebaseFirestore.instance
        .collection('deliv_requests')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      double todayEarned = 0.0;
      int todayCount = 0;
      double weekEarned = 0.0;
      int weekCount = 0;
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      final Map<int, int> dayCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

      for (var doc in snap.docs) {
        final data = doc.data();
        final rawPay = data['pay']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0';
        final payVal = double.tryParse(rawPay) ?? 0.0;

        DateTime? completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        completedAt ??= (data['timestamp'] as Timestamp?)?.toDate();
        completedAt ??= (data['createdAt'] as Timestamp?)?.toDate();
        completedAt ??= now;

        if (completedAt.year == now.year &&
            completedAt.month == now.month &&
            completedAt.day == now.day) {
          todayEarned += payVal;
          todayCount++;
        }

        if (completedAt.isAfter(oneWeekAgo)) {
          weekEarned += payVal;
          weekCount++;
          final weekday = completedAt.weekday;
          dayCounts[weekday] = (dayCounts[weekday] ?? 0) + 1;
        }

        final studentUid = (data['postedBy'] ?? data['userId'] ?? data['studentId'] ?? data['requester_id'] ?? '').toString();
        if (studentUid.isNotEmpty && !_rememberedStudents.containsKey(studentUid)) {
          _preloadStudentProfile(studentUid);
        }
      }

      final totalRuns = snap.docs.length;
      String tier = 'Rookie Courier';
      if (totalRuns >= 50) {
        tier = 'Gold Elite Tier';
      } else if (totalRuns >= 20) {
        tier = 'Silver Pro Tier';
      } else if (totalRuns >= 5) {
        tier = 'Active Courier';
      }

      setState(() {
        _todayEarnings = todayEarned;
        _todayTripsCount = todayCount;
        _weekEarnings = weekEarned;
        _weekTripsCount = weekCount;
        _totalRuns = totalRuns;
        _driverTier = tier;
        _weeklyDayCounts = dayCounts;
        if (_pendingCashout == 0.0 && weekEarned > 0.0) {
          _pendingCashout = weekEarned;
        }
      });
    });
  }

  Future<void> _preloadStudentProfile(String uid) async {
    if (uid.isEmpty || _rememberedStudents.containsKey(uid)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null && mounted) {
        final d = doc.data()!;
        final profile = {
          'uid': uid,
          'name': d['displayName'] ?? d['name'] ?? d['firstName'] ?? 'Campus Student',
          'photoUrl': d['photoUrl'] ?? d['profileImageUrl'] ?? d['studentImageUrl'],
          'phoneNumber': d['phoneNumber'] ?? d['phone'] ?? '',
          'campus': d['campus'] ?? 'Main Campus',
          'course': d['course'] ?? d['bio'] ?? '',
          'dishiId': d['dishiId'] ?? '',
          'rating': (d['rating'] as num?)?.toDouble() ?? 5.0,
        };
        setState(() {
          _rememberedStudents[uid] = profile;
          if (!_recentStudentsList.any((s) => s['uid'] == uid)) {
            _recentStudentsList.insert(0, profile);
          }
        });
      }
    } catch (_) {}
  }

  void _showStudentProfileModal(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final phone = student['phoneNumber'] ?? '';
        final cleanPhone = phone.toString().replaceAll(RegExp(r'[^0-9]'), '');
        final photoUrl = student['photoUrl'];
        final hasPhoto = photoUrl != null && photoUrl.toString().isNotEmpty;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _neonCyan, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _neonCyan.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: _surfaceLight,
                  backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                  child: !hasPhoto
                      ? Text(
                          ((student['name'] ?? 'S') as String)[0].toUpperCase(),
                          style: const TextStyle(color: _neonCyan, fontSize: 30, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      student['name'] ?? 'Campus Student',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: _neonCyan, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${student['campus'] ?? 'Main Campus'} • Verified Client',
                style: const TextStyle(color: _textSecondary, fontSize: 13),
              ),
              if ((student['course'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  student['course'],
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${((student['rating'] ?? 5.0) as num).toStringAsFixed(1)} Rating',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(height: 24, width: 1, color: Colors.white12),
                    Column(
                      children: [
                        const Icon(Icons.badge_rounded, color: _neonGreen, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          student['dishiId']?.isNotEmpty == true ? student['dishiId'] : 'Verified',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(height: 24, width: 1, color: Colors.white12),
                    const Column(
                      children: [
                        Icon(Icons.shield_outlined, color: _neonBlue, size: 20),
                        SizedBox(height: 4),
                        Text(
                          'DISHI Client',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: const Text('Call Student', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      onPressed: phone.toString().isEmpty
                          ? null
                          : () => launchUrl(Uri.parse('tel:$phone')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      onPressed: cleanPhone.isEmpty
                          ? null
                          : () => launchUrl(Uri.parse('https://wa.me/$cleanPhone?text=Hello%20${Uri.encodeComponent(student['name'] ?? 'Student')}%2C%20this%20is%20your%20DISHI%20DeLiv%20courier!')),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Future<void> _toggleStatus(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set(
        {
          'isOnline': value,
          'vehicleMode': _vehicleMode,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (value) {
        await LocationService.startBroadcasting(uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🟢 You are ONLINE. Live orders and GPS tracking enabled.'),
              backgroundColor: _neonGreen,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await LocationService.stopBroadcasting();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚪ You are OFFLINE. Shift paused.'),
              backgroundColor: Colors.white24,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
    setState(() => _isOnline = value);
  }

  Future<void> _setVehicleMode(String mode) async {
    setState(() => _vehicleMode = mode);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set(
        {'vehicleMode': mode},
        SetOptions(merge: true),
      );
    }
  }

  // ── CASH OUT SHEET ───────────────────────────────────────────────
  void _showCashOutModal() {
    final defaultPhone = widget.user['phoneNumber'] ?? '0700000000';
    final amountController = TextEditingController(text: _pendingCashout.toStringAsFixed(0));
    final phoneController = TextEditingController(text: defaultPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 20,
              right: 20,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _neonGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: _neonGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Instant M-PESA Payout',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Available Balance:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                          Text(
                            'KES ${_pendingCashout.toStringAsFixed(0)}',
                            style: const TextStyle(color: _neonGreen, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Payout Channel:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                          Text('Instant Safaricom M-PESA B2C', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Transfer Fee:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                          Text('0 KES (Free for DISHI Riders)', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Withdraw Amount (KES)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Icon(Icons.attach_money, color: _neonGreen),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Payout Destination (M-PESA Phone Number)',
                    hintText: 'e.g. 0712345678 or 254712345678',
                    labelStyle: const TextStyle(color: _textSecondary),
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Icon(Icons.phone_iphone_rounded, color: _neonCyan),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isCashingOut
                        ? null
                        : () async {
                            final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                            if (amt <= 0 || amt > _pendingCashout) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid withdrawal amount.')),
                              );
                              return;
                            }
                            final enteredPhone = phoneController.text.trim();
                            final digitsOnly = enteredPhone.replaceAll(RegExp(r'[^0-9]'), '');
                            if (digitsOnly.length < 9) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid M-PESA phone number.')),
                              );
                              return;
                            }
                            setModalState(() => _isCashingOut = true);
                            Navigator.pop(ctx);
                            await _processMpesaCashout(amt, enteredPhone);
                          },
                    child: _isCashingOut
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            'Withdraw Now via M-PESA',
                            style: TextStyle(color: Color(0xFF080C14), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _processMpesaCashout(double amount, String phone) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isCashingOut = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mpesa/driver_withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driver_id': uid,
          'amount': amount,
          'method': 'M-PESA Number',
          'destination': phone,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ KES ${amount.toStringAsFixed(0)} sent to $phone via M-PESA!'),
              backgroundColor: _neonGreen,
            ),
          );
          setState(() {
            _pendingCashout = (_pendingCashout - amount).clamp(0.0, double.infinity);
          });
        }
      } else {
        String errMsg = 'Cash out failed';
        try {
          final resData = jsonDecode(response.body);
          if (resData is Map && resData.containsKey('error')) {
            errMsg = resData['error'].toString();
          }
        } catch (_) {}
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Withdrawal notice: $errMsg')));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timed out. Please verify your connection.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isCashingOut = false);
    }
  }

  // ── ACCEPT GIG ───────────────────────────────────────────────────
  Future<void> _acceptGig(String gigId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.user['uid'];
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in as an authenticated courier to accept gigs.')),
        );
      }
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('deliv_requests').doc(gigId).update({
        'status': 'accepted',
        'stage': 'en_route_pickup',
        'driverId': uid,
        'driverName': widget.user['displayName'] ?? widget.user['name'] ?? 'Courier',
        'driverPhone': widget.user['phoneNumber'] ?? '',
        'driverVehicle': _vehicleMode,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gig Accepted! Launching Google Maps Turn-by-Turn...'),
            backgroundColor: _neonCyan,
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DelivActiveRouteView(rideId: gigId),
          ),
        );
      }
    } catch (e) {
      // Backend Fallback (Admin SDK bypass) if client rules block or network error occurs
      bool acceptedViaBackend = false;
      try {
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/v2/deliv/requests/accept'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'request_id': gigId,
            'driver_id': uid,
            'driver_name': widget.user['displayName'] ?? widget.user['name'] ?? 'Courier',
            'driver_phone': widget.user['phoneNumber'] ?? '',
            'driver_vehicle': _vehicleMode,
            'eta': '10 mins',
          }),
        ).timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          acceptedViaBackend = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gig Accepted! Launching Google Maps Turn-by-Turn...'),
                backgroundColor: _neonCyan,
              ),
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DelivActiveRouteView(rideId: gigId),
              ),
            );
          }
        }
      } catch (_) {}

      if (!acceptedViaBackend && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
      }
    }
  }

  Future<void> _rejectGig(String gigId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('deliv_requests').doc(gigId).update({
          'rejectedBy': FieldValue.arrayUnion([uid]),
        });
      }
    } catch (_) {}
  }

  // ── POST GIG / ERRAND SHEET ──────────────────────────────────────
  void _showPostGigSheet() {
    String selectedType = 'Food Delivery';
    final payController = TextEditingController(text: '150');
    final pickupController = TextEditingController(text: 'Main Cafeteria');
    final dropoffController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Broadcast Campus Errand', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  dropdownColor: _surfaceLight,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Errand Type',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: gigCategories.where((g) => g['name'] != 'All').map((g) {
                    return DropdownMenuItem<String>(
                      value: g['name'],
                      child: Row(
                        children: [
                          Text(g['icon'], style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(g['name']),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setSheetState(() => selectedType = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pickupController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Pickup Location',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dropoffController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Dropoff Hostel / Hall',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: payController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Courier Pay (KES)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        await FirebaseFirestore.instance.collection('deliv_requests').add({
                          'type': selectedType,
                          'pay': 'KES ${payController.text.trim()}',
                          'pickup': pickupController.text.trim(),
                          'dropoff': dropoffController.text.trim(),
                          'status': 'open',
                          'postedBy': uid,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (mounted) {
                          nav.pop();
                          messenger.showSnackBar(const SnackBar(content: Text('Errand Broadcasted!')));
                        }
                      }
                    },
                    child: const Text('Broadcast Gig to Fleet', style: TextStyle(color: Color(0xFF080C14), fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── EMERGENCY SOS ────────────────────────────────────────────────
  void _triggerDriverEmergencySOS() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _neonRed, size: 26),
            SizedBox(width: 8),
            Text('Roadside Emergency SOS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Activate high-priority alert to Campus Security & dispatch nearest fellow DISHI riders to your exact GPS coordinates?',
          style: TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance.collection('sos_alerts').add({
                  'studentUid': uid,
                  'userRole': 'driver',
                  'studentName': widget.user['displayName'] ?? 'Courier Rider',
                  'emergencyType': 'driver_roadside',
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'active',
                });
                await LocationService.startBroadcasting(uid, sosMode: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🚨 SOS Broadcast Active! Campus security alerted.'),
                      backgroundColor: _neonRed,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
            child: const Text('BROADCAST SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] ?? widget.user['displayName'] ?? 'Courier';
    final firstName = name.split(' ')[0];

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── EXECUTIVE DRIVER TOP HEADER ───────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => ProfileHubSheet(user: widget.user),
                            );
                          },
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: _surfaceLight,
                                backgroundImage: widget.user['photoUrl'] != null
                                    ? NetworkImage(widget.user['photoUrl'])
                                    : null,
                                child: widget.user['photoUrl'] == null
                                    ? const Icon(Icons.person, color: Colors.white70, size: 28)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: _isOnline ? _neonGreen : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _bgColor, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getGreeting()} $firstName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '★ ${_driverRating.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      color: Color(0xFFFBBF24),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '• Verified • $_driverTier',
                                      style: const TextStyle(color: _textSecondary, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Master Online / Offline Switch Pill
                        GestureDetector(
                          onTap: () => _toggleStatus(!_isOnline),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? _neonGreen.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _isOnline ? _neonGreen : Colors.white24,
                                width: 1.5,
                              ),
                              boxShadow: _isOnline
                                  ? [
                                      BoxShadow(
                                        color: _neonGreen.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isOnline)
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) => Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _neonGreen,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _neonGreen.withValues(alpha: 0.8),
                                            blurRadius: 6 * _pulseController.value,
                                            spreadRadius: 2 * _pulseController.value,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.white38,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  _isOnline ? 'ONLINE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: _isOnline ? _neonGreen : Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── VEHICLE MODALITY SELECTOR ─────────────────────
                    Row(
                      children: [
                        _buildVehiclePill('boda', '🛵 Boda-Boda', 'Speed: 40 km/h'),
                        const SizedBox(width: 8),
                        _buildVehiclePill('bike', '🚲 Bicycle', 'Eco • 20 km/h'),
                        const SizedBox(width: 8),
                        _buildVehiclePill('foot', '🏃 Foot Runner', '<1 km radius'),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── LIVE EARNINGS TELEMETRY STRIP ─────────────────
                    Row(
                      children: [
                        _buildEarningsCard('Today', 'KES ${_todayEarnings.toStringAsFixed(0)}', _neonGreen, '$_todayTripsCount runs'),
                        const SizedBox(width: 10),
                        _buildEarningsCard('Week Total', 'KES ${_weekEarnings.toStringAsFixed(0)}', _neonBlue, '$_weekTripsCount runs'),
                        const SizedBox(width: 10),
                        _buildEarningsCard('Balance', 'KES ${_pendingCashout.toStringAsFixed(0)}', _neonCyan, 'Ready'),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Cash Out Action Slider / Bar
                    HighFrictionAction(
                      label: 'Hold to Cash Out to M-PESA',
                      baseColor: _neonGreen,
                      onActionCompleted: _showCashOutModal,
                    ),

                    const SizedBox(height: 20),

                    // ── QUICK COURIER TOOLS ROW ───────────────────────
                    Row(
                      children: [
                        _buildQuickToolButton(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Scan Ticket',
                          color: _neonCyan,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DriverScannerView()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickToolButton(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Surge Heatmap',
                          color: _neonOrange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DelivHeatmapView()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickToolButton(
                          icon: Icons.bar_chart_rounded,
                          label: 'Analytics',
                          color: _neonBlue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DelivAnalyticsView(
                                weeklyEarnings: _weekEarnings,
                                completedTrips: _weekTripsCount,
                                todayEarnings: _todayEarnings,
                                customerRating: _driverRating,
                                dailyTrips: _weeklyDayCounts,
                                totalCompletedRuns: _totalRuns,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickToolButton(
                          icon: Icons.emergency_rounded,
                          label: 'Road SOS',
                          color: _neonRed,
                          onTap: _triggerDriverEmergencySOS,
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ── ACTIVE DELIVERY IN PROGRESS (HUD) ─────────────
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('deliv_requests')
                          .where('driverId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .where('status', whereIn: ['accepted', 'picking_up', 'in_transit', 'arrived'])
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final activeDoc = snapshot.data!.docs.first;
                        final activeData = activeDoc.data() as Map<String, dynamic>;
                        final catInfo = gigCategories.firstWhere(
                          (g) => g['name'] == activeData['type'],
                          orElse: () => gigCategories.last,
                        );

                        return _buildActiveMissionHUD(activeDoc.id, activeData, catInfo);
                      },
                    ),

                    // ── REMEMBERED CAMPUS STUDENTS & CLIENTS ─────────
                    if (_recentStudentsList.isNotEmpty) ...[
                      _buildRememberedStudentsSection(),
                      const SizedBox(height: 18),
                    ],

                    // ── AVAILABLE GIGS HEADER ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Available Gigs Feed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showPostGigSheet,
                          icon: const Icon(Icons.add, size: 16, color: _neonCyan),
                          label: const Text(
                            'Post Errand',
                            style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Categories Scroll
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: gigCategories.map((g) {
                          final isSelected = _selectedCategory == g['name'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Row(
                                children: [
                                  Text(g['icon']),
                                  const SizedBox(width: 6),
                                  Text(
                                    g['name'],
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF080C14) : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: _neonCyan,
                              backgroundColor: _cardColor,
                              side: BorderSide(
                                color: isSelected ? _neonCyan : Colors.white10,
                              ),
                              onSelected: (_) => setState(() => _selectedCategory = g['name']),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── REAL-TIME GIGS STREAM ─────────────────────────
                    if (!_isOnline)
                      _buildOfflinePrompt()
                    else
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('deliv_requests')
                            .where('status', isEqualTo: 'open')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _neonRed)),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator(color: _neonCyan));
                          }

                          var docs = snapshot.data!.docs.toList();
                          docs.sort((a, b) {
                            final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                            final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                            if (aTime == null || bTime == null) return 0;
                            return bTime.compareTo(aTime);
                          });

                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            docs = docs.where((d) {
                              final data = d.data() as Map<String, dynamic>;
                              final rejectedBy = List.from(data['rejectedBy'] ?? []);
                              return !rejectedBy.contains(uid);
                            }).toList();
                          }

                          if (_selectedCategory != 'All') {
                            docs = docs.where((d) {
                              final data = d.data() as Map<String, dynamic>;
                              return data['type'] == _selectedCategory;
                            }).toList();
                          }

                          // Preload student profiles for all available open gigs
                          for (final d in docs) {
                            final gData = d.data() as Map<String, dynamic>;
                            final sUid = (gData['postedBy'] ?? gData['userId'] ?? gData['studentId'] ?? gData['requester_id'] ?? '').toString();
                            if (sUid.isNotEmpty && !_rememberedStudents.containsKey(sUid)) {
                              _preloadStudentProfile(sUid);
                            }
                          }

                          if (docs.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.radar_rounded, size: 48, color: _textSecondary),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Scanning Campus for Orders...',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Orders from cafeterias, hostels, and students will appear here instantly.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: _textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final catInfo = gigCategories.firstWhere(
                                (g) => g['name'] == data['type'],
                                orElse: () => gigCategories.last,
                              );
                              return _buildGigOrderCard(doc.id, data, catInfo);
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── VEHICLE PILL ──────────────────────────────────────────────────
  Widget _buildVehiclePill(String mode, String title, String speed) {
    final bool isSelected = _vehicleMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setVehicleMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? _neonCyan.withValues(alpha: 0.15) : _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _neonCyan : Colors.white12,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? _neonCyan : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                speed,
                style: TextStyle(
                  color: isSelected ? _neonCyan.withValues(alpha: 0.8) : _textSecondary,
                  fontSize: 10,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── EARNINGS TELEMETRY CARD ───────────────────────────────────────
  Widget _buildEarningsCard(String title, String amount, Color color, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: _textSecondary, fontSize: 11.5)),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              amount,
              style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(sub, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── QUICK COURIER TOOL BUTTON ─────────────────────────────────────
  Widget _buildQuickToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ACTIVE MISSION CONTROL HUD ────────────────────────────────────
  Widget _buildActiveMissionHUD(String docId, Map<String, dynamic> data, Map<String, dynamic> catInfo) {
    final stage = data['stage'] ?? 'en_route_pickup';
    final customerPhone = (data['customerPhone'] ?? data['phone'] ?? '').toString();
    final studentUid = (data['postedBy'] ?? data['userId'] ?? data['studentId'] ?? data['requester_id'] ?? '').toString();
    if (studentUid.isNotEmpty && !_rememberedStudents.containsKey(studentUid)) {
      _preloadStudentProfile(studentUid);
    }
    final student = _rememberedStudents[studentUid];

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _neonCyan.withValues(alpha: 0.18),
            const Color(0xFF101726),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonCyan, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _neonCyan.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _neonCyan,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions_bike, size: 14, color: Colors.black),
                    SizedBox(width: 5),
                    Text(
                      'ACTIVE COURIER MISSION',
                      style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                data['pay']?.toString() ?? 'KES -',
                style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(catInfo['icon'], style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['type'] ?? 'Delivery Run',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (customerPhone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone_in_talk, color: _neonGreen, size: 20),
                  onPressed: () => launchUrl(Uri.parse('tel:$customerPhone')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Student Profile Card in Mission HUD
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (student != null) _showStudentProfileModal(student);
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: _neonCyan.withValues(alpha: 0.2),
                    backgroundImage: (student?['photoUrl'] != null && student!['photoUrl'].toString().isNotEmpty)
                        ? NetworkImage(student['photoUrl'])
                        : null,
                    child: (student?['photoUrl'] == null || student!['photoUrl'].toString().isEmpty)
                        ? Text(
                            ((student?['name'] ?? 'S') as String)[0].toUpperCase(),
                            style: const TextStyle(color: _neonCyan, fontSize: 16, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (student != null) _showStudentProfileModal(student);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                student?['name'] ?? 'Campus Student Requester',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: _neonCyan, size: 14),
                          ],
                        ),
                        Text(
                          student?['campus'] ?? 'Verified Campus Student',
                          style: const TextStyle(color: _textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                if (customerPhone.isNotEmpty || (student?['phoneNumber'] ?? '').toString().isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: _neonGreen, size: 20),
                    onPressed: () {
                      final p = customerPhone.isNotEmpty ? customerPhone : (student?['phoneNumber'] ?? '').toString();
                      launchUrl(Uri.parse('tel:$p'));
                    },
                    tooltip: 'Call Student',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: _neonCyan, size: 20),
                    onPressed: () {
                      final p = customerPhone.isNotEmpty ? customerPhone : (student?['phoneNumber'] ?? '').toString();
                      final clean = p.replaceAll(RegExp(r'[^0-9]'), '');
                      final name = student?['name'] ?? 'Student';
                      launchUrl(Uri.parse('https://wa.me/$clean?text=Hello%20${Uri.encodeComponent(name)}%2C%20this%20is%20your%20DISHI%20DeLiv%20courier!'));
                    },
                    tooltip: 'WhatsApp Student',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.storefront, size: 15, color: _textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Pickup: ${data['pickup'] ?? 'Campus Store'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 15, color: _neonRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Destination: ${data['dropoff'] ?? 'Hostel'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Navigation Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.map_rounded, size: 20),
              label: const Text(
                'Open Google Maps Turn-by-Turn GPS',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DelivActiveRouteView(rideId: docId)),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Quick Stage Progression Action
          Row(
            children: [
              if (stage == 'en_route_pickup')
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _neonGreen,
                      side: const BorderSide(color: _neonGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('deliv_requests').doc(docId).update({
                        'stage': 'at_pickup',
                      });
                    },
                    child: const Text('Mark Arrived at Vendor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              else if (stage == 'at_pickup')
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _neonOrange,
                      side: const BorderSide(color: _neonOrange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('deliv_requests').doc(docId).update({
                        'stage': 'in_transit',
                      });
                    },
                    child: const Text('Package Picked Up • Start Delivery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              else if (stage == 'in_transit' || stage == 'arrived')
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('deliv_requests').doc(docId).update({
                        'stage': 'delivered',
                        'status': 'completed',
                        'completedAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🎉 Order marked as DELIVERED! Earnings credited.'), backgroundColor: _neonGreen),
                        );
                      }
                    },
                    child: const Text('Complete Delivery & Collect Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── GIG ORDER CARD ────────────────────────────────────────────────
  Widget _buildGigOrderCard(String gigId, Map<String, dynamic> data, Map<String, dynamic> catInfo) {
    final Color color = catInfo['color'] as Color;
    final studentUid = (data['postedBy'] ?? data['userId'] ?? data['studentId'] ?? data['requester_id'] ?? '').toString();
    if (studentUid.isNotEmpty && !_rememberedStudents.containsKey(studentUid)) {
      _preloadStudentProfile(studentUid);
    }
    final student = _rememberedStudents[studentUid];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
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
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(catInfo['icon'], style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['type'] ?? 'Errand Run',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Text(
                        'Instant Payout • ~0.8 km run',
                        style: TextStyle(color: _textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _neonGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _neonGreen),
                ),
                child: Text(
                  data['pay']?.toString() ?? 'KES -',
                  style: const TextStyle(color: _neonGreen, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Student Customer Banner
          GestureDetector(
            onTap: () {
              if (student != null) _showStudentProfileModal(student);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _neonCyan.withValues(alpha: 0.2),
                    backgroundImage: (student?['photoUrl'] != null && student!['photoUrl'].toString().isNotEmpty)
                        ? NetworkImage(student['photoUrl'])
                        : null,
                    child: (student?['photoUrl'] == null || student!['photoUrl'].toString().isEmpty)
                        ? Text(
                            ((student?['name'] ?? 'S') as String)[0].toUpperCase(),
                            style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                student?['name'] ?? 'Campus Student Requester',
                                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: _neonCyan, size: 12),
                          ],
                        ),
                        Text(
                          student?['campus'] ?? 'Tap to view profile details',
                          style: const TextStyle(color: _textSecondary, fontSize: 10.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _neonCyan, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 15, color: _textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pickup: ${data['pickup'] ?? 'Campus Point'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 15, color: _neonRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Deliver to: ${data['dropoff'] ?? 'Student Residence'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => _rejectGig(gigId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textSecondary,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Pass', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: () => _acceptGig(gigId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Accept & Navigate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── OFFLINE PROMPT BANNER ─────────────────────────────────────────
  Widget _buildOfflinePrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.power_settings_new_rounded, color: Colors.white54, size: 36),
          ),
          const SizedBox(height: 14),
          const Text(
            'You are Currently Offline',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Go online to receive incoming food deliveries, parcel runs, and campus gigs around your location.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('GO ONLINE NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              onPressed: () => _toggleStatus(true),
            ),
          ),
        ],
      ),
    );
  }

  // ── REMEMBERED STUDENTS CAROUSEL ──────────────────────────────────
  Widget _buildRememberedStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.school_rounded, color: _neonCyan, size: 18),
                SizedBox(width: 8),
                Text(
                  'Remembered Students & Clients',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _neonCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _neonCyan.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${_recentStudentsList.length} Connected',
                style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 102,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _recentStudentsList.length,
            itemBuilder: (context, index) {
              final student = _recentStudentsList[index];
              final photoUrl = student['photoUrl'];
              final hasPhoto = photoUrl != null && photoUrl.toString().isNotEmpty;

              return GestureDetector(
                onTap: () => _showStudentProfileModal(student),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _neonCyan.withValues(alpha: 0.2),
                        backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                        child: !hasPhoto
                            ? Text(
                                ((student['name'] ?? 'S') as String)[0].toUpperCase(),
                                style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        student['name'] ?? 'Student',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        student['campus'] ?? 'Client',
                        style: const TextStyle(color: _textSecondary, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
}

