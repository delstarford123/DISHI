import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/admin_service.dart';
import 'package:url_launcher/url_launcher.dart';

// -- CUSTOM EXECUTIVE THEME COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminDatabaseIndexesView extends StatefulWidget {
  const AdminDatabaseIndexesView({super.key});

  @override
  State<AdminDatabaseIndexesView> createState() => _AdminDatabaseIndexesViewState();
}

class _AdminDatabaseIndexesViewState extends State<AdminDatabaseIndexesView> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _healthData;
  String _searchIndexQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchHealth();
  }

  Future<void> _fetchHealth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _adminService.getDatabaseHealth();
      if (mounted) {
        setState(() {
          _healthData = data;
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
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: _neonCyan,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _healthData?['status'] ?? 'UNKNOWN';
    final latency = _healthData?['latency_ms'] ?? 0;
    final counts = (_healthData?['counts'] as Map<String, dynamic>?) ?? {};
    final indexes = (_healthData?['indexes'] as List<dynamic>?) ?? [];

    final filteredIndexes = indexes.where((idx) {
      if (_searchIndexQuery.isEmpty) return true;
      final col = (idx['collection'] ?? '').toString().toLowerCase();
      final fields = (idx['fields'] ?? '').toString().toLowerCase();
      return col.contains(_searchIndexQuery) || fields.contains(_searchIndexQuery);
    }).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Database & Firestore Indexes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            tooltip: 'Refresh Telemetry',
            onPressed: _fetchHealth,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  color: _neonCyan,
                  backgroundColor: _cardColor,
                  onRefresh: _fetchHealth,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Status Banner
                      _buildHealthStatusBanner(status, latency),
                      const SizedBox(height: 20),

                      // Collections Overview
                      const Text('Collection Telemetry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Live document metrics across Firestore collection groups', style: TextStyle(color: _textSecondary, fontSize: 12)),
                      const SizedBox(height: 12),
                      _buildCollectionsGrid(counts),
                      const SizedBox(height: 24),

                      // Firestore Composite Indexes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Composite Indexes Monitor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _neonCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _neonCyan.withOpacity(0.4)),
                            ),
                            child: Text('${indexes.length} Registered', style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Required composite indexes for queries with equality and sorting filters', style: TextStyle(color: _textSecondary, fontSize: 12)),
                      const SizedBox(height: 12),

                      // Index Search
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search collection or fields...',
                          hintStyle: const TextStyle(color: _textSecondary),
                          prefixIcon: const Icon(Icons.search, color: _textSecondary),
                          filled: true,
                          fillColor: _surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchIndexQuery = val.toLowerCase().trim();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Index List
                      if (filteredIndexes.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                          child: const Text('No matching indexes found.', style: TextStyle(color: _textSecondary)),
                        )
                      else
                        ...filteredIndexes.map((idx) => _buildIndexCard(idx)),

                      const SizedBox(height: 24),

                      // Quick Actions Card
                      _buildQuickLinksCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHealthStatusBanner(String status, int latency) {
    final bool isHealthy = status == 'HEALTHY';
    final Color badgeColor = isHealthy ? _neonCyan : (status == 'DEGRADED' ? _neonOrange : _neonRed);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: badgeColor.withOpacity(0.08), blurRadius: 16, spreadRadius: 2),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(isHealthy ? Icons.storage_rounded : Icons.warning_rounded, color: badgeColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Firestore Cluster: ', style: const TextStyle(color: _textSecondary, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Query Ping Latency: ${latency}ms', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Project: swapeat-39f5e (default database)', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsGrid(Map<String, dynamic> counts) {
    final items = [
      {'name': 'Users', 'count': counts['users'] ?? 0, 'icon': Icons.people, 'color': _neonCyan},
      {'name': 'Orders', 'count': counts['orders'] ?? 0, 'icon': Icons.receipt_long, 'color': _neonBlue},
      {'name': 'Transactions', 'count': counts['transactions'] ?? 0, 'icon': Icons.account_balance_wallet, 'color': Colors.greenAccent},
      {'name': 'M-PESA Logs', 'count': counts['mpesa_transactions'] ?? 0, 'icon': Icons.phone_android, 'color': _neonOrange},
      {'name': 'Disputes', 'count': counts['disputes'] ?? 0, 'icon': Icons.gavel, 'color': _neonRed},
      {'name': 'Tickets', 'count': counts['support_tickets'] ?? 0, 'icon': Icons.support_agent, 'color': Colors.amberAccent},
      {'name': 'DeLiv Gigs', 'count': counts['deliv_requests'] ?? 0, 'icon': Icons.two_wheeler, 'color': _neonCyan},
      {'name': 'Harambee', 'count': counts['harambee_campaigns'] ?? 0, 'icon': Icons.volunteer_activism, 'color': Colors.pinkAccent},
      {'name': 'Campus Feed', 'count': counts['campus_feed'] ?? 0, 'icon': Icons.dynamic_feed, 'color': _neonBlue},
      {'name': 'Audit Logs', 'count': counts['admin_action_logs'] ?? 0, 'icon': Icons.history, 'color': Colors.purpleAccent},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final Color col = item['color'] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _surfaceLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(item['icon'] as IconData, color: col, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['count']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                    Text(item['name'] as String, style: const TextStyle(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIndexCard(Map<String, dynamic> idx) {
    final col = idx['collection'] ?? '';
    final fields = idx['fields'] ?? '';
    final status = idx['status'] ?? 'ACTIVE';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _neonBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.table_chart_outlined, color: _neonBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(col, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _neonCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 10)),
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Text('Fields: $fields', style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinksCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonCyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: _neonCyan, size: 20),
              SizedBox(width: 8),
              Text('Firestore Console Shortcuts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Manage indexes, security rules, and manual document overrides directly:', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                backgroundColor: _cardColor,
                avatar: const Icon(Icons.link, color: _neonCyan, size: 16),
                label: const Text('Indexes Console', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  _copyToClipboard('https://console.firebase.google.com/u/0/project/swapeat-39f5e/firestore/indexes', 'Indexes URL');
                },
              ),
              ActionChip(
                backgroundColor: _cardColor,
                avatar: const Icon(Icons.security, color: _neonBlue, size: 16),
                label: const Text('Rules Console', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  _copyToClipboard('https://console.firebase.google.com/u/0/project/swapeat-39f5e/firestore/rules', 'Rules URL');
                },
              ),
              ActionChip(
                backgroundColor: _cardColor,
                avatar: const Icon(Icons.copy, color: _neonOrange, size: 16),
                label: const Text('Copy Project ID', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  _copyToClipboard('swapeat-39f5e', 'Project ID');
                },
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
            const Icon(Icons.cloud_off_rounded, color: _neonRed, size: 54),
            const SizedBox(height: 16),
            const Text('Telemetry Error', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Failed to load database health metrics', style: const TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: _fetchHealth,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
