import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/mpesa_theme.dart';
import '../spending_analytics_view.dart';
import '../scheduled_allowances_view.dart';
import '../dispute_resolution_view.dart';
import '../savings_target_view.dart';
import '../medical_lock_view.dart';
import '../lunchbox_planner.dart';

const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class ParentFinancialsTab extends StatelessWidget {
  final List<Map<String, dynamic>> linkedStudents;

  const ParentFinancialsTab({
    super.key,
    required this.linkedStudents,
  });

  @override
  Widget build(BuildContext context) {
    final parentUser = {'uid': FirebaseAuth.instance.currentUser?.uid ?? ''};
    final selectedStudentUid = linkedStudents.isNotEmpty ? linkedStudents.first['uid'] : null;

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const Text('Financial Command Hub', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Manage digital allowances, view analytics, and control family spending guardrails.', style: TextStyle(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionGridButton(context, Icons.bar_chart_rounded, 'Spending Analytics', _neonCyan, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SpendingAnalyticsView(parentUser: parentUser, selectedStudentUid: selectedStudentUid)));
              }),
              _buildActionGridButton(context, Icons.schedule_rounded, 'Digital Allowances', _neonBlue, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduledAllowancesView(parentUser: parentUser, selectedStudentUid: selectedStudentUid)));
              }),
              _buildActionGridButton(context, Icons.bento_rounded, 'Lunchbox Cafeteria', _neonOrange, () {
                if (linkedStudents.isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LunchboxPlanner(studentUid: linkedStudents.first['uid'], studentName: linkedStudents.first['name'], parentUid: parentUser['uid']!)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please link a student first.')));
                }
              }),
              _buildActionGridButton(context, Icons.savings_rounded, 'Savings Goals', MPesaTheme.primaryGreen, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SavingsTargetView(parentUser: parentUser, selectedStudentUid: selectedStudentUid)));
              }),
              _buildActionGridButton(context, Icons.receipt_long_rounded, 'Receipts & Disputes', Colors.tealAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DisputeResolutionCenterView(parentUser: parentUser)));
              }),
              _buildActionGridButton(context, Icons.local_hospital_rounded, 'Medical Lock', _neonPink, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MedicalLockView(parentUser: parentUser, selectedStudentUid: selectedStudentUid)));
              }),
            ],
          ),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _buildActionGridButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
