import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFF92B60);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class SplitBillView extends StatefulWidget {
  final UserModel userModel;
  final double? initialAmount;

  const SplitBillView({
    super.key,
    required this.userModel,
    this.initialAmount,
  });

  @override
  State<SplitBillView> createState() => _SplitBillViewState();
}

class _SplitBillViewState extends State<SplitBillView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController(text: 'Campus Meal / Groceries');
  final TextEditingController _friendIdController = TextEditingController();
  final List<String> _friends = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _titleController.dispose();
    _friendIdController.dispose();
    super.dispose();
  }

  void _addFriend() {
    final id = _friendIdController.text.trim().toUpperCase();
    if (id.isEmpty) return;
    if (id == widget.userModel.dishiId?.toUpperCase() || id == widget.userModel.uid.toUpperCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Huwezi kujiongeza mwenyewe kama comrade! (You cannot add yourself).')),
      );
      return;
    }
    if (!_friends.contains(id)) {
      setState(() {
        _friends.add(id);
        _friendIdController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comrade is already in the split list.')),
      );
    }
  }

  Future<void> _sendRequests() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || _friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weka kiasi na uongeze angalau comrade mmoja kwa DISHI ID yake.')),
      );
      return;
    }

    final double? totalAmount = double.tryParse(amountText);
    if (totalAmount == null || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kiasi si sahihi (Invalid amount).')));
      return;
    }

    setState(() => _isSending = true);

    try {
      final double perPerson = totalAmount / (_friends.length + 1);
      final db = FirebaseFirestore.instance;

      final Map<String, dynamic> participantsMap = {};
      final List<String> participantUids = [];

      for (final fId in _friends) {
        String targetUid = fId;
        String targetName = fId;

        try {
          final q = await db.collection('users').where('dishiId', isEqualTo: fId).limit(1).get();
          if (q.docs.isNotEmpty) {
            targetUid = q.docs.first.id;
            targetName = (q.docs.first.data()['displayName'] as String?) ?? fId;
          } else {
            final qAlt = await db.collection('users').where('swapeatCode', isEqualTo: fId).limit(1).get();
            if (qAlt.docs.isNotEmpty) {
              targetUid = qAlt.docs.first.id;
              targetName = (qAlt.docs.first.data()['displayName'] as String?) ?? fId;
            }
          }
        } catch (_) {}

        participantUids.add(targetUid);
        participantsMap[targetUid] = {
          'dishiId': fId,
          'name': targetName,
          'amount': perPerson,
          'status': 'pending',
          'paidAt': null,
        };
      }

      final docRef = await db.collection('split_bills').add({
        'creatorId': widget.userModel.uid,
        'creatorName': widget.userModel.displayName.isEmpty ? 'Comrade' : widget.userModel.displayName,
        'title': _titleController.text.trim().isEmpty ? 'Campus Meal Split' : _titleController.text.trim(),
        'totalAmount': totalAmount,
        'perPersonAmount': perPerson,
        'friends': _friends,
        'participantUids': participantUids,
        'participants': participantsMap,
        'paidMembers': [widget.userModel.uid],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Dispatch notifications to each participant
      for (final pUid in participantUids) {
        try {
          await db.collection('notifications').add({
            'targetUserId': pUid,
            'title': 'Comrade Bill Split Request 👥',
            'message': '${widget.userModel.displayName} has split a bill of KES ${totalAmount.toStringAsFixed(0)}. Your share is KES ${perPerson.toStringAsFixed(0)}. Put your PIN to pay.',
            'type': 'split_bill_request',
            'splitBillId': docRef.id,
            'amount': perPerson,
            'creatorId': widget.userModel.uid,
            'creatorName': widget.userModel.displayName,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'unread',
          });
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isSending = false;
          _friends.clear();
          _amountController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _neonCyan,
            content: Text(
              'Ombi limetumwa! Comrades wametumiwa arifa kuweka PIN zao. (KES ${perPerson.toStringAsFixed(0)} each).',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: $e')));
      }
    }
  }

  void _showPinPaymentDialog(DocumentSnapshot splitDoc) {
    final data = Map<String, dynamic>.from(splitDoc.data() as Map);
    final String splitId = splitDoc.id;
    final String creatorName = data['creatorName'] ?? 'Comrade';
    final String creatorId = data['creatorId'] ?? '';
    final String title = data['title'] ?? 'Campus Meal Split';
    final double share = ((data['perPersonAmount'] ?? 0.0) as num).toDouble();

    final TextEditingController pinCtrl = TextEditingController();
    bool isProcessing = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, color: _neonCyan, size: 22),
                        SizedBox(width: 8),
                        Text('Approve Split Bill', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, color: _textSecondary), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _neonCyan.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Split Request From:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                          Text(creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Purpose / Item:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Your Share to Pay:', style: TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('KES ${share.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enter your 4-digit DISHI PIN to authorize payment:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 12),
                    filled: true,
                    fillColor: _surfaceLight,
                    errorText: errorText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _neonCyan)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            final pin = pinCtrl.text.trim();
                            if (pin.length != 4) {
                              setModalState(() => errorText = 'Weka tarakimu 4 za PIN (Enter 4-digit PIN).');
                              return;
                            }

                            setModalState(() {
                              isProcessing = true;
                              errorText = null;
                            });

                            try {
                              final db = FirebaseFirestore.instance;
                              final userRef = db.collection('users').doc(widget.userModel.uid);
                              final userSnap = await userRef.get();
                              final userData = userSnap.data() ?? {};

                              final storedPin = (userData['pin'] ?? userData['walletPin'] ?? '1234').toString().trim();
                              if (storedPin.isNotEmpty && storedPin != pin) {
                                setModalState(() {
                                  isProcessing = false;
                                  errorText = 'PIN si sahihi (Incorrect PIN). Tafadhali jaribu tena.';
                                });
                                return;
                              }

                              final currentBalance = ((userData['walletBalance'] ?? 0.0) as num).toDouble();
                              if (currentBalance < share) {
                                setModalState(() {
                                  isProcessing = false;
                                  errorText = 'Salio halitoshi (KES ${currentBalance.toStringAsFixed(0)}). Huna kiasi hiki.';
                                });
                                return;
                              }

                              // Atomic payment settlement
                              await userRef.update({'walletBalance': currentBalance - share});

                              if (creatorId.isNotEmpty) {
                                final creatorRef = db.collection('users').doc(creatorId);
                                final cSnap = await creatorRef.get();
                                if (cSnap.exists) {
                                  final cBal = ((cSnap.data()?['walletBalance'] ?? 0.0) as num).toDouble();
                                  await creatorRef.update({'walletBalance': cBal + share});
                                }
                              }

                              // Record Transactions
                              await db.collection('transactions').add({
                                'userId': widget.userModel.uid,
                                'title': 'Split Bill Paid: $title',
                                'amount': share,
                                'type': 'debit',
                                'category': 'split_bill',
                                'recipientId': creatorId,
                                'recipientName': creatorName,
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              await db.collection('transactions').add({
                                'userId': creatorId,
                                'title': 'Split Share from ${widget.userModel.displayName}',
                                'amount': share,
                                'type': 'credit',
                                'category': 'split_bill',
                                'senderId': widget.userModel.uid,
                                'senderName': widget.userModel.displayName,
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              // Update split_bills doc
                              final List paidMembers = List.from(data['paidMembers'] ?? []);
                              if (!paidMembers.contains(widget.userModel.uid)) {
                                paidMembers.add(widget.userModel.uid);
                              }

                              final Map<String, dynamic> participants = Map<String, dynamic>.from(data['participants'] ?? {});
                              if (participants.containsKey(widget.userModel.uid)) {
                                final pData = Map<String, dynamic>.from(participants[widget.userModel.uid] as Map);
                                pData['status'] = 'paid';
                                pData['paidAt'] = DateTime.now().toIso8601String();
                                participants[widget.userModel.uid] = pData;
                              }

                              final bool allPaid = paidMembers.length >= ((data['participantUids'] as List?)?.length ?? 1) + 1;

                              await db.collection('split_bills').doc(splitId).update({
                                'paidMembers': paidMembers,
                                'participants': participants,
                                'status': allPaid ? 'completed' : 'partially_paid',
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              // Notify creator
                              await db.collection('notifications').add({
                                'targetUserId': creatorId,
                                'title': 'Comrade Paid Share! 💰',
                                'message': '${widget.userModel.displayName} has paid KES ${share.toStringAsFixed(0)} for $title.',
                                'type': 'split_bill_paid',
                                'splitBillId': splitId,
                                'createdAt': FieldValue.serverTimestamp(),
                                'status': 'unread',
                              });

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: _neonCyan,
                                    content: Text('Malipo ya KES ${share.toStringAsFixed(0)} yametumwa kwa $creatorName!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() {
                                isProcessing = false;
                                errorText = 'Hitilafu ya malipo: $e';
                              });
                            }
                          },
                    child: isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('Thibitisha & Lipa (Confirm & Pay)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final double perPerson = totalAmount > 0 ? (totalAmount / (_friends.length + 1)) : 0;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Comrade Bill Splitting', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _cardColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _neonCyan,
          indicatorWeight: 3,
          labelColor: _neonCyan,
          unselectedLabelColor: _textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.add_card, size: 20), text: 'Split New Bill'),
            Tab(icon: Icon(Icons.history, size: 20), text: 'Incoming & My Bills'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: SPLIT NEW BILL
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _neonCyan.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.group, color: _neonCyan, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Equal Comrade Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            SizedBox(height: 2),
                            Text('Enter total bill and add friends by DISHI ID. Everyone gets an instant prompt to pay with their PIN.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Bill Purpose / Description',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: 'KES ',
                    prefixStyle: const TextStyle(color: _neonCyan, fontSize: 28, fontWeight: FontWeight.bold),
                    labelText: 'Total Bill Amount',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _friendIdController,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Enter Friend\'s DISHI ID (e.g. STU8821)',
                          hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                          filled: true,
                          fillColor: _cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _addFriend(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(color: _neonCyan, borderRadius: BorderRadius.circular(12)),
                      child: IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.black),
                        onPressed: _addFriend,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_friends.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: const Text('Add at least one comrade above to calculate split shares.', style: TextStyle(color: _textSecondary, fontSize: 13)),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _neonCyan.withValues(alpha: 0.2),
                                  child: const Icon(Icons.person, color: _neonCyan, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(_friends[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            Row(
                              children: [
                                Text('KES ${perPerson.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () => setState(() => _friends.removeAt(index)),
                                  child: const Icon(Icons.close, color: _neonPink, size: 20),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                if (_friends.isNotEmpty && totalAmount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _neonCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _neonCyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your Share (1 of ${_friends.length + 1} comrades):', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        Text('KES ${perPerson.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSending ? null : _sendRequests,
                    icon: _isSending ? const SizedBox.shrink() : const Icon(Icons.send_rounded, size: 18),
                    label: _isSending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('Send Split Requests (Comrades Enter PIN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),

          // TAB 2: INCOMING REQUESTS & MY BILLS
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('split_bills').orderBy('createdAt', descending: true).limit(30).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _neonCyan));
              }

              final docs = snapshot.data?.docs ?? [];
              final incomingBills = docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final pUids = List<String>.from(d['participantUids'] ?? []);
                final paid = List<String>.from(d['paidMembers'] ?? []);
                return pUids.contains(widget.userModel.uid) && !paid.contains(widget.userModel.uid);
              }).toList();

              final myCreatedBills = docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return d['creatorId'] == widget.userModel.uid;
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // INCOMING SECTION
                  const Text('Pending Incoming Requests (Put PIN to Pay)', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (incomingBills.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                      child: const Text('No pending bill requests for you right now.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                    )
                  else
                    ...incomingBills.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final share = ((data['perPersonAmount'] ?? 0.0) as num).toDouble();
                      final creator = data['creatorName'] ?? 'Comrade';
                      final title = data['title'] ?? 'Meal Split';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _neonOrange.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_long, color: _neonOrange, size: 20),
                                    const SizedBox(width: 8),
                                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: _neonOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Action Required', style: TextStyle(color: _neonOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Requested by: $creator', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Your Share: KES ${share.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontSize: 16, fontWeight: FontWeight.bold)),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _neonCyan,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.lock_open, size: 14),
                                  label: const Text('Lipa na PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () => _showPinPaymentDialog(doc),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 16),
                  const Text('Bills Created by You', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (myCreatedBills.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                      child: const Text('You haven\'t created any group bill splits yet.', style: TextStyle(color: _textSecondary, fontSize: 12)),
                    )
                  else
                    ...myCreatedBills.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final total = ((data['totalAmount'] ?? 0.0) as num).toDouble();
                      final title = data['title'] ?? 'Meal Split';
                      final paidCount = (data['paidMembers'] as List?)?.length ?? 1;
                      final totalCount = ((data['friends'] as List?)?.length ?? 0) + 1;
                      final status = data['status'] ?? 'pending';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('KES ${total.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$paidCount of $totalCount comrades paid', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: status == 'completed' ? Colors.greenAccent.withValues(alpha: 0.2) : _neonOrange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status == 'completed' ? 'Completed' : 'Pending',
                                    style: TextStyle(color: status == 'completed' ? Colors.greenAccent : _neonOrange, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
