import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class DelivHeatmapView extends StatelessWidget {
  const DelivHeatmapView({super.key});

  final List<Map<String, dynamic>> _hotspots = const [
    {
      'name': 'Main Student Cafeteria',
      'category': 'Dining & Fast Food',
      'surge': '1.5x',
      'demandLevel': 'Very High',
      'color': Color(0xFFFF2A6D),
      'activeOrders': 8,
      'avgPay': 'KES 180',
      'bestTime': '12:00 PM - 2:30 PM & 6:00 PM - 9:00 PM',
      'icon': Icons.restaurant_rounded,
    },
    {
      'name': 'Science & Tech Complex',
      'category': 'Academic Gigs & Printing',
      'surge': '1.3x',
      'demandLevel': 'High',
      'color': Color(0xFFFF6F00),
      'activeOrders': 5,
      'avgPay': 'KES 150',
      'bestTime': '10:00 AM - 4:00 PM',
      'icon': Icons.science_rounded,
    },
    {
      'name': 'Hostels Zone (Hall 3 - Hall 7)',
      'category': 'Late Night Snacks & Parcels',
      'surge': '1.4x',
      'demandLevel': 'High',
      'color': Color(0xFF8B5CF6),
      'activeOrders': 6,
      'avgPay': 'KES 140',
      'bestTime': '7:00 PM - 11:30 PM',
      'icon': Icons.apartment_rounded,
    },
    {
      'name': 'University Main Library',
      'category': 'Coffee, Drinks & Errand Runs',
      'surge': '1.2x',
      'demandLevel': 'Moderate',
      'color': Color(0xFF3B82F6),
      'activeOrders': 3,
      'avgPay': 'KES 130',
      'bestTime': '2:00 PM - 10:00 PM',
      'icon': Icons.local_library_rounded,
    },
    {
      'name': 'Campus Commercial Gate & Market',
      'category': 'Groceries & Heavy Parcels',
      'surge': '1.3x',
      'demandLevel': 'High',
      'color': Color(0xFF10B981),
      'activeOrders': 4,
      'avgPay': 'KES 220',
      'bestTime': '3:00 PM - 7:00 PM',
      'icon': Icons.storefront_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Campus Demand Heatmap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _neonOrange.withValues(alpha: 0.15),
                  _neonCyan.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _neonOrange.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _neonOrange.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, color: _neonOrange, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Surge Multipliers Active',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Position yourself near high-demand hotspots to earn up to 50% more per delivery.',
                        style: TextStyle(color: _textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'High-Demand Campus Hotspots',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Hotspots List
          ..._hotspots.map((spot) {
            final Color spotColor = spot['color'];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: spotColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: spotColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(spot['icon'], color: spotColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spot['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              spot['category'],
                              style: const TextStyle(color: _textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Surge Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: spotColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: spotColor),
                        ),
                        child: Text(
                          '${spot['surge']} Surge',
                          style: TextStyle(
                            color: spotColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric('Active Orders', '${spot['activeOrders']} orders', _neonCyan),
                      _buildMetric('Avg Payout', spot['avgPay'], Colors.white),
                      _buildMetric('Demand', spot['demandLevel'], spotColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 13, color: _textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        'Peak hours: ${spot['bestTime']}',
                        style: const TextStyle(color: _textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
