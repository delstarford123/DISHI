import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class SpendingAnalyticsView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const SpendingAnalyticsView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<SpendingAnalyticsView> createState() => _SpendingAnalyticsViewState();
}

class _SpendingAnalyticsViewState extends State<SpendingAnalyticsView> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Spending Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.selectedStudentUid == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No student selected in Dependents tab.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: widget.selectedStudentUid == null
                  ? const Center(child: Text('No students linked.', style: TextStyle(color: Colors.white54)))
                  : StreamBuilder<QuerySnapshot>(
                      // Assuming transactions are stored under users/{uid}/transactions
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.selectedStudentUid)
                          .collection('transactions')
                          .orderBy('timestamp', descending: true)
                          .limit(100)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: MPesaTheme.neonCyan));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No recent spending data found.', style: TextStyle(color: Colors.white54)),
                          );
                        }

                        // Process data
                        double totalMeals = 0;
                        double totalTransport = 0;
                        double totalBooks = 0;
                        double totalOther = 0;

                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                          final type = data['type']?.toString().toLowerCase() ?? '';
                          final category = data['category']?.toString().toLowerCase() ?? '';

                          // Only count outbound spending
                          if (type == 'purchase' || type == 'transfer' || type == 'payment') {
                            if (category.contains('food') || category.contains('meal')) {
                              totalMeals += amount;
                            } else if (category.contains('transport') || category.contains('ride')) {
                              totalTransport += amount;
                            } else if (category.contains('book') || category.contains('stationery')) {
                              totalBooks += amount;
                            } else {
                              totalOther += amount;
                            }
                          }
                        }

                        final totalSpending = totalMeals + totalTransport + totalBooks + totalOther;

                        if (totalSpending == 0) {
                          return const Center(
                            child: Text('No outbound spending detected yet.', style: TextStyle(color: Colors.white54)),
                          );
                        }

                        return Column(
                          children: [
                            Text(
                              'Total Spent: Ksh ${totalSpending.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 250,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 50,
                                  sections: [
                                    if (totalMeals > 0)
                                      PieChartSectionData(
                                        color: MPesaTheme.neonCyan,
                                        value: totalMeals,
                                        title: '${((totalMeals / totalSpending) * 100).toStringAsFixed(1)}%',
                                        radius: 60,
                                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    if (totalTransport > 0)
                                      PieChartSectionData(
                                        color: MPesaTheme.neonOrange,
                                        value: totalTransport,
                                        title: '${((totalTransport / totalSpending) * 100).toStringAsFixed(1)}%',
                                        radius: 60,
                                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    if (totalBooks > 0)
                                      PieChartSectionData(
                                        color: MPesaTheme.neonBlue,
                                        value: totalBooks,
                                        title: '${((totalBooks / totalSpending) * 100).toStringAsFixed(1)}%',
                                        radius: 60,
                                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    if (totalOther > 0)
                                      PieChartSectionData(
                                        color: MPesaTheme.primaryRed,
                                        value: totalOther,
                                        title: '${((totalOther / totalSpending) * 100).toStringAsFixed(1)}%',
                                        radius: 60,
                                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildLegendItem(MPesaTheme.neonCyan, 'Meals & Food', totalMeals),
                            _buildLegendItem(MPesaTheme.neonOrange, 'Transport', totalTransport),
                            _buildLegendItem(MPesaTheme.neonBlue, 'Books & Stationery', totalBooks),
                            _buildLegendItem(MPesaTheme.primaryRed, 'Other', totalOther),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String title, double amount) {
    if (amount <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const Spacer(),
          Text('Ksh ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
