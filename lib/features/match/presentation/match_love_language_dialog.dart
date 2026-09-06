import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonBlue = Color(0xFF00FFD1);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _cardColor = Color(0xFF131A2A);

class MatchLoveLanguageDialog extends StatefulWidget {
  const MatchLoveLanguageDialog({super.key});

  @override
  State<MatchLoveLanguageDialog> createState() => _MatchLoveLanguageDialogState();
}

class _MatchLoveLanguageDialogState extends State<MatchLoveLanguageDialog> {
  final List<String> _defaultLanguages = [
    'Words of Affirmation',
    'Quality Time',
    'Receiving Gifts',
    'Acts of Service',
    'Physical Touch',
  ];
  
  List<String> _customLanguages = [];
  List<String> _selectedLanguages = [];
  bool _isLoading = true;
  bool _isSaving = false;
  
  final TextEditingController _customLangController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLoveLanguages();
  }

  @override
  void dispose() {
    _customLangController.dispose();
    super.dispose();
  }

  Future<void> _fetchLoveLanguages() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final savedLangs = List<String>.from(data['loveLanguages'] ?? []);
        final savedCustom = List<String>.from(data['customLoveLanguages'] ?? []);
        
        setState(() {
          _selectedLanguages = savedLangs;
          _customLanguages = savedCustom;
        });
      }
    } catch (e) {
      debugPrint('Error fetching love languages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLoveLanguages() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one love language.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'loveLanguages': _selectedLanguages,
        'customLoveLanguages': _customLanguages,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Love Languages Saved! 💕', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: _neonPink));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleSelection(String lang) {
    setState(() {
      if (_selectedLanguages.contains(lang)) {
        _selectedLanguages.remove(lang);
      } else {
        if (_selectedLanguages.length < 2) {
          _selectedLanguages.add(lang);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only select up to 2 love languages.')));
        }
      }
    });
  }

  void _addCustomLanguage() {
    final val = _customLangController.text.trim();
    if (val.isNotEmpty && !_customLanguages.contains(val) && !_defaultLanguages.contains(val)) {
      setState(() {
        _customLanguages.add(val);
        _selectedLanguages.add(val);
        if (_selectedLanguages.length > 2) {
          _selectedLanguages.removeAt(0); // Keep it at max 2
        }
      });
      _customLangController.clear();
    }
  }

  void _deleteCustomLanguage(String lang) {
    setState(() {
      _customLanguages.remove(lang);
      _selectedLanguages.remove(lang);
    });
  }

  @override
  Widget build(BuildContext context) {
    final allLanguages = [..._defaultLanguages, ..._customLanguages];

    return Dialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _isLoading 
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: _neonPink)))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, color: _neonPink, size: 64),
                    const SizedBox(height: 16),
                    const Text('Your Love Language', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Select your Primary and Secondary love languages (up to 2).', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 24),
                    
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allLanguages.map((lang) {
                        final isSelected = _selectedLanguages.contains(lang);
                        final isPrimary = _selectedLanguages.isNotEmpty && _selectedLanguages.first == lang;
                        final isCustom = _customLanguages.contains(lang);
                        
                        return GestureDetector(
                          onTap: () => _toggleSelection(lang),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? _neonPink.withOpacity(0.2) : _surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? _neonPink : Colors.transparent),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  Text(isPrimary ? '1️⃣ ' : '2️⃣ ', style: const TextStyle(fontSize: 12)),
                                ],
                                Text(lang, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                if (isCustom) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _deleteCustomLanguage(lang),
                                    child: const Icon(Icons.close, color: Colors.white54, size: 16),
                                  )
                                ]
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    
                    // Add Custom
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customLangController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add custom (e.g. Sending TikToks)',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              filled: true,
                              fillColor: _surfaceLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: _neonBlue),
                          onPressed: _addCustomLanguage,
                        )
                      ],
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _neonPink, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _isSaving ? null : _saveLoveLanguages,
                        child: _isSaving 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('SAVE LANGUAGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
