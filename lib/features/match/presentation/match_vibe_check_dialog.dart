import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/vibe_service.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonBlue = Color(0xFF00FFD1);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1E293B);

class MatchVibeCheckDialog extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const MatchVibeCheckDialog({super.key, required this.receiverId, required this.receiverName});

  @override
  State<MatchVibeCheckDialog> createState() => _MatchVibeCheckDialogState();
}

class _MatchVibeCheckDialogState extends State<MatchVibeCheckDialog> {
  final VibeService _vibeService = VibeService();
  
  bool _isSuper = false;
  bool _isSecret = false;
  String _selectedIcebreaker = '';
  bool _isLoading = false;

  final List<String> _icebreakers = [
    "Coffee or Tea? ☕",
    "What's your favorite spot on campus? 🏛️",
    "Library Lock-in or Night Club? 🪩",
    "Best food joint nearby? 🍔"
  ];

  Future<void> _sendVibe() async {
    final senderId = FirebaseAuth.instance.currentUser?.uid;
    if (senderId == null) return;

    setState(() => _isLoading = true);
    
    try {
      await _vibeService.sendVibe(
        senderId: senderId,
        receiverId: widget.receiverId,
        isSuper: _isSuper,
        isSecret: _isSecret,
        icebreaker: _selectedIcebreaker,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vibe Sent! ⚡', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: _neonPink));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _isSuper ? Colors.amber : _neonPink.withOpacity(0.5), width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Icon(Icons.flash_on, color: _isSuper ? Colors.amber : _neonPink, size: 64),
                    const SizedBox(height: 16),
                    Text('Vibe Check ${widget.receiverName}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Send a direct notification to let them know you are interested.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Icebreaker Selection
              const Text('Add an Icebreaker (Optional)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icebreakers.map((ib) {
                  final isSelected = _selectedIcebreaker == ib;
                  return ChoiceChip(
                    label: Text(ib, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 10)),
                    selected: isSelected,
                    selectedColor: _neonBlue,
                    backgroundColor: _surfaceLight,
                    onSelected: (val) {
                      setState(() => _selectedIcebreaker = val ? ib : '');
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Toggles
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Secret Vibe 🕵️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Hide your identity until they match.', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                        Switch(value: _isSecret, activeThumbColor: _neonPink, onChanged: (v) => setState(() => _isSecret = v)),
                      ],
                    ),
                    const Divider(color: Colors.white10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Super Vibe ⭐️', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                SizedBox(width: 4),
                                Text('-Ksh 10', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text('Skip the queue and highlight your vibe.', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                        Switch(value: _isSuper, activeThumbColor: Colors.amber, onChanged: (v) => setState(() => _isSuper = v)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _isSuper ? Colors.amber : _neonPink, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _isLoading ? null : _sendVibe,
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isSuper ? 'SEND SUPER VIBE' : 'SEND VIBE', style: TextStyle(color: _isSuper ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
