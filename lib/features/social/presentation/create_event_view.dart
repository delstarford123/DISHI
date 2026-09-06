import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/mpesa_theme.dart';

class CreateEventView extends StatefulWidget {
  final Map<String, dynamic> user;

  const CreateEventView({super.key, required this.user});

  @override
  State<CreateEventView> createState() => _CreateEventViewState();
}

class _CreateEventViewState extends State<CreateEventView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  
  // Phase 6 Additions
  final _vipPriceController = TextEditingController();
  final _regularCapacityController = TextEditingController();
  final _vipCapacityController = TextEditingController();
  final _earlyBirdCapacityController = TextEditingController();
  final _promoCodeController = TextEditingController();
  final _promoDiscountController = TextEditingController();
  
  final _capacityController = TextEditingController();
  final _earlyBirdPriceController = TextEditingController();
  final _earlyBirdDeadlineController = TextEditingController();
  final _payoutDestinationController = TextEditingController();

  String _selectedCategory = 'Party';
  final List<String> _categories = ['Party', 'Sports', 'Academic', 'Arts', 'Tech', 'Other'];

  String _payoutType = 'M-PESA Number';
  final List<String> _payoutTypes = ['M-PESA Number', 'Paybill', 'Buy Goods Till'];

  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an event poster.')));
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final eventId = const Uuid().v4();
      
      final storageRef = FirebaseStorage.instance.ref().child('event_images').child('$eventId.jpg');
      await storageRef.putFile(_imageFile!);
      final imageUrl = await storageRef.getDownloadURL();

      final eventData = {
        'id': eventId,
        'title': _titleController.text.trim(),
        'date': _dateController.text.trim(),
        'time': _timeController.text.trim(),
        'location': _locationController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 0,
        'regularCapacity': int.tryParse(_regularCapacityController.text.trim()) ?? 0,
        'vipPrice': double.tryParse(_vipPriceController.text.trim()),
        'vipCapacity': int.tryParse(_vipCapacityController.text.trim()) ?? 0,
        'earlyBirdPrice': double.tryParse(_earlyBirdPriceController.text.trim()),
        'earlyBirdCapacity': int.tryParse(_earlyBirdCapacityController.text.trim()) ?? 0,
        'earlyBirdDeadline': _earlyBirdDeadlineController.text.trim(),
        'promoCode': _promoCodeController.text.trim().toUpperCase(),
        'promoDiscount': double.tryParse(_promoDiscountController.text.trim()) ?? 0.0,
        'payoutType': _payoutType,
        'payoutDestination': _payoutDestinationController.text.trim(),
        'imageUrl': imageUrl,
        'creatorId': widget.user['dishiId'] ?? widget.user['uid'],
        'creatorName': widget.user['name'] ?? widget.user['displayName'] ?? 'DISHI User',
        'createdAt': FieldValue.serverTimestamp(),
        'ticketsSold': 0,
        'vipSold': 0,
        'earlyBirdSold': 0,
        'regularSold': 0,
        'views': 0,
        'revenue': 0.0,
      };

      await FirebaseFirestore.instance.collection('events').doc(eventId).set(eventData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event Created Successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131A2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: MPesaTheme.neonCyan.withOpacity(0.5)),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(_imageFile!, fit: BoxFit.cover),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, color: MPesaTheme.neonCyan, size: 48),
                                  SizedBox(height: 8),
                                  Text('Upload Event Poster', style: TextStyle(color: MPesaTheme.neonCyan)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    const Text('Event Details', style: TextStyle(color: MPesaTheme.neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTextField(_titleController, 'Event Title', Icons.title),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: const Color(0xFF131A2A),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.category, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF131A2A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_dateController, 'Date (e.g. Oct 15)', Icons.calendar_today)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_timeController, 'Time (e.g. 9:00 PM)', Icons.access_time)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_locationController, 'Location', Icons.location_on),
                    const SizedBox(height: 16),
                    _buildTextField(_descController, 'Description (Supports Markdown)', Icons.description, maxLines: 3),
                    const SizedBox(height: 24),

                    const Text('Ticketing & Inventory (Phase 6)', style: TextStyle(color: MPesaTheme.neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTextField(_capacityController, 'Total Overall Capacity', Icons.people, isNumber: true),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_priceController, 'Regular Price', Icons.attach_money, isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_regularCapacityController, 'Regular Cap', Icons.inventory, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_earlyBirdPriceController, 'Early Bird Price', Icons.local_offer, isNumber: true, isRequired: false)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_earlyBirdCapacityController, 'Early Bird Cap', Icons.inventory, isNumber: true, isRequired: false)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_earlyBirdDeadlineController, 'Early Bird Deadline', Icons.timer, isRequired: false),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_vipPriceController, 'VIP Price', Icons.star, isNumber: true, isRequired: false)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_vipCapacityController, 'VIP Cap', Icons.inventory, isNumber: true, isRequired: false)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Promo & Marketing', style: TextStyle(color: MPesaTheme.neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_promoCodeController, 'Promo Code (Opt)', Icons.discount, isRequired: false)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_promoDiscountController, '% Discount', Icons.percent, isNumber: true, isRequired: false)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text('Payout Configuration', style: TextStyle(color: MPesaTheme.neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('A 5 KES commission applies per ticket. The rest is routed to your selected destination.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _payoutType,
                      dropdownColor: const Color(0xFF131A2A),
                      decoration: InputDecoration(
                        labelText: 'Withdrawal Method',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF131A2A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: _payoutTypes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _payoutType = val!),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_payoutDestinationController, 'Destination Number/Paybill/Till', Icons.numbers, isNumber: true),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonCyan),
                        onPressed: _submitEvent,
                        child: const Text('Publish Event', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: (val) {
        if (isRequired && (val == null || val.isEmpty)) return 'Required';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF131A2A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
