import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonBlue = Color(0xFF00B2FE);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class DormSharedWalletView extends StatefulWidget {
  const DormSharedWalletView({super.key});

  @override
  State<DormSharedWalletView> createState() => _DormSharedWalletViewState();
}

class _DormSharedWalletViewState extends State<DormSharedWalletView> {
  String _currentUid = '';
  double _walletBalance = 0.0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _myWallets = [];
  List<Map<String, dynamic>> _pendingInvites = [];
  String? _selectedWalletId;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    if (_currentUid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
      if (userDoc.exists && mounted) {
        _walletBalance = (userDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      }

      final resp = await http.get(
        Uri.parse('${ApiConfig.v6DormMyWallets}/$_currentUid'),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && mounted) {
        final resData = json.decode(resp.body);
        final wallets = List<Map<String, dynamic>>.from(resData['wallets'] ?? []);
        final invites = List<Map<String, dynamic>>.from(resData['pending_invites'] ?? []);

        setState(() {
          _myWallets = wallets;
          _pendingInvites = invites;
          if (_selectedWalletId == null && wallets.isNotEmpty) {
            _selectedWalletId = wallets.first['id'];
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? get _activeWallet {
    if (_myWallets.isEmpty) return null;
    return _myWallets.firstWhere((w) => w['id'] == _selectedWalletId, orElse: () => _myWallets.first);
  }

  void _showCreateDormSheet() {
    final nameController = TextEditingController(text: 'Dorm Cooking Gas & WiFi');
    final roomController = TextEditingController(text: 'Room 4B');
    final targetController = TextEditingController(text: '4000');
    String category = 'Cooking Gas & Groceries';

    final categories = [
      'Cooking Gas & Groceries',
      'Monthly WiFi Token',
      'Electricity Tokens',
      'Drinking Water Refill',
      'Hostel Cleaning Supplies',
      'Weekend Dorm Feast',
      'General Shared Pool'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Create Shared Dorm Vault', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Vault Name',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: roomController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Hostel / Room Number',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Target Pooled Amount (KES)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Purpose Category', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: category,
                      dropdownColor: _surfaceLight,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => category = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final room = roomController.text.trim();
                    final target = double.tryParse(targetController.text.trim()) ?? 3000.0;

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    try {
                      final resp = await http.post(
                        Uri.parse(ApiConfig.v6DormCreate),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'creator_uid': _currentUid,
                          'name': name,
                          'room_number': room,
                          'target_amount': target,
                          'category': category,
                        }),
                      ).timeout(const Duration(seconds: 15));

                      final data = json.decode(resp.body);
                      if (resp.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(data['message'] ?? 'Dorm Vault Created!'), backgroundColor: _neonCyan),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(data['error'] ?? 'Could not create dorm vault'), backgroundColor: _neonPink),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Create Dorm Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInviteRoommateSheet(String walletId) {
    final idController = TextEditingController();
    Map<String, dynamic>? foundComrade;
    bool isSearching = false;
    String searchError = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Link Roommate by DISHI ID', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Enter your roommate\'s DISHI ID, phone number, or email to invite them to this shared vault.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: idController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'e.g. DISHI-84920 or Phone',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neonCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSearching
                          ? null
                          : () async {
                              final query = idController.text.trim();
                              if (query.isEmpty) return;
                              setSheetState(() {
                                isSearching = true;
                                searchError = '';
                                foundComrade = null;
                              });

                              try {
                                final resp = await http.post(
                                  Uri.parse(ApiConfig.v6DormLookupDishiId),
                                  headers: {'Content-Type': 'application/json'},
                                  body: json.encode({'identifier': query}),
                                ).timeout(const Duration(seconds: 15));

                                final data = json.decode(resp.body);
                                if (resp.statusCode == 200) {
                                  setSheetState(() => foundComrade = data);
                                } else {
                                  setSheetState(() => searchError = data['error'] ?? 'Comrade not found');
                                }
                              } catch (e) {
                                setSheetState(() => searchError = 'Network error: $e');
                              } finally {
                                setSheetState(() => isSearching = false);
                              }
                            },
                      child: isSearching
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text('Find', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (searchError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(searchError, style: const TextStyle(color: _neonPink, fontSize: 12)),
                  ),

                // Found Comrade Card
                if (foundComrade != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _neonCyan.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _neonCyan.withOpacity(0.2),
                          child: const Icon(Icons.person, color: _neonCyan),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(foundComrade!['name'] ?? 'Comrade', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('DISHI ID: ${foundComrade!['dishi_id']}', style: const TextStyle(color: _neonCyan, fontSize: 11)),
                              Text(foundComrade!['campus'] ?? 'Main Campus', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);

                      try {
                        final resp = await http.post(
                          Uri.parse(ApiConfig.v6DormInvite),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'wallet_id': walletId,
                            'invited_uid': foundComrade!['uid'],
                            'sender_uid': _currentUid,
                          }),
                        ).timeout(const Duration(seconds: 15));

                        final data = json.decode(resp.body);
                        if (resp.statusCode == 200) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(data['message'] ?? 'Invite sent!'), backgroundColor: _neonCyan),
                          );
                          _loadData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(data['error'] ?? 'Invite failed'), backgroundColor: _neonPink),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
                        );
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    child: const Text('Send Vault Invite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContributeSheet(String walletId) {
    final amtController = TextEditingController();
    final noteController = TextEditingController(text: 'Gas & Groceries Contribution');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Contribute to Dorm Vault', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Available Personal Wallet: KES ${_walletBalance.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontSize: 12)),
              const SizedBox(height: 14),

              TextField(
                controller: amtController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount (KES)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
                  final note = noteController.text.trim();
                  if (amt <= 0) return;

                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);

                  try {
                    final resp = await http.post(
                      Uri.parse(ApiConfig.v6DormContribute),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'wallet_id': walletId,
                        'student_uid': _currentUid,
                        'amount': amt,
                        'note': note,
                      }),
                    ).timeout(const Duration(seconds: 15));

                    final data = json.decode(resp.body);
                    if (resp.statusCode == 200) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(data['message'] ?? 'Contribution added!'), backgroundColor: _neonCyan),
                      );
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(data['error'] ?? 'Contribution failed'), backgroundColor: _neonPink),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                child: const Text('Confirm Contribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProposeExpenseSheet(String walletId) {
    final titleController = TextEditingController();
    final amtController = TextEditingController();
    final noteController = TextEditingController();
    String category = 'Gas Refill';

    final categories = ['Gas Refill', 'WiFi Token', 'Electricity Token', 'Groceries', 'Water', 'Cleaning Supplies'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Propose Collective Expense', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Roommates vote to approve before funds are released.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 14),

                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Expense Title (e.g. 13kg Gas cylinder refill)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: amtController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Estimated Amount (KES)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Category dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: category,
                      dropdownColor: _surfaceLight,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => category = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Vendor Name / Details (Optional)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
                    if (title.isEmpty || amt <= 0) return;

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    try {
                      final resp = await http.post(
                        Uri.parse(ApiConfig.v6DormProposeExpense),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'wallet_id': walletId,
                          'student_uid': _currentUid,
                          'title': title,
                          'amount': amt,
                          'category': category,
                          'vendor_notes': noteController.text.trim(),
                        }),
                      ).timeout(const Duration(seconds: 15));

                      final data = json.decode(resp.body);
                      if (resp.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(data['message'] ?? 'Proposal submitted!'), backgroundColor: _neonCyan),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(data['error'] ?? 'Proposal failed'), backgroundColor: _neonPink),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('Submit for Roommate Vote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBillSplitterDialog(Map<String, dynamic> wallet) {
    final totalController = TextEditingController(text: (wallet['target_amount'] ?? 2000).toString());
    final members = List<Map<String, dynamic>>.from(wallet['members'] ?? []);
    final int count = members.isEmpty ? 1 : members.length;
    double perPerson = (double.tryParse(totalController.text) ?? 2000.0) / count;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.call_split, color: _neonCyan),
              SizedBox(width: 8),
              Text('Roommate Bill Splitter', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Calculate equal contributions for dorm expenses:', style: TextStyle(color: _textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: totalController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Total Bill Amount (KES)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (val) {
                  final t = double.tryParse(val) ?? 0.0;
                  setDlgState(() => perPerson = t / count);
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$count Roommates', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const Text('Equal Share Each:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Text('KES ${perPerson.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: _textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Nudge sent to $count roommates for KES ${perPerson.toStringAsFixed(0)} each!'), backgroundColor: _neonCyan),
                );
              },
              child: const Text('Nudge Roommates'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respondInvite(String walletId, String decision) async {
    setState(() => _isLoading = true);
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6DormRespondInvite),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'wallet_id': walletId,
          'student_uid': _currentUid,
          'decision': decision,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Updated!'), backgroundColor: _neonCyan),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Action failed'), backgroundColor: _neonPink),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeWallet;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Dorm Shared Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _neonCyan), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _neonOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: const Text('Create Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showCreateDormSheet,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _neonCyan,
              backgroundColor: _cardColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Incoming Invites Tray
                    if (_pendingInvites.isNotEmpty) ...[
                      const Text('Incoming Vault Invitations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ..._pendingInvites.map((inv) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _neonCyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _neonCyan.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.mark_email_unread_rounded, color: _neonCyan, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${inv['wallet_name']} (${inv['room_number'] ?? "Dorm"})',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Invited by ${inv['creator_name'] ?? "Roommate"} • Goal: KES ${inv['target_amount']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _respondInvite(inv['wallet_id'], 'decline'),
                                    child: const Text('Decline', style: TextStyle(color: _textSecondary, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                                    onPressed: () => _respondInvite(inv['wallet_id'], 'accept'),
                                    child: const Text('Accept & Join', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    if (active == null)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          children: [
                            const Icon(Icons.home_work_outlined, color: _neonOrange, size: 54),
                            const SizedBox(height: 14),
                            const Text('No Active Dorm Shared Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            const Text('Create a shared vault for cooking gas, WiFi, or groceries, then link your roommates using their DISHI ID.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 12)),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Shared Vault', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _showCreateDormSheet,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Vault Selector if multiple
                      if (_myWallets.length > 1) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _myWallets.map((w) {
                              final isSel = (w['id'] == _selectedWalletId);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(w['name'] ?? 'Vault', style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  selected: isSel,
                                  selectedColor: _neonCyan,
                                  backgroundColor: _cardColor,
                                  onSelected: (_) => setState(() => _selectedWalletId = w['id']),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Hero Vault Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E1A11), Color(0xFF4A2511), Color(0xFF1E130C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.orangeAccent.withOpacity(0.4), width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.12), blurRadius: 20, spreadRadius: 2)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.cottage, color: Colors.orangeAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Text(active['room_number'] ?? 'Dorm', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                  child: Text('${(active['members'] as List?)?.length ?? 1} Roommates', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(active['name'] ?? 'Dorm Vault', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Category: ${active['category'] ?? "Essentials"}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 14),

                            // Balance
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('KES ${(active['balance'] ?? 0).toString()}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                                Text('Goal: KES ${(active['target_amount'] ?? 0).toString()}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Progress
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ((active['progress_percent'] ?? 0) / 100.0).clamp(0.0, 1.0),
                                backgroundColor: _surfaceLight,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Quick Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _neonCyan,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Contribute', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    onPressed: () => _showContributeSheet(active['id']),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white30),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.person_add, size: 16),
                                    label: const Text('Link Mate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    onPressed: () => _showInviteRoommateSheet(active['id']),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  style: IconButton.styleFrom(backgroundColor: _surfaceLight),
                                  icon: const Icon(Icons.call_split, color: _neonCyan, size: 20),
                                  tooltip: 'Split Bill Calculator',
                                  onPressed: () => _showBillSplitterDialog(active),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Roommates Roster
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Roommates Roster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          TextButton.icon(
                            onPressed: () => _showInviteRoommateSheet(active['id']),
                            icon: const Icon(Icons.add, color: _neonCyan, size: 16),
                            label: const Text('Add by DISHI ID', style: TextStyle(color: _neonCyan, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ...((active['members'] as List?) ?? []).map((m) {
                        final isCaptain = m['role'] == 'captain';
                        final cAmt = (m['total_contributed'] ?? 0).toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isCaptain ? Colors.orangeAccent.withOpacity(0.2) : _neonCyan.withOpacity(0.15),
                                child: Icon(isCaptain ? Icons.star : Icons.person, color: isCaptain ? Colors.orangeAccent : _neonCyan, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(m['name'] ?? 'Roommate', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        if (isCaptain) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(6)),
                                            child: const Text('Captain', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text('DISHI ID: ${m['dishi_id'] ?? "—"}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Text('KES $cAmt', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),

                      // Propose & Vote Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Shared Purchases & Expenses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            icon: const Icon(Icons.receipt, size: 14),
                            label: const Text('Propose', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _showProposeExpenseSheet(active['id']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
                        child: const Row(
                          children: [
                            Icon(Icons.how_to_vote, color: _neonCyan, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Democratized Dorm Spending', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  SizedBox(height: 2),
                                  Text('Propose purchases like cooking gas or WiFi vouchers. All roommates vote to release pooled funds.', style: TextStyle(color: _textSecondary, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
