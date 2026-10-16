import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class DelivAnalyticsView extends StatelessWidget {
  final double weeklyEarnings;
  final int completedTrips;
  final double todayEarnings;
  final double customerRating;
  final double acceptanceRate;
  final double avgSpeedMins;
  final double cancellationRate;
  final Map<int, int>? dailyTrips;
  final int totalCompletedRuns;

  const DelivAnalyticsView({
    super.key,
    this.weeklyEarnings = 0.0,
    this.completedTrips = 0,
    this.todayEarnings = 0.0,
    this.customerRating = 5.0,
    this.acceptanceRate = 98.0,
    this.avgSpeedMins = 12.5,
    this.cancellationRate = 0.0,
    this.dailyTrips,
    this.totalCompletedRuns = 0,
  });

  @override
  Widget build(BuildContext context) {
    final Map<int, int> tripsMap = dailyTrips ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    int maxDaily = tripsMap.values.fold(0, (max, v) => math.max(max, v));
    if (maxDaily == 0) maxDaily = 1;

    // Determine current tier
    String tierTitle = 'Bronze Courier Tier';
    String tierDesc = 'Complete ${math.max(1, 20 - totalCompletedRuns)} more deliveries to reach Silver Tier.';
    Color tierColor = const Color(0xFFCD7F32);
    if (totalCompletedRuns >= 50) {
      tierTitle = 'Gold Elite Tier';
      tierDesc = 'Top campus fleet status! Unlocked VIP priority routing & reduced platform fees.';
      tierColor = const Color(0xFFFBBF24);
    } else if (totalCompletedRuns >= 20) {
      tierTitle = 'Silver Pro Tier';
      tierDesc = 'Complete ${math.max(1, 50 - totalCompletedRuns)} more deliveries to unlock Gold Elite Tier.';
      tierColor = const Color(0xFFE2E8F0);
    }

    final days = [
      {'name': 'Mon', 'day': 1},
      {'name': 'Tue', 'day': 2},
      {'name': 'Wed', 'day': 3},
      {'name': 'Thu', 'day': 4},
      {'name': 'Fri', 'day': 5},
      {'name': 'Sat', 'day': 6},
      {'name': 'Sun', 'day': 7},
    ];

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Driver Shift Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        children: [
          // Weekly Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _neonCyan.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: _neonCyan.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('This Week\'s Real Earnings', style: TextStyle(color: _textSecondary, fontSize: 13)),
                    Icon(Icons.trending_up_rounded, color: _neonCyan, size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'KES ${weeklyEarnings.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildQuickMetric('Completed (Week)', '$completedTrips runs', Icons.check_circle_rounded, _neonCyan),
                    const SizedBox(width: 16),
                    _buildQuickMetric('Today\'s Share', 'KES ${todayEarnings.toStringAsFixed(0)}', Icons.bolt_rounded, _neonOrange),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Weekly Shift Performance', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Daily Trips Bar Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Trips (Mon - Sun)', style: TextStyle(color: _textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days.map((d) {
                    final dayNum = d['day'] as int;
                    final dayName = d['name'] as String;
                    final count = tripsMap[dayNum] ?? 0;
                    final fillRatio = count > 0 ? (count / maxDaily).clamp(0.2, 1.0) : 0.08;
                    final isPeak = count > 0 && count == maxDaily;
                    return _buildBar(dayName, count, fillRatio, isPeak: isPeak);
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Courier Quality Score', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                _buildQualityRow(
                  'Customer Rating',
                  '${customerRating.toStringAsFixed(1)} / 5.0',
                  '★ ${customerRating >= 4.5 ? 'Excellent' : 'Good'} rating',
                  _neonCyan,
                ),
                const Divider(color: Colors.white10, height: 20),
                _buildQualityRow(
                  'Order Acceptance Rate',
                  '${acceptanceRate.toStringAsFixed(0)}%',
                  'Fleet dispatch priority metric',
                  _neonBlue,
                ),
                const Divider(color: Colors.white10, height: 20),
                _buildQualityRow(
                  'Avg Delivery Speed',
                  '${avgSpeedMins.toStringAsFixed(1)} mins',
                  'Turnaround time from accept to dropoff',
                  _neonOrange,
                ),
                const Divider(color: Colors.white10, height: 20),
                _buildQualityRow(
                  'Cancellation Rate',
                  '${cancellationRate.toStringAsFixed(1)}%',
                  'Platform threshold: < 5.0%',
                  const Color(0xFF10B981),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tier Progression
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tierColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.workspace_premium_rounded, color: tierColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tierTitle,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tierDesc,
                        style: const TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuickMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String day, int count, double fillRatio, {bool isPeak = false}) {
    return Column(
      children: [
        Text('$count', style: TextStyle(color: isPeak ? _neonCyan : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          width: 22,
          height: 80 * fillRatio,
          decoration: BoxDecoration(
            color: isPeak ? _neonCyan : _neonBlue.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildQualityRow(String title, String stat, String subtitle, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 11.5)),
          ],
        ),
        Text(stat, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
