import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/admin_service.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class FraudVelocityView extends StatefulWidget {
  const FraudVelocityView({super.key});

  @override
  State<FraudVelocityView> createState() => _FraudVelocityViewState();
}

class _FraudVelocityViewState extends State<FraudVelocityView> {
  final AdminService _adminService = AdminService();
  List<dynamic> _flaggedUsers = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, wash_trading, velocity_spike, critical

  @override
  void initState() {
    super.initState();
    _fetchFlags();
  }

  Future<void> _fetchFlags() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final flags = await _adminService.getFraudFlags();
      if (mounted) {
        setState(() {
          _flaggedUsers = flags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _takeAction(Map<String, dynamic> flag, String action) async {
    final userId = (flag['user_id'] ?? '').toString();
    final flagId = (flag['id'] ?? flag['flag_id'] ?? userId).toString();
    final userName = flag['name'] ?? userId;

    try {
      if (action == 'Shadow Ban') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardColor,
            title: const Text('Confirm Account Suspension', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              'Are you sure you want to suspend / shadow-ban $userName ($userId)?\n\nThey will be blocked from transacting and earning commissions.',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonRed, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Suspend Account'),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        await _adminService.suspendUser(userId, 'Wash trading & fraud velocity violation');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account for $userName suspended successfully.'), backgroundColor: Colors.green),
          );
        }
      } else {
        // Dismiss flag
        try {
          await _adminService.dismissFraudFlag(flagId);
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Flag dismissed for $userName.'), backgroundColor: _neonCyan),
          );
        }
      }

