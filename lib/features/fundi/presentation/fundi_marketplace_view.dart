import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/models/user_model.dart';
import '../../auth/presentation/role_selection_view.dart';
import 'fundi_dashboard_view.dart';

class FundiMarketplaceView extends StatefulWidget {
  final UserModel userModel;
  const FundiMarketplaceView({super.key, required this.userModel});

  @override
  State<FundiMarketplaceView> createState() => _FundiMarketplaceViewState();
}

class _FundiMarketplaceViewState extends State<FundiMarketplaceView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Fundi Juaji', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (widget.userModel.roles.contains('Fundi'))
            IconButton(
              icon: const Icon(Icons.dashboard, color: MPesaTheme.primaryGreen),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FundiDashboardView(user: widget.userModel.toJson()),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trust Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF05D5AA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF05D5AA).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Color(0xFF05D5AA)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '1.5% Escrow Fee applied on payout.\nAll services are backed by DISHI Escrow.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Categories', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildCategoryRow('Academic Support', 'Tutoring, Printing, Formatting', Icons.school, Colors.blue),
            const SizedBox(height: 12),
            _buildCategoryRow('Tech & Digital', 'Software Setup, Repairs', Icons.computer, Colors.orange),
            const SizedBox(height: 12),
            _buildCategoryRow('Daily Errands', 'Grocery, Laundry, Cleaning', Icons.shopping_bag, Colors.pink),
            const SizedBox(height: 12),
            _buildCategoryRow('Lifestyle & Grooming', 'Barber, Braiding, Sneaker Wash', Icons.cut, Colors.purple),
            
            const SizedBox(height: 32),
            const Text('Trending Fundis', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildFundiCard('John Kamau', 'Calculus Tutor', 'BSc Math, Year 3', 4.9, 120),
            const SizedBox(height: 12),
            _buildFundiCard('Sarah Wanjiku', 'In-Hostel Braiding', 'Block B', 4.8, 85),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RoleSelectionView(
                initialRoles: widget.userModel.roles,
                isEditing: true,
              )
            )
          );
        },
        backgroundColor: const Color(0xFF05D5AA),
        icon: const Icon(Icons.work, color: Colors.black),
        label: const Text('Become a Fundi', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoryRow(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A2235)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        ],
      ),
    );
  }

  Widget _buildFundiCard(String name, String service, String details, double rating, int jobs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A2235)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF1A2235),
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(service, style: const TextStyle(color: Color(0xFF05D5AA), fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(rating.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('$jobs jobs', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.verified, color: Colors.blue, size: 16),
              const SizedBox(width: 4),
              Text(details, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF05D5AA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(80, 32),
                ),
                child: const Text('Hire', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Removed _showFundiRegistrationBottomSheet as it's handled by RoleSelectionView
}
