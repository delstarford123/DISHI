import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/housing_property_model.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _textSecondary = Color(0xFF8B9BB4);

class MerchantHousingDashboard extends StatefulWidget {
  const MerchantHousingDashboard({super.key});

  @override
  State<MerchantHousingDashboard> createState() => _MerchantHousingDashboardState();
}

class _MerchantHousingDashboardState extends State<MerchantHousingDashboard> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ─── Post Room Form Controllers ───────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _securityCtrl = TextEditingController();
  final _amenitiesCtrl = TextEditingController();
  File? _selectedImage;
  bool _isPosting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _securityCtrl.dispose();
    _amenitiesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _postRoom() async {
    if (_titleCtrl.text.isEmpty || _locationCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please fill title, location, and price')));
      return;
    }
    setState(() => _isPosting = true);
    try {
      String? imageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref('property_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // Build amenities list from comma-separated string
      final amenities = _amenitiesCtrl.text
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance.collection('housing_properties').add({
        'title': _titleCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'pricePerMonth': double.tryParse(_priceCtrl.text) ?? 0.0,
        'description': _descCtrl.text.trim(),
        'security': _securityCtrl.text.trim(),
        'amenities': amenities,
        'imageUrls': imageUrl != null ? [imageUrl] : [],
        'merchant_id': _currentUserId,
        'availableRooms': 1,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear form
      _titleCtrl.clear();
      _locationCtrl.clear();
      _priceCtrl.clear();
      _descCtrl.clear();
      _securityCtrl.clear();
      _amenitiesCtrl.clear();
      setState(() => _selectedImage = null);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Room posted to Keja Marketplace!'),
              backgroundColor: Color(0xFF05D5AA)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showPostRoomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Post a Room',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                // Image picker
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 75);
                    if (picked != null) {
                      setSheet(() => _selectedImage = File(picked.path));
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: _surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _selectedImage != null
                                ? _neonCyan
                                : Colors.white24)),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_selectedImage!, fit: BoxFit.cover))
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  size: 36, color: Color(0xFF05D5AA)),
                              SizedBox(height: 8),
                              Text('Tap to upload room photo',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _field('Room Title', 'e.g. Single Room — Karen Estate', _titleCtrl),
                const SizedBox(height: 12),
                _field('Location', 'e.g. Karen, Nairobi', _locationCtrl),
                const SizedBox(height: 12),
                _field('Price per Month (KES)', '0.00', _priceCtrl,
                    isNumber: true),
                const SizedBox(height: 12),
                _field('Description', 'Describe the room...', _descCtrl,
                    maxLines: 3),
                const SizedBox(height: 12),
                _field('Security Details',
                    'e.g. 24hr guard, CCTV, electric fence', _securityCtrl),
                const SizedBox(height: 12),
                _field('Amenities (comma-separated)',
                    'e.g. WiFi, Water, Electricity, Parking', _amenitiesCtrl),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _neonCyan,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: _isPosting ? null : _postRoom,
                    icon: _isPosting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.home, color: Colors.black),
                    label: Text(
                        _isPosting ? 'Posting...' : 'Post to Keja Marketplace',
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String hint, TextEditingController ctrl,
      {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.multiline,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _neonCyan)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Landlord Hub',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: _showPostRoomSheet,
            icon: const Icon(Icons.add_home, color: _neonCyan),
            label: const Text('Post Room',
                style:
                    TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Actions (Horizontal scroll)
            const Text('Property Actions',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildActionCard(Icons.add_home, 'Post Room', _neonCyan,
                      onTap: _showPostRoomSheet),
                  _buildActionCard(Icons.document_scanner, 'E-Leases', _neonBlue),
                  _buildActionCard(Icons.message, 'Broadcasts', _neonCyan),
                  _buildActionCard(Icons.warning, 'Maintenance', _neonOrange),
                  _buildActionCard(Icons.upload_file, 'CSV Import', _neonPurple),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Properties Stream
            const Text('Your Properties',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                .collection('housing_properties')
                .where('merchant_id', isEqualTo: _currentUserId.isEmpty ? '__none__' : _currentUserId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _neonBlue));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _neonCyan.withOpacity(0.3))),
                    child: Column(
                      children: [
                        const Icon(Icons.home_work,
                            size: 48, color: _textSecondary),
                        const SizedBox(height: 12),
                        const Text('No properties listed yet',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Tap "Post Room" to list your first property',
                            style:
                                TextStyle(color: _textSecondary, fontSize: 13),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showPostRoomSheet,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _neonCyan),
                          icon: const Icon(Icons.add_home, color: Colors.black),
                          label: const Text('Post Room',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }

                final properties = snapshot.data!.docs
                    .map((doc) => HousingPropertyModel.fromJson(
                        doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                return Column(
                  children:
                      properties.map((prop) => _buildPropertyCard(prop)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(HousingPropertyModel prop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prop.imageUrls.isNotEmpty)
            Image.network(prop.imageUrls.first,
                height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox()),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _neonBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.apartment, color: _neonBlue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prop.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('${prop.availableRooms} rooms available',
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Text('KES ${prop.pricePerMonth.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: _neonCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String label, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
