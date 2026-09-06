import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/housing_property_model.dart';
import 'room_detail_view.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _textSecondary = Color(0xFF8B9BB4);

class HousingMarketplaceView extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const HousingMarketplaceView({super.key, required this.user});

  @override
  State<HousingMarketplaceView> createState() => _HousingMarketplaceViewState();
}

class _HousingMarketplaceViewState extends State<HousingMarketplaceView> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Under 5k', 'Verified', 'Hostels', 'Singles'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Keja Marketplace', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.map, color: _neonBlue), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    selectedColor: _neonBlue,
                    backgroundColor: _surfaceLight,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          
          // Live Properties Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.streamCollection('housing_properties', orderByField: 'pricePerMonth'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _neonBlue));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error loading properties: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No properties listed right now.', style: TextStyle(color: _textSecondary)));
                }

                List<HousingPropertyModel> properties = snapshot.data!.docs
                    .map((doc) => HousingPropertyModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                // Apply Local Filters
                if (_selectedFilter == 'Under 5k') {
                  properties = properties.where((p) => p.pricePerMonth < 5000).toList();
                } else if (_selectedFilter == 'Verified') {
                  properties = properties.where((p) => p.isVerified).toList();
                }

                if (properties.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: _textSecondary),
                        const SizedBox(height: 16),
                        Text('No properties match "$_selectedFilter"', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final prop = properties[index];
                    return _buildPropertyCard(prop);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPropertyCard(HousingPropertyModel prop) {
    return GestureDetector(
      onTap: () {
        // We will route to room_detail_view and pass the property/user
        Navigator.push(context, MaterialPageRoute(builder: (context) => RoomDetailView(propertyId: prop.id, user: widget.user)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _surfaceLight, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mock Image Header (Replace with CachedNetworkImage when storage is live)
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: _surfaceLight,
                image: prop.imageUrls.isNotEmpty
                    ? DecorationImage(image: NetworkImage(prop.imageUrls.first), fit: BoxFit.cover)
                    : null,
              ),
              child: prop.imageUrls.isEmpty
                  ? const Center(child: Icon(Icons.home_work, size: 64, color: _textSecondary))
                  : null,
            ),
            
            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          prop.title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (prop.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _neonBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.verified, color: _neonBlue, size: 14),
                              SizedBox(width: 4),
                              Text('Verified', style: TextStyle(color: _neonBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: _textSecondary, size: 14),
                      const SizedBox(width: 4),
                      Text(prop.location, style: const TextStyle(color: _textSecondary, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ksh ${prop.pricePerMonth.toStringAsFixed(0)} / mo',
                        style: const TextStyle(color: _neonBlue, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${prop.availableRooms} rooms left',
                        style: TextStyle(color: prop.availableRooms < 3 ? Colors.orange : _textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                      )
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
