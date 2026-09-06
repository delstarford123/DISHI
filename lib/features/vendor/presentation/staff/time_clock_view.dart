import 'package:flutter/material.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class TimeClockView extends StatefulWidget {
  const TimeClockView({super.key});

  @override
  State<TimeClockView> createState() => _TimeClockViewState();
}

class _TimeClockViewState extends State<TimeClockView> {
  bool _isClockedIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Time Clock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isClockedIn ? '8:45 AM' : '--:--',
              style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _isClockedIn ? 'Currently Clocked In' : 'Currently Clocked Out',
              style: TextStyle(color: _isClockedIn ? Colors.green : _textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isClockedIn = !_isClockedIn;
                });
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isClockedIn ? Colors.red.withOpacity(0.1) : _neonOrange.withOpacity(0.1),
                  border: Border.all(
                    color: _isClockedIn ? Colors.red : _neonOrange,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isClockedIn ? Colors.red : _neonOrange).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    _isClockedIn ? 'CLOCK\nOUT' : 'CLOCK\nIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isClockedIn ? Colors.red : _neonOrange,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
