import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
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
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Landlord Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Actions (Horizontal scroll)
            const Text('Property Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildActionCard(Icons.document_scanner, 'E-Leases', _neonBlue),
                  _buildActionCard(Icons.message, 'Broadcasts', _neonCyan),
                  _buildActionCard(Icons.warning, 'Maintenance', _neonOrange),
                  _buildActionCard(Icons.upload_file, 'CSV Import', _neonPurple),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Properties Stream
            const Text('Your Properties', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.streamCollection(
                'housing_properties', 
                whereField: 'merchant_id', 
                isEqualTo: _currentUserId.isEmpty ? 'MOCK_ID' : _currentUserId
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _neonBlue));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('You have no listed properties.', style: TextStyle(color: _textSecondary)));
                }

                final properties = snapshot.data!.docs.map((doc) => 
                  HousingPropertyModel.fromJson(doc.data() as Map<String, dynamic>, doc.id)
                ).toList();

                return Column(
                  children: properties.map((prop) => _buildPropertyCard(prop)).toList(),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
      ),
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
                Text(prop.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Rooms Available: ${prop.availableRooms}', style: const TextStyle(color: _textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Text('KES ${prop.pricePerMonth.toStringAsFixed(0)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String label, Color color) {
    return Container(
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
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
