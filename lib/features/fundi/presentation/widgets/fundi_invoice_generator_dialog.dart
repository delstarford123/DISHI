import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/mpesa_theme.dart';

class FundiInvoiceGeneratorDialog extends StatefulWidget {
  final String fundiId;
  final String fundiName;
  final String fundiPhone;

  const FundiInvoiceGeneratorDialog({
    super.key,
    required this.fundiId,
    required this.fundiName,
    required this.fundiPhone,
  });

  @override
  State<FundiInvoiceGeneratorDialog> createState() => _FundiInvoiceGeneratorDialogState();
}

class _MaterialItem {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController costCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    costCtrl.dispose();
  }
}

class _FundiInvoiceGeneratorDialogState extends State<FundiInvoiceGeneratorDialog> {
  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _hostelLocationCtrl = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  final _laborCostCtrl = TextEditingController();
  final _warrantyCtrl = TextEditingController(text: '7 Days Comrade Service Guarantee');

  final List<_MaterialItem> _materials = [];
  bool _isSavingGig = false;
  String _selectedCategory = 'Tech & Digital';

  final List<String> _categories = [
    'Tech & Digital',
    'Academic Support',
    'Daily Errands',
    'Lifestyle & Grooming',
    'Hardware & Repairs',
    'Housing Maintenance',
  ];

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _hostelLocationCtrl.dispose();
    _jobTitleCtrl.dispose();
    _laborCostCtrl.dispose();
    _warrantyCtrl.dispose();
    for (var m in _materials) {
      m.dispose();
    }
    super.dispose();
  }

  void _addMaterialLine() {
    setState(() {
      _materials.add(_MaterialItem());
    });
  }

  void _removeMaterialLine(int index) {
    setState(() {
      _materials[index].dispose();
      _materials.removeAt(index);
    });
  }

  double get _laborCost => double.tryParse(_laborCostCtrl.text.trim()) ?? 0.0;

  double get _materialsTotal {
    double total = 0.0;
    for (var m in _materials) {
      total += double.tryParse(m.costCtrl.text.trim()) ?? 0.0;
    }
    return total;
  }

  double get _subtotal => _laborCost + _materialsTotal;
  double get _escrowFee => _subtotal * 0.015; // 1.5% DISHI Escrow protection
  double get _grandTotal => _subtotal;

  String _generateInvoiceText() {
    final clientName = _clientNameCtrl.text.trim().isEmpty ? 'Client' : _clientNameCtrl.text.trim();
    final title = _jobTitleCtrl.text.trim().isEmpty ? 'Gig Service' : _jobTitleCtrl.text.trim();
    final hostel = _hostelLocationCtrl.text.trim().isEmpty ? 'Campus' : _hostelLocationCtrl.text.trim();
    final warranty = _warrantyCtrl.text.trim();

    final buffer = StringBuffer();
    buffer.writeln('📋 *DISHI COMRADE FUNDI ESTIMATE* 🛠️');
    buffer.writeln('────────────────────────');
    buffer.writeln('*Fundi:* ${widget.fundiName} (${widget.fundiPhone})');
    buffer.writeln('*Client:* $clientName');
    buffer.writeln('*Location:* $hostel');
    buffer.writeln('*Service:* $title');
    buffer.writeln('────────────────────────');
    buffer.writeln('*Cost Breakdown:*');
    buffer.writeln('• Labor Fee: KES ${_laborCost.toStringAsFixed(0)}');

    if (_materials.isNotEmpty) {
      buffer.writeln('• Parts & Materials:');
      for (var m in _materials) {
        final n = m.nameCtrl.text.trim().isEmpty ? 'Material/Part' : m.nameCtrl.text.trim();
        final c = double.tryParse(m.costCtrl.text.trim()) ?? 0.0;
        buffer.writeln('   - $n: KES ${c.toStringAsFixed(0)}');
      }
      buffer.writeln('  Parts Subtotal: KES ${_materialsTotal.toStringAsFixed(0)}');
    }

    buffer.writeln('────────────────────────');
    buffer.writeln('💰 *Total Payable: KES ${_grandTotal.toStringAsFixed(0)}*');
    buffer.writeln('🛡️ _Protected by DISHI 1.5% Escrow (Payout upon client satisfaction)_');
    if (warranty.isNotEmpty) {
      buffer.writeln('✅ *Warranty:* $warranty');
    }
    buffer.writeln('\nPowered by DISHI SwapEat • Safe Campus Services');

    return buffer.toString();
  }

  Future<void> _sendViaWhatsApp() async {
    final phone = _clientPhoneCtrl.text.replaceAll(RegExp(r'[^0-9+]'), '');
    final invoice = _generateInvoiceText();
    final encoded = Uri.encodeComponent(invoice);
    final url = phone.isNotEmpty
        ? Uri.parse('https://wa.me/$phone?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: invoice));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp unavailable. Estimate copied to clipboard!')),
        );
      }
    }
  }

  Future<void> _saveAsDishiJob() async {
    if (_jobTitleCtrl.text.trim().isEmpty || _subtotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify job title and valid price')),
      );
      return;
    }

    setState(() => _isSavingGig = true);

    try {
      final materialsList = _materials.map((m) => {
        'name': m.nameCtrl.text.trim(),
        'cost': double.tryParse(m.costCtrl.text.trim()) ?? 0.0,
      }).toList();

      await FirebaseFirestore.instance.collection('fundi_jobs').add({
        'title': _jobTitleCtrl.text.trim(),
        'description': 'Materials: ${materialsList.map((e) => "${e['name']} (KES ${e['cost']})").join(', ')}\nLocation: ${_hostelLocationCtrl.text.trim()}',
        'amount': _grandTotal,
        'labor_cost': _laborCost,
        'materials_cost': _materialsTotal,
        'materials_items': materialsList,
        'category': _selectedCategory,
        'fundi_id': widget.fundiId,
        'fundi_name': widget.fundiName,
        'poster_id': 'quote_client',
        'payer_name': _clientNameCtrl.text.trim().isEmpty ? 'Client' : _clientNameCtrl.text.trim(),
        'phone': _clientPhoneCtrl.text.trim(),
        'location': _hostelLocationCtrl.text.trim(),
        'warranty': _warrantyCtrl.text.trim(),
        'status': 'open',
        'is_custom_quote': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Smart Quote saved to My Gigs! You can share with client.'),
            backgroundColor: Color(0xFF05D5AA),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingGig = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save gig: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131A26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: const Color(0xFF05D5AA).withOpacity(0.3), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF05D5AA).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, color: Color(0xFF05D5AA), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Smart Fundi Quote',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category dropdown
              const Text('Service Category', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: const Color(0xFF1A2235),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A2235),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val ?? _categories[0]),
              ),
              const SizedBox(height: 14),

              // Job Title
              _buildInput('Job Title / Problem', _jobTitleCtrl, 'e.g. Broken Laptop Screen & Thermal Paste', Icons.handyman),
              const SizedBox(height: 14),

              // Client Details
              Row(
                children: [
                  Expanded(child: _buildInput('Client Name', _clientNameCtrl, 'e.g. Brian Ochieng', Icons.person)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput('Client Phone', _clientPhoneCtrl, '0712345678', Icons.phone, isPhone: true)),
                ],
              ),
              const SizedBox(height: 14),

              // Hostel / Room Location
              _buildInput('Campus Hostel / Room No.', _hostelLocationCtrl, 'e.g. Hall 4, Room 212', Icons.location_on),
              const SizedBox(height: 18),

              // Labor Fee
              const Text('Labor Fee (KES)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _laborCostCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'e.g. 500',
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text('KES', style: TextStyle(color: Color(0xFF05D5AA), fontWeight: FontWeight.bold)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A2235),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 18),

              // Materials & Spare parts list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Spare Parts & Materials', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addMaterialLine,
                    icon: const Icon(Icons.add_circle, color: Color(0xFF05D5AA), size: 18),
                    label: const Text('Add Part', style: TextStyle(color: Color(0xFF05D5AA), fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              if (_materials.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Center(
                    child: Text('No spare parts added. Tap "+ Add Part" if client pays for hardware.',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                )
              else
                ..._materials.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: item.nameCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Item name (e.g. 8GB RAM)',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1A2235),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: item.costCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(color: Color(0xFF05D5AA), fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'KES',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1A2235),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                          onPressed: () => _removeMaterialLine(idx),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 14),
              _buildInput('Warranty / Guarantee Note', _warrantyCtrl, 'e.g. 7 Days Free Repair Guarantee', Icons.verified_user),
              const SizedBox(height: 16),

              // Live Total Calculation Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2235),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF05D5AA).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    _summaryLine('Labor Subtotal', 'KES ${_laborCost.toStringAsFixed(2)}'),
                    if (_materials.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _summaryLine('Parts/Materials Subtotal', 'KES ${_materialsTotal.toStringAsFixed(2)}'),
                    ],
                    const SizedBox(height: 4),
                    _summaryLine('DISHI Escrow Guarantee Fee (1.5%)', 'KES ${_escrowFee.toStringAsFixed(2)}', isEscrow: true),
                    const Divider(color: Colors.white12, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Estimated Due', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('KES ${_grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF05D5AA), fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                      label: const Text('Send WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _sendViaWhatsApp,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.black, size: 18),
                      label: _isSavingGig
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Save to Gigs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MPesaTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSavingGig ? null : _saveAsDishiJob,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _generateInvoiceText()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Quote summary copied to clipboard!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 14, color: Colors.white54),
                  label: const Text('Copy Quote Text', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, String hint, IconData icon, {bool isPhone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            prefixIcon: Icon(icon, color: Colors.white38, size: 16),
            filled: true,
            fillColor: const Color(0xFF1A2235),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _summaryLine(String label, String value, {bool isEscrow = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isEscrow ? const Color(0xFF05D5AA) : const Color(0xFF8B9BB4), fontSize: 11)),
        Text(value, style: TextStyle(color: isEscrow ? const Color(0xFF05D5AA) : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
