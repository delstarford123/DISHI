import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _neonOrange = Color(0xFFFF6F00);

class MatchSpeedDatingView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchSpeedDatingView({super.key, this.userModel});

  @override
  State<MatchSpeedDatingView> createState() => _MatchSpeedDatingViewState();
}

class _MatchSpeedDatingViewState extends State<MatchSpeedDatingView> {
  bool _isJoining = false;
  bool _hasJoined = false;

  Future<void> _reserveSeat() async {
    setState(() => _isJoining = true);
    final String uid = widget.userModel?['uid'] ?? 'guest';

    try {
      await FirebaseFirestore.instance.collection('speed_dating_reservations').add({
        'uid': uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _hasJoined = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seat Reserved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Speed Dating Roulette', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, color: _neonOrange, size: 100),
              const SizedBox(height: 24),
              const Text('Friday Night Roulette', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Get matched with a random student on campus for a 3-minute blind chat. If you both vibe, your profiles are revealed!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 48),
              if (_hasJoined)
                Column(
                  children: [
                    const CircularProgressIndicator(color: _neonOrange),
                    const SizedBox(height: 16),
                    const Text('Waiting for a match...', style: TextStyle(color: _neonOrange, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: _isJoining ? null : _reserveSeat,
                    child: _isJoining
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('JOIN THE QUEUE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
