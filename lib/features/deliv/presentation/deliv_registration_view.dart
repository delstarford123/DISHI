import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'deliv_driver_dashboard.dart';

class DelivRegistrationView extends StatefulWidget {
  const DelivRegistrationView({super.key});

  @override
  State<DelivRegistrationView> createState() => _DelivRegistrationViewState();
}

class _DelivRegistrationViewState extends State<DelivRegistrationView> {
  String _selectedVehicle = 'Walking';
  bool _isLoading = false;
  bool _documentUploaded = false;

  final List<String> _vehicleTypes = ['Walking', 'Bicycle', 'Motorbike', 'Car'];
  
  // 10 New Driver Features
  String? _operatingHours;
  final _zonesController = TextEditingController();
  String? _maxWeight;
  final _altContactController = TextEditingController();
  bool _cashChange = false;
  bool _expressDelivery = false;
  final _licensePlateController = TextEditingController();
  final _bioController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  
  final _hoursOptions = ['Mornings', 'Evenings', 'Late Night', 'Flexible'];
  final _weightOptions = ['Light Food Only', 'Medium Parcels', 'Heavy/Bulky'];

  @override
  void dispose() {
    _zonesController.dispose();
    _altContactController.dispose();
    _licensePlateController.dispose();
    _bioController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_documentUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your ID/License to continue.'), backgroundColor: MPesaTheme.neonPink),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'roles': FieldValue.arrayUnion(['driver']),
          'isDriverVerified': true, // Auto-verifying for immediate access
          'driverVehicleType': _selectedVehicle,
          'driverProfile': {
            'operatingHours': _operatingHours,
            'preferredZones': _zonesController.text.trim(),
            'maxWeight': _maxWeight,
            'altContact': _altContactController.text.trim(),
            'cashChangeAvailable': _cashChange,
            'expressDelivery': _expressDelivery,
            'licensePlate': _licensePlateController.text.trim(),
            'bio': _bioController.text.trim(),
            'emergencyContactName': _emergencyNameController.text.trim(),
            'emergencyContactPhone': _emergencyPhoneController.text.trim(),
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver Account Created Successfully!'), backgroundColor: MPesaTheme.primaryGreen),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DelivDriverDashboard(user: {})),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: MPesaTheme.neonPink),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Become a Driver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.delivery_dining, size: 80, color: MPesaTheme.primaryGreen),
            const SizedBox(height: 16),
            const Text(
              'Join the DISHI Delivery Fleet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Earn money by delivering food and items on campus.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),

            // Vehicle Type
            const Text('Vehicle Type', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedVehicle,
                  dropdownColor: const Color(0xFF131A2A),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedVehicle = newValue);
                    }
                  },
                  items: _vehicleTypes.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Document Upload
            const Text('ID / License Verification', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // Simulate upload delay
                setState(() => _isLoading = true);
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) {
                    setState(() {
                      _documentUploaded = true;
                      _isLoading = false;
                    });
                  }
                });
              },
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: _documentUploaded ? MPesaTheme.primaryGreen.withOpacity(0.1) : const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _documentUploaded ? MPesaTheme.primaryGreen : Colors.white24,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _documentUploaded ? Icons.check_circle : Icons.upload_file,
                        color: _documentUploaded ? MPesaTheme.primaryGreen : Colors.white54,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _documentUploaded ? 'Document Uploaded' : 'Tap to Upload ID / License',
                        style: TextStyle(
                          color: _documentUploaded ? MPesaTheme.primaryGreen : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            const Text('Logistics & Delivery Prefs', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDropdown('Operating Hours', _hoursOptions, _operatingHours, (val) => setState(() => _operatingHours = val)),
            _buildDropdown('Max Delivery Weight', _weightOptions, _maxWeight, (val) => setState(() => _maxWeight = val)),
            _buildTextField('Preferred Delivery Zones', _zonesController, hint: 'e.g., Hostels, Library'),
            _buildSwitch('I carry cash change', _cashChange, (val) => setState(() => _cashChange = val)),
            _buildSwitch('Available for Express Delivery', _expressDelivery, (val) => setState(() => _expressDelivery = val)),
            
            const SizedBox(height: 32),
            const Text('Driver Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField('License Plate (if applicable)', _licensePlateController, hint: 'e.g. KCA 123A'),
            _buildTextField('Short Bio/Intro', _bioController, hint: 'Fastest runner on campus', maxLines: 2),
            _buildTextField('Alternative Contact Number', _altContactController, hint: 'e.g. 0700000000', keyboardType: TextInputType.phone),
            
            const SizedBox(height: 32),
            const Text('Emergency Contact (Safety First)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField('Emergency Contact Name', _emergencyNameController, hint: 'e.g. John Doe'),
            _buildTextField('Emergency Contact Phone', _emergencyPhoneController, hint: 'e.g. 0722000000', keyboardType: TextInputType.phone),
            
            const SizedBox(height: 48),

            // Submit Button
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen))
                : ElevatedButton(
                    onPressed: _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: MPesaTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Submit Registration', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? currentValue, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          hint: Text(label, style: const TextStyle(color: Colors.white54)),
          isExpanded: true,
          dropdownColor: const Color(0xFF131A2A),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF131A2A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
        ),
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          Switch(
            value: value,
            activeThumbColor: MPesaTheme.primaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
