import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM EXECUTIVE THEME COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminTransactionsView extends StatefulWidget {
  const AdminTransactionsView({super.key});

  @override
  State<AdminTransactionsView> createState() => _AdminTransactionsViewState();
}

class _AdminTransactionsViewState extends State<AdminTransactionsView> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _allTransactions = [];
  String _searchQuery = '';
  String _selectedTypeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final txs = await _adminService.getRichTransactions();
      if (mounted) {
        setState(() {
          _allTransactions = txs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), backgroundColor: _neonCyan, duration: const Duration(seconds: 2)),
    );
  }

  // --- M-PESA RECONCILIATION MODAL ---
  void _openMpesaReconcileModal() {
    final TextEditingController queryController = TextEditingController();
    bool isSearching = false;
    List<dynamic> queryResults = [];
    String? searchError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: _neonCyan, size: 22),
                      SizedBox(width: 8),
                      Text('M-PESA Reconciliation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Search by M-PESA Receipt Number, Phone, or Checkout Request ID:', style: TextStyle(color: _textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: queryController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. NLX1234567 or ws_CO_...',
                        hintStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _surfaceLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSearching
                        ? null
                        : () async {
                            final q = queryController.text.trim();
                            if (q.isEmpty) return;
                            setSheetState(() {
                              isSearching = true;
                              searchError = null;
                              queryResults = [];
                            });

                            try {
                              final res = await _adminService.queryMpesaTransaction(q);
                              setSheetState(() {
                                queryResults = res;
                                isSearching = false;
                              });
                            } catch (e) {
                              setSheetState(() {
                                searchError = e.toString();
                                isSearching = false;
                              });
                            }
                          },
                    child: isSearching
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Search', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (searchError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _neonRed.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(searchError!, style: const TextStyle(color: _neonRed, fontSize: 12)),
                ),

              // Query results
              if (queryResults.isNotEmpty) ...[
                const Text('Matching Records:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: queryResults.length,
                    itemBuilder: (context, idx) {
                      final item = queryResults[idx] is Map ? Map<String, dynamic>.from(queryResults[idx] as Map) : <String, dynamic>{};
                      final amount = item['amount'] ?? item['Amount'] ?? 0;
                      final phone = item['phone_number'] ?? item['phoneNumber'] ?? 'N/A';
                      final receipt = item['mpesa_receipt_number'] ?? item['MpesaReceiptNumber'] ?? item['receipt'] ?? 'N/A';
                      final status = item['status'] ?? 'unknown';
                      final userId = item['user_id'] ?? item['uid'] ?? '';
                      final checkoutId = item['id'] ?? '';
                      final isCredited = status == 'completed' || item['manually_credited'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Receipt: $receipt', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('KES $amount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Phone: $phone • Status: $status', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                            Text('User ID: $userId', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 8),
                            if (!isCredited && userId.isNotEmpty)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  try {
                                    await _adminService.manualCreditMpesa(
                                      checkoutId: checkoutId,
                                      userId: userId,
                                      amount: (amount as num).toDouble(),
                                      receipt: receipt.toString(),
                                      reason: 'Admin verified Daraja receipt $receipt',
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Successfully credited KES $amount to $userId!'), backgroundColor: _neonCyan),
                                      );
                                      _fetchTransactions();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Credit Failed: $e'), backgroundColor: _neonRed),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                label: const Text('Credit Wallet Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            else if (isCredited)
                              Row(
                                children: [
                                  const Icon(Icons.check, color: Colors.greenAccent, size: 14),
                                  const SizedBox(width: 4),
                                  Text(item['manually_credited'] == true ? 'Manually Credited by Admin' : 'Already Credited & Completed',
                                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter transactions
    final filteredTxs = _allTransactions.where((rawTx) {
      final tx = rawTx is Map ? Map<String, dynamic>.from(rawTx) : <String, dynamic>{};
      final desc = (tx['description'] ?? '').toString().toLowerCase();
      final type = (tx['type'] ?? '').toString().toLowerCase();
      final id = (tx['id'] ?? '').toString().toLowerCase();
      final student = tx['student_data'] is Map ? Map<String, dynamic>.from(tx['student_data']) : <String, dynamic>{};
      final vendor = tx['vendor_data'] is Map ? Map<String, dynamic>.from(tx['vendor_data']) : <String, dynamic>{};
      final studentName = (student['name'] ?? '').toString().toLowerCase();
      final vendorName = (vendor['name'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          desc.contains(_searchQuery) ||
          id.contains(_searchQuery) ||
          studentName.contains(_searchQuery) ||
          vendorName.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_selectedTypeFilter == 'ALL') return true;
      if (_selectedTypeFilter == 'TOPUP') return type == 'topup';
      if (_selectedTypeFilter == 'PAYMENT') return type == 'payment' || type == 'order';
      if (_selectedTypeFilter == 'REFUND') return type.contains('refund');
      if (_selectedTypeFilter == 'ADJUSTMENT') return type.contains('adjust') || type.contains('admin');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('System Ledger & Reconciliation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            tooltip: 'Refresh Ledger',
            onPressed: _fetchTransactions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.manage_search),
        label: const Text('M-PESA Resolver', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openMpesaReconcileModal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    // Search & Type Filters
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search by TX ID, user, or description...',
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
                              children: ['ALL', 'TOPUP', 'PAYMENT', 'REFUND', 'ADJUSTMENT'].map((filter) {
                                final isSel = _selectedTypeFilter == filter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(filter, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    selected: isSel,
                                    selectedColor: _neonCyan,
                                    backgroundColor: _surfaceLight,
                                    onSelected: (val) {
                                      if (val) setState(() => _selectedTypeFilter = filter);
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Ledger Count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${filteredTxs.length} of ${_allTransactions.length} Entries', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                          const Text('Real-time immutable audit', style: TextStyle(color: _neonCyan, fontSize: 11)),
                        ],
                      ),
                    ),

                    // Ledger List
                    Expanded(
                      child: filteredTxs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.receipt_long_outlined, color: _textSecondary, size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No transactions found matching filter.', style: TextStyle(color: _textSecondary)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredTxs.length,
                              itemBuilder: (context, index) {
                                final tx = filteredTxs[index];
                                return _buildRichTxCard(tx);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRichTxCard(dynamic rawTx) {
    final tx = rawTx is Map ? Map<String, dynamic>.from(rawTx) : <String, dynamic>{};
    final type = (tx['type'] ?? 'Unknown').toString();
    final bool isCredit = type == 'topup' || type == 'refund' || type.contains('Credit') || type.contains('Refund');
    final Color amountColor = isCredit ? _neonCyan : Colors.white;

    final student = tx['student_data'] is Map ? Map<String, dynamic>.from(tx['student_data']) : <String, dynamic>{};
    final vendor = tx['vendor_data'] is Map ? Map<String, dynamic>.from(tx['vendor_data']) : <String, dynamic>{};

    Map<String, dynamic> primaryUser = isCredit ? student : (type == 'payment' ? vendor : student);
    if (primaryUser.isEmpty && student.isNotEmpty) primaryUser = student;

    final String name = primaryUser['name'] ?? 'Unknown Party';
    final String email = primaryUser['email'] ?? '';
    final String phone = primaryUser['phone'] ?? '';
    final String imageUrl = primaryUser['image'] ?? '';
    final double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final String desc = tx['description'] ?? (tx['reason'] ?? type);
    final String txId = tx['id']?.toString() ?? '';
    final String status = tx['status'] ?? 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _surfaceLight,
                backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                child: imageUrl.isEmpty ? Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: amountColor, size: 18) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(desc, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(name, style: TextStyle(color: isCredit ? _neonCyan : _neonOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                    if (email.isNotEmpty && email != 'N/A')
                      Text(phone.isNotEmpty ? '$email • $phone' : email, style: const TextStyle(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
                    else if (phone.isNotEmpty)
                      Text(phone, style: const TextStyle(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : '-'} KES ${amount.toStringAsFixed(2)}',
                    style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (status == 'completed' ? Colors.greenAccent : _neonOrange).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(status.toUpperCase(), style: TextStyle(color: status == 'completed' ? Colors.greenAccent : _neonOrange, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ID: ${txId.length > 12 ? txId.substring(0, 12) : txId}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
              InkWell(
                onTap: () => _copyToClipboard(txId, 'Transaction ID'),
                child: const Text('Copy ID', style: TextStyle(color: _neonBlue, fontSize: 11)),
              ),
            ],
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
            const Text('Failed to Load Ledger', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Network or security timeout', style: const TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: _fetchTransactions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
