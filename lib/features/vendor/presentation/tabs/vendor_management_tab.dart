import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  @override
  void initState() {
    super.initState();
    _insightsFuture = _fetchInsights();
  }

  Future<List<dynamic>> _fetchInsights() async {
    try {
      final response = await http.get(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_management/market_insights?vendorUid=${widget.user['uid']}'),
      ).timeout(const Duration(seconds: 15));
      
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
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_management/staff/clock_in'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorUid': widget.user['uid'],
          'pin': pin,
        }),
      ).timeout(const Duration(seconds: 15));

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
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_management/staff/clock_out'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorUid': widget.user['uid'],
          'shiftId': _activeShiftId,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => _activeShiftId = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Clocked out'), backgroundColor: _neonOrange));
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
      final response = await http.post(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/vendor_management/vault/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorUid': widget.user['uid'],
          'docType': 'Food Handling License',
          'docUrl': 'https://firebasestorage.googleapis.com/v0/b/mock-bucket/o/license.pdf',
        }),
      ).timeout(const Duration(seconds: 15));

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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Multi-Branch & Menu Management
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Shop Management', Icons.store, Colors.white),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorMenuEditor()));
              },
              icon: const Icon(Icons.fastfood, size: 18),
              label: const Text('Manage Menu'),
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
            _buildSectionHeader('Health & Safety Vault', Icons.verified_user, Colors.white),
            TextButton.icon(
              onPressed: _isVaultUploading ? null : _handleVaultUpload,
              icon: _isVaultUploading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2))
                  : const Icon(Icons.upload_file, color: _neonCyan),
              label: const Text('Upload Doc', style: TextStyle(color: _neonCyan)),
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

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                Text(marketPrice, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
