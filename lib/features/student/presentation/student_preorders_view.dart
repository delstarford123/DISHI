import '../../deliv/presentation/deliv_active_route_view.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/api_config.dart';
import 'vendor_directory_view.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class StudentPreordersView extends StatefulWidget {
  const StudentPreordersView({super.key});

  @override
  State<StudentPreordersView> createState() => _StudentPreordersViewState();
}

class _StudentPreordersViewState extends State<StudentPreordersView> {
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  void _showDynamicQRTokenModal(String orderId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _DynamicQRTokenSheet(orderId: orderId, studentUid: _currentUserId),
    );
  }

  void _showDineInTableModal() {
    final tableController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.table_restaurant, color: _neonCyan),
            SizedBox(width: 10),
            Text('Dine-In Table Delivery', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Cafeteria Table Number or scan the QR sticker on your table to receive food right to your seat.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tableController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'e.g. Table 14',
                hintStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                prefixIcon: const Icon(Icons.pin, color: _neonCyan),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
            onPressed: () {
              final tbl = tableController.text.trim();
              if (tbl.isEmpty) return;
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Table $tbl registered! Choose your meal for direct seat delivery.'), backgroundColor: _neonCyan),
              );
            },
            child: const Text('Confirm Table', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  void _showRequestCourierModal(String orderId, String vendorName) {
    final locationController = TextEditingController(text: 'Hall 4, Room B12');
    final List<String> campusLandmarks = [
      'Hall 1', 'Hall 2', 'Hall 3', 'Hall 4', 'Hall 5',
      'Science Complex', 'Main Library', 'Engineering Labs', 'Postgrad Hostel'
    ];
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (mCtx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.two_wheeler, color: _neonOrange, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Request DeLiv Courier', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Pick up from $vendorName & deliver to you', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Select or enter your campus drop-off point:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),

              // Landmark quick chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: campusLandmarks.map((lm) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: _surfaceLight,
                      label: Text(lm, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: () {
                        setModalState(() {
                          locationController.text = '$lm, Room ';
                        });
                      },
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: locationController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Hostel / Building & Room Number',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  prefixIcon: const Icon(Icons.door_front_door, color: _neonCyan),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Escrow Courier Fee Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: _neonCyan, size: 18),
                        SizedBox(width: 8),
                        Text('Courier Fee (DISHI Escrow):', style: TextStyle(color: _textSecondary, fontSize: 13)),
                      ],
                    ),
                    Text('KES 50.00', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delivery_dining),
                  label: Text(isSubmitting ? 'Dispatching...' : 'Dispatch Courier (KES 50)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: isSubmitting ? null : () async {
                    final dropoff = locationController.text.trim();
                    if (dropoff.isEmpty) return;
                    setModalState(() => isSubmitting = true);

                    try {
                      final resp = await http.post(
                        Uri.parse(ApiConfig.campusGigsRequestOrderDelivery),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'order_id': orderId,
                          'student_id': _currentUserId,
                          'dropoff_location': dropoff,
                          'delivery_fee': 50.0,
                        }),
                      ).timeout(const Duration(seconds: 30));

                      Navigator.pop(mCtx);

                      if (resp.statusCode == 200) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 Courier dispatched! Track rider live in this card.'),
                            backgroundColor: _neonCyan,
                          ),
                        );
                      } else {
                        String errMsg = 'Failed to request courier';
                        try {
                          final parsed = json.decode(resp.body);
                          errMsg = parsed['error'] ?? resp.body;
                        } catch (_) {}
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Error: $errMsg'), backgroundColor: Colors.redAccent),
                        );
                      }
                    } on TimeoutException {
                      Navigator.pop(mCtx);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Request timed out. Please try again.'), backgroundColor: Colors.redAccent),
                      );
                    } catch (e) {
                      Navigator.pop(mCtx);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: const Text('Live Pre-Orders & Dining', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_restaurant, color: _neonCyan),
            tooltip: 'Dine-In Table Ordering',
            onPressed: _showDineInTableModal,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('studentUid', isEqualTo: _currentUserId.isEmpty ? 'MOCK_ID' : _currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }

          final docs = snapshot.data?.docs ?? [];
          final activeOrders = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final status = (data['status'] ?? '').toString().toLowerCase();
            return status != 'collected' && status != 'cancelled';
          }).toList();

          if (activeOrders.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activeOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final data = activeOrders[index].data() as Map<String, dynamic>;
              data['id'] = activeOrders[index].id;
              return _buildOrderCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fastfood_outlined, size: 64, color: _textSecondary),
          const SizedBox(height: 16),
          const Text('No active pre-orders', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Skip cafeteria lines by ordering ahead.', style: TextStyle(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonCyan,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView()));
            },
            child: const Text('Browse Cafeterias & Stores', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['prep_status'] ?? order['status'] ?? 'Queued').toString();
    final items = order['items'] as List<dynamic>? ?? [];
    final total = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final orderId = order['id'] as String? ?? 'ORD_001';
    final tableNumber = order['table_number'] as String?;
    final vendorName = (order['vendorName'] ?? order['vendor_name'] ?? 'Campus Canteen').toString();
    final isCourier = order['fulfillmentType'] == 'deliv_courier' || order['deliv_request_id'] != null;
    final delivGigId = (order['deliv_request_id'] ?? order['gig_id']) as String?;
    final deliveryPin = (order['studentDeliveryPin'] ?? order['student_delivery_pin'] ?? '----').toString();
    final dropoffLocation = (order['dropoffLocation'] ?? order['dropoff'] ?? 'Hostel').toString();

    Color statusColor = _neonCyan;
    int stepIndex = 0;
    if (status.toLowerCase().contains('cooking') || status.toLowerCase().contains('prep')) {
      statusColor = _neonOrange;
      stepIndex = 1;
    } else if (status.toLowerCase().contains('ready') || status.toLowerCase().contains('transit')) {
      statusColor = Colors.greenAccent;
      stepIndex = 2;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withAlpha(90)),
        boxShadow: [
          BoxShadow(color: statusColor.withAlpha(25), blurRadius: 10, spreadRadius: 1)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Row(
                children: [
                  if (isCourier)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _neonOrange.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _neonOrange.withAlpha(120)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.two_wheeler, color: _neonOrange, size: 12),
                          SizedBox(width: 4),
                          Text('DeLiv', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (tableNumber != null && tableNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.table_restaurant, color: _neonCyan, size: 14),
                const SizedBox(width: 6),
                Text('Dine-In: Table $tableNumber', style: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          if (isCourier) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: _neonOrange, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Deliver to: $dropoffLocation',
                    style: const TextStyle(color: _neonOrange, fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Feature 16: Live Preparation Queue Stepper
          Row(
            children: [
              _buildStepNode('Queued', stepIndex >= 0, statusColor),
              _buildStepConnector(stepIndex >= 1, statusColor),
              _buildStepNode(isCourier ? 'Prep' : 'Cooking', stepIndex >= 1, statusColor),
              _buildStepConnector(stepIndex >= 2, statusColor),
              _buildStepNode(isCourier ? 'Dispatched' : 'Ready', stepIndex >= 2, statusColor),
            ],
          ),
          const SizedBox(height: 14),

          // Items Preview
          Text(
            items.map((i) => "${i['quantity'] ?? 1}x ${i['name'] ?? 'Meal'}").join(', '),
            style: const TextStyle(color: _textSecondary, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // If courier is active, show the secret Delivery PIN Banner
          if (isCourier) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withAlpha(100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Delivery PIN: $deliveryPin',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 2),
                        const Text('Tell this PIN to the courier to verify & receive your package.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: KES ${total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Wrap(
                spacing: 8,
                children: [
                  if (isCourier && delivGigId != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('Track Courier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DelivActiveRouteView(rideId: delivGigId)));
                      },
                    )
                  else if (!isCourier)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _neonOrange),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.two_wheeler, color: _neonOrange, size: 16),
                      label: const Text('Send Courier', style: TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _showRequestCourierModal(orderId, vendorName),
                    ),

                  // Feature 17: Dynamic Pickup QR Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Pickup QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _showDynamicQRTokenModal(orderId),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(String title, bool isDone, Color activeColor) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isDone ? activeColor : _surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Icon(isDone ? Icons.check : Icons.circle, color: isDone ? Colors.black : Colors.white24, size: 14),
        ),
        const SizedBox(width: 4),
        Text(title, style: TextStyle(color: isDone ? Colors.white : _textSecondary, fontSize: 11, fontWeight: isDone ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildStepConnector(bool isDone, Color activeColor) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: isDone ? activeColor : Colors.white12,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature 17: Dynamic QR Pickup Token Sheet (Live 30-sec countdown & 4-digit PIN)
// ─────────────────────────────────────────────────────────────────────────────
class _DynamicQRTokenSheet extends StatefulWidget {
  final String orderId;
  final String studentUid;

  const _DynamicQRTokenSheet({required this.orderId, required this.studentUid});

  @override
  State<_DynamicQRTokenSheet> createState() => _DynamicQRTokenSheetState();
}

class _DynamicQRTokenSheetState extends State<_DynamicQRTokenSheet> {
  String _qrPayload = '';
  String _shortPin = '----';
  int _secondsLeft = 30;
  Timer? _countdownTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchToken();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _fetchToken();
        }
      });
    });
  }

  Future<void> _fetchToken() async {
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6QrToken),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'order_id': widget.orderId,
          'student_uid': widget.studentUid,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 && mounted) {
        final data = json.decode(resp.body);
        setState(() {
          _qrPayload = data['qr_payload'] ?? 'DISHI:TOKEN';
          _shortPin = data['short_pin'] ?? '0000';
          _secondsLeft = (data['expires_in_seconds'] as num?)?.toInt() ?? 30;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.security, color: _neonCyan, size: 22),
                  SizedBox(width: 8),
                  Text('Encrypted Pickup Pass', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close, color: _textSecondary), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Present this dynamic QR or 4-digit PIN at the cafeteria counter to collect your meal. Automatically updates every 30 seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Dynamic QR Code Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _qrPayload.isEmpty
                ? const SizedBox(width: 180, height: 180, child: Center(child: CircularProgressIndicator(color: Colors.black)))
                : QrImageView(
                    data: _qrPayload,
                    version: QrVersions.auto,
                    size: 180.0,
                    backgroundColor: Colors.white,
                  ),
          ),
          const SizedBox(height: 16),

          // 4-Digit Numeric PIN Fallback
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: _surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _neonCyan.withAlpha(50)),
            ),
            child: Column(
              children: [
                const Text('Cashier PIN Code', style: TextStyle(color: _textSecondary, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  _shortPin,
                  style: const TextStyle(color: _neonCyan, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Countdown Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: _neonOrange, size: 16),
              const SizedBox(width: 6),
              Text(
                'Refreshes in $_secondsLeft seconds',
                style: const TextStyle(color: _neonOrange, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
