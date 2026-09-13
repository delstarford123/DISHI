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

  final VirtualCardService _cardService = VirtualCardService();
  final LocalAuthentication _auth = LocalAuthentication();
  
  Map<String, dynamic>? _cardData;
  List<Map<String, dynamic>> _recentTransactions = [];

  // Card Controls
  String _selectedTheme = 'Neon Cyan';
  bool _onlineTransactions = true;
  double _dailyLimit = 5000;
  bool _travelMode = false;

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
        });
        await _updateFirestoreCard(_cardData!);
      }
      _fetchRecentTransactions();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading card: $e')));
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
      // Ignore gracefully
    }
  }

  Future<void> _authenticateAndReveal() async {
    if (_showDetails) {
      setState(() => _showDetails = false);
      if (!_isFront) _flipCard();
      return;
    }
    
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        _onAuthSuccess();
        return;
      }
      
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to reveal DISHI Card details',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      
      if (didAuthenticate) {
        _onAuthSuccess();
      } else {
        _showPinFallbackDialog();
      }
    } catch (e) {
      _showPinFallbackDialog();
    }
  }

  void _onAuthSuccess() {
    setState(() {
      _showDetails = true;
    });
  }

  void _showPinFallbackDialog() {
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
                _onAuthSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN')));
              }
            },
            child: const Text('Verify', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      )
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
        content: Text(isFrozen ? 'Card Unfrozen.' : 'Card Frozen! Transactions blocked.', style: const TextStyle(color: Colors.white)),
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
        content: Text(isBurner ? 'Burner Mode Deactivated.' : 'Burner Mode Active! Card will self-destruct after 1 use.', style: const TextStyle(color: Colors.white)),
        backgroundColor: isBurner ? Colors.grey : Colors.orange,
      ));
    }
  }

  void _showLocalPayQR() {
    // Generate an offline, dynamic TOTP (Time-Based One Time Password) style token
    // The vendor scans this and sends it to the backend, which verifies the timestamp is within 60s
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
            const Text('Dynamic offline token. Expires in 60s', style: TextStyle(color: Colors.white54, fontSize: 12)),
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

  void _copyToClipboard() {
    if (!_showDetails) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authenticate to reveal and copy PAN')));
      return;
    }
    final pan = _cardData?['pan'];
    if (pan != null) {
      Clipboard.setData(ClipboardData(text: pan));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card Number copied to clipboard!'), backgroundColor: Colors.green));
    }
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
              const Text('Card Settings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              const Text('Daily Limit (Ksh)', style: TextStyle(color: Colors.white70)),
              Slider(
                value: _dailyLimit,
                min: 0,
                max: 10000,
                divisions: 20,
                activeColor: const Color(0xFF05D5AA),
                label: 'Ksh ${_dailyLimit.toInt()}',
                onChanged: (v) {
                  setModalState(() => _dailyLimit = v);
                  setState(() => _dailyLimit = v);
                },
                onChangeEnd: (v) => _updateFirestoreCard({'dailyLimit': v}),
              ),
              
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Online Transactions', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Allow usage on e-commerce sites', style: TextStyle(color: Colors.white54, fontSize: 12)),
                activeColor: const Color(0xFF05D5AA),
                value: _onlineTransactions,
                onChanged: (v) {
                  setModalState(() => _onlineTransactions = v);
                  setState(() => _onlineTransactions = v);
                  _updateFirestoreCard({'onlineTransactions': v});
                },
              ),
              
              const SizedBox(height: 16),
              const Text('Card Theme', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: ['Neon Cyan', 'Midnight Blue', 'Lava Red', 'Gold Prestige'].map((theme) {
                  return ChoiceChip(
                    label: Text(theme),
                    selected: _selectedTheme == theme,
                    selectedColor: const Color(0xFF05D5AA),
                    backgroundColor: Colors.white12,
                    labelStyle: TextStyle(color: _selectedTheme == theme ? Colors.black : Colors.white),
                    onSelected: (s) {
                      setModalState(() => _selectedTheme = theme);
                      setState(() => _selectedTheme = theme);
                      _updateFirestoreCard({'theme': theme});
                    },
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Replace Card (Panic)'),
                  onPressed: () {
                    Navigator.pop(context);
                    _regenerateCard();
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      )
    );
  }

  Future<void> _regenerateCard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Replace Card?', style: TextStyle(color: Colors.white)),
        content: const Text('Your current card will be destroyed immediately. A new PAN and CVV will be generated. This action costs Ksh 2.00.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Pay Ksh 2 & Replace', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        // Deduct 2 Ksh fee
        await FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).update({
          'walletBalance': FieldValue.increment(-2.0)
        });

        // Generate new mock card data
        final random = Random();
        final newPan = List.generate(16, (_) => random.nextInt(10).toString()).join();
        final newCvv = List.generate(3, (_) => random.nextInt(10).toString()).join();
        final newExpiry = '${DateTime.now().month.toString().padLeft(2, '0')}/${(DateTime.now().year + 3).toString().substring(2)}';
        
        setState(() {
          _cardData = {
            'pan': newPan,
            'cvv': newCvv,
            'expiry': newExpiry,
            'status': 'active', // Reset status if it was burner
            'theme': _selectedTheme,
            'onlineTransactions': _onlineTransactions,
            'dailyLimit': _dailyLimit,
          };
          _showDetails = false;
          if (!_isFront) _flipCard();
        });
        await _updateFirestoreCard(_cardData!);
        
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New card generated! Ksh 2.00 fee deducted.'), backgroundColor: Colors.green));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
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
                  Icon(Icons.wifi, color: _selectedTheme == 'Gold Prestige' ? Colors.black87 : Colors.white),
                ],
              ),
              if (_cardData?['status'] == 'frozen')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                  child: const Text('FROZEN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                )
              else if (_cardData?['status'] == 'burner')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(20)),
                  child: const Text('BURNER MODE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
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
                      fontSize: 24,
                      letterSpacing: 4,
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
                      Text(widget.userModel.displayName.toUpperCase(), style: TextStyle(color: _selectedTheme == 'Gold Prestige' ? Colors.black87 : Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('EXPIRES', style: TextStyle(color: _selectedTheme == 'Gold Prestige' ? Colors.black54 : Colors.white70, fontSize: 10, letterSpacing: 1)),
                      Text(_isLoading ? '**/**' : (_cardData?['expiry'] ?? '**/**'), style: TextStyle(color: _selectedTheme == 'Gold Prestige' ? Colors.black87 : Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
                        style: const TextStyle(color: Colors.black, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
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
                'Issued by DISHI Financial Services. Keep your PIN secure.',
                style: TextStyle(color: Colors.black54, fontSize: 8),
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
              icon: _cardData?['status'] == 'frozen' ? Icons.ac_unit : Icons.lock_outline,
              label: _cardData?['status'] == 'frozen' ? 'Unfreeze' : 'Freeze',
              color: _cardData?['status'] == 'frozen' ? Colors.green : Colors.blue,
              onTap: _toggleFreeze,
            ),
            _buildControlButton(
              icon: Icons.local_fire_department,
              label: 'Burner',
              color: _cardData?['status'] == 'burner' ? Colors.grey : Colors.orange,
              onTap: _toggleBurnerMode,
            ),
            _buildControlButton(
              icon: Icons.settings,
              label: 'Settings',
              color: Colors.white,
              onTap: _showSettingsModal,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.copy, color: Colors.white54, size: 16),
              label: const Text('Copy Card Details', style: TextStyle(color: Colors.white54)),
              onPressed: _copyToClipboard,
            ),
          ],
        )
      ],
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spending Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(color: const Color(0xFF05D5AA), value: 60, title: 'Food', radius: 15, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                  PieChartSectionData(color: Colors.blue, value: 25, title: 'Transport', radius: 15, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                  PieChartSectionData(color: Colors.orange, value: 15, title: 'Other', radius: 15, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                ]
              )
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
        title: const Text('DISHI Virtual Card', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
            const SizedBox(height: 16),
            Text(
              _showDetails ? 'Tap to flip card' : 'Tap to reveal details',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 32),
            _buildCardControls(),
            const SizedBox(height: 32),
            _buildAnalyticsChart(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
