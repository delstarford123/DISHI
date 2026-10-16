import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminRecordDetailsDialog extends StatelessWidget {
  final String title;
  final String documentId;
  final Map<String, dynamic> data;

  const AdminRecordDetailsDialog({
    super.key,
    required this.title,
    required this.documentId,
    required this.data,
  });

  static void show(BuildContext context, {required String title, required String documentId, required Map<String, dynamic> data}) {
    showDialog(
      context: context,
      builder: (context) => AdminRecordDetailsDialog(
        title: title,
        documentId: documentId,
        data: data,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(data);

    return AlertDialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 1.5)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: _neonCyan, size: 18),
            tooltip: 'Copy JSON',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document JSON copied to clipboard'), backgroundColor: _neonCyan),
              );
            },
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: $documentId', style: const TextStyle(color: _textSecondary, fontSize: 11)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: _neonCyan)),
        ),
      ],
    );
  }
}
