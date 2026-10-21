import 'package:flutter/material.dart';
import '../../../../core/services/api_config.dart';
import '../../../../core/services/secure_http_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';
import '../vendor_menu_editor.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFFF2A5F);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorManagementTabView extends StatefulWidget {
  final Map<String, dynamic> user;

  const VendorManagementTabView({super.key, required this.user});

  @override
  State<VendorManagementTabView> createState() => _VendorManagementTabViewState();
}

class _VendorManagementTabViewState extends State<VendorManagementTabView> {
  // Staff Shift State
  final _pinController = TextEditingController();
  bool _isClockingIn = false;
  bool _isClockingOut = false;
  String? _activeShiftId;

  // Insights State
  late Future<List<dynamic>> _insightsFuture;

  // Vault State
  bool _isVaultUploading = false;

  // Staff Addition State
  final _staffNameController = TextEditingController();
  final _staffRoleController = TextEditingController();
  final _staffPinController = TextEditingController();
  bool _isStaffAdding = false;

  // Equipment Maintenance State
  final _equipmentNameController = TextEditingController();
  final _issueDescController = TextEditingController();
  bool _needsRepair = false;
  bool _isLoggingMaintenance = false;

  // Branch Management State
  final _branchNameController = TextEditingController();
  final _branchLocController = TextEditingController();
  bool _isAddingBranch = false;

  @override
  void dispose() {
    _pinController.dispose();
    _staffNameController.dispose();
    _staffRoleController.dispose();
    _staffPinController.dispose();
    _equipmentNameController.dispose();
    _issueDescController.dispose();
    _branchNameController.dispose();
    _branchLocController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _insightsFuture = _fetchInsights();
  }

  Future<List<dynamic>> _fetchInsights() async {
    try {
      final response = await SecureHttpClient.get(
        '${ApiConfig.baseUrl}/api/v1/vendor_management/market_insights?vendorUid=${widget.user['uid']}',
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['insights'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<void> _handleClockIn() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a 4-digit PIN')));
      return;
    }

    setState(() => _isClockingIn = true);
    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_management/staff/clock_in',
        body: {
          'vendorUid': widget.user['uid'],
          'pin': pin,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => _activeShiftId = data['shiftId']);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Clocked in'), backgroundColor: _neonCyan));
        _pinController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Clock In failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isClockingIn = false);
    }
  }

