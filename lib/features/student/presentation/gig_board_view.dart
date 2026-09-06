import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class GigBoardView extends StatefulWidget {
  final Map<String, dynamic> user;
  const GigBoardView({super.key, required this.user});

  @override
  State<GigBoardView> createState() => _GigBoardViewState();
}

class _GigBoardViewState extends State<GigBoardView> {
  String _selectedCategory = 'All';
  String _locationFilter = 'All'; // "On-Campus only", "Remote", "All"
  
  final List<String> _categories = ['All', 'Design', 'Programming', 'Writing', 'Tutor', 'Errands'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Gig Board', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: MPesaTheme.neonCyan),
            onPressed: () => _postGigDialog(context),
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('gigs')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                // 1. Gig Categories & 9. Location Filters
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final catMatch = _selectedCategory == 'All' || data['category'] == _selectedCategory;
                  final locMatch = _locationFilter == 'All' || data['locationType'] == _locationFilter;
                  return catMatch && locMatch;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('No gigs found. Post one!', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final gig = filteredDocs[index].data() as Map<String, dynamic>;
                    return _buildGigCard(gig, filteredDocs[index].id);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c),
                  selected: _selectedCategory == c,
                  onSelected: (val) => setState(() => _selectedCategory = c),
                  selectedColor: MPesaTheme.neonCyan.withOpacity(0.3),
                  checkmarkColor: MPesaTheme.neonCyan,
                  backgroundColor: const Color(0xFF131A2A),
                  labelStyle: TextStyle(color: _selectedCategory == c ? MPesaTheme.neonCyan : Colors.white70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Location:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _locationFilter,
                dropdownColor: const Color(0xFF131A2A),
                style: const TextStyle(color: MPesaTheme.neonCyan, fontSize: 12),
                underline: const SizedBox(),
                items: ['All', 'On-Campus', 'Remote'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (val) => setState(() => _locationFilter = val!),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGigCard(Map<String, dynamic> gig, String gigId) {
    // 5. Urgency Badges
    final urgency = gig['urgency'] ?? 'Flexible';
    Color urgencyColor = Colors.grey;
    if (urgency == 'Urgent') urgencyColor = Colors.redAccent;
    if (urgency == 'Flexible') urgencyColor = Colors.greenAccent;
    
    // 10. Gig Verification
    final isVerified = gig['posterVerified'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: urgencyColor.withOpacity(0.5)),
                ),
                child: Text(urgency, style: TextStyle(color: urgencyColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text(gig['category'] ?? 'Category', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(gig['title'] ?? 'Gig Title', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('By ${gig['posterName'] ?? 'Student'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (isVerified) const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.verified, color: Colors.blueAccent, size: 14),
              )
            ],
          ),
          // 4. Rating & Reviews summary
          if (gig['posterRating'] != null)
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text('${gig['posterRating']} (Student Freelancer)', style: const TextStyle(color: Colors.amber, fontSize: 12)),
              ],
            ),
            
          const SizedBox(height: 12),
          Text(gig['description'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 14)),
          
          // 2. Portfolio Carousel
          if (gig['portfolioImages'] != null && (gig['portfolioImages'] as List).isNotEmpty)
            Container(
              height: 100,
              margin: const EdgeInsets.only(top: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (gig['portfolioImages'] as List).length,
                itemBuilder: (context, idx) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(gig['portfolioImages'][idx]),
                        fit: BoxFit.cover,
                      )
                    ),
                  );
                },
              ),
            ),
            
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KES ${gig['budget'] ?? 0}', style: const TextStyle(color: MPesaTheme.neonCyan, fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  // 7. In-App Gig Chat
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
                    onPressed: () => _openChat(gigId, gig['posterName']),
                  ),
                  // 6. Gig Bidding System / 8. Quick Hire (depends on fixed price)
                  if (gig['isFixedPrice'] == true)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonCyan),
                      onPressed: () => _quickHireEscrow(gigId, gig['budget']),
                      child: const Text('Quick Hire', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    )
                  else
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: MPesaTheme.neonCyan)),
                      onPressed: () => _placeBid(gigId),
                      child: const Text('Place Bid', style: TextStyle(color: MPesaTheme.neonCyan)),
                    )
                ],
              )
            ],
          )
        ],
      ),
    );
  }
  
  // 3. Escrow Payments Flow
  void _quickHireEscrow(String gigId, num amount) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF131A2A),
      title: const Text('Secure Hire via Escrow', style: TextStyle(color: Colors.white)),
      content: Text('KES $amount will be deducted from your DISHI Wallet and held securely in Escrow until the gig is completed. Are you sure you want to hire this freelancer?', style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonCyan),
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funds secured in Escrow. You have hired the freelancer!')));
            // Actually call escrow backend here
          },
          child: const Text('Confirm & Hire', style: TextStyle(color: Colors.black)),
        )
      ],
    ));
  }
  
  void _placeBid(String gigId) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF131A2A),
      title: const Text('Place your Bid', style: TextStyle(color: Colors.white)),
      content: const TextField(
        decoration: InputDecoration(
          hintText: 'Enter your bid amount in KES',
          hintStyle: TextStyle(color: Colors.white54),
          prefixIcon: Icon(Icons.money, color: MPesaTheme.neonCyan),
        ),
        keyboardType: TextInputType.number,
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.neonCyan),
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bid placed! The poster will be notified.')));
          },
          child: const Text('Submit Bid', style: TextStyle(color: Colors.black)),
        )
      ],
    ));
  }
  
  void _openChat(String gigId, String posterName) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening chat with $posterName...')));
    // Push to ChatView
  }

  void _postGigDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const AlertDialog(
      backgroundColor: Color(0xFF131A2A),
      title: Text('Post a Gig', style: TextStyle(color: Colors.white)),
      content: Text('Gig posting form goes here.', style: TextStyle(color: Colors.white70)),
    ));
  }
}
