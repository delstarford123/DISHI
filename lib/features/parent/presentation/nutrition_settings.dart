import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF161B29);
const Color _surfaceLight = Color(0xFF1E2538);
const Color _neonOrange = Color(0xFFFF6B00);
const Color _textSecondary = Color(0xFF8B9BB4);

class NutritionSettings extends StatefulWidget {
  final String studentUid;
  final String studentName;

  const NutritionSettings({super.key, required this.studentUid, required this.studentName});

  @override
  State<NutritionSettings> createState() => _NutritionSettingsState();
}

class _NutritionSettingsState extends State<NutritionSettings> {
  final List<String> _availableAllergens = ['Peanuts', 'Dairy', 'Gluten', 'Eggs', 'Soy', 'Tree Nuts'];
  List<String> _selectedAllergens = [];
  
  final Map<String, TextEditingController> _limitControllers = {
    'Sugar': TextEditingController(),
    'Junk Food': TextEditingController(),
    'Soda': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _selectedAllergens = List<String>.from(data['allergies'] ?? []);
        final limits = Map<String, dynamic>.from(data['categoryLimits'] ?? {});
        limits.forEach((key, value) {
          if (_limitControllers.containsKey(key)) {
            _limitControllers[key]!.text = value.toString();
          }
        });
      });
    }
  }

  void _saveSettings() async {
    Map<String, int> limits = {};
    _limitControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        final val = int.tryParse(controller.text);
        if (val != null) {
          limits[key] = val;
        }
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(widget.studentUid).update({
      'allergies': _selectedAllergens,
      'categoryLimits': limits,
    });

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nutrition settings saved'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text('Nutrition - ${widget.studentName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Allergen Blocks', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Select ingredients to block. POS will reject any meal containing these.', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableAllergens.map((allergen) {
              final isSelected = _selectedAllergens.contains(allergen);
              return FilterChip(
                label: Text(allergen),
                selected: isSelected,
                selectedColor: _neonOrange.withOpacity(0.3),
                checkmarkColor: _neonOrange,
                backgroundColor: _cardColor,
                labelStyle: TextStyle(color: isSelected ? _neonOrange : Colors.white),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedAllergens.add(allergen);
                    } else {
                      _selectedAllergens.remove(allergen);
                    }
                  });
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          const Text('Category Daily Limits', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Set maximum allowable portions per day. Leave blank for no limit.', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          
          ..._limitControllers.entries.map((entry) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: entry.value,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Max ${entry.key} per day',
                labelStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.fastfood, color: _textSecondary),
              ),
            ),
          )),
          
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _saveSettings,
            child: const Text('SAVE NUTRITION SETTINGS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
