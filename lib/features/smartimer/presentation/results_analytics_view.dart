import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class ResultsAnalyticsView extends StatelessWidget {
  const ResultsAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Results & Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _surfaceLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall Progress', style: TextStyle(color: _textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Target vs Actual', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _neonCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Text('+12%', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                // Mock Bar Chart
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBar('Data Structures', 0.8, 0.6),
                    _buildBar('Math', 0.6, 0.7),
                    _buildBar('AI', 0.9, 0.8),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Log New Score', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildScoreInput('CAT 1 Score (out of 30)'),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () {},
            child: const Text('SAVE SCORE & GET AI ADVICE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.purpleAccent)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                    SizedBox(width: 8),
                    Text('Groq AI Advice', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                SizedBox(height: 12),
                Text('Your actual score in Math is trailing your target by 15%. I recommend using the Spaced Repetition flashcards for Calculus formulas for at least 20 mins daily.', style: TextStyle(color: Colors.white, height: 1.5)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBar(String label, double targetHeight, double actualHeight) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(width: 16, height: 100 * targetHeight, color: _surfaceLight),
            const SizedBox(width: 4),
            Container(width: 16, height: 100 * actualHeight, color: actualHeight >= targetHeight ? _neonCyan : _neonPink),
          ],
        ),
        const SizedBox(height: 8),
        Text(label.substring(0, 3), style: const TextStyle(color: _textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildScoreInput(String label) {
    return TextField(
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
