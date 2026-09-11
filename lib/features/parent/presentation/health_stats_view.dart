import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'package:fl_chart/fl_chart.dart';

class HealthStatsView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const HealthStatsView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<HealthStatsView> createState() => _HealthStatsViewState();
}

class _HealthStatsViewState extends State<HealthStatsView> {
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Health & Growth Stats'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.favorite, color: MPesaTheme.neonPink, size: 32),
                SizedBox(width: 12),
                Text(
                  'Health Analytics',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Track your student\'s nutritional purchases and physical activity goals to ensure they maintain a balanced lifestyle on campus.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            if (widget.selectedStudentUid == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No student selected in Dependents tab.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 32),
            if (widget.selectedStudentUid != null) ...[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Mock Data Analytics Widget for Phase 3 visualization
                      _buildSummaryCard('Calories (This Week)', '14,200 kcal', Icons.local_dining, Colors.orange),
                      const SizedBox(height: 16),
                      _buildSummaryCard('Water Intake Avg', '2.5 L / day', Icons.water_drop, Colors.blue),
                      const SizedBox(height: 16),
                      _buildSummaryCard('Fruit Purchases', '12 Items', Icons.apple, Colors.green),
                      const SizedBox(height: 32),
                      const Text(
                        'Weekly Nutrition Trend',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  getTitlesWidget: (value, meta) {
                                    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                    if (value.toInt() >= 0 && value.toInt() < days.length) {
                                      return Text(days[value.toInt()], style: const TextStyle(color: Colors.white54, fontSize: 12));
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: const [
                                  FlSpot(0, 3),
                                  FlSpot(1, 4),
                                  FlSpot(2, 3.5),
                                  FlSpot(3, 5),
                                  FlSpot(4, 4.5),
                                  FlSpot(5, 6),
                                  FlSpot(6, 5),
                                ],
                                isCurved: true,
                                color: MPesaTheme.neonPink,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                belowBarData: BarAreaData(show: true, color: MPesaTheme.neonPink.withOpacity(0.2)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF131A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white54)),
        trailing: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }
}

