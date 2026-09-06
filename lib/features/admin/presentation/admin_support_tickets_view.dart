import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class AdminSupportTicketsView extends StatefulWidget {
  const AdminSupportTicketsView({super.key});

  @override
  State<AdminSupportTicketsView> createState() => _AdminSupportTicketsViewState();
}

class _AdminSupportTicketsViewState extends State<AdminSupportTicketsView> {
  final List<Map<String, dynamic>> _tickets = [
    {
      'id': 'TKT-991',
      'user': 'Student SWP-101',
      'issue': 'Vendor denied receiving offline payment',
      'status': 'Open',
    },
    {
      'id': 'TKT-992',
      'user': 'Vendor V-104',
      'issue': 'E-Float withdrawal delayed',
      'status': 'Open',
    },
  ];

  void _resolveTicket(String id) {
    setState(() {
      _tickets.removeWhere((t) => t['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ticket \$id marked as resolved.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispute Resolution'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        itemBuilder: (context, index) {
          final ticket = _tickets[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(ticket['issue'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Reported by: ${ticket['user']}"),
              ),
              trailing: ElevatedButton(
                onPressed: () => _resolveTicket(ticket['id']),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                child: const Text('Resolve'),
              ),
            ),
          );
        },
      ),
    );
  }
}
