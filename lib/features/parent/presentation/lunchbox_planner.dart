import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF161B29);
const Color _neonOrange = Color(0xFFFF6B00);
const Color _textSecondary = Color(0xFF8B9BB4);

class LunchboxPlanner extends StatefulWidget {
  final String studentUid;
  final String studentName;
  final String parentUid;

  const LunchboxPlanner({super.key, required this.studentUid, required this.studentName, required this.parentUid});

  @override
  State<LunchboxPlanner> createState() => _LunchboxPlannerState();
}

class _LunchboxPlannerState extends State<LunchboxPlanner> {
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  String _selectedDay = 'Monday';
  
  List<Map<String, dynamic>> _menuItems = [];
  Map<String, List<Map<String, dynamic>>> _preorders = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch preorders
      final snapshot = await FirebaseFirestore.instance.collection('preorders')
          .where('studentId', isEqualTo: widget.studentUid)
          .where('status', isEqualTo: 'pending')
          .get();
      
      Map<String, List<Map<String, dynamic>>> loaded = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final day = data['dayOfWeek'] as String;
        if (!loaded.containsKey(day)) {
          loaded[day] = [];
        }
        loaded[day]!.add({
          'id': doc.id,
          'name': data['mealName'],
          'price': data['price'],
          'vendorId': data['vendorId'] ?? '',
        });
      }
      
      // 2. Fetch real vendors map
      final vendorsSnapshot = await FirebaseFirestore.instance.collection('users')
          .where('roles', arrayContains: 'vendor')
          .get();
      
      Map<String, String> vendorNames = {};
      for (var doc in vendorsSnapshot.docs) {
        vendorNames[doc.id] = doc.data()['displayName'] ?? 'Vendor';
      }
          
      // 3. Fetch real vendor menus
      final menusSnapshot = await FirebaseFirestore.instance.collection('vendor_menus').get();
      
      List<Map<String, dynamic>> dynamicMenu = [];
      for (var doc in menusSnapshot.docs) {
        final data = doc.data();
        final vendorId = data['vendorId'] as String;
        // Only include items from active vendors
        if (vendorNames.containsKey(vendorId)) {
          dynamicMenu.add({
            'id': doc.id,
            'name': data['name'],
            'price': data['price'],
            'description': data['description'] ?? '',
            'imageUrl': data['imageUrl'] ?? '',
            'vendorId': vendorId,
            'vendorName': vendorNames[vendorId]!,
          });
        }
      }

      setState(() {
        _preorders = loaded;
        _menuItems = dynamicMenu;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadPreorders() {
    _loadData(); // Re-use the full load for simplicity
  }

  void _addPreorder(Map<String, dynamic> item) async {
    // Show confirmation dialog to deduct from Parent Vault
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Confirm Pre-order', style: TextStyle(color: _neonOrange)),
        content: Text('Pre-order ${item['name']} from ${item['vendorName']} for $_selectedDay?\n\nThis will instantly deduct Ksh ${item['price']} from your Vault and pay the vendor.', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Confirm & Pay', style: TextStyle(color: Colors.black))
          ),
        ],
      )
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      
      final parentDoc = await FirebaseFirestore.instance.collection('users').doc(widget.parentUid).get();
      double vaultBalance = (parentDoc.data()?['vaultBalance'] ?? 0.0).toDouble();
      
      if (vaultBalance < item['price']) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient funds in Vault')));
        return;
      }
      
      final txId = const Uuid().v4();
      final batch = FirebaseFirestore.instance.batch();
      
      // Deduct from parent
      batch.update(parentDoc.reference, {'vaultBalance': FieldValue.increment(-item['price'])});
      
      // Add to Vendor Wallet instantly
      final vendorRef = FirebaseFirestore.instance.collection('users').doc(item['vendorId']);
      batch.update(vendorRef, {'walletBalance': FieldValue.increment(item['price'])});
      
      // Add Preorder
      final preorderRef = FirebaseFirestore.instance.collection('preorders').doc(txId);
      batch.set(preorderRef, {
        'studentId': widget.studentUid,
        'studentName': widget.studentName,
        'parentUid': widget.parentUid,
        'vendorId': item['vendorId'],
        'vendorName': item['vendorName'],
        'mealName': item['name'],
        'price': item['price'],
        'dayOfWeek': _selectedDay,
        'status': 'pending', // Will be changed to 'fulfilled' by vendor
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pre-order placed successfully')));
      _loadData(); // Refresh
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelPreorder(String id, double price, String vendorId) async {
    // We should refund the parent and deduct from vendor
    try {
      setState(() => _isLoading = true);
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('users').doc(widget.parentUid), {
        'vaultBalance': FieldValue.increment(price)
      });
      if (vendorId.isNotEmpty) {
        batch.update(FirebaseFirestore.instance.collection('users').doc(vendorId), {
          'walletBalance': FieldValue.increment(-price)
        });
      }
      batch.delete(FirebaseFirestore.instance.collection('preorders').doc(id));
      await batch.commit();
      
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text('Lunchbox - ${widget.studentName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonOrange))
        : Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _days.map((day) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(day),
                  selected: _selectedDay == day,
                  selectedColor: _neonOrange,
                  onSelected: (val) {
                    if (val) setState(() => _selectedDay = day);
                  },
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Current Pre-orders', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if ((_preorders[_selectedDay] ?? []).isEmpty)
                  const Text('No meals pre-ordered for this day.', style: TextStyle(color: _textSecondary)),
                ...(_preorders[_selectedDay] ?? []).map((p) => ListTile(
                  tileColor: _cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  title: Text(p['name'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Ksh ${p['price']}', style: const TextStyle(color: _neonOrange)),
                  trailing: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _cancelPreorder(p['id'], (p['price'] as num).toDouble(), p['vendorId'] ?? '')),
                )),
                const SizedBox(height: 32),
                const Text('Available Menu Items', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_menuItems.isEmpty)
                   const Text('No items available from vendors right now.', style: TextStyle(color: _textSecondary)),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    final imageUrl = item['imageUrl'] as String?;
                    return Card(
                      color: _cardColor,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: (imageUrl != null && imageUrl.isNotEmpty)
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : Container(color: Colors.black26, child: const Icon(Icons.fastfood, color: Colors.white54, size: 40)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(item['vendorName'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Ksh ${item['price']}', style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
                                    GestureDetector(
                                      onTap: () => _addPreorder(item),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: _neonOrange, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
