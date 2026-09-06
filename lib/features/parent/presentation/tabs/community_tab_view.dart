import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _textSecondary = Color(0xFF8B9BB4);

class CommunityTabView extends StatelessWidget {
  final Map<String, dynamic> user;
  
  const CommunityTabView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: _neonBlue,
            labelColor: _neonBlue,
            unselectedLabelColor: _textSecondary,
            tabs: [
              Tab(text: 'Forum'),
              Tab(text: 'Calendar'),
              Tab(text: 'P2P Transfer'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildForumView(),
                _buildCalendarView(),
                _buildP2pTransferView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForumView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Parent Forum', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () {}, 
              icon: const Icon(Icons.edit, size: 16), 
              label: const Text('Post'),
              style: ElevatedButton.styleFrom(backgroundColor: _neonBlue),
            )
          ],
        ),
        const SizedBox(height: 16),
        _buildForumPost('Carpool to MMUST', 'Anyone driving from CBD tomorrow morning?', 'Jane D.', '2h ago'),
        _buildForumPost('Vendor Review: QuickBites', 'The new healthy wraps are amazing! Highly recommend.', 'John S.', '5h ago'),
      ],
    );
  }

  Widget _buildForumPost(String title, String content, String author, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$author • $time', style: const TextStyle(color: _neonCyan, fontSize: 12)),
              const Row(
                children: [
                  Icon(Icons.thumb_up_alt_outlined, color: _textSecondary, size: 16),
                  SizedBox(width: 4),
                  Text('12', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  SizedBox(width: 12),
                  Icon(Icons.comment_outlined, color: _textSecondary, size: 16),
                  SizedBox(width: 4),
                  Text('4', style: TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Upcoming Events', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildEventCard('Sports Day', 'Friday, 12th Nov', 'Main Campus Field', true),
        _buildEventCard('PTA Meeting', 'Monday, 15th Nov', 'Virtual / Zoom', false),
      ],
    );
  }

  Widget _buildEventCard(String title, String date, String location, bool isSchool) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: isSchool ? _neonBlue : _neonCyan, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: isSchool ? _neonBlue.withOpacity(0.2) : _neonCyan.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(isSchool ? 'School' : 'Family', style: TextStyle(color: isSchool ? _neonBlue : _neonCyan, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: _textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(date, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, color: _textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildP2pTransferView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send Funds to Another Parent', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Chip in for gifts, carpools, or cover a friend\'s lunchbox instantly.', style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 24),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Parent Phone Number or Tag ID',
              labelStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (Ksh)',
              labelStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Note (e.g. Teacher Gift)',
              labelStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Send Funds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
