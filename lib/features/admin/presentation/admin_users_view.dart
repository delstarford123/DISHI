import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../main.dart';

// -- CUSTOM EXECUTIVE THEME COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _allUsers = [];
  String _searchQuery = '';
  String _selectedRoleFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _adminService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback directly to Firestore if backend proxy fails
      try {
        final snap = await FirebaseFirestore.instance.collection('users').limit(150).get();
        final users = snap.docs.map((d) {
          final m = d.data();
          m['uid'] = d.id;
          return m;
        }).toList();

        if (mounted) {
          setState(() {
            _allUsers = users;
            _isLoading = false;
          });
        }
      } catch (err) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), backgroundColor: _neonCyan, duration: const Duration(seconds: 2)),
    );
  }

  // --- ADMIN ACTIONS ---

  void _showChangeRoleDialog(String userId, String currentRole) {
    String selectedRole = currentRole.toLowerCase();
    final allowedRoles = ['student', 'vendor', 'driver', 'caretaker', 'fundi', 'parent', 'admin'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonBlue, width: 1.5)),
          title: const Text('Change User Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User UID: $userId', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              const SizedBox(height: 16),
              const Text('Select target role:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allowedRoles.map((role) {
                  final isSel = selectedRole == role;
                  return ChoiceChip(
                    label: Text(role.toUpperCase(), style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: isSel,
                    selectedColor: _neonCyan,
                    backgroundColor: _surfaceLight,
                    onSelected: (val) {
                      if (val) setDialogState(() => selectedRole = role);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _adminService.updateUserRole(userId, selectedRole);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('User role updated to ${selectedRole.toUpperCase()}'), backgroundColor: _neonCyan),
                    );
                    _fetchUsers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Role Update Failed: $e'), backgroundColor: _neonRed),
                    );
                  }
                }
              },
              child: const Text('Confirm Role', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustBalanceDialog(String userId, double currentBalance) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    bool isCredit = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 1.5)),
          title: const Text('Adjust Wallet Balance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Balance: KES ${currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('+ CREDIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      selected: isCredit,
                      selectedColor: _neonCyan,
                      backgroundColor: _surfaceLight,
                      labelStyle: TextStyle(color: isCredit ? Colors.black : Colors.white),
                      onSelected: (val) => setDialogState(() => isCredit = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('- DEBIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      selected: !isCredit,
                      selectedColor: _neonRed,
                      backgroundColor: _surfaceLight,
                      labelStyle: TextStyle(color: !isCredit ? Colors.white : Colors.white70),
                      onSelected: (val) => setDialogState(() => isCredit = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Reason for Adjustment',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isCredit ? _neonCyan : _neonRed),
              onPressed: () async {
                final amountText = amountController.text.trim();
                final reason = reasonController.text.trim();
                final parsedAmount = double.tryParse(amountText);
                if (parsedAmount == null || parsedAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid positive amount')));
                  return;
                }
                Navigator.pop(context);
                final finalAmount = isCredit ? parsedAmount : -parsedAmount;
                try {
                  final newBal = await _adminService.adjustUserBalance(userId, finalAmount, reason.isEmpty ? 'Admin manual adjustment' : reason);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Balance updated. New Balance: KES ${newBal.toStringAsFixed(2)}'), backgroundColor: _neonCyan),
                    );
                    _fetchUsers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Balance Adjustment Failed: $e'), backgroundColor: _neonRed),
                    );
                  }
                }
              },
              child: Text(isCredit ? 'Apply Credit' : 'Apply Debit', style: TextStyle(color: isCredit ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuspendDialog(String userId, bool isCurrentlySuspended) {
    final TextEditingController reasonController = TextEditingController(text: isCurrentlySuspended ? '' : 'Violation of community safety terms');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isCurrentlySuspended ? _neonCyan : _neonRed, width: 1.5)),
        title: Text(isCurrentlySuspended ? 'Reactivate User Account' : 'Suspend User Account', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCurrentlySuspended
                  ? 'Reactivating will unfreeze the user auth credentials and allow them to log in.'
                  : 'Suspending will immediately revoke the user refresh tokens and block access.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (!isCurrentlySuspended) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Suspension Reason',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isCurrentlySuspended ? _neonCyan : _neonRed),
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (isCurrentlySuspended) {
                  await _adminService.unsuspendUser(userId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User reactivated successfully'), backgroundColor: _neonCyan));
                  }
                } else {
                  await _adminService.suspendUser(userId, reasonController.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User suspended successfully'), backgroundColor: _neonOrange));
                  }
                }
                _fetchUsers();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e'), backgroundColor: _neonRed));
                }
              }
            },
            child: Text(isCurrentlySuspended ? 'Reactivate' : 'Suspend', style: TextStyle(color: isCurrentlySuspended ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResetPinDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.amberAccent, width: 1.5)),
        title: const Text('Reset User Security PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will clear any failed attempt lockouts and flag the account to require a fresh PIN setup upon their next login.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _adminService.resetUserPin(userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN reset flag set for user'), backgroundColor: _neonCyan));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PIN Reset failed: $e'), backgroundColor: _neonRed));
                }
              }
            },
            child: const Text('Force Reset PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _impersonateUser(String userId) async {
    try {
      final token = await _adminService.impersonateUser(userId);
      await FirebaseAuth.instance.signInWithCustomToken(token);

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final uData = userDoc.data() ?? {};
      final rolesList = uData['roles'] as List<dynamic>? ?? [];
      final roleSingular = uData['role'] as String? ?? '';
      final userRole = rolesList.isNotEmpty ? rolesList.first.toString() : (roleSingular.isNotEmpty ? roleSingular : 'student');
      final userName = uData['name'] ?? uData['displayName'] ?? '';

      await SecureStorageService.saveUserData(
        userId: userId,
        role: userRole,
        name: userName,
        email: uData['email'],
        phone: uData['phoneNumber'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ghost login active. Redirecting...'), backgroundColor: _neonCyan));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const InitialRouter()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ghost Login Failed: $e'), backgroundColor: _neonRed));
      }
    }
  }

  void _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonRed, width: 2)),
        title: const Text('Delete User Account?', style: TextStyle(color: _neonRed, fontWeight: FontWeight.bold)),
        content: const Text(
          'Warning: This permanently removes the user from Firebase Auth and deletes their profile in Firestore. This action CANNOT be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('PERMANENTLY DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminService.deleteUser(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted successfully')));
          _fetchUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: _neonRed));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter users
    final filteredUsers = _allUsers.where((u) {
      final name = (u['name'] ?? u['displayName'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phoneNumber'] ?? u['phone'] ?? '').toString().toLowerCase();
      final uid = (u['uid'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? 'student').toString().toLowerCase();
      final status = (u['status'] ?? 'active').toString().toLowerCase();

      // Search match
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          uid.contains(_searchQuery);

      if (!matchesSearch) return false;

      // Role filter match
      if (_selectedRoleFilter == 'ALL') return true;
      if (_selectedRoleFilter == 'SUSPENDED') return status == 'suspended';
      return role == _selectedRoleFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('User & Identity Command', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            tooltip: 'Refresh Users',
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    // Search & Filters Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search by name, email, phone, or UID...',
                              hintStyle: const TextStyle(color: _textSecondary),
                              prefixIcon: const Icon(Icons.search, color: _textSecondary),
                              filled: true,
                              fillColor: _surfaceLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.toLowerCase().trim();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['ALL', 'STUDENT', 'VENDOR', 'DRIVER', 'CARETAKER', 'ADMIN', 'SUSPENDED'].map((filter) {
                                final isSel = _selectedRoleFilter == filter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(filter, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    selected: isSel,
                                    selectedColor: _neonCyan,
                                    backgroundColor: _surfaceLight,
                                    onSelected: (val) {
                                      if (val) setState(() => _selectedRoleFilter = filter);
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Metrics Banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${filteredUsers.length} of ${_allUsers.length} Users', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                          const Text('Tap user for actions', style: TextStyle(color: _neonCyan, fontSize: 11)),
                        ],
                      ),
                    ),

                    // Users List
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.person_search_rounded, color: _textSecondary, size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No matching users found.', style: TextStyle(color: _textSecondary)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                return _buildUserTile(user);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final uid = user['uid'] ?? user['id'] ?? '';
    final name = user['name'] ?? user['displayName'] ?? 'Unknown User';
    final email = user['email'] ?? 'No email';
    final phone = user['phoneNumber'] ?? user['phone'] ?? 'No phone';
    final role = (user['role'] ?? 'student').toString().toUpperCase();
    final status = (user['status'] ?? 'active').toString().toLowerCase();
    final isSuspended = status == 'suspended';
    final double balance = (user['walletBalance'] as num?)?.toDouble() ?? 0.0;
    final photoUrl = user['photoUrl'] ?? user['profilePic'] ?? user['photo'] ?? user['image'];

    Color roleColor = _neonCyan;
    if (role == 'VENDOR') roleColor = _neonOrange;
    if (role == 'ADMIN') roleColor = _neonRed;
    if (role == 'DRIVER') roleColor = Colors.purpleAccent;
    if (role == 'CARETAKER') roleColor = _neonBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSuspended ? _neonRed : _surfaceLight, width: isSuspended ? 1.5 : 1.0),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        collapsedIconColor: Colors.white70,
        iconColor: _neonCyan,
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _surfaceLight,
              backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty) ? NetworkImage(photoUrl.toString()) : null,
              child: (photoUrl == null || photoUrl.toString().isEmpty)
                  ? Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 16))
                  : null,
            ),
            if (isSuspended)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: _neonRed, shape: BoxShape.circle),
                  child: const Icon(Icons.block, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(role, style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(color: _textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bal: KES ${balance.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(
                  isSuspended ? 'SUSPENDED' : 'ACTIVE',
                  style: TextStyle(color: isSuspended ? _neonRed : Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _surfaceLight,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick info & copyable items
                Row(
                  children: [
                    Expanded(
                      child: Text('UID: $uid', style: const TextStyle(color: _textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: _textSecondary, size: 14),
                      tooltip: 'Copy UID',
                      onPressed: () => _copyToClipboard(uid, 'UID'),
                    ),
                  ],
                ),
                if (phone.isNotEmpty && phone != 'No phone')
                  Row(
                    children: [
                      Expanded(
                        child: Text('Phone: $phone', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: _textSecondary, size: 14),
                        tooltip: 'Copy Phone',
                        onPressed: () => _copyToClipboard(phone, 'Phone number'),
                      ),
                    ],
                  ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),

                // Action Buttons Matrix
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      backgroundColor: _cardColor,
                      avatar: const Icon(Icons.badge, color: _neonBlue, size: 16),
                      label: const Text('Change Role', style: TextStyle(color: Colors.white, fontSize: 11)),
                      onPressed: () => _showChangeRoleDialog(uid, role),
                    ),
                    ActionChip(
                      backgroundColor: _cardColor,
                      avatar: const Icon(Icons.account_balance_wallet, color: _neonCyan, size: 16),
                      label: const Text('Adjust Balance', style: TextStyle(color: Colors.white, fontSize: 11)),
                      onPressed: () => _showAdjustBalanceDialog(uid, balance),
                    ),
                    ActionChip(
                      backgroundColor: _cardColor,
                      avatar: Icon(isSuspended ? Icons.check_circle : Icons.block, color: isSuspended ? _neonCyan : _neonOrange, size: 16),
                      label: Text(isSuspended ? 'Reactivate' : 'Suspend', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      onPressed: () => _showSuspendDialog(uid, isSuspended),
                    ),
                    ActionChip(
                      backgroundColor: _cardColor,
                      avatar: const Icon(Icons.lock_reset, color: Colors.amberAccent, size: 16),
                      label: const Text('Reset PIN', style: TextStyle(color: Colors.white, fontSize: 11)),
                      onPressed: () => _showResetPinDialog(uid),
                    ),
                    ActionChip(
                      backgroundColor: _cardColor,
                      avatar: const Icon(Icons.visibility, color: _neonCyan, size: 16),
                      label: const Text('Ghost Login', style: TextStyle(color: Colors.white, fontSize: 11)),
                      onPressed: () => _impersonateUser(uid),
                    ),
                    ActionChip(
                      backgroundColor: _neonRed.withOpacity(0.15),
                      avatar: const Icon(Icons.delete_forever, color: _neonRed, size: 16),
                      label: const Text('Delete User', style: TextStyle(color: _neonRed, fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _deleteUser(uid),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _neonRed, size: 54),
            const SizedBox(height: 16),
            const Text('Failed to Load Users', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Network or security timeout', style: const TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: _fetchUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
