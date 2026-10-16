import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/mpesa_theme.dart';

class FundiServiceManagerDialog extends StatefulWidget {
  final String fundiId;

  const FundiServiceManagerDialog({
    super.key,
    required this.fundiId,
  });

  @override
  State<FundiServiceManagerDialog> createState() => _FundiServiceManagerDialogState();
}

class _FundiServiceManagerDialogState extends State<FundiServiceManagerDialog> {
  final _serviceTitleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '1 hour');
  final _descriptionCtrl = TextEditingController();
  String _selectedCategory = 'Tech & Digital';
  bool _isAdding = false;

  final List<String> _categories = [
    'Tech & Digital',
    'Academic Support',
    'Daily Errands',
    'Lifestyle & Grooming',
    'Hardware & Repairs',
    'Housing Maintenance',
  ];

  final Map<String, List<Map<String, dynamic>>> _presets = {
    'Tech & Digital': [
      {'title': 'OS Installation & Formatting', 'price': 600, 'duration': '1.5 hrs'},
      {'title': 'Phone Screen Replacement', 'price': 1200, 'duration': '45 mins'},
      {'title': 'Laptop Cleaning & Thermal Paste', 'price': 800, 'duration': '1 hr'},
      {'title': 'Wi-Fi & Router Configuration', 'price': 500, 'duration': '30 mins'},
    ],
    'Academic Support': [
      {'title': 'Calculus & Stats Tutoring', 'price': 500, 'duration': '1 hr'},
      {'title': 'LaTeX Document Typesetting', 'price': 400, 'duration': 'Same day'},
      {'title': 'Project Proofreading & Editing', 'price': 700, 'duration': '2 hrs'},
      {'title': 'Exam Prep Coaching', 'price': 600, 'duration': '1.5 hrs'},
    ],
    'Lifestyle & Grooming': [
      {'title': 'Hostel Room Haircut / Fade', 'price': 300, 'duration': '40 mins'},
      {'title': 'Knotless Braids / Styling', 'price': 1500, 'duration': '3 hrs'},
      {'title': 'Dreadlocks Wash & Retouch', 'price': 800, 'duration': '1.5 hrs'},
      {'title': 'Sneaker Deep Wash & Whitening', 'price': 250, 'duration': '1 day'},
    ],
    'Daily Errands': [
      {'title': 'Hostel Room Deep Cleaning', 'price': 500, 'duration': '2 hrs'},
      {'title': 'Laundry Handwash & Ironing', 'price': 400, 'duration': '1 day'},
      {'title': 'Market Produce / Soko Run', 'price': 350, 'duration': '1 hr'},
      {'title': 'Hostel Relocation / Packing Help', 'price': 700, 'duration': '2 hrs'},
    ],
    'Hardware & Repairs': [
      {'title': 'Shower Heater / Instant Shower Fix', 'price': 600, 'duration': '1 hr'},
      {'title': 'Hostel Door Lock / Latch Replacement', 'price': 450, 'duration': '45 mins'},
      {'title': 'Extension Cable Wire Repair', 'price': 200, 'duration': '20 mins'},
      {'title': 'Desk / Bed Frame Reinforcement', 'price': 500, 'duration': '1 hr'},
    ],
  };

  @override
  void dispose() {
    _serviceTitleCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _serviceTitleCtrl.text = preset['title'] ?? '';
      _priceCtrl.text = preset['price'].toString();
      _durationCtrl.text = preset['duration'] ?? '1 hour';
    });
  }

  Future<void> _addNewService() async {
    final title = _serviceTitleCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    if (title.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter service title and valid price')),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      await FirebaseFirestore.instance
          .collection('fundi_profiles')
          .doc(widget.fundiId)
          .collection('services')
          .add({
        'title': title,
        'category': _selectedCategory,
        'price': price,
        'duration': _durationCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear inputs
      _serviceTitleCtrl.clear();
      _priceCtrl.clear();
      _descriptionCtrl.clear();

      if (mounted) {
        setState(() => _isAdding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service added to your rate card!'), backgroundColor: Color(0xFF05D5AA)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save service: $e')),
        );
      }
    }
  }

  Future<void> _toggleServiceActive(String serviceId, bool current) async {
    await FirebaseFirestore.instance
        .collection('fundi_profiles')
        .doc(widget.fundiId)
        .collection('services')
        .doc(serviceId)
        .update({'isActive': !current});
  }

  Future<void> _deleteService(String serviceId) async {
    await FirebaseFirestore.instance
        .collection('fundi_profiles')
        .doc(widget.fundiId)
        .collection('services')
        .doc(serviceId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final currentPresets = _presets[_selectedCategory] ?? [];

    return Dialog(
      backgroundColor: const Color(0xFF131A26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: MPesaTheme.primaryGreen.withOpacity(0.3), width: 1.5),
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
                          color: MPesaTheme.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.design_services, color: MPesaTheme.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'My Services & Rates',
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
              const SizedBox(height: 14),

              // Category dropdown
              const Text('Category', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: const Color(0xFF1A2235),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A2235),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val ?? _categories[0]),
              ),
              const SizedBox(height: 14),

              // Quick Presets
              if (currentPresets.isNotEmpty) ...[
                const Text('Popular Presets (Tap to fill)', style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: currentPresets.map((preset) {
                    return InkWell(
                      onTap: () => _applyPreset(preset),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          '+ ${preset['title']} (KES ${preset['price']})',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Service Title
              const Text('Service Name', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _serviceTitleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Phone Screen Replacement',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1A2235),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Price & Duration
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Price (KES)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFF05D5AA), fontSize: 14, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: '500',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: const Color(0xFF1A2235),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Est. Duration', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _durationCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: '1 hour',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: const Color(0xFF1A2235),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              const Text('What is Included (Optional)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Free diagnostic check + brings all required tools',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1A2235),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),

              // Add Service Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAdding ? null : _addNewService,
                  icon: const Icon(Icons.add, color: Colors.black, size: 18),
                  label: _isAdding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Add Service to Rate Card', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF05D5AA),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Current Services List Header
              const Text(
                'Current Active Offerings',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Live Stream of services
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('fundi_profiles')
                    .doc(widget.fundiId)
                    .collection('services')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: MPesaTheme.primaryGreen)));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No services added yet. Add your services above so campus clients can view your rate card!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['title'] ?? 'Service';
                      final price = (data['price'] as num?)?.toDouble() ?? 0.0;
                      final duration = data['duration'] ?? '';
                      final isActive = data['isActive'] ?? true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2235),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? Colors.white12 : Colors.white.withOpacity(0.04),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: isActive ? Colors.white : Colors.white38,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      decoration: isActive ? null : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        'KES ${price.toStringAsFixed(0)}',
                                        style: const TextStyle(color: Color(0xFF05D5AA), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      if (duration.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text('• $duration', style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 11)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isActive ? Icons.visibility : Icons.visibility_off,
                                color: isActive ? Colors.white70 : Colors.white24,
                                size: 18,
                              ),
                              onPressed: () => _toggleServiceActive(doc.id, isActive),
                              tooltip: isActive ? 'Pause offering' : 'Activate offering',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              onPressed: () => _deleteService(doc.id),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
