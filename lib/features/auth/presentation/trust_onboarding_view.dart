import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'pin_setup_view.dart';

class TrustOnboardingView extends StatefulWidget {
  final String role;
  const TrustOnboardingView({super.key, required this.role});

  @override
  State<TrustOnboardingView> createState() => _TrustOnboardingViewState();
}

class _TrustOnboardingViewState extends State<TrustOnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Secure Offline Payments',
      'description': 'Even if the campus Wi-Fi drops, your app will still work. Transactions queue locally and sync instantly when you reconnect.',
      'icon': Icons.wifi_off,
    },
    {
      'title': 'Fair Trade Ecosystem',
      'description': 'DISHI enforces strict 1:1 wash trading limits and daily caps to ensure a fair environment for everyone.',
      'icon': Icons.balance,
    },
    {
      'title': 'Keja Streaks & Trust',
      'description': 'Pay rent on time to build your Keja Streak. Higher streaks unlock better perks and housing opportunities.',
      'icon': Icons.local_fire_department,
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < _onboardingData.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      } else {
        timer.cancel();
        _navigateToPinSetup();
      }
    });
  }

  void _navigateToPinSetup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => PinSetupView(role: widget.role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  // Reset timer on manual swipe to avoid instant jumping
                  _timer?.cancel();
                  _startAutoPlay();
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _onboardingData[index]['icon'],
                          size: 100,
                          color: MPesaTheme.primaryGreen,
                        ),
                        const SizedBox(height: 40),
                        Text(
                          _onboardingData[index]['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _onboardingData[index]['description'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingData.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? MPesaTheme.primaryGreen : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentPage == _onboardingData.length - 1) {
                    _timer?.cancel();
                    _navigateToPinSetup();
                  } else {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: MPesaTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _currentPage == _onboardingData.length - 1 ? 'Get Started' : 'Next',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
