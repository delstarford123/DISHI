import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trust_onboarding_view.dart';
import 'package:url_launcher/url_launcher.dart';

class RoleSelectionView extends StatefulWidget {
  final List<String>? initialRoles;
  final bool isEditing;

  const RoleSelectionView({
    super.key,
    this.initialRoles,
    this.isEditing = false,
  });

  @override
  State<RoleSelectionView> createState() => _RoleSelectionViewState();
}

class _RoleSelectionViewState extends State<RoleSelectionView> with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  bool _isPhoneFocused = false;
  bool _isLoading = false;

  late String _selectedRoleId;

  final List<Map<String, dynamic>> _roles = [
    {
      'id': 'student',
      'title': 'Student',
      'tag': 'Campus Comrade',
      'badge': 'Smart Wallet & Eats',
      'desc': 'Order food, split bills, and connect on UniUptown with peer-to-peer campus perks.',
      'perks': ['0% Fee Student Wallet', '50/50 Bill Splitting', 'Okoa Food & UniUptown'],
      'icon': Icons.school_rounded,
      'color': const Color(0xFF38BDF8),
      'gradient': [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
    },
    {
      'id': 'vendor',
      'title': 'Food Vendor',
      'tag': 'Merchant',
      'badge': 'Instant POS Payouts',
      'desc': 'Sell food, manage live pre-orders, and grow campus sales with instant M-PESA settlements.',
      'perks': ['Real-Time Orders POS', 'Direct M-PESA Payouts', 'Dynamic QR Code Pay'],
      'icon': Icons.storefront_rounded,
      'color': const Color(0xFFFB923C),
      'gradient': [const Color(0xFFFB923C), const Color(0xFFEA580C)],
    },
    {
      'id': 'driver',
      'title': 'Delivery Driver',
      'tag': 'Campus Courier',
      'badge': 'Flexible Shifts',
      'desc': 'Earn income delivering hot meals to students and staff across campus residences.',
      'perks': ['Earn per delivery run', 'Live GPS Navigation', 'Instant Daily Payouts'],
      'icon': Icons.two_wheeler_rounded,
      'color': const Color(0xFF10B981),
      'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
    },
    {
      'id': 'parent',
      'title': 'Parent / Guardian',
      'tag': 'Sponsor',
      'badge': 'Direct M-PESA Stash',
      'desc': 'Fund student wallets and monitor nourishment expenses with complete security.',
      'perks': ['1-Click STK Push Funding', 'Meal Allowance Budget', 'Emergency SOS Alerts'],
      'icon': Icons.family_restroom_rounded,
      'color': const Color(0xFFA855F7),
      'gradient': [const Color(0xFFA855F7), const Color(0xFF7C3AED)],
    },
    {
      'id': 'house_owner',
      'title': 'House Owner',
      'tag': 'Keja Host',
      'badge': 'Zero-Vacancy Host',
      'desc': 'List hostel units, connect with verified students, and manage rent effortlessly.',
      'perks': ['Verified Student Leads', 'Direct Rent Collection', 'Maintenance Requests'],
      'icon': Icons.apartment_rounded,
      'color': const Color(0xFF2DD4BF),
      'gradient': [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
    },
    {
      'id': 'fundi',
      'title': 'Fundi & Artisan',
      'tag': 'Campus Gigs',
      'badge': 'Escrow Protection',
      'desc': 'Offer repair, tech, and artisan services to students with secured escrow payments.',
      'perks': ['Campus Gig Marketplace', 'Escrow Payment Lock', 'Direct Client Calling'],
      'icon': Icons.handyman_rounded,
      'color': const Color(0xFFFBBF24),
      'gradient': [const Color(0xFFFBBF24), const Color(0xFFD97706)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedRoleId = (widget.initialRoles != null && widget.initialRoles!.isNotEmpty)
        ? widget.initialRoles!.first
        : 'student';

    _phoneFocusNode.addListener(() {
      setState(() => _isPhoneFocused = _phoneFocusNode.hasFocus);
    });

    _loadExistingUserData();
  }

  Future<void> _loadExistingUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        String phone = user.phoneNumber!;
        if (phone.startsWith('+254')) {
          _phoneController.text = phone.substring(4);
        } else if (phone.startsWith('254')) {
          _phoneController.text = phone.substring(3);
        } else {
          _phoneController.text = phone;
        }
      } else {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data() ?? {};
            final savedPhone = (data['phoneNumber'] ?? data['phone']) as String?;
            if (savedPhone != null && savedPhone.isNotEmpty && _phoneController.text.isEmpty) {
              if (savedPhone.startsWith('+254')) {
                _phoneController.text = savedPhone.substring(4);
              } else if (savedPhone.startsWith('254')) {
                _phoneController.text = savedPhone.substring(3);
              } else {
                _phoneController.text = savedPhone;
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitRoles() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Please enter your phone number to continue.'),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Normalize phone number for Safaricom M-PESA
    String formattedPhone = rawPhone.replaceAll(RegExp(r'\s+'), '');
    if (!formattedPhone.startsWith('+254') && !formattedPhone.startsWith('254')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '254${formattedPhone.substring(1)}';
      } else if (formattedPhone.startsWith('7') || formattedPhone.startsWith('1')) {
        formattedPhone = '254$formattedPhone';
      }
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'roles': [_selectedRoleId],
          'phoneNumber': formattedPhone,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      if (widget.isEditing) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrustOnboardingView(role: _selectedRoleId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save role: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = _roles.firstWhere(
      (r) => r['id'] == _selectedRoleId,
      orElse: () => _roles.first,
    );

    // Split roles into 2 columns for the asymmetrical Bento Grid
    final col1Roles = [_roles[0], _roles[2], _roles[5]]; // Student, Driver, Fundi
    final col2Roles = [_roles[1], _roles[3], _roles[4]]; // Vendor, Parent, House Owner

    return Scaffold(
      backgroundColor: const Color(0xFF080C14), // Premium Obsidian
      body: Stack(
        children: [
          // Ambient Radial Light Mesh
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00FFD1).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      if (widget.isEditing)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        const SizedBox(width: 8),
                      const Spacer(),
                      // DISHI Network verified badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131A26),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFF00FFD1).withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00FFD1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF00FFD1),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'DISHI SMART CAMPUS',
                              style: TextStyle(
                                color: Color(0xFF00FFD1),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (widget.isEditing) const SizedBox(width: 40) else const SizedBox(width: 8),
                    ],
                  ),
                ),

                // Main Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Section Header
                        Text(
                          widget.isEditing ? 'Change Role' : 'Select Your Role',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap your profile to unlock tailored wallets, tools, and campus services.',
                          style: TextStyle(
                            color: Color(0xFF8B9BB4),
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── ASYMMETRICAL BENTO GRID ──────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Column 1
                            Expanded(
                              child: Column(
                                children: col1Roles.map((role) {
                                  return _buildBentoCard(role);
                                }).toList(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Column 2
                            Expanded(
                              child: Column(
                                children: col2Roles.map((role) {
                                  return _buildBentoCard(role);
                                }).toList(),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Active Role Spotlight Description
                        _buildRoleSpotlight(selectedRole),

                        const SizedBox(height: 20),

                        // ── INTEGRATED FROSTED PHONE INPUT PILL ─────────
                        const Text(
                          'M-PESA Phone Number',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF101726),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isPhoneFocused
                                  ? const Color(0xFF00FFD1)
                                  : Colors.white.withValues(alpha: 0.12),
                              width: _isPhoneFocused ? 1.5 : 1.0,
                            ),
                            boxShadow: _isPhoneFocused
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00FFD1).withValues(alpha: 0.18),
                                      blurRadius: 14,
                                    ),
                                  ]
                                : [],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: Row(
                            children: [
                              // Country code badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('🇰🇪', style: TextStyle(fontSize: 17)),
                                    SizedBox(width: 6),
                                    Text(
                                      '+254',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  focusNode: _phoneFocusNode,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '712 345 678',
                                    hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.verified_user_outlined,
                                color: Color(0xFF00FFD1),
                                size: 18,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── CTA SUBMISSION BUTTON ──────────────────────
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00FFD1), Color(0xFF10B981)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FFD1).withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitRoles,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF080C14),
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        widget.isEditing
                                            ? 'Save Profile Role'
                                            : 'Continue as ${selectedRole['title']}',
                                        style: const TextStyle(
                                          color: Color(0xFF080C14),
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Color(0xFF080C14),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.parse('https://dishi.delstarfordworks.co.ke/terms');
                                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11.5,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const Text(' • ', style: TextStyle(color: Colors.white38, fontSize: 11.5)),
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.parse('https://dishi.delstarfordworks.co.ke/privacy');
                                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11.5,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Security Trust note
                        const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, size: 12, color: Colors.white38),
                              SizedBox(width: 5),
                              Text(
                                'Direct M-PESA Daraja Integration • 256-Bit SSL',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BENTO CARD COMPONENT ──────────────────────────────────────────
  Widget _buildBentoCard(Map<String, dynamic> role) {
    final bool isSelected = role['id'] == _selectedRoleId;
    final Color roleColor = role['color'];
    final List<Color> gradient = role['gradient'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRoleId = role['id'];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF141D2D)
              : const Color(0xFF101726).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00FFD1) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00FFD1).withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 0.5,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Checkmark
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Glowing Icon Container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? gradient
                          : [gradient[0].withValues(alpha: 0.25), gradient[1].withValues(alpha: 0.15)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: roleColor.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    role['icon'],
                    color: isSelected ? Colors.white : roleColor,
                    size: 22,
                  ),
                ),

                // Selected Checkmark Badge
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FFD1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00FFD1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: Color(0xFF080C14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Micro Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                role['badge'].toString().toUpperCase(),
                style: TextStyle(
                  color: roleColor,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 6),

            // Role Title
            Text(
              role['title'],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 2),

            // Tagline
            Text(
              role['tag'],
              style: const TextStyle(
                color: Color(0xFF8B9BB4),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Expanded Perks List (Only on selected tile for clean Bento physics)
            if (isSelected) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (role['perks'] as List<String>).take(2).map((perk) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF00FFD1), size: 12),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              perk,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── SPOTLIGHT BAR ──────────────────────────────────────────────────
  Widget _buildRoleSpotlight(Map<String, dynamic> role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (role['color'] as Color).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (role['color'] as Color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.stars_rounded,
              color: role['color'] as Color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${role['title']} Experience',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role['desc'],
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
