import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminLiquidationQueueSheet extends StatefulWidget {
  const AdminLiquidationQueueSheet({super.key});

  @override
  State<AdminLiquidationQueueSheet> createState() => _AdminLiquidationQueueSheetState();
}

class _AdminLiquidationQueueSheetState extends State<AdminLiquidationQueueSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final resp = await http.get(
        Uri.parse(ApiConfig.v6SavingsAdminLiquidationList),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && mounted) {
        final data = json.decode(resp.body);
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data['requests'] ?? []);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(String reqId, String action) async {
    final notesController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(action == 'approve' ? 'Approve & Liquidate Vault' : 'Reject Liquidation', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action == 'approve'
                  ? 'This will immediately unlock the student\'s locked savings and transfer the liquidated funds to their main wallet.'
                  : 'Specify why this early liquidation is not approved.',
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Admin Notes (Optional)',
                labelStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: action == 'approve' ? _neonCyan : _neonPink, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action == 'approve' ? 'Confirm Liquidation' : 'Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.v6SavingsAdminLiquidationAction),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'request_id': reqId,
          'action': action,
          'admin_notes': notesController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Processed!'), backgroundColor: action == 'approve' ? _neonCyan : _neonPink),
        );
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonPink));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              const Text('Admin Liquidation Queue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Review emergency liquidation requests from students for locked savings vaults.', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: _neonCyan)))
          else if (_requests.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
              child: const Center(
                child: Text('No early liquidation requests pending at this time.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 13)),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _requests.length,
                itemBuilder: (context, idx) {
                  final req = _requests[idx];
                  final isPending = req['status'] == 'pending';
                  final amt = (req['amount'] ?? 0).toString();
                  final name = req['applicant_name'] ?? 'Student';
                  final reason = req['reason_category'] ?? 'Emergency';
                  final vTitle = req['vault_title'] ?? 'Vault';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isPending ? _neonOrange.withOpacity(0.5) : Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$name: KES $amt', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPending ? _neonOrange.withOpacity(0.2) : (req['status'] == 'approved' ? _neonCyan.withOpacity(0.2) : _neonPink.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (req['status'] ?? 'pending').toString().toUpperCase(),
                                style: TextStyle(color: isPending ? _neonOrange : (req['status'] == 'approved' ? _neonCyan : _neonPink), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Vault: $vTitle • Reason: $reason', style: const TextStyle(color: _neonCyan, fontSize: 12)),
                        if ((req['explanation'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('"${req['explanation']}"', style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
                        ],
                        if (isPending) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _neonPink,
                                  side: const BorderSide(color: _neonPink),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _handleAction(req['id'], 'reject'),
                                child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _neonCyan,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _handleAction(req['id'], 'approve'),
                                child: const Text('Liquidate to Wallet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
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
