import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_model.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class StudentTransfersView extends StatefulWidget {
  final UserModel? userModel;
  final String? prefilledRecipientId;

  const StudentTransfersView({
    super.key,
    this.userModel,
    this.prefilledRecipientId,
  });

  @override
  State<StudentTransfersView> createState() => _StudentTransfersViewState();
}

class _StudentTransfersViewState extends State<StudentTransfersView> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isSearchingRecipient = false;
  Map<String, dynamic>? _foundRecipient;
  String? _recipientError;

  bool _isTransferring = false;
  String? _errorMessage;
  Map<String, dynamic>? _completedTx;

  final List<double> _quickAmounts = [50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledRecipientId != null && widget.prefilledRecipientId!.isNotEmpty) {
      _recipientController.text = widget.prefilledRecipientId!;
      _lookupRecipient(widget.prefilledRecipientId!);
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _lookupRecipient(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _foundRecipient = null;
        _recipientError = null;
      });
      return;
    }

    setState(() {
      _isSearchingRecipient = true;
      _recipientError = null;
    });

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final usersRef = FirebaseFirestore.instance.collection('users');

      // 1. Try search by DISHI ID
      var snap = await usersRef.where('dishiId', isEqualTo: trimmed.toUpperCase()).limit(1).get();

      // 2. If not found, try search by phone
      if (snap.docs.isEmpty) {
        String phoneFormatted = trimmed.replaceAll('+', '').replaceAll(' ', '');
        if (phoneFormatted.startsWith('0')) {
          phoneFormatted = '254${phoneFormatted.substring(1)}';
        }
        snap = await usersRef.where('phoneNumber', isEqualTo: phoneFormatted).limit(1).get();
        if (snap.docs.isEmpty) {
          snap = await usersRef.where('phone', isEqualTo: phoneFormatted).limit(1).get();
        }
      }

      // 3. If not found and input looks like a UID
      if (snap.docs.isEmpty && trimmed.length >= 20) {
        final doc = await usersRef.doc(trimmed).get();
        if (doc.exists) {
          final data = doc.data()!;
          data['uid'] = doc.id;
          if (doc.id == currentUid) {
            setState(() {
              _foundRecipient = null;
              _recipientError = 'You cannot send money to yourself';
              _isSearchingRecipient = false;
            });
            return;
          }
          setState(() {
            _foundRecipient = data;
            _isSearchingRecipient = false;
          });
          return;
        }
      }

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        if (doc.id == currentUid) {
          setState(() {
            _foundRecipient = null;
            _recipientError = 'You cannot send money to yourself';
            _isSearchingRecipient = false;
          });
          return;
        }
        final data = doc.data();
        data['uid'] = doc.id;
        setState(() {
          _foundRecipient = data;
          _isSearchingRecipient = false;
        });
      } else {
        setState(() {
          _foundRecipient = null;
          _recipientError = 'No verified student found with this DISHI ID or phone';
          _isSearchingRecipient = false;
        });
      }
    } catch (e) {
      setState(() {
        _foundRecipient = null;
        _recipientError = 'Error verifying recipient: $e';
        _isSearchingRecipient = false;
      });
    }
  }

  Future<void> _executeTransfer(double currentBalance) async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (_foundRecipient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid recipient'), backgroundColor: _neonPink),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than KES 0'), backgroundColor: _neonPink),
      );
      return;
    }

    if (amount > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance. Available: KES ${currentBalance.toStringAsFixed(2)}'),
          backgroundColor: _neonPink,
        ),
      );
      return;
    }

    final senderUid = FirebaseAuth.instance.currentUser?.uid;
    if (senderUid == null) return;

    final receiverUid = _foundRecipient!['uid'] as String;
    final receiverName = _foundRecipient!['displayName'] ?? _foundRecipient!['name'] ?? 'Fellow Student';
    final note = _noteController.text.trim().isEmpty ? 'Peer Transfer' : _noteController.text.trim();

    // Confirmation Bottom Sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: _neonCyan, size: 22),
                SizedBox(width: 8),
                Text('Confirm Peer Transfer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Send To:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                      Text(receiverName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                      Text('KES ${amount.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transfer Fee:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                      Text('FREE (KES 0.00)', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Note:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                      Text(note, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm & Send Instantly', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isTransferring = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final senderRef = firestore.collection('users').doc(senderUid);
      final receiverRef = firestore.collection('users').doc(receiverUid);

      await firestore.runTransaction((tx) async {
        final senderSnap = await tx.get(senderRef);
        final receiverSnap = await tx.get(receiverRef);

        if (!senderSnap.exists) throw Exception('Sender account not found');
        if (!receiverSnap.exists) throw Exception('Recipient account not found');

        final senderData = senderSnap.data();
        final senderBalance = (senderData?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        if (senderBalance < amount) {
          throw Exception('Insufficient funds in wallet');
        }

        final receiverData = receiverSnap.data();
        final receiverBalance = (receiverData?['walletBalance'] as num?)?.toDouble() ?? 0.0;

        // Deduct from sender
        tx.update(senderRef, {'walletBalance': senderBalance - amount});

        // Credit receiver
        tx.update(receiverRef, {'walletBalance': receiverBalance + amount});

        // Log transaction record
        final txDocRef = firestore.collection('transactions').doc();
        final txData = {
          'type': 'p2p_transfer',
          'senderUid': senderUid,
          'receiverUid': receiverUid,
          'senderName': widget.userModel?.displayName ?? 'Student',
          'receiverName': receiverName,
          'amount': amount,
          'fee': 0.0,
          'note': note,
          'status': 'completed',
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': DateTime.now().toIso8601String(),
        };
        tx.set(txDocRef, txData);

        // Notify recipient in notifications collection
        final notifRef = firestore.collection('notifications').doc();
        tx.set(notifRef, {
          'targetUserId': receiverUid,
          'title': 'Money Received! 💸',
          'body': 'You received KES ${amount.toStringAsFixed(2)} from ${widget.userModel?.displayName ?? "a fellow student"}.',
          'type': 'p2p_received',
          'amount': amount,
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': [],
        });
      });

      if (mounted) {
        setState(() {
          _isTransferring = false;
          _completedTx = {
            'amount': amount,
            'receiverName': receiverName,
            'note': note,
            'time': DateTime.now(),
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBalance = widget.userModel?.walletBalance ?? 0.0;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text('Instant Peer Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _completedTx != null
            ? _buildSuccessView()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Balance banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF131A2A), Color(0xFF1B2A4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _neonCyan.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Available to Send', style: TextStyle(color: _textSecondary, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                'KES ${currentBalance.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt, color: _neonCyan, size: 14),
                                SizedBox(width: 4),
                                Text('0% FEE', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recipient input
                    const Text('Send To (DISHI ID or Phone)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _recipientController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. STU1294 or 0712345678',
                        hintStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _surfaceLight,
                        prefixIcon: const Icon(Icons.person_search, color: _neonCyan),
                        suffixIcon: _isSearchingRecipient
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _neonCyan)),
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward, color: _neonCyan),
                                onPressed: () => _lookupRecipient(_recipientController.text),
                              ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        if (val.length >= 4) {
                          _lookupRecipient(val);
                        } else {
                          setState(() {
                            _foundRecipient = null;
                            _recipientError = null;
                          });
                        }
                      },
                    ),

                    // Recipient verification card
                    if (_foundRecipient != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _neonCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _neonCyan.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _neonCyan,
                              child: Text(
                                (_foundRecipient!['displayName'] ?? _foundRecipient!['name'] ?? 'S').substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _foundRecipient!['displayName'] ?? _foundRecipient!['name'] ?? 'Verified Student',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'DISHI ID: ${_foundRecipient!['dishiId'] ?? _foundRecipient!['uid']?.substring(0, 8)}',
                                    style: const TextStyle(color: _neonCyan, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.verified, color: _neonCyan, size: 20),
                          ],
                        ),
                      ),
                    ],

                    if (_recipientError != null) ...[
                      const SizedBox(height: 8),
                      Text(_recipientError!, style: const TextStyle(color: _neonPink, fontSize: 12)),
                    ],

                    const SizedBox(height: 24),

                    // Amount input
                    const Text('Amount (KES)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: 'KES ',
                        prefixStyle: const TextStyle(color: _neonCyan, fontSize: 24, fontWeight: FontWeight.bold),
                        hintText: '0',
                        hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
                        filled: true,
                        fillColor: _surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick amount chips
                    Wrap(
                      spacing: 8,
                      children: _quickAmounts.map((amt) {
                        return ActionChip(
                          backgroundColor: _surfaceLight,
                          label: Text('+ KES ${amt.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          onPressed: () {
                            _amountController.text = amt.toInt().toString();
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Note input
                    const Text('Add a Note (Optional)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. Lunch contribution, hostel Wi-Fi...',
                        hintStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(_errorMessage!, style: const TextStyle(color: _neonPink, fontSize: 13), textAlign: TextAlign.center),
                    ],

                    const SizedBox(height: 32),

                    // Submit button
                    _isTransferring
                        ? const Center(child: CircularProgressIndicator(color: _neonCyan))
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _neonCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 20),
                            label: const Text('Send Money Instantly', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            onPressed: () => _executeTransfer(currentBalance),
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final amt = (_completedTx!['amount'] as num).toDouble();
    final receiver = _completedTx!['receiverName'] as String;
    final note = _completedTx!['note'] as String;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 64),
            ),
            const SizedBox(height: 20),
            const Text('Transfer Successful!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'KES ${amt.toStringAsFixed(2)} sent to $receiver',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text('Note: "$note"', style: const TextStyle(color: _textSecondary, fontSize: 13)),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done · Return to Home', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