      setState(() {
        _flaggedUsers.removeWhere((v) => (v['id'] == flagId || v['user_id'] == userId));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed),
        );
      }
    }
  }

  void _showUserProfileModal(Map<String, dynamic> flag) {
    final name = flag['name'] ?? 'User Profile';
    final role = (flag['role'] ?? 'user').toString().toUpperCase();
    final photoUrl = flag['photo_url']?.toString() ?? '';
    final email = flag['email']?.toString() ?? '';
    final phone = flag['phone']?.toString() ?? '';
    final uid = flag['user_id']?.toString() ?? '';
    final balance = (flag['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    final campus = flag['campus']?.toString() ?? 'Main Campus';
    final status = flag['status']?.toString() ?? 'active';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            _buildAvatar(photoUrl, name, size: 70),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRoleBadge(role),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status == 'active' ? Colors.green.withOpacity(0.15) : _neonRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: status == 'active' ? Colors.greenAccent : _neonRed, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildProfileRow(Icons.fingerprint, 'User ID', uid, canCopy: true),
                  const Divider(color: Colors.white10, height: 16),
                  _buildProfileRow(Icons.email_outlined, 'Email', email.isNotEmpty ? email : 'Not Provided'),
                  const Divider(color: Colors.white10, height: 16),
                  _buildProfileRow(Icons.phone_outlined, 'M-PESA Phone', phone.isNotEmpty ? phone : 'Not Provided', canCopy: true),
                  const Divider(color: Colors.white10, height: 16),
                  _buildProfileRow(Icons.location_on_outlined, 'Campus / Location', campus),
                  const Divider(color: Colors.white10, height: 16),
                  _buildProfileRow(Icons.account_balance_wallet_outlined, 'Wallet Balance', 'KES ${balance.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _takeAction(flag, 'Dismiss');
                    },
                    child: const Text('Dismiss Flag', style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _takeAction(flag, 'Shadow Ban');
                    },
                    child: const Text('Shadow Ban User', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value, {bool canCopy = false}) {
    return Row(
      children: [
        Icon(icon, color: _neonCyan, size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
        if (canCopy && value.isNotEmpty) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 1)),
              );
            },
            child: const Icon(Icons.copy, color: _textSecondary, size: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar(String? photoUrl, String name, {double size = 44}) {
    if (photoUrl != null && photoUrl.trim().isNotEmpty && photoUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(name, size),
        ),
      );
    }
    return _buildFallbackAvatar(name, size);
  }

  Widget _buildFallbackAvatar(String name, double size) {
    final initials = name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_neonBlue, _neonCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: size * 0.4),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color = _neonBlue;
    if (role.toLowerCase().contains('vendor')) color = _neonOrange;
    if (role.toLowerCase().contains('student')) color = _neonCyan;
    if (role.toLowerCase().contains('staff')) color = Colors.purpleAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(role.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _flaggedUsers.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final uid = (u['user_id'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      final reason = (u['reason'] ?? '').toString().toLowerCase();
      final category = (u['category'] ?? '').toString().toLowerCase();
      final risk = (u['risk_score'] as num?)?.toInt() ?? 0;

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          uid.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          reason.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_selectedFilter == 'wash_trading') return category == 'wash_trading';
      if (_selectedFilter == 'velocity_spike') return category == 'velocity_spike';
      if (_selectedFilter == 'critical') return risk >= 80;
      return true;
    }).toList();

    final washCount = _flaggedUsers.where((u) => u['category'] == 'wash_trading').length;
    final criticalCount = _flaggedUsers.where((u) => ((u['risk_score'] as num?) ?? 0) >= 80).length;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Fraud & Wash Trading Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            tooltip: 'Refresh Radar',
            onPressed: _fetchFlags,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // KPI Summary Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Flags', '${_flaggedUsers.length}', Icons.shield_outlined, _neonBlue)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Wash Trading', '$washCount', Icons.swap_horiz, _neonOrange)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Critical Risk', '$criticalCount', Icons.warning_amber_rounded, _neonRed)),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search Name, User ID, Phone, or Reason...',
                  hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: _surfaceLight,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, color: _textSecondary, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Flags (${_flaggedUsers.length})'),
                  _buildFilterChip('wash_trading', 'Wash Trading ($washCount)'),
                  _buildFilterChip('critical', 'Critical Risk ($criticalCount)'),
                  _buildFilterChip('velocity_spike', 'Velocity Spikes'),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Flags List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _neonRed))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: _neonRed, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                                onPressed: _fetchFlags,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_user_outlined, color: _neonCyan.withOpacity(0.5), size: 56),
                                  const SizedBox(height: 12),
                                  const Text('No flagged wash trading activities detected.', style: TextStyle(color: _textSecondary)),
                                  const SizedBox(height: 4),
                                  const Text('All campus transactions conform to 1:1 integrity standards.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final flag = filtered[idx] as Map<String, dynamic>;
                                return _buildFlagCard(flag);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        selected: isSelected,
        selectedColor: _neonCyan,
        backgroundColor: _surfaceLight,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onSelected: (val) => setState(() => _selectedFilter = filterKey),
      ),
    );
  }

  Widget _buildFlagCard(Map<String, dynamic> flag) {
    final uid = (flag['user_id'] ?? '').toString();
    final name = (flag['name'] ?? 'Comrade').toString();
    final email = flag['email']?.toString() ?? '';
    final phone = flag['phone']?.toString() ?? '';
    final photoUrl = flag['photo_url']?.toString();
    final role = (flag['role'] ?? 'user').toString();
    final reason = flag['reason'] ?? 'Suspicious Activity';
    final desc = flag['description'] ?? '';
    final riskScore = (flag['risk_score'] as num?)?.toInt() ?? 50;
    final txCount = flag['recent_tx_count'] ?? 1;
    final vendorName = flag['vendor_name']?.toString();

    final isCritical = riskScore >= 80;
    final isHigh = riskScore >= 60;
    final severityColor = isCritical ? _neonRed : (isHigh ? _neonOrange : Colors.amberAccent);

    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: severityColor.withOpacity(isCritical ? 0.6 : 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: User Avatar, Name, Role, and Risk Score
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(photoUrl, name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildRoleBadge(role),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('ID: ${uid.length > 12 ? '${uid.substring(0, 12)}...' : uid}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: uid));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User ID copied'), duration: Duration(seconds: 1)),
                              );
                            },
                            child: const Icon(Icons.copy, color: _textSecondary, size: 12),
                          ),
                        ],
                      ),
                      if (phone.isNotEmpty || email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          [phone, email].where((s) => s.isNotEmpty).join(' • '),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: severityColor.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Text('$riskScore/100', style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(isCritical ? 'CRITICAL' : 'RISK', style: TextStyle(color: severityColor, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Anomaly Description Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: severityColor, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar, color: severityColor, size: 14),
                      const SizedBox(width: 6),
                      Text(reason, style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      const Spacer(),
                      Text('$txCount Txs', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  if (vendorName != null && vendorName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Linked Cafeteria / Kiosk: $vendorName',
                      style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showUserProfileModal(flag),
                  icon: const Icon(Icons.person_search, color: _neonCyan, size: 16),
                  label: const Text('View Profile', style: TextStyle(color: _neonCyan, fontSize: 12)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _takeAction(flag, 'Dismiss'),
                  child: const Text('Dismiss', style: TextStyle(color: _textSecondary, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _takeAction(flag, 'Shadow Ban'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.block, size: 14),
                  label: const Text('Shadow Ban', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
