import sys
import re

with open('lib/features/deliv/presentation/deliv_driver_dashboard.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix the top header row overflow by wrapping the first inner Row with Expanded
content = content.replace(
'''                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => ProfileHubSheet(user: widget.user),
                                );
                              },
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: _cardColor,
                                backgroundImage: widget.user['photoUrl'] != null ? NetworkImage(widget.user['photoUrl']) : null,
                                child: widget.user['photoUrl'] == null ? const Icon(Icons.person, color: Colors.white54) : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_getGreeting()} $firstName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('Boda · ★ 4.9 · 312 trips', style: TextStyle(color: _textSecondary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        Container''',
'''                        Expanded(
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => ProfileHubSheet(user: widget.user),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: _cardColor,
                                  backgroundImage: widget.user['photoUrl'] != null ? NetworkImage(widget.user['photoUrl']) : null,
                                  child: widget.user['photoUrl'] == null ? const Icon(Icons.person, color: Colors.white54, size: 30) : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${_getGreeting()} $firstName', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    const Text('Boda · ★ 4.9 · 312 trips', style: TextStyle(color: _textSecondary, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container'''
)

# 2. Fix the stream builder query (remove orderBy) and add hasError check
content = content.replace(
'''                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('deliv_requests')
                          .where('status', isEqualTo: 'open')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _neonCyan));''',
'''                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('deliv_requests')
                          .where('status', isEqualTo: 'open')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error loading gigs: ${snapshot.error}', style: const TextStyle(color: _neonRed))));
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _neonCyan));'''
)

# And sort locally
content = content.replace(
'''                        var docs = snapshot.data!.docs;
                        final uid = FirebaseAuth.instance.currentUser?.uid;''',
'''                        var docs = snapshot.data!.docs.toList();
                        docs.sort((a, b) {
                          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                          if (aTime == null || bTime == null) return 0;
                          return bTime.compareTo(aTime);
                        });
                        final uid = FirebaseAuth.instance.currentUser?.uid;'''
)

# 3. Slide to cash out
content = content.replace(
'''                    // --- CASH OUT SLIDER ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Slide to Cash Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20)),
                            child: const Icon(Icons.arrow_forward_ios, color: _neonCyan, size: 16),
                          )
                        ],
                      ),
                    ),''',
'''                    // --- CASH OUT SLIDER ---
                    HighFrictionAction(
                      label: 'Hold to Cash Out Earnings',
                      baseColor: _neonCyan,
                      onActionCompleted: () {
                         _cashOutEarnings();
                      },
                    ),'''
)

# 4. Increase sizes and fix imports
content = content.replace("import 'package:firebase_auth/firebase_auth.dart';", "import 'package:firebase_auth/firebase_auth.dart';\nimport 'dart:convert';\nimport 'package:http/http.dart' as http;\nimport '../../../core/config/api_config.dart';")

# Add _cashOutEarnings method
cash_out_func = '''
  Future<void> _cashOutEarnings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mpesa/driver_withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driver_id': uid,
          'amount': _earnings,
          'method': 'M-PESA Number',
          'destination': widget.user['phoneNumber'] ?? '0700000000'
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cash out successful! Check M-PESA.')));
        setState(() => _earnings = 0);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cash out failed: ${response.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _acceptGig'''
content = content.replace("  void _acceptGig", cash_out_func)

# Increase font sizes in Earnings Card
content = content.replace(
'''            Text(title, style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),''',
'''            Text(title, style: const TextStyle(color: _textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),'''
)

# Increase font sizes in Stat Column
content = content.replace(
'''      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
      ],''',
'''      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 14)),
      ],'''
)

# Check Categories font sizes
content = content.replace(
'''                                  Text(g['name'], style: TextStyle(color: isSelected ? Colors.black : Colors.white)),''',
'''                                  Text(g['name'], style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 16)),'''
)

with open('lib/features/deliv/presentation/deliv_driver_dashboard.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated deliv_driver_dashboard.dart')
