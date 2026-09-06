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
  
  // Mock standard items that can be pre-ordered
  final List<Map<String, dynamic>> _menuItems = [
    {'id': 'item_lunch_a', 'name': 'Standard Lunch Meal', 'price': 200, 'vendorId': 'vendor_canteen_1', 'vendorName': 'Main Canteen'},
    {'id': 'item_lunch_b', 'name': 'Premium Rice & Beans', 'price': 250, 'vendorId': 'vendor_canteen_1', 'vendorName': 'Main Canteen'},
    {'id': 'item_snack_1', 'name': 'Fruit Salad', 'price': 100, 'vendorId': 'vendor_canteen_1', 'vendorName': 'Main Canteen'},
  ];

  Map<String, List<Map<String, dynamic>>> _preorders = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreorders();
  }

  void _loadPreorders() async {
    setState(() => _isLoading = true);
    try {
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
        });
      }
      setState(() {
        _preorders = loaded;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading preorders: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addPreorder(Map<String, dynamic> item) async {
    // Show confirmation dialog to deduct from Parent Vault
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Confirm Pre-order', style: TextStyle(color: _neonOrange)),
        content: Text('Pre-order ${item['name']} for $_selectedDay?\n\nThis will instantly deduct Ksh ${item['price']} from your Vault.', style: const TextStyle(color: Colors.white)),
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
      
      // We will create the preorder document. The backend should technically handle the money deduction securely via a transaction route.
      // But for this demo, we'll write directly if they have enough balance. 
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
      _loadPreorders(); // Refresh
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
       setState(() => _isLoading = false);
    }
  }

  void _cancelPreorder(String id, double price) async {
    // We should refund the parent
    try {
      setState(() => _isLoading = true);
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('users').doc(widget.parentUid), {
        'vaultBalance': FieldValue.increment(price)
      });
      batch.delete(FirebaseFirestore.instance.collection('preorders').doc(id));
      await batch.commit();
      
      _loadPreorders();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
       setState(() => _isLoading = false);
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
                  trailing: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _cancelPreorder(p['id'], (p['price'] as num).toDouble())),
                )),
                const SizedBox(height: 32),
                const Text('Available Menu Items', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._menuItems.map((item) => Card(
                  color: _cardColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${item['vendorName']} - Ksh ${item['price']}', style: const TextStyle(color: _textSecondary)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, foregroundColor: Colors.black),
                      onPressed: () => _addPreorder(item),
                      child: const Text('Add'),
                    ),
                  ),
                )),
              ],
            ),
          )
        ],
      ),
    );
  }
}