  Future<void> _handleClockOut() async {
    if (_activeShiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active shift found to clock out.')));
      return;
    }

    setState(() => _isClockingOut = true);
    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_management/staff/clock_out',
        body: {
          'vendorUid': widget.user['uid'],
          'shiftId': _activeShiftId,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final shiftSales = data['shiftSales'] ?? 0.0;
        final shiftDeposits = data['shiftDeposits'] ?? 0.0;
        setState(() => _activeShiftId = null);
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: _cardColor,
              title: const Row(
                children: [
                  Icon(Icons.receipt_long, color: _neonCyan),
                  SizedBox(width: 8),
                  Expanded(child: Text('Shift Summary', style: TextStyle(color: Colors.white))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Shift ended successfully.', style: TextStyle(color: _textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Sales', style: TextStyle(color: Colors.white)),
                      Text('KES $shiftSales', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(color: _textSecondary),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Agent Deposits', style: TextStyle(color: Colors.white)),
                      Text('KES $shiftDeposits', style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: _neonCyan)),
                )
              ],
            )
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Clock Out failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isClockingOut = false);
    }
  }

  Future<void> _handleVaultUpload() async {
    setState(() => _isVaultUploading = true);
    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_management/vault/upload',
        body: {
          'vendorUid': widget.user['uid'],
          'docType': 'Food Handling License',
          'docUrl': 'https://firebasestorage.googleapis.com/v0/b/mock-bucket/o/license.pdf',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Uploaded to vault'), backgroundColor: _neonCyan));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Upload failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isVaultUploading = false);
    }
  }

  Future<void> _handleAddStaff() async {
    final name = _staffNameController.text.trim();
    final role = _staffRoleController.text.trim();
    final pin = _staffPinController.text.trim();

    if (name.isEmpty || role.isEmpty || pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields and provide a 4-digit PIN.')));
      return;
    }

    setState(() => _isStaffAdding = true);

    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_management/staff/add',
        body: {
          'vendorUid': widget.user['uid'],
          'name': name,
          'role': role,
          'pin': pin,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Staff added'), backgroundColor: _neonCyan));
        _staffNameController.clear();
        _staffRoleController.clear();
        _staffPinController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Add staff failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isStaffAdding = false);
    }
  }

  Future<void> _handleMaintenanceLog() async {
    final equipment = _equipmentNameController.text.trim();
    final issue = _issueDescController.text.trim();

    if (equipment.isEmpty || issue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill equipment name and issue description.')));
      return;
    }

    setState(() => _isLoggingMaintenance = true);

    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_management/maintenance/log',
        body: {
          'vendorUid': widget.user['uid'],
          'equipmentName': equipment,
          'issueDescription': issue,
          'needsRepair': _needsRepair,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Maintenance logged'), backgroundColor: _neonCyan));
        _equipmentNameController.clear();
        _issueDescController.clear();
        setState(() => _needsRepair = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Logging failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoggingMaintenance = false);
    }
  }

  Future<void> _handleAddBranch() async {
    final name = _branchNameController.text.trim();
    final loc = _branchLocController.text.trim();

    if (name.isEmpty || loc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all branch details.')));
      return;
    }

    setState(() => _isAddingBranch = true);

    try {
      final response = await SecureHttpClient.post(
        '${ApiConfig.baseUrl}/api/v1/vendor_management/branches/add',
        body: {
          'vendorUid': widget.user['uid'],
          'branchName': name,
          'location': loc,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Branch added'), backgroundColor: _neonCyan));
        _branchNameController.clear();
        _branchLocController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Add branch failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isAddingBranch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Multi-Branch & Menu Management
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionHeader('Shop Management', Icons.store, Colors.white),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorMenuEditor()));
              },
              icon: const Icon(Icons.fastfood, size: 16),
              label: const Text('Manage Menu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        
        const SizedBox(height: 32),

        // Staff Shift Management
        _buildSectionHeader('Staff Shift Clock-In', Icons.badge, _neonCyan),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                _activeShiftId != null 
                    ? 'Active shift ongoing.'
                    : 'Enter 4-digit PIN to clock in or out of your shift.', 
                style: const TextStyle(color: _textSecondary, fontSize: 13)
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: 'Staff PIN',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.lock, color: _neonCyan),
                  counterText: "", // Hide length counter
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isClockingIn || _activeShiftId != null) ? null : _handleClockIn,
                      style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isClockingIn 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))
                          : const Text('Clock In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_isClockingOut || _activeShiftId == null) ? null : _handleClockOut,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: _neonCyan), padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isClockingOut
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _neonCyan))
                          : const Text('Clock Out', style: TextStyle(color: _neonCyan)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Role-Based Access Control
        _buildSectionHeader('Role-Based Access (RBAC)', Icons.admin_panel_settings, _neonPink),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add staff members and assign roles (e.g., Cashier, Manager).', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _staffNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Staff Name',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _staffRoleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Role (e.g. Cashier)',
                        labelStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _bgColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _staffPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '4-Digit PIN',
                        labelStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _bgColor,
                        counterText: "",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isStaffAdding ? null : _handleAddStaff,
                  icon: _isStaffAdding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.person_add, color: Colors.white),
                  label: Text(_isStaffAdding ? 'Adding...' : 'Add Staff Member', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: _neonPink, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Market Pricing Insights
        _buildSectionHeader('Market Pricing Insights', Icons.insights, _neonOrange),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Anonymous campus averages to help you stay competitive.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              
              FutureBuilder<List<dynamic>>(
                future: _insightsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: _neonOrange),
                    ));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No insights available.', style: TextStyle(color: _textSecondary));
                  }

                  return Column(
                    children: snapshot.data!.map((item) {
                      final comp = item['competitiveness'] as String;
                      IconData icon;
                      Color color;
                      
                      if (comp.contains("Excellent")) {
                        icon = Icons.check_circle;
                        color = _neonCyan;
                      } else if (comp.contains("High")) {
                        icon = Icons.warning_amber;
                        color = _neonPink;
                      } else {
                        icon = Icons.remove_circle_outline;
                        color = Colors.white;
                      }

                      return Column(
                        children: [
                          _buildInsightRow(
                            item['item'], 
                            '${item['yourPrice']} KSH', 
                            '${item['marketAvg']} KSH (Avg)', 
                            icon, 
                            color
                          ),
                          const Divider(color: _textSecondary),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Health & Safety Vault
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionHeader('Health & Safety Vault', Icons.verified_user, Colors.white),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _isVaultUploading ? null : _handleVaultUpload,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _isVaultUploading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2))
                  : const Icon(Icons.upload_file, color: _neonCyan, size: 18),
              label: const Text('Upload Doc', style: TextStyle(color: _neonCyan, fontSize: 12)),
            )
          ],
        ),
        const SizedBox(height: 8),
        
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user['uid'])
              .collection('vault')
              .orderBy('uploadedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No documents uploaded yet.', style: TextStyle(color: _textSecondary)),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _textSecondary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.description, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['docType'] ?? 'Document', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('${data['status'] == 'verified' ? 'Verified' : 'Pending'} • Uploaded', style: const TextStyle(color: _neonCyan, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.remove_red_eye, color: _textSecondary)),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 32),

        // Equipment Maintenance Log
        _buildSectionHeader('Equipment Maintenance Log', Icons.build, Colors.amber),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Track repairs and maintenance schedules for fryers, ovens, and fridges.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _equipmentNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Equipment Name (e.g. Fridge A)',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issueDescController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Issue / Routine Description',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Needs Urgent Repair', style: TextStyle(color: Colors.white, fontSize: 14)),
                activeColor: Colors.amber,
                value: _needsRepair,
                onChanged: (val) {
                  setState(() => _needsRepair = val);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoggingMaintenance ? null : _handleMaintenanceLog,
                  icon: _isLoggingMaintenance ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black)) : const Icon(Icons.engineering, color: Colors.black),
                  label: Text(_isLoggingMaintenance ? 'Logging...' : 'Log Maintenance', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 32),
        _buildBranchManagementSection(),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightRow(String item, String myPrice, String marketPrice, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: Text(myPrice, style: const TextStyle(color: Colors.white)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    marketPrice,
                    style: TextStyle(color: color, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBranchManagementSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: _neonCyan),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Multi-Branch Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Expand operations by registering new branches.', style: TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _branchNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Branch Name',
              labelStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _branchLocController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Location',
              labelStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAddingBranch ? null : _handleAddBranch,
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isAddingBranch
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Add Branch', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

