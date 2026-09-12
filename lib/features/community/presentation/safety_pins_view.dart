import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SafetyPinsView extends StatefulWidget {
  const SafetyPinsView({super.key});

  @override
  State<SafetyPinsView> createState() => _SafetyPinsViewState();
}

class _SafetyPinsViewState extends State<SafetyPinsView> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedType = 'Warning';

  final List<String> _types = ['Warning', 'Safe Zone', 'Help Needed', 'Suspicious Activity'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showAddPinDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131A2A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Safety Pin', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    dropdownColor: const Color(0xFF1A2235),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Pin Type',
                      labelStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF1A2235),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    items: _types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (val) {
                      setStateDialog(() => _selectedType = val!);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Location / Title',
                      labelStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF1A2235),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF1A2235),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    if (_titleController.text.trim().isEmpty) return;
                    
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('safety_pins_locations').add({
                        'uid': user.uid,
                        'type': _selectedType,
                        'title': _titleController.text.trim(),
                        'description': _descController.text.trim(),
                        'upvotes': 0,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }
                    if (mounted) {
                      _titleController.clear();
                      _descController.clear();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Safety Pin added to campus map!'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  child: const Text('Drop Pin', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Warning': return Colors.orangeAccent;
      case 'Safe Zone': return Colors.greenAccent;
      case 'Help Needed': return Colors.redAccent;
      case 'Suspicious Activity': return Colors.purpleAccent;
      default: return Colors.white;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Warning': return Icons.warning;
      case 'Safe Zone': return Icons.verified_user;
      case 'Help Needed': return Icons.local_hospital;
      case 'Suspicious Activity': return Icons.visibility;
      default: return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Campus Safety Pins', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('safety_pins_locations')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No safety pins dropped yet.\nStay safe!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final type = data['type'] ?? 'Warning';
              final color = _getColorForType(type);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getIconForType(type), color: color),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  data['title'] ?? 'Unknown Location',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(type, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['description'] ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPinDialog,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text('Drop Pin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
