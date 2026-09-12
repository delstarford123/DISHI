import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/vendor_agent_service.dart';
import '../../../core/widgets/offline_image_widget.dart';
import '../../../core/widgets/high_friction_action.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';
class VendorTopupView extends StatefulWidget {
  final String studentUid;
  
  const VendorTopupView({super.key, required this.studentUid});

  @override
  State<VendorTopupView> createState() => _VendorTopupViewState();
}

class _VendorTopupViewState extends State<VendorTopupView> {
  final _pinController = TextEditingController();
  bool _isBuddyMeal = false;
  bool _isCashOut = false;
  
  final List<Map<String, dynamic>> _catalog = [
    {'id': 'item_lunch_a', 'name': 'Standard Lunch Meal', 'price': 200, 'category': 'meal', 'allergens': ['Gluten', 'Dairy']},
    {'id': 'item_snack_1', 'name': 'Peanut Snack', 'price': 30, 'category': 'snack', 'allergens': ['Peanuts']},
    {'id': 'item_drink_soda', 'name': 'Soda', 'price': 50, 'category': 'Sugar', 'allergens': []},
    {'id': 'item_drink_water', 'name': 'Water', 'price': 30, 'category': 'drink', 'allergens': []},
  ];
  final Map<String, int> _cart = {};

  double get _totalAmount {
    double total = 0;
    _cart.forEach((id, qty) {
      final item = _catalog.firstWhere((e) => e['id'] == id);
      total += item['price'] * qty;
    });
    return total;
  }
  
  // Visual verification data
  String _studentName = 'Loading...';
  String? _studentImageUrl;

  @override
  void initState() {
    super.initState();
    _loadStudentDetails();
  }

  Future<void> _loadStudentDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).get();
      if (doc.exists) {
        setState(() {
          _studentName = doc.data()?['displayName'] ?? 'Unknown Student';
          _studentImageUrl = doc.data()?['studentImageUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error loading student details: $e");
    }
  }

  double _calculatedCommission = 0.0;

  void _calculateProfit(String value) {
    if (value.isEmpty) {
      setState(() => _calculatedCommission = 0.0);
      return;
    }
    final amount = double.tryParse(value) ?? 0.0;
    setState(() {
      _calculatedCommission = VendorAgentService.calculateTopUpCommission(amount);
    });
  }

  void _processTopup() async {
    if (_totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty'), backgroundColor: MPesaTheme.primaryRed));
      return;
    }
    
    try {
      final vendorId = FirebaseAuth.instance.currentUser!.uid;
      final txId = DateTime.now().millisecondsSinceEpoch.toString();
      final timestamp = DateTime.now().toUtc().toIso8601String();
      
      final rawData = '${widget.studentUid}:$_totalAmount:$vendorId:$txId:$timestamp';
      final hmac = Hmac(sha256, utf8.encode('super-secret-vendor-key'));
      final signature = hmac.convert(utf8.encode(rawData)).toString();

      final cartItems = _cart.entries.map((e) {
        final item = _catalog.firstWhere((cat) => cat['id'] == e.key);
        return {
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'category': item['category'],
          'allergens': item['allergens'],
          'qty': e.value
        };
      }).toList();

      final payload = {
        'uid': widget.studentUid,
        'amount': _totalAmount,
        'vendorId': vendorId,
        'signature': signature,
        'txId': txId,
        'timestamp': timestamp,
        'isBuddyMeal': _isBuddyMeal,
        'isCashOut': _isCashOut,
        'items': cartItems,
      };

      if (_pinController.text.isNotEmpty) {
        payload['pin'] = _pinController.text;
      }

      final endpoint = _isCashOut ? ApiConfig.transactionCashout : ApiConfig.transactionCharge;

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          String errMsg = 'Failed to charge student';
          try {
            final parsed = jsonDecode(response.body);
            errMsg = parsed['error'] ?? response.body;
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $errMsg'), backgroundColor: MPesaTheme.primaryRed));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: MPesaTheme.primaryRed));
    }
  }

  void _requestSOS() async {
    try {
      final vendorId = FirebaseAuth.instance.currentUser!.uid;
      final response = await http.post(
        Uri.parse(ApiConfig.transactionSos),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': widget.studentUid,
          'vendorId': vendorId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS Request Sent to Parent'), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send SOS: ${response.body}'), backgroundColor: MPesaTheme.primaryRed));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: MPesaTheme.primaryRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DISHI Agent Top-Up'),
        backgroundColor: MPesaTheme.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Visual Verification Required', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Center(
              child: _studentImageUrl != null 
                ? OfflineImageWidget(
                    imageUrl: _studentImageUrl!,
                    width: 120,
                    height: 120,
                    borderRadius: 60,
                  )
                : const CircleAvatar(
                    radius: 60,
                    backgroundColor: Color(0xFF161B29),
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
            ),
            const SizedBox(height: 16),
            Text(_studentName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            const Text('Add Items to Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ..._catalog.map((item) {
              final qty = _cart[item['id']] ?? 0;
              return Card(
                child: ListTile(
                  title: Text(item['name']),
                  subtitle: Text('Ksh ${item['price']} | Category: ${item['category']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: qty > 0 ? () {
                          setState(() {
                            _cart[item['id']] = qty - 1;
                            if (_cart[item['id']] == 0) _cart.remove(item['id']);
                          });
                        } : null,
                      ),
                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setState(() {
                            _cart[item['id']] = qty + 1;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Ksh $_totalAmount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: MPesaTheme.primaryGreen)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: () async {
                final snapshot = await FirebaseFirestore.instance.collection('preorders')
                  .where('studentId', isEqualTo: widget.studentUid)
                  .where('vendorId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                  .where('status', isEqualTo: 'pending')
                  .get();
                  
                if (snapshot.docs.isNotEmpty) {
                   String meals = snapshot.docs.map((d) => d['mealName']).join(', ');
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PRE-ORDERS FOUND: $meals'), backgroundColor: Colors.blue, duration: const Duration(seconds: 10)));
                } else {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pre-orders found for this student today.')));
                }
              },
              icon: const Icon(Icons.bento),
              label: const Text('Check Active Pre-orders'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Buddy Meal (x2)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Student is paying for a friend', style: TextStyle(color: Colors.black54)),
              value: _isBuddyMeal,
              onChanged: (val) => setState(() => _isBuddyMeal = val),
              activeThumbColor: MPesaTheme.primaryGreen,
            ),
            SwitchListTile(
              title: const Text('Cash Out Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Provide physical cash to student (e.g., bus fare)', style: TextStyle(color: Colors.black54)),
              value: _isCashOut,
              onChanged: (val) => setState(() => _isCashOut = val),
              activeThumbColor: MPesaTheme.primaryGreen,
            ),
            
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _requestSOS,
              icon: const Icon(Icons.sos),
              label: const Text('Request Emergency SOS Fund'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 32),
            
            const Text('Student Authorization', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('For offline students, ask for their 4-digit PIN to authorize. Online students do not need a PIN here if they showed a valid QR Token.', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(labelText: 'Student PIN (Optional)', prefixIcon: Icon(Icons.lock)),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            const SizedBox(height: 32),
            
            HighFrictionAction(
              label: 'Slide to Charge Student',
              onActionCompleted: _processTopup,
              baseColor: MPesaTheme.primaryGreen,
            )
          ],
        ),
      ),
    );
  }
}
