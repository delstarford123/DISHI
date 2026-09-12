import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DataConsentView extends StatefulWidget {
  final String userId;
  const DataConsentView({super.key, required this.userId});

  @override
  State<DataConsentView> createState() => _DataConsentViewState();
}

class _DataConsentViewState extends State<DataConsentView> {
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('Are you sure you want to permanently delete your account? Your account will be soft-deleted for 30 days before permanent erasure.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.delete(
        Uri.parse('\${ApiConfig.baseUrl}/api/security/\${widget.userId}/delete_account'),
      );
      
      if (response.statusCode == 200) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion process initiated.')));
           // Navigate back to login
           Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        throw Exception('Failed to delete account');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Privacy & Consent')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage your data and privacy settings.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('Permanently wipe your data from our systems.'),
              onTap: _isLoading ? null : _deleteAccount,
              trailing: _isLoading ? const CircularProgressIndicator() : null,
            )
          ],
        ),
      ),
    );
  }
}
