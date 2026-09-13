import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/services/notification_service.dart';
import 'widgets/pos_numpad.dart';

class VendorTopupView extends StatefulWidget {
  final String studentUid;
  
  const VendorTopupView({super.key, required this.studentUid});

  @override
  State<VendorTopupView> createState() => _VendorTopupViewState();
}

class _VendorTopupViewState extends State<VendorTopupView> with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  bool _isBuddyMeal = false;
  bool _isCashOut = false;
  
  List<Map<String, dynamic>> _catalog = [];
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
  List<Map<String, dynamic>> _activePreorders = [];
  bool _isFulfilling = false;
  bool _isLoadingCatalog = true;

  // Phase 2 State
  late TabController _tabController;
  List<String> _studentAllergens = [];
  String _depositDisplay = "0";
  double _calculatedCommission = 0.0;
  DateTime? _lastTransactionTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudentDetails();
  }

  Future<void> _loadStudentDetails() async {
    try {
      final vendorId = FirebaseAuth.instance.currentUser?.uid;
      if (vendorId != null) {
        final menusSnapshot = await FirebaseFirestore.instance.collection('vendor_menus').where('vendorId', isEqualTo: vendorId).get();
        if (mounted) {
          setState(() {
            _catalog = menusSnapshot.docs.map((doc) => {
              'id': doc.id,
              'name': doc['name'],
              'price': doc['price'],
              'description': doc.data().containsKey('description') ? doc['description'] : '',
              'imageUrl': doc.data().containsKey('imageUrl') ? doc['imageUrl'] : '',
              'allergens': doc.data().containsKey('allergens') ? doc['allergens'] : '',
            }).toList();
            _isLoadingCatalog = false;
          });
        }
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).get();
      if (doc.exists) {
        setState(() {
          _studentName = doc.data()?['displayName'] ?? 'Unknown Student';
          _studentImageUrl = doc.data()?['studentImageUrl'];
          if (doc.data()!.containsKey('allergens')) {
            final al = doc.data()!['allergens'];
            if (al is List) {
              _studentAllergens = al.map((e) => e.toString()).toList();
            } else if (al is String) {
              _studentAllergens = al.split(',').map((e) => e.trim()).toList();
            }
          }
        });
      }
      
      // Check for active preorders
      if (vendorId != null) {
        final preorderSnap = await FirebaseFirestore.instance.collection('preorders')
            .where('studentId', isEqualTo: widget.studentUid)
            .where('vendorId', isEqualTo: vendorId)
            .where('status', isEqualTo: 'pending')
            .get();
        
        if (preorderSnap.docs.isNotEmpty) {
          setState(() {
            _activePreorders = preorderSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading student details: $e");
    }
  }

  void _fulfillPreorder(String preorderId, String mealName) async {
    setState(() => _isFulfilling = true);
    try {
      await FirebaseFirestore.instance.collection('preorders').doc(preorderId).update({
        'status': 'fulfilled',
        'fulfilledAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _activePreorders.removeWhere((p) => p['id'] == preorderId);
      });
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fulfilled $mealName!'), backgroundColor: MPesaTheme.primaryGreen));
      }
      
      NotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Preorder Fulfilled ✅',
        body: '$mealName was successfully redeemed!',
      );
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fulfilling preorder: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isFulfilling = false);
    }
  }

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

  void _processAgentDeposit() async {
    final amount = double.tryParse(_depositDisplay) ?? 0.0;
    if (amount <= 0) return;

    if (VendorAgentService.isWashTradingSuspected()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FRAUD ALERT: Wash Trading Suspected. Deposit Locked.'), backgroundColor: Colors.red));
      return;
    }

    try {
      final vendorId = FirebaseAuth.instance.currentUser!.uid;
      final response = await http.post(
        Uri.parse(ApiConfig.transactionTopup),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': widget.studentUid,
          'amount': amount,
          'vendorId': vendorId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deposit Successful!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response.body}'), backgroundColor: MPesaTheme.primaryRed));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: MPesaTheme.primaryRed));
    }
  }

  // Phase 1 Additions
  final List<Map<String, int>> _savedTabs = [];
  double _cartDiscount = 0.0;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void dispose() {
    _tabController.dispose();
    _pinController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _saveTab() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty'), backgroundColor: MPesaTheme.primaryRed));
      return;
    }
    setState(() {
      _savedTabs.add(Map.from(_cart));
      _cart.clear();
      _cartDiscount = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order saved to Tabs!'), backgroundColor: MPesaTheme.primaryGreen));
  }

  void _restoreTab(int index) {
    setState(() {
      _cart.clear();
      _cart.addAll(_savedTabs[index]);
      _savedTabs.removeAt(index);
      _cartDiscount = 0.0;
    });
  }

  void _showCashTenderDialog() {
    if (_totalAmount <= 0) return;
    double amountTendered = 0.0;
    String displayString = "0";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cash Calculator'),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    Text('Total Due: Ksh ${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('Tendered: Ksh $displayString', style: const TextStyle(fontSize: 24, color: MPesaTheme.primaryGreen)),
                    Text('Change: Ksh ${(amountTendered - _totalAmount).clamp(0, double.infinity).toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Colors.black54)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PosNumpad(
                        onKeyPressed: (val) {
                          setDialogState(() {
                            if (displayString == "0") displayString = val;
                            else displayString += val;
                            amountTendered = double.tryParse(displayString) ?? 0.0;
                          });
                        },
                        onClear: () {
                          setDialogState(() {
                            displayString = "0";
                            amountTendered = 0.0;
                          });
                        },
                        onBackspace: () {
                          setDialogState(() {
                            if (displayString.length > 1) {
                              displayString = displayString.substring(0, displayString.length - 1);
                            } else {
                              displayString = "0";
                            }
                            amountTendered = double.tryParse(displayString) ?? 0.0;
                          });
                        },
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: amountTendered >= _totalAmount ? () {
                    Navigator.pop(context);
                    _processTopup(isCash: true);
                  } : null,
                  style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen, foregroundColor: Colors.white),
                  child: const Text('Exact / Mark Paid'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDiscountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Cart Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Staff Meal (50% Off)'),
              onTap: () {
                setState(() => _cartDiscount = _totalAmount * 0.5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Remove Discount'),
              onTap: () {
                setState(() => _cartDiscount = 0.0);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey.keyLabel == 'Enter' || event.logicalKey.keyLabel == 'Numpad Enter') {
        if (_cart.isNotEmpty) _processTopup();
      } else if (event.logicalKey.keyLabel == 's' || event.logicalKey.keyLabel == 'S') {
        _saveTab();
      } else if (event.logicalKey.keyLabel == 'c' || event.logicalKey.keyLabel == 'C') {
        _showCashTenderDialog();
      }
    }
  }

  void _processTopup({bool isCash = false}) async {
    final finalAmount = _totalAmount - _cartDiscount;
    if (finalAmount <= 0 && _totalAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty'), backgroundColor: MPesaTheme.primaryRed));
      return;
    }

    final now = DateTime.now();
    if (_lastTransactionTime != null && now.difference(_lastTransactionTime!).inSeconds < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FRAUD ALERT: Rapid scan detected. Please wait.'), backgroundColor: Colors.red));
      return;
    }
    _lastTransactionTime = now;
    
    try {
      final vendorId = FirebaseAuth.instance.currentUser!.uid;
      final txId = DateTime.now().millisecondsSinceEpoch.toString();
      final timestamp = DateTime.now().toUtc().toIso8601String();
      
      final rawData = '${widget.studentUid}:$finalAmount:$vendorId:$txId:$timestamp';
      final hmac = Hmac(sha256, utf8.encode('super-secret-vendor-key'));
      final signature = hmac.convert(utf8.encode(rawData)).toString();

      final cartItems = _cart.entries.map((e) {
        final item = _catalog.firstWhere((cat) => cat['id'] == e.key);
        return {
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'qty': e.value
        };
      }).toList();

      final payload = {
        'uid': widget.studentUid,
        'amount': finalAmount,
        'vendorId': vendorId,
        'signature': signature,
        'txId': txId,
        'timestamp': timestamp,
        'isBuddyMeal': _isBuddyMeal,
        'isCashOut': _isCashOut,
        'isCashPayment': isCash,
        'discountApplied': _cartDiscount,
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isCash ? 'Cash Payment Recorded!' : 'Wallet Payment Successful!'), backgroundColor: Colors.green));
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

  Widget _buildStudentHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _studentImageUrl != null 
            ? OfflineImageWidget(imageUrl: _studentImageUrl!, width: 60, height: 60, borderRadius: 30)
            : const CircleAvatar(radius: 30, backgroundColor: Color(0xFF161B29), child: Icon(Icons.person, size: 30, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_studentName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (_activePreorders.isNotEmpty)
                  const Text('Has Pending Preorders', style: TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.sos, color: Colors.red), onPressed: _requestSOS, tooltip: 'SOS'),
        ],
      ),
    );
  }

  Widget _buildFavoritesGrid() {
    if (_isLoadingCatalog) return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));
    if (_catalog.isEmpty) return const Center(child: Text('Menu is empty.', style: TextStyle(color: Colors.red)));

    return GridView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _catalog.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final item = _catalog[index];
        return InkWell(
          onTap: () {
            if (item['allergens'] != null && item['allergens'].toString().isNotEmpty && _studentAllergens.isNotEmpty) {
              final List<String> itemAllergens = item['allergens'].toString().split(',').map((e) => e.trim().toLowerCase()).toList();
              final List<String> studentAllergensLower = _studentAllergens.map((e) => e.toLowerCase()).toList();
              final hasAllergen = itemAllergens.any((a) => studentAllergensLower.contains(a));
              
              if (hasAllergen) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('⚠️ ALLERGEN WARNING', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    content: Text('This item contains allergens (${item['allergens']}) that conflict with the student\'s profile!'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _cart[item['id']] = (_cart[item['id']] ?? 0) + 1;
                          });
                        },
                        child: const Text('Override & Add'),
                      )
                    ],
                  )
                );
                return;
              }
            }

            setState(() {
              _cart[item['id']] = (_cart[item['id']] ?? 0) + 1;
            });
          },
          child: Card(
            color: MPesaTheme.primaryGreen.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: MPesaTheme.primaryGreen.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
                    ? Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['imageUrl'], fit: BoxFit.cover)))
                    : const Expanded(child: Icon(Icons.fastfood, size: 40, color: MPesaTheme.primaryGreen)),
                  const SizedBox(height: 8),
                  Text(item['name'], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('Ksh ${item['price']}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCart() {
    final finalAmount = _totalAmount - _cartDiscount;
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.save), onPressed: _saveTab, tooltip: 'Save to Tab (S)'),
                    IconButton(icon: const Icon(Icons.local_offer), onPressed: _showDiscountDialog, tooltip: 'Discount'),
                  ],
                )
              ],
            ),
            const Divider(),
            if (_savedTabs.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _savedTabs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text('Tab ${index + 1}'),
                      backgroundColor: Colors.orange.shade100,
                      onPressed: () => _restoreTab(index),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _cart.isEmpty
                  ? const Center(child: Text('Tap items to add to cart', style: TextStyle(color: Colors.grey)))
                  : ListView(
                      children: _cart.entries.map((e) {
                        final item = _catalog.firstWhere((cat) => cat['id'] == e.key);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item['name']),
                          subtitle: Text('Ksh ${item['price']} x ${e.value}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  setState(() {
                                    _cart[item['id']] = e.value - 1;
                                    if (_cart[item['id']] == 0) _cart.remove(item['id']);
                                  });
                                },
                              ),
                              Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  setState(() {
                                    _cart[item['id']] = e.value + 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const Divider(),
            if (_cartDiscount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount:', style: TextStyle(color: Colors.red)),
                  Text('- Ksh ${_cartDiscount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Ksh ${finalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: MPesaTheme.primaryGreen)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.money),
                    label: const Text('Cash (C)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _showCashTenderDialog,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Wallet (Enter)'),
                    style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _processTopup,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodSalesTab() {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          
          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildStudentHeader(),
                      const Divider(),
                      Expanded(child: _buildFavoritesGrid()),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: _buildCart(),
                ),
              ],
            );
          }
          
          return Column(
            children: [
              _buildStudentHeader(),
              Expanded(
                flex: 2,
                child: _buildFavoritesGrid(),
              ),
              Expanded(
                flex: 3,
                child: _buildCart(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAgentDepositTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildStudentHeader(),
          const SizedBox(height: 16),
          const Text('Enter Cash Amount to Deposit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            'Ksh $_depositDisplay',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: MPesaTheme.primaryGreen),
          ),
          if (_calculatedCommission > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'You will earn Ksh ${_calculatedCommission.toStringAsFixed(2)} commission',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 32),
          Expanded(
            child: SizedBox(
              width: 300,
              child: PosNumpad(
                onKeyPressed: (val) {
                  setState(() {
                    if (_depositDisplay == "0") _depositDisplay = val;
                    else _depositDisplay += val;
                    _calculateProfit(_depositDisplay);
                  });
                },
                onClear: () {
                  setState(() {
                    _depositDisplay = "0";
                    _calculateProfit("0");
                  });
                },
                onBackspace: () {
                  setState(() {
                    if (_depositDisplay.length > 1) {
                      _depositDisplay = _depositDisplay.substring(0, _depositDisplay.length - 1);
                    } else {
                      _depositDisplay = "0";
                    }
                    _calculateProfit(_depositDisplay);
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          HighFrictionAction(
            label: 'Slide to Deposit to Student Wallet',
            onActionCompleted: _processAgentDeposit,
            baseColor: MPesaTheme.primaryGreen,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_keyboardFocusNode.hasFocus) {
      FocusScope.of(context).requestFocus(_keyboardFocusNode);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('DISHI Agent POS'),
        backgroundColor: MPesaTheme.primaryGreen,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fastfood), text: 'Food Sales'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Agent Deposit'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFoodSalesTab(),
          _buildAgentDepositTab(),
        ],
      ),
    );
  }
}
