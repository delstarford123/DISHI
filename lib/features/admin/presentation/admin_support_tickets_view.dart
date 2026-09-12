import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminSupportTicketsView extends StatefulWidget {
  const AdminSupportTicketsView({super.key});

  @override
  State<AdminSupportTicketsView> createState() => _AdminSupportTicketsViewState();
}

class _AdminSupportTicketsViewState extends State<AdminSupportTicketsView> {
  final AdminService _adminService = AdminService();

  Future<void> _resolveTicket(String id) async {
    final TextEditingController controller = TextEditingController();
    final resolution = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Resolve Ticket', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter resolution note (sent to user)',
            hintStyle: TextStyle(color: _textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _surfaceLight)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (resolution != null) {
      try {
        await _adminService.closeTicket(id, resolution.isEmpty ? 'Resolved by Admin' : resolution);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket resolved')));
          setState(() {}); // refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Helpdesk Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _adminService.getActiveTickets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonCyan));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
          }

          final tickets = snapshot.data ?? [];
          if (tickets.isEmpty) {
            return const Center(child: Text('No active tickets. Inbox Zero!', style: TextStyle(color: _neonCyan, fontSize: 16)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final t = tickets[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ticket #${t['id']?.toString().substring(0,6)}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('OPEN', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(t['issue'] ?? 'No subject provided', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('User ID: ${t['user_id'] ?? 'Unknown'}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                    if (t['description'] != null) ...[
                      const SizedBox(height: 8),
                      Text(t['description'], style: const TextStyle(color: Colors.white70)),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                        onPressed: () => _resolveTicket(t['id']),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Resolve Ticket'),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
