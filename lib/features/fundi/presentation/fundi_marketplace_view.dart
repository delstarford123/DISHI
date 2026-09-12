import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/models/user_model.dart';
import 'fundi_dashboard_view.dart';
import 'fundi_registration_view.dart';

class FundiMarketplaceView extends StatefulWidget {
  final UserModel userModel;
  const FundiMarketplaceView({super.key, required this.userModel});

  @override
  State<FundiMarketplaceView> createState() => _FundiMarketplaceViewState();
}

class _FundiMarketplaceViewState extends State<FundiMarketplaceView> {
  String? _selectedCategory;

  final List<Map<String, dynamic>> _categories = [
    {'title': 'Academic Support', 'subtitle': 'Tutoring, Printing, Formatting', 'icon': Icons.school, 'color': Colors.blue},
    {'title': 'Tech & Digital', 'subtitle': 'Software Setup, Repairs', 'icon': Icons.computer, 'color': Colors.orange},
    {'title': 'Daily Errands', 'subtitle': 'Grocery, Laundry, Cleaning', 'icon': Icons.shopping_bag, 'color': Colors.pink},
    {'title': 'Lifestyle & Grooming', 'subtitle': 'Barber, Braiding, Sneaker Wash', 'icon': Icons.cut, 'color': Colors.purple},
  ];

  @override
  Widget build(BuildContext context) {
    bool isFundi = widget.userModel.roles.contains('Fundi');

    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Fundi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (isFundi)
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Categories', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                if (_selectedCategory != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedCategory = null),
                    child: const Text('Clear Filter', style: TextStyle(color: Color(0xFF05D5AA))),
                  )
              ],
            ),
            const SizedBox(height: 16),
            ..._categories.map((cat) => _buildCategoryRow(
                  cat['title'], 
                  cat['subtitle'], 
                  cat['icon'], 
                  cat['color']
                )),
            
            const SizedBox(height: 32),
            Text(
              _selectedCategory == null ? 'Trending Fundis' : '$_selectedCategory Fundis', 
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            _buildRealFundisList(),
          ],
        ),
      ),
      floatingActionButton: isFundi ? null : FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FundiRegistrationView(
                userModel: widget.userModel,
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
    bool isSelected = _selectedCategory == title;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            // Toggle selection
            _selectedCategory = isSelected ? null : title;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : const Color(0xFF131A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : const Color(0xFF1A2235)),
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
              if (isSelected)
                Icon(Icons.check_circle, color: color, size: 20)
              else
                const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealFundisList() {
    Query query = FirebaseFirestore.instance.collection('campus_gig_workers').where('is_available', isEqualTo: true);
    
    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF05D5AA)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading fundis: ${snapshot.error}', style: TextStyle(color: Colors.red[300])));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Text('No fundis found in this category right now.', style: TextStyle(color: Colors.white54)),
          );
        }

        // Sort in memory to avoid needing a complex Firestore composite index
        var docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;
          double aRating = (aData['rating'] ?? 0).toDouble();
          double bRating = (bData['rating'] ?? 0).toDouble();
          return bRating.compareTo(aRating); // Descending order
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var workerData = doc.data() as Map<String, dynamic>;
            String workerId = workerData['user_id'] ?? '';
            String service = workerData['category'] ?? 'Service';
            double rating = (workerData['rating'] ?? 5.0).toDouble();
            int jobs = workerData['completed_gigs'] ?? 0;
            String desc = workerData['description'] ?? 'Verified Campus Fundi';

            // Fetch the user's name
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(workerId).get(),
              builder: (context, userSnap) {
                String name = 'Loading...';
                if (userSnap.hasData && userSnap.data!.exists) {
                  var uData = userSnap.data!.data() as Map<String, dynamic>;
                  name = uData['firstName'] ?? uData['lastName'] ?? 'Campus Worker';
                }

                return _buildFundiCard(
                  workerId: workerId,
                  name: name,
                  service: service,
                  details: desc,
                  rating: rating,
                  jobs: jobs,
                );
              },
            );
          },
        );
      }
    );
  }

  Widget _buildFundiCard({
    required String workerId,
    required String name,
    required String service,
    required String details,
    required double rating,
    required int jobs
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
                        Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                Expanded(
                  child: Text(
                    details, 
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton(
                  onPressed: widget.userModel.uid == workerId ? null : () {
                    // Show hire dialog
                    _showHireDialog(workerId, name, service);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF05D5AA),
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(80, 32),
                  ),
                  child: const Text('Hire', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showHireDialog(String workerId, String workerName, String category) {
    final TextEditingController detailsCtrl = TextEditingController();
    final TextEditingController priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: Text('Hire $workerName', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Requesting $category service', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: detailsCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Job Details',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF05D5AA))),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Offer Price (Ksh)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF05D5AA))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF05D5AA)),
            onPressed: () async {
              if (detailsCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
              
              String details = detailsCtrl.text;
              double? price = double.tryParse(priceCtrl.text);
              if (price == null) return;
              
              Navigator.pop(ctx);
              
              // We simulate the backend request by writing to Firebase directly to keep things fast and offline-capable in flutter
              try {
                await FirebaseFirestore.instance.collection('campus_gig_requests').add({
                  'requester_id': widget.userModel.uid,
                  'category': category,
                  'details': details,
                  'price_offer': price,
                  'status': 'pending',
                  'worker_id': workerId,
                  'created_at': FieldValue.serverTimestamp(),
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gig Request sent successfully! Escrow pending.'))
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send request: $e'))
                  );
                }
              }
            },
            child: const Text('Send Offer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
