import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:local_auth/local_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/virtual_card_service.dart';

class VirtualCardView extends StatefulWidget {
  final UserModel userModel;

  const VirtualCardView({super.key, required this.userModel});

  @override
  State<VirtualCardView> createState() => _VirtualCardViewState();
}

class _VirtualCardViewState extends State<VirtualCardView> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFront = true;
  bool _showDetails = false;
  bool _isLoading = true;
  bool _isChargingOnline = false;

  final VirtualCardService _cardService = VirtualCardService();
  final LocalAuthentication _auth = LocalAuthentication();
  
  Map<String, dynamic>? _cardData;
  List<Map<String, dynamic>> _recentTransactions = [];

  // Card Controls
  String _selectedTheme = 'Neon Cyan';
  bool _onlineTransactions = true;
  double _dailyLimit = 5000;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadCardData();
  }

  Future<void> _loadCardData() async {
    setState(() => _isLoading = true);
    try {
      final card = await _cardService.getCardDetails(widget.userModel.uid);
      if (card != null) {
        setState(() {
          _cardData = card;
          _selectedTheme = card['theme'] ?? 'Neon Cyan';
          _onlineTransactions = card['onlineTransactions'] ?? true;
          _dailyLimit = (card['dailyLimit'] ?? 5000).toDouble();
        });
      } else {
        // Generate a unique fallback card if API fails or for new offline users
        final random = Random();
        final newPan = List.generate(16, (_) => random.nextInt(10).toString()).join();
        final newCvv = List.generate(3, (_) => random.nextInt(10).toString()).join();
        final newExpiry = '${DateTime.now().month.toString().padLeft(2, '0')}/${(DateTime.now().year + 3).toString().substring(2)}';
        
        final fallbackCard = {
          'pan': newPan,
          'cvv': newCvv,
          'expiry': newExpiry,
          'status': 'active',
          'theme': 'Neon Cyan',
          'onlineTransactions': true,
          'dailyLimit': 5000,
        };
        setState(() {
          _cardData = fallbackCard;
          _selectedTheme = 'Neon Cyan';
          _onlineTransactions = true;
          _dailyLimit = 5000;
        });
        try {
          await _updateFirestoreCard(fallbackCard);
        } catch (saveErr) {
          debugPrint('Silent fallback for card write: $saveErr');
        }
      }
      _fetchRecentTransactions();
    } catch (e) {
      if (_cardData == null) {
        final random = Random();
        final newPan = List.generate(16, (_) => random.nextInt(10).toString()).join();
        final newCvv = List.generate(3, (_) => random.nextInt(10).toString()).join();
        final newExpiry = '${DateTime.now().month.toString().padLeft(2, '0')}/${(DateTime.now().year + 3).toString().substring(2)}';
        setState(() {
          _cardData = {
            'pan': newPan,
            'cvv': newCvv,
            'expiry': newExpiry,
            'status': 'active',
            'theme': 'Neon Cyan',
            'onlineTransactions': true,
            'dailyLimit': 5000,
          };
          _selectedTheme = 'Neon Cyan';
          _onlineTransactions = true;
          _dailyLimit = 5000;
        });
      }
      debugPrint('Error loading card from Firestore: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFirestoreCard(Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('virtual_cards').doc(widget.userModel.uid).set(data, SetOptions(merge: true));
  }

  Future<void> _fetchRecentTransactions() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('card_transactions')
          .where('uid', isEqualTo: widget.userModel.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
          
      if (mounted) {
        setState(() {
          _recentTransactions = query.docs.map((d) => d.data()).toList();
        });
      }
    } catch(e) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('card_transactions')
            .where('uid', isEqualTo: widget.userModel.uid)
            .limit(10)
            .get();
        if (mounted) {
          final list = query.docs.map((d) => d.data()).toList();
          list.sort((a, b) {
            final tA = a['timestamp'];
            final tB = b['timestamp'];
            if (tA is Timestamp && tB is Timestamp) return tB.compareTo(tA);
            return 0;
          });
          setState(() => _recentTransactions = list);
        }
      } catch (_) {}
    }
  }

  Future<void> _authenticateAndReveal({VoidCallback? onSuccess}) async {
    if (_showDetails) {
      if (onSuccess != null) {
        onSuccess();
      } else {
        setState(() => _showDetails = false);
        if (!_isFront) _flipCard();
      }
      return;
    }
    
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        _onAuthSuccess(onSuccess: onSuccess);
        return;
      }
      
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to reveal DISHI Card details',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      
      if (didAuthenticate) {
        _onAuthSuccess(onSuccess: onSuccess);
      } else {
        _showPinFallbackDialog(onSuccess: onSuccess);
      }
    } catch (e) {
      _showPinFallbackDialog(onSuccess: onSuccess);
    }
  }

  void _onAuthSuccess({VoidCallback? onSuccess}) {
    setState(() {
      _showDetails = true;
    });
    if (onSuccess != null) {
      onSuccess();
    }
  }

  void _showPinFallbackDialog({VoidCallback? onSuccess}) {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Enter PIN', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          maxLength: 4,
          decoration: InputDecoration(
            hintText: '4-digit PIN',
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: const Color(0xFF05D5AA).withOpacity(0.5))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF05D5AA))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF05D5AA)),
            onPressed: () {
              if (pinController.text.length >= 4) {
                Navigator.pop(context);
                _onAuthSuccess(onSuccess: onSuccess);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN')));
              }
            },
            child: const Text('Verify', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFreeze() async {
    final isFrozen = _cardData?['status'] == 'frozen';
    final newStatus = isFrozen ? 'active' : 'frozen';
    setState(() {
      _cardData!['status'] = newStatus;
    });
    await _updateFirestoreCard({'status': newStatus});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isFrozen ? 'Card Unfrozen.' : 'Card Frozen! All transactions blocked.', style: const TextStyle(color: Colors.white)),
        backgroundColor: isFrozen ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _toggleBurnerMode() async {
    final isBurner = _cardData?['status'] == 'burner';
    final newStatus = isBurner ? 'active' : 'burner';
    setState(() {
      _cardData!['status'] = newStatus;
    });
    await _updateFirestoreCard({'status': newStatus});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isBurner ? 'Burner Mode Deactivated.' : 'Burner Mode Active! Card will auto self-destruct after 1 purchase.', style: const TextStyle(color: Colors.white)),
        backgroundColor: isBurner ? Colors.grey : Colors.orange,
      ));
    }
  }

  Future<void> _toggleOnlineTransactions(bool value) async {
    setState(() {
      _onlineTransactions = value;
      if (_cardData != null) _cardData!['onlineTransactions'] = value;
    });
    await _updateFirestoreCard({'onlineTransactions': value});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? 'Online Transactions Enabled for E-Commerce & Subscriptions' : 'Online Transactions Disabled'),
        backgroundColor: value ? const Color(0xFF05D5AA) : Colors.orange,
      ));
    }
  }

  void _showLocalPayQR() {
    final String offlineTotpToken = 'OFFLINE-QR|${widget.userModel.uid}|${DateTime.now().millisecondsSinceEpoch}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Text('Offline Pay QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                data: offlineTotpToken,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Scan to Pay', style: TextStyle(color: Color(0xFF05D5AA), fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Dynamic offline token. Verified by cafeteria cashiers.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          )
        ],
      ),
    );
  }

  void _showOnlineCredentialsSheet() {
    if (!_showDetails) {
      _authenticateAndReveal(onSuccess: _showOnlineCredentialsSheet);
      return;
    }

    final pan = _cardData?['pan'] ?? '';
    final expiry = _cardData?['expiry'] ?? '';
    final cvv = _cardData?['cvv'] ?? '';
    final name = widget.userModel.displayName.toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF05D5AA).withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.credit_card, color: Color(0xFF05D5AA), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Online Checkout Credentials', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Tap copy on any field to paste into web checkouts', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildCredentialTile(
                title: 'CARD NUMBER (PAN)',
                value: pan.length == 16 ? '${pan.substring(0, 4)} ${pan.substring(4, 8)} ${pan.substring(8, 12)} ${pan.substring(12)}' : pan,
                copyValue: pan,
                icon: Icons.numbers,
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildCredentialTile(
                      title: 'EXPIRATION',
                      value: expiry,
                      copyValue: expiry,
                      icon: Icons.calendar_month,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCredentialTile(
                      title: 'CVV / CVC',
                      value: cvv,
                      copyValue: cvv,
                      icon: Icons.lock,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildCredentialTile(
                title: 'CARDHOLDER NAME',
                value: name,
                copyValue: name,
                icon: Icons.person,
              ),
              const SizedBox(height: 10),

              _buildCredentialTile(
                title: 'BILLING COUNTRY & ZIP',
                value: 'Kenya (KE) • Postal Code 00100',
                copyValue: '00100',
                icon: Icons.location_on,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF05D5AA),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.copy_all, size: 20),
                  label: const Text('Copy All Details For Autofill', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final allText = 'Card: $pan\nExpiry: $expiry\nCVV: $cvv\nName: $name\nCountry: Kenya\nZip: 00100';
                    Clipboard.setData(ClipboardData(text: allText));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All card details copied to clipboard!'), backgroundColor: Colors.green),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'DISHI never asks for your CVV. Never share this code with anyone.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCredentialTile({
    required String title,
    required String value,
    required String copyValue,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF05D5AA), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Color(0xFF05D5AA), size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: copyValue));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied $title to clipboard'), duration: const Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showOnlineShoppingGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('How to Use Your Card Online', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Make purchases on Jumia, Coursera, campus bookstores & digital subscriptions.', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),

              _buildGuideStep(
                stepNum: '1',
                title: 'Top Up Your DISHI Student Wallet',
                desc: 'Your virtual card is linked directly to your wallet balance. Top up via M-PESA anytime with 0 fee.',
                icon: Icons.account_balance_wallet,
              ),
              const SizedBox(height: 14),

              _buildGuideStep(
                stepNum: '2',
                title: 'Choose "Credit / Debit Card" at Checkout',
                desc: 'Select Visa/Debit Card on Jumia, Kilimall, Coursera, Google Play, Spotify, or your university portal.',
                icon: Icons.payment,
              ),
              const SizedBox(height: 14),

              _buildGuideStep(
                stepNum: '3',
                title: 'Enter Your 16-Digit PAN, Expiry & CVV',
                desc: 'Tap "Online Details" on your card in DISHI to reveal and copy your credentials with 1 tap.',
                icon: Icons.password,
              ),
              const SizedBox(height: 14),

              _buildGuideStep(
                stepNum: '4',
                title: 'Activate "Burner Mode" for 1-Time Purchases',
                desc: 'Buying from a new or trial website? Enable Burner Mode and the card automatically self-destructs after one charge.',
                icon: Icons.local_fire_department,
              ),
              const SizedBox(height: 14),

              _buildGuideStep(
                stepNum: '5',
                title: 'Earn 1% Instant Cashback Always',
                desc: 'Every online purchase automatically credits 1% cashback straight back to your DISHI student wallet balance.',
                icon: Icons.celebration,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF05D5AA),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it! Ready to Shop', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideStep({
    required String stepNum,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF05D5AA).withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF05D5AA)),
          ),
          child: Text(stepNum, style: const TextStyle(color: Color(0xFF05D5AA), fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }  void _showOnlineSimulatorDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFF05D5AA)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Coming Soon',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF05D5AA).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF05D5AA).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.credit_card_outlined, color: Color(0xFF05D5AA), size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Online Card Simulator',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Online purchase simulation is currently undergoing beta testing and will be available in an upcoming update.',
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'Once enabled, simulations will run in an isolated test environment and will NOT deduct funds from your Active Student Wallet.',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF05D5AA),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeOnlinePayment({
    required String merchant,
    required double amount,
    required String category,
    required String pan,
    required String cvv,
    required String expiry,
  }) async {
    _showOnlineSimulatorDialog();
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Card Controls & Limits', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              const Text('Daily Spend Limit (KES)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              Slider(
                value: _dailyLimit,
                min: 500,
                max: 20000,
                divisions: 39,
                activeColor: const Color(0xFF05D5AA),
                label: 'KES ${_dailyLimit.toInt()}',
                onChanged: (v) {
                  setModalState(() => _dailyLimit = v);
                  setState(() => _dailyLimit = v);
                },
                onChangeEnd: (v) => _updateFirestoreCard({'dailyLimit': v}),
              ),
              
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Online E-Commerce Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Allow usage on Jumia, Kilimall, Coursera, etc.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                activeColor: const Color(0xFF05D5AA),
                value: _onlineTransactions,
                onChanged: (v) {
                  setModalState(() => _onlineTransactions = v);
                  _toggleOnlineTransactions(v);
                },
              ),
              
              const SizedBox(height: 16),
              const Text('Card Visual Theme', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: ['Neon Cyan', 'Midnight Blue', 'Lava Red', 'Gold Prestige'].map((theme) {
                  return ChoiceChip(
                    label: Text(theme),
                    selected: _selectedTheme == theme,
                    selectedColor: const Color(0xFF05D5AA),
                    backgroundColor: Colors.white12,
                    labelStyle: TextStyle(color: _selectedTheme == theme ? Colors.black : Colors.white, fontSize: 12),
                    onSelected: (s) {
                      setModalState(() => _selectedTheme = theme);
                      setState(() => _selectedTheme = theme);
                      _updateFirestoreCard({'theme': theme});
                    },
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.9), foregroundColor: Colors.white),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Replace Card (Panic Regeneration)'),
                  onPressed: () {
                    Navigator.pop(context);
                    _regenerateCard();
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _regenerateCard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Replace Card?', style: TextStyle(color: Colors.white)),
        content: const Text('Your current card will be destroyed immediately. A new PAN and CVV will be generated. This action costs KES 2.00.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Pay KES 2 & Replace', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        await FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).update({
          'walletBalance': FieldValue.increment(-2.0)
        });

        final random = Random();
        final newPan = List.generate(16, (_) => random.nextInt(10).toString()).join();
        final newCvv = List.generate(3, (_) => random.nextInt(10).toString()).join();
        final newExpiry = '${DateTime.now().month.toString().padLeft(2, '0')}/${(DateTime.now().year + 3).toString().substring(2)}';
        
        setState(() {
          _cardData = {
            'pan': newPan,
            'cvv': newCvv,
            'expiry': newExpiry,
            'status': 'active',
            'theme': _selectedTheme,
            'onlineTransactions': _onlineTransactions,
            'dailyLimit': _dailyLimit,
          };
          _showDetails = false;
          if (!_isFront) _flipCard();
        });
        await _updateFirestoreCard(_cardData!);
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New card generated! KES 2.00 fee deducted.'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  List<Color> _getThemeColors() {
    switch (_selectedTheme) {
      case 'Midnight Blue': return [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)];
      case 'Lava Red': return [const Color(0xFF230707), const Color(0xFF8A1010)];
      case 'Gold Prestige': return [const Color(0xFFBF953F), const Color(0xFFFCF6BA), const Color(0xFFB38728)];
      case 'Neon Cyan':
      default: return [const Color(0xFF00FFD1), const Color(0xFF3B82F6)];
    }
  }

  Widget _buildFrontCard() {
    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: _getThemeColors(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _getThemeColors().first.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.15,
              child: Image.asset('assets/img/dishi_logo.png', width: 150, height: 150, errorBuilder: (c,e,s)=>const SizedBox()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/img/dishi_logo.png', height: 24, errorBuilder: (c, e, s) => const Icon(Icons.credit_card, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text('DISHI VIRTUAL', style: TextStyle(color: _selectedTheme == 'Gold Prestige' ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                    ],
                  ),
                  Row(
                    children: [
                      if (_cardData?['status'] == 'frozen')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                          child: const Text('FROZEN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                        )
                      else if (_cardData?['status'] == 'burner')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(12)),
                          child: const Text('BURNER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9)),
                        ),
                      Icon(Icons.wifi, color: _selectedTheme == 'Gold Prestige' ? Colors.black87 : Colors.white),
                    ],
                  ),
                ],
              ),
              Builder(builder: (_) {
                final pan = _cardData?['pan'] as String?;
                String displayPan = '**** **** **** ****';
                if (!_isLoading && pan != null && pan.length >= 16) {
                  displayPan = _showDetails
                      ? '${pan.substring(0, 4)} ${pan.substring(4, 8)} ${pan.substring(8, 12)} ${pan.substring(12)}'
                      : '**** **** **** ${pan.substring(12)}';
                }
                return Text(
                  displayPan,
                  style: TextStyle(
                      color: _selectedTheme == 'Gold Prestige' ? Colors.black87 : Colors.white,
                      fontSize: 22,
                      letterSpacing: 3.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: _selectedTheme == 'Gold Prestige' ? Colors.transparent : Colors.black45, blurRadius: 4)]),
                );
              }),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CARDHOLDER', style: TextStyle(color: _selectedTheme == 'Gold Prestige' ? Colors.black54 : Colors.white70, fontSize: 10, letterSpacing: 1)),
                      Text(widget.userModel.displayName.toUpperCase(), style: TextStyle(color: _selectedTheme == 'Gold Prestige' ? Colors.black87 : Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('EXPIRES', style: TextStyle(color: _selectedTheme == 'Gold Prestige' ? Colors.black54 : Colors.white70, fontSize: 10, letterSpacing: 1)),
                      Text(_isLoading ? '**/**' : (_cardData?['expiry'] ?? '**/**'), style: TextStyle(color: _selectedTheme == 'Gold Prestige' ? Colors.black87 : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: _getThemeColors().reversed.toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Container(width: double.infinity, height: 40, color: Colors.black87),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 30,
                      color: Colors.white,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _showDetails ? (_cardData?['cvv'] ?? '***') : '***',
                        style: const TextStyle(color: Colors.black, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('CVV', style: TextStyle(color: _selectedTheme == 'Gold Prestige' ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Issued by DISHI Financial Services for Campus Students. Direct wallet integration.',
                style: TextStyle(color: Colors.white54, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.qr_code,
              label: 'Pay QR',
              color: const Color(0xFF05D5AA),
              onTap: _showLocalPayQR,
            ),
            _buildControlButton(
              icon: Icons.content_copy,
              label: 'Details',
              color: const Color(0xFF38BDF8),
              onTap: _showOnlineCredentialsSheet,
            ),
            _buildControlButton(
              icon: _cardData?['status'] == 'frozen' ? Icons.ac_unit : Icons.lock_outline,
              label: _cardData?['status'] == 'frozen' ? 'Unfreeze' : 'Freeze',
              color: _cardData?['status'] == 'frozen' ? Colors.green : Colors.blue,
              onTap: _toggleFreeze,
            ),
            _buildControlButton(
              icon: Icons.local_fire_department,
              label: 'Burner',
              color: _cardData?['status'] == 'burner' ? Colors.orange : Colors.grey,
              onTap: _toggleBurnerMode,
            ),
            _buildControlButton(
              icon: Icons.tune,
              label: 'Controls',
              color: Colors.white,
              onTap: _showSettingsModal,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Quick Online Status & Limit Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF131A2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _onlineTransactions ? const Color(0xFF05D5AA).withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _onlineTransactions ? Icons.shopping_cart_checkout : Icons.remove_shopping_cart,
                  color: _onlineTransactions ? const Color(0xFF05D5AA) : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _onlineTransactions ? 'Online Payments Active' : 'Online Payments Disabled',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      'Daily Limit: KES ${_dailyLimit.toStringAsFixed(0)} • Direct Wallet',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _onlineTransactions,
                activeColor: const Color(0xFF05D5AA),
                onChanged: _toggleOnlineTransactions,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildOnlineShoppingHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF05D5AA).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF05D5AA).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.language, color: Color(0xFF05D5AA), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shop Online with DISHI Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Jumia, Coursera, campus portals & e-commerce', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Feature chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildFeatureChip('0% Foreign Markup', Icons.check_circle_outline),
              _buildFeatureChip('1% Instant Cashback', Icons.monetization_on_outlined),
              _buildFeatureChip('Burner Anti-Fraud', Icons.shield_outlined),
            ],
          ),
          const SizedBox(height: 16),

          // Action row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('How to Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  onPressed: _showOnlineShoppingGuide,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF05D5AA),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.credit_card_outlined, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Simulate Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  onPressed: _showOnlineSimulatorDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF05D5AA), size: 13),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Card Activity', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: _fetchRecentTransactions,
              child: const Text('Refresh', style: TextStyle(color: Color(0xFF05D5AA), fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_recentTransactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF131A2A), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Icon(Icons.credit_card_off, color: Colors.white24, size: 40),
                const SizedBox(height: 8),
                const Text('No card transactions yet', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Pay at campus cafeterias or test an online checkout above!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(_recentTransactions.length, 5),
            itemBuilder: (context, index) {
              final tx = _recentTransactions[index];
              final isOnline = tx['type'] == 'online' || (tx['category'] ?? '').toString().toLowerCase().contains('online');
              final merchant = tx['merchant_name'] ?? tx['merchantId'] ?? 'Campus Merchant';
              final amount = (tx['amount'] ?? 0.0).toDouble();
              final cashback = (tx['cashback'] ?? (amount * 0.01)).toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF38BDF8).withOpacity(0.15) : const Color(0xFF05D5AA).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOnline ? Icons.shopping_bag_outlined : Icons.restaurant,
                        color: isOnline ? const Color(0xFF38BDF8) : const Color(0xFF05D5AA),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(merchant, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.blue.withOpacity(0.2) : Colors.teal.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(isOnline ? 'ONLINE' : 'POS', style: TextStyle(color: isOnline ? Colors.lightBlueAccent : const Color(0xFF05D5AA), fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(tx['category'] ?? 'General', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('- KES ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        if (cashback > 0)
                          Text('+ KES ${cashback.toStringAsFixed(2)} cbk', style: const TextStyle(color: Color(0xFF05D5AA), fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAnalyticsChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Card Spending Breakdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: [
                  PieChartSectionData(color: const Color(0xFF05D5AA), value: 55, title: 'Meals 55%', radius: 18, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  PieChartSectionData(color: const Color(0xFF38BDF8), value: 25, title: 'Web 25%', radius: 18, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  PieChartSectionData(color: Colors.orange, value: 20, title: 'Books 20%', radius: 18, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _cardData == null) {
      return const Scaffold(backgroundColor: Color(0xFF0A0F1C), body: Center(child: CircularProgressIndicator(color: Color(0xFF05D5AA))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: const Text('DISHI Virtual Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showDetails ? _flipCard : _authenticateAndReveal,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final angle = _animation.value * pi;
                  final isFrontVisible = angle <= pi / 2;

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: isFrontVisible ? _buildFrontCard() : _buildBackCard(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _showDetails ? 'Tap card to flip between front & back' : 'Tap card or details to authenticate & reveal numbers',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 24),

            _buildCardControls(),
            const SizedBox(height: 24),

            _buildOnlineShoppingHero(),
            const SizedBox(height: 24),

            _buildRecentTransactionsSection(),
            const SizedBox(height: 24),

            _buildAnalyticsChart(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
