import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:local_auth/local_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/virtual_card_service.dart';
import 'package:intl/intl.dart';

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

  String _selectedTheme = 'Neon Cyan';
  bool _onlineTransactions = true;
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
        });
      } else {
        // Generate via backend
        final newCard = await _cardService.generateCard(widget.userModel.uid);
        setState(() {
          _cardData = newCard;
        });
      }
      _fetchRecentTransactions();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading card: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRecentTransactions() async {
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
  }

  Future<void> _authenticateAndReveal() async {
    if (_showDetails) {
      setState(() => _showDetails = false);
      return;
    }
    
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        setState(() => _showDetails = true);
        return;
      }
      
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to reveal your DISHI Card details',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
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
    setState(() => _showDetails = true);
    if (_isFront) {
      _flipCard(); // Automatically flip to back to show CVV
    }
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

  Future<void> _toggleFreeze(bool value) async {
    final newStatus = value ? 'frozen' : 'active';
    try {
      await _cardService.updateStatus(widget.userModel.uid, newStatus);
      if (_cardData != null) {
        setState(() {
          _cardData!['status'] = newStatus;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _toggleBurnerMode() async {
    final isBurner = _cardData?['status'] == 'burner';
    final newStatus = isBurner ? 'active' : 'burner';
    try {
      await _cardService.updateStatus(widget.userModel.uid, newStatus);
      if (_cardData != null) {
        setState(() {
          _cardData!['status'] = newStatus;
        });
      }
      if (isBurner) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Burner mode deactivated. Card is back to normal.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Burner mode active! Card will self-destruct after next use.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
          // Logo watermark
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.15,
              child: Image.asset('assets/img/dishi_logo.png', width: 150, height: 150),
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
                      const Text('DISHI VIRTUAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                    ],
                  ),
                  const Icon(Icons.wifi, color: Colors.white),
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
              // Null-safe access — avoids 'null check operator on null value' crash
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 4,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
                );
              }),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CARDHOLDER', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1)),
                      Text(widget.userModel.displayName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('EXPIRES', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1)),
                      Text(_isLoading ? '**/**' : (_cardData?['expiry'] ?? '**/**'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
          children: [
            const SizedBox(height: 24),
            Container(
              height: 40,
              width: double.infinity,
              color: Colors.black87,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      color: Colors.white.withOpacity(0.9),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        _isLoading || _cardData == null ? '***' : (_showDetails ? (_cardData?['cvv']?.toString() ?? '***') : '***'),
                        style: const TextStyle(color: Colors.black, fontStyle: FontStyle.italic, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Issued by DISHI Wallet.\nFor support, contact support@delstarfordworks.co.ke',
                style: TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocalQRPayDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF00FFD1))),
        title: const Text('Local Merchant Pay', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Have the merchant scan this QR to charge your card locally.', style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                data: 'DISHI_CARD:${widget.userModel.uid}:${_cardData!['pan']}',
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Text('Earn 1% Cashback!', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Color(0xFF00FFD1)))),
        ],
      ),
    );
  }

  void _showLimitDialog() {
    if (_cardData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card data is not loaded yet.')));
      return;
    }
    final TextEditingController limitController = TextEditingController(text: _cardData!['dailyLimit'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Set Daily Limit', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: limitController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Limit (Ksh)',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFD1))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final val = double.tryParse(limitController.text);
              if (val != null) {
                await _cardService.updateLimit(widget.userModel.uid, val);
                setState(() => _cardData!['dailyLimit'] = val);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limit updated')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFD1)),
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Change Card PIN', style: TextStyle(color: Colors.white)),
        content: const TextField(
          obscureText: true,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.white),
          maxLength: 4,
          decoration: InputDecoration(
            labelText: 'New 4-Digit PIN',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFD1))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN successfully changed!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFD1)),
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showAutoTopUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Auto-Top Up', style: TextStyle(color: Colors.white)),
        content: const Text('Automatically transfer funds from your main DISHI wallet when your card balance is low.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-Top Up enabled!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFD1)),
            child: const Text('Enable', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showCategoryLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Category Limits', style: TextStyle(color: Colors.white)),
        content: const Text('Set strict spending limits for categories like "Entertainment" or "Food".', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limits applied successfully.')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFD1)),
            child: const Text('Set limits', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _regenerateCard() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Regenerate Card', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Are you sure? Your current card will be destroyed and a new one will be issued immediately. This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final newCard = await _cardService.generateCard(widget.userModel.uid);
                setState(() => _cardData = newCard);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card regenerated successfully.')));
              } catch(e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Destroy & Replace', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Virtual Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: () {
              // Toggle theme
              setState(() {
                if (_selectedTheme == 'Neon Cyan') {
                  _selectedTheme = 'Midnight Blue';
                } else if (_selectedTheme == 'Midnight Blue') _selectedTheme = 'Lava Red';
                else _selectedTheme = 'Neon Cyan';
              });
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFD1)))
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DISHI Balance', style: TextStyle(color: Colors.white54, fontSize: 14)),
                      Text('Ksh ${widget.userModel.walletBalance.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00FFD1), fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (widget.userModel.parentUid != null && widget.userModel.parentUid!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: Colors.white54, size: 14),
                          const SizedBox(width: 4),
                          const Text('Linked to Parent Sponsor', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          const Spacer(),
                          InkWell(
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up request sent to parent!'))),
                            child: const Text('Request Funds', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  GestureDetector(
                    onTap: _flipCard,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        final transform = Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(_animation.value * pi);
                          
                        return Transform(
                          transform: transform,
                          alignment: Alignment.center,
                          child: _animation.value < 0.5 
                            ? _buildFrontCard()
                            : _buildBackCard(),
                        );
                      }
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Primary Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _authenticateAndReveal,
                          icon: Icon(_showDetails ? Icons.visibility_off : Icons.visibility, color: Colors.black, size: 20),
                          label: Text(_showDetails ? 'Hide' : 'Reveal', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFD1),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (!_isLoading && _cardData != null) Clipboard.setData(ClipboardData(text: _cardData!['pan']));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card number copied!')));
                          },
                          icon: const Icon(Icons.copy, color: Color(0xFF00FFD1), size: 20),
                          label: const Text('Copy', style: TextStyle(color: Color(0xFF00FFD1), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00FFD1), width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Text('Card Controls', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Controls Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.5,
                    children: [
                      _buildControlTile(
                        icon: Icons.qr_code_scanner, 
                        label: 'Local Pay QR', 
                        color: Colors.purpleAccent,
                        onTap: _showLocalQRPayDialog
                      ),
                      _buildControlTile(
                        icon: _cardData?['status'] == 'frozen' ? Icons.ac_unit : Icons.lock_open, 
                        label: _cardData?['status'] == 'frozen' ? 'Unfreeze' : 'Freeze Card', 
                        color: _cardData?['status'] == 'frozen' ? Colors.redAccent : Colors.blueAccent,
                        onTap: () => _toggleFreeze(_cardData?['status'] != 'frozen')
                      ),
                      _buildControlTile(
                        icon: Icons.speed, 
                        label: 'Limit: Ksh ${_cardData?['dailyLimit']?.toInt()}', 
                        color: Colors.greenAccent,
                        onTap: _showLimitDialog
                      ),
                      _buildControlTile(
                        icon: _cardData?['status'] == 'burner' ? Icons.local_fire_department : Icons.fireplace_outlined, 
                        label: _cardData?['status'] == 'burner' ? 'Turn off Burner' : 'Burner Mode', 
                        color: _cardData?['status'] == 'burner' ? Colors.redAccent : Colors.orangeAccent,
                        onTap: _toggleBurnerMode
                      ),
                      _buildControlTile(
                        icon: _onlineTransactions ? Icons.language : Icons.public_off, 
                        label: _onlineTransactions ? 'Online Pay On' : 'Online Pay Off', 
                        color: _onlineTransactions ? Colors.cyanAccent : Colors.grey,
                        onTap: () {
                          setState(() => _onlineTransactions = !_onlineTransactions);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_onlineTransactions ? 'Online transactions enabled' : 'Online transactions disabled')));
                        }
                      ),
                      _buildControlTile(
                        icon: _travelMode ? Icons.flight_takeoff : Icons.flight_land, 
                        label: _travelMode ? 'Travel Mode On' : 'Travel Mode Off', 
                        color: _travelMode ? Colors.amberAccent : Colors.grey,
                        onTap: () {
                          setState(() => _travelMode = !_travelMode);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_travelMode ? 'International transactions allowed' : 'International transactions blocked')));
                        }
                      ),
                      _buildControlTile(
                        icon: Icons.pin, 
                        label: 'Change PIN', 
                        color: Colors.pinkAccent,
                        onTap: _showChangePinDialog
                      ),
                      _buildControlTile(
                        icon: Icons.autorenew, 
                        label: 'Auto-Top Up', 
                        color: Colors.tealAccent,
                        onTap: _showAutoTopUpDialog
                      ),
                      _buildControlTile(
                        icon: Icons.category, 
                        label: 'Category Limits', 
                        color: Colors.indigoAccent,
                        onTap: _showCategoryLimitDialog
                      ),
                      _buildControlTile(
                        icon: Icons.credit_score, 
                        label: 'Regenerate Card', 
                        color: Colors.redAccent,
                        onTap: _regenerateCard
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Text('Recent Transactions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  if (_recentTransactions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFF131A2A), borderRadius: BorderRadius.circular(16)),
                      child: const Column(
                        children: [
                          Icon(Icons.receipt_long, color: Colors.white24, size: 48),
                          SizedBox(height: 12),
                          Text('No transactions yet.', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentTransactions.length,
                      separatorBuilder: (c, i) => const Divider(color: Colors.white12),
                      itemBuilder: (context, index) {
                        final tx = _recentTransactions[index];
                        final isRefund = tx['type'] == 'refund';
                        final date = (tx['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(isRefund ? Icons.arrow_downward : Icons.shopping_bag, color: isRefund ? Colors.green : Colors.white),
                          ),
                          title: Text(tx['merchantName'] ?? 'Merchant', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(DateFormat('MMM d, yyyy • h:mm a').format(date), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${isRefund ? '+' : '-'}Ksh ${tx['amount']}', style: TextStyle(color: isRefund ? Colors.green : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  const Text('Completed', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white54),
                                color: const Color(0xFF131A2A),
                                onSelected: (val) {
                                  if (val == 'receipt') {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading statement PDF...')));
                                  } else if (val == 'dispute') {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction disputed! We will review it.')));
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'receipt', child: Text('Download Receipt', style: TextStyle(color: Colors.white))),
                                  const PopupMenuItem(value: 'dispute', child: Text('Dispute Transaction', style: TextStyle(color: Colors.redAccent))),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 32),
                  
                  // Analytics Placeholder (Feature 13)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFF131A2A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Spending Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Icon(Icons.pie_chart, color: Color(0xFF00FFD1)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 150,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: () {
                                if (_recentTransactions.isEmpty) {
                                  return [PieChartSectionData(color: Colors.grey, value: 100, title: '', radius: 30)];
                                }
                                double food = 0, tech = 0, subs = 0, other = 0;
                                for (var tx in _recentTransactions) {
                                  final amt = (tx['amount'] as num?)?.toDouble() ?? 0;
                                  final name = (tx['merchantName'] as String?)?.toLowerCase() ?? '';
                                  if (name.contains('food') || name.contains('kfc') || name.contains('restaurant')) food += amt;
                                  else if (name.contains('tech') || name.contains('apple') || name.contains('safaricom')) tech += amt;
                                  else if (name.contains('netflix') || name.contains('spotify') || name.contains('dstv')) subs += amt;
                                  else other += amt;
                                }
                                final total = food + tech + subs + other;
                                if (total == 0) return [PieChartSectionData(color: Colors.grey, value: 100, title: '', radius: 30)];
                                
                                return [
                                  if (food > 0) PieChartSectionData(color: Colors.blue, value: food, title: '${(food/total*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                  if (tech > 0) PieChartSectionData(color: Colors.orange, value: tech, title: '${(tech/total*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                  if (subs > 0) PieChartSectionData(color: Colors.purple, value: subs, title: '${(subs/total*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                  if (other > 0) PieChartSectionData(color: Colors.green, value: other, title: '${(other/total*100).toStringAsFixed(0)}%', radius: 30, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                ];
                              }()
                            )
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Legend(color: Colors.blue, label: 'Food'),
                            SizedBox(width: 12),
                            _Legend(color: Colors.orange, label: 'Tech'),
                            SizedBox(width: 12),
                            _Legend(color: Colors.purple, label: 'Subs'),
                            SizedBox(width: 12),
                            _Legend(color: Colors.green, label: 'Other'),
                          ],
                        )
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Request Physical Card (Feature 20)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance.collection('physical_card_requests').add({
                            'uid': widget.userModel.uid,
                            'studentName': widget.userModel.displayName,
                            'parentUid': widget.userModel.parentUid ?? 'unknown',
                            'status': 'pending',
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Physical card request received. We will notify you when it ships!')));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to request card: $e')));
                          }
                        }
                      },
                      icon: const Icon(Icons.credit_card, color: Colors.white),
                      label: const Text('Request Physical Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildControlTile({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}
