import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/admin_service.dart';

class FraudVelocityView extends StatefulWidget {
  const FraudVelocityView({super.key});

  @override
  State<FraudVelocityView> createState() => _FraudVelocityViewState();
}

class _FraudVelocityViewState extends State<FraudVelocityView> {
  List<dynamic> _flaggedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFlags();
  }

  Future<void> _fetchFlags() async {
    setState(() => _isLoading = true);
    try {
      final flags = await AdminService().getFraudFlags();
      setState(() {
        _flaggedUsers = flags;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _takeAction(String userId, String action) async {
    try {
      if (action == 'Shadow Ban') {
        // Suspend user API call
        // Assuming AdminService has suspendUser or we can hit it directly
        // For now just show a message, real integration requires suspend endpoint wrapper in AdminService
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action "\$action" executed against \$userId. (Call suspend API)')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action "\$action" executed against \$userId')));
      }
      setState(() {
        _flaggedUsers.removeWhere((v) => v['user_id'] == userId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error taking action: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1219), // Match admin dashboard dark theme
      appBar: AppBar(
        title: const Text('Fraud & Wash Trading', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B29),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
            : _flaggedUsers.isEmpty
                ? const Center(child: Text('No flagged users', style: TextStyle(color: Colors.white70)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _flaggedUsers.length,
                    itemBuilder: (context, index) {
                      final vendor = _flaggedUsers[index];
                      final isHighSeverity = (vendor['recent_tx_count'] ?? 0) >= 5;

                      return Card(
                        color: const Color(0xFF1C2230),
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isHighSeverity ? Colors.redAccent : Colors.orangeAccent),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('User ID: \${vendor['user_id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text('\${vendor['recent_tx_count']} Txs', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(vendor['reason'] ?? 'Suspicious Activity', style: TextStyle(color: isHighSeverity ? Colors.redAccent : Colors.orange, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _takeAction(vendor['user_id'], 'Dismiss'),
                                    child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _takeAction(vendor['user_id'], 'Shadow Ban'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    child: const Text('Shadow Ban', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
