import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class VendorSavingsVaultSheet extends StatefulWidget {
  final Map<String, dynamic> vendorUser;

  const VendorSavingsVaultSheet({super.key, required this.vendorUser});

  @override
  State<VendorSavingsVaultSheet> createState() => _VendorSavingsVaultSheetState();
}

class _VendorSavingsVaultSheetState extends State<VendorSavingsVaultSheet> {
  String _vendorUid = '';
  double _earningsBalance = 0.0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _vaults = [];
  double _totalSaved = 0.0;

  @override
  void initState() {
    super.initState();
    _vendorUid = widget.vendorUser['uid'] ?? '';
    _loadVaults();
  }

  Future<void> _loadVaults() async {
    if (_vendorUid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_vendorUid).get();
      if (doc.exists && mounted) {
        final d = doc.data() ?? {};
        _earningsBalance = (d['walletBalance'] as num?)?.toDouble() ?? (d['vendorEarnings'] as num?)?.toDouble() ?? 0.0;
      }

      final resp = await http.get(
        Uri.parse('${ApiConfig.v6SavingsList}/$_vendorUid'),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && mounted) {
        final resData = json.decode(resp.body);
        setState(() {
          _vaults = List<Map<String, dynamic>>.from(resData['vaults'] ?? []);
          _totalSaved = (resData['total_saved'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateVaultDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    String category = 'Stock Restocking Reserve';

    final categories = [
      'Stock Restocking Reserve',
      'Stall Rent & Electricity Pool',
      'Kitchen Equipment Maintenance',
      'Business Surplus Buffer'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create Vendor Business Vault', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reserve Category', style: TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(10)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: category,
                      dropdownColor: _surfaceLight,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setDlgState(() => category = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Vault Title (e.g. 50kg Rice & Oil)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Target Reserve (KES)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: () async {
                final title = titleController.text.trim().isEmpty ? category : titleController.text.trim();
                final target = double.tryParse(targetController.text.trim()) ?? 5000.0;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                try {
                  final resp = await http.post(
                    Uri.parse(ApiConfig.v6SavingsCreate),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'user_id': _vendorUid,
                      'category': category,
                      'title': title,
                      'target_amount': target,
                      'lock_period': 'flexible',
                      'initial_deposit': 0.0,
                    }),
                  ).timeout(const Duration(seconds: 15));

                  final data = json.decode(resp.body);
                  if (resp.statusCode == 201) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(data['message'] ?? 'Business vault created!'), backgroundColor: _neonCyan),
                    );
                    _loadVaults();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositDialog(Map<String, dynamic> vault) {
    final amtController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Save to ${vault['title']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Vendor Earnings: KES ${_earningsBalance.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: amtController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (KES)',
                labelStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
            onPressed: () async {
              final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              try {
                final resp = await http.post(
                  Uri.parse(ApiConfig.v6SavingsDeposit),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'user_id': _vendorUid,
                    'vault_id': vault['id'],
                    'amount': amt,
                  }),
                ).timeout(const Duration(seconds: 15));

                final data = json.decode(resp.body);
                if (resp.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'] ?? 'Saved!'), backgroundColor: _neonCyan),
                  );
                  _loadVaults();
                }
              } catch (_) {
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(Map<String, dynamic> vault) {
    final amtController = TextEditingController();
    final double bal = (vault['current_balance'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Withdraw from ${vault['title']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vault Balance: KES ${bal.toStringAsFixed(2)}', style: const TextStyle(color: _neonOrange, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: amtController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (KES)',
                labelStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, foregroundColor: Colors.white),
            onPressed: () async {
              final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
              if (amt <= 0 || amt > bal) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              try {
                final resp = await http.post(
                  Uri.parse(ApiConfig.v6SavingsWithdraw),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'user_id': _vendorUid,
                    'vault_id': vault['id'],
                    'amount': amt,
                  }),
                ).timeout(const Duration(seconds: 15));

                final data = json.decode(resp.body);
                if (resp.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'] ?? 'Funds withdrawn!'), backgroundColor: _neonCyan),
                  );
                  _loadVaults();
                }
              } catch (_) {
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Withdraw to Earnings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Vendor Business Vaults', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Total Saved: KES ${_totalSaved.toStringAsFixed(2)} • Available: KES ${_earningsBalance.toStringAsFixed(2)}',
            style: const TextStyle(color: _neonCyan, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_circle, size: 18),
            label: const Text('Create New Business Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _showCreateVaultDialog,
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: _neonCyan)))
          else if (_vaults.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
              child: const Center(
                child: Text('No vendor reserves created yet. Set aside daily sales for restocking, equipment, or rent.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 12)),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _vaults.length,
                itemBuilder: (context, idx) {
                  final v = _vaults[idx];
                  final cBal = (v['current_balance'] as num?)?.toDouble() ?? 0.0;
                  final tAmt = (v['target_amount'] as num?)?.toDouble() ?? 5000.0;
                  final prog = ((cBal / (tAmt > 0 ? tAmt : 1.0)) * 100.0).clamp(0.0, 100.0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(v['title'] ?? 'Reserve', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('KES ${cBal.toStringAsFixed(0)} / ${tAmt.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: prog / 100.0,
                            backgroundColor: _surfaceLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(_neonCyan),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _neonCyan,
                                side: const BorderSide(color: _neonCyan),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showDepositDialog(v),
                              child: const Text('Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _neonOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showWithdrawDialog(v),
                              child: const Text('Withdraw', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
