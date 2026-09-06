import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_call_view.dart';
import '../../../core/services/audio_service.dart';

class MatchIncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerAvatar;
  final bool isVideoCall;

  const MatchIncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerAvatar,
    required this.isVideoCall,
  });

  @override
  State<MatchIncomingCallScreen> createState() => _MatchIncomingCallScreenState();
}

class _MatchIncomingCallScreenState extends State<MatchIncomingCallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    AudioService().startRinging(widget.isVideoCall);
    
    // Listen for the caller ending the call before we answer
    FirebaseFirestore.instance.collection('active_calls').doc(widget.callId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'ended' || data['status'] == 'declined') {
          _endCallWithoutAnswering();
        }
      } else {
        _endCallWithoutAnswering();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    AudioService().stopRinging();
    super.dispose();
  }

  void _endCallWithoutAnswering() {
    if (mounted) {
      AudioService().stopRinging();
      Navigator.pop(context);
    }
  }

  Future<void> _answerCall() async {
    AudioService().stopRinging();
    await FirebaseFirestore.instance.collection('active_calls').doc(widget.callId).update({
      'status': 'answered',
    });
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MatchCallView(
            userName: widget.callerName,
            userAvatar: widget.callerAvatar,
            isVideoCall: widget.isVideoCall,
            isIncoming: true,
            roomId: widget.callId,
          ),
        ),
      );
    }
  }

  Future<void> _declineCall([String? message]) async {
    AudioService().stopRinging();
    await FirebaseFirestore.instance.collection('active_calls').doc(widget.callId).update({
      'status': 'declined',
      if (message != null) 'declineMessage': message,
    });
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF020617)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.isVideoCall ? Icons.videocam : Icons.call, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Incoming ${widget.isVideoCall ? "Video" : "Voice"} Call',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(widget.callerName, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 60),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isVideoCall ? Colors.cyanAccent : Colors.greenAccent).withOpacity(0.3 * (1 - _pulseController.value)),
                            blurRadius: 40 * _pulseController.value,
                            spreadRadius: 20 * _pulseController.value,
                          )
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.black45,
                  backgroundImage: widget.callerAvatar.isNotEmpty ? NetworkImage(widget.callerAvatar) : null,
                  child: widget.callerAvatar.isEmpty
                      ? Text(
                          widget.callerName.substring(0, 3).toUpperCase(),
                          style: const TextStyle(fontSize: 40, color: Colors.white),
                        )
                      : null,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _showDeclineOptions,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Decline', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _answerCall,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call, color: Colors.black, size: 36),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Answer', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showDeclineOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Decline with message', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildDeclineOption('Sorry, I am busy right now.'),
              _buildDeclineOption('I am in a meeting.'),
              _buildDeclineOption('I will call you back later.'),
              _buildDeclineOption('Please send a text message instead.'),
              ListTile(
                leading: const Icon(Icons.call_end, color: Colors.redAccent),
                title: const Text('Decline without message', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _declineCall();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeclineOption(String message) {
    return ListTile(
      leading: const Icon(Icons.message, color: Colors.cyanAccent),
      title: Text(message, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        Navigator.pop(context);
        _declineCall(message);
      },
    );
  }
}
