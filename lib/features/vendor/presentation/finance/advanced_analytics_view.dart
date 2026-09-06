import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdvancedAnalyticsView extends StatelessWidget {
  const AdvancedAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Advanced Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Revenue Summary
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _neonOrange.withOpacity(0.3), width: 1.5),
                boxShadow: [BoxShadow(color: _neonOrange.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Revenue (This Week)', style: TextStyle(color: _textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  const Text('KES 142,500', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text('+15% from last week', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Best Selling Items
            const Text('Top Selling Items', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatBar('Smokie Pasua', 85, '850 sold'),
            _buildStatBar('Chapati Beans', 60, '420 sold'),
            _buildStatBar('Pilau Njeri', 40, '210 sold'),
            _buildStatBar('Smocha', 75, '630 sold'),
            
            const SizedBox(height: 32),
            
            // Peak Hours
            const Text('Peak Sales Hours', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPeakHours(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBar(String label, double percentage, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(detail, style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _neonOrange,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _neonOrange.withOpacity(0.5), blurRadius: 10)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakHours() {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildVerticalBar('8AM', 0.2),
          _buildVerticalBar('10AM', 0.5),
          _buildVerticalBar('12PM', 1.0),
          _buildVerticalBar('2PM', 0.8),
          _buildVerticalBar('4PM', 0.4),
          _buildVerticalBar('6PM', 0.7),
        ],
      ),
    );
  }

  Widget _buildVerticalBar(String label, double heightFactor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: 100 * heightFactor,
          decoration: BoxDecoration(
            color: _neonOrange,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: _neonOrange.withOpacity(0.3), blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10)),
      ],
    );
  }
}
