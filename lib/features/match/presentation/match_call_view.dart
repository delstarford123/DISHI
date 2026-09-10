import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/webrtc_signaling_service.dart';

class MatchCallView extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final String? calleeId;
  final bool isVideoCall;
  final bool isIncoming;
  final String? roomId;

  const MatchCallView({
    super.key,
    required this.userName,
    required this.userAvatar,
    this.calleeId,
    required this.isVideoCall,
    this.isIncoming = false,
    this.roomId,
  });

  @override
  State<MatchCallView> createState() => _MatchCallViewState();
}

class _MatchCallViewState extends State<MatchCallView> with SingleTickerProviderStateMixin {
  final WebRTCSignalingService _signaling = WebRTCSignalingService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  late AnimationController _pulseController;
  bool _callAnswered = false;
  String? _currentRoomId;

  bool _isMicMuted = false;
  bool _isVideoMuted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    
    _initRenderers();

    if (widget.isVideoCall) {
      AudioService().startRinging(true);
    } else {
      AudioService().startRinging(false);
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _signaling.onAddRemoteStream = ((stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    });

    _signaling.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        AudioService().stopRinging();
        if (mounted) {
          setState(() {
            _callAnswered = true;
          });
          AudioService().stopRinging();
        }
      }
    };

    await _signaling.openUserMedia(_localRenderer, _remoteRenderer, widget.isVideoCall);

    if (!widget.isIncoming) {
      // We are the caller, create a room
      _currentRoomId = await _signaling.createRoom(
        _remoteRenderer,
        calleeId: widget.calleeId ?? 'target_user_id',
        callerName: FirebaseAuth.instance.currentUser?.displayName ?? 'You',
        callerAvatar: FirebaseAuth.instance.currentUser?.photoURL ?? '',
        isVideo: widget.isVideoCall,
      );

      // Start ringing for the caller
      AudioService().startRinging(widget.isVideoCall);

      // Listen for decline or answer to stop ringtone
      FirebaseFirestore.instance.collection('active_calls').doc(_currentRoomId).snapshots().listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          if (data['status'] == 'answered') {
            AudioService().stopRinging();
            setState(() {
              _callAnswered = true;
            });
          }
          if (data['status'] == 'declined' && mounted) {
            AudioService().stopRinging();
            _endCall();
            
            // Professional Safaricom-like message display
            String msg = data['declineMessage'] ?? 'The user is currently unavailable.';
            _showProfessionalMessage(msg);
          }
        }
      });
    } else {
      // We are incoming, we wait until user hits 'Accept' to join the room.
      _currentRoomId = widget.roomId;
      if (_currentRoomId != null) {
        await _signaling.joinRoom(_currentRoomId!, _remoteRenderer);
      }
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    AudioService().stopRinging();
    _pulseController.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _signaling.hangUp(_localRenderer);
    
    // Always mark call as ended when this screen is disposed —
    // regardless of whether the call was answered or not.
    // This prevents the callee's incoming-call screen from lingering.
    if (_currentRoomId != null) {
      FirebaseFirestore.instance.collection('active_calls').doc(_currentRoomId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {}); // Ignore if doc deleted
    }
    super.dispose();
  }

  void _endCall() async {
    AudioService().stopRinging();
    _signaling.hangUp(_localRenderer);
    if (_currentRoomId != null) {
      await FirebaseFirestore.instance.collection('active_calls').doc(_currentRoomId).update({
        'status': 'ended',
      }).catchError((_) {}); // Ignore if doc deleted
    }
    if (mounted) Navigator.pop(context);
  }

  void _showProfessionalMessage(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('Subscriber Message', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _toggleMic() {
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
    _signaling.localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMicMuted;
    });
  }

  void _toggleCamera() {
    if (!widget.isVideoCall) return;
    setState(() {
      _isVideoMuted = !_isVideoMuted;
    });
    _signaling.localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isVideoMuted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: Remote Stream or Dark gradient
          if (_callAnswered && widget.isVideoCall)
            RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E293B), Color(0xFF020617)],
                ),
              ),
            ),
          
          // Dim overlay if not answered
          if (!_callAnswered)
            Container(color: Colors.black.withOpacity(0.4)),

          // PiP Local Video View
          if (_callAnswered && widget.isVideoCall && !_isVideoMuted)
            Positioned(
              top: 60,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),
            ),

          // Foreground Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                if (!_callAnswered) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.isVideoCall ? Icons.videocam : Icons.call, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Calling...',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
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
                      child: Text(
                        widget.userName.substring(0, 3).toUpperCase(),
                        style: const TextStyle(fontSize: 40, color: Colors.white),
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Call Controls Bottom Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_callAnswered) ...[
                        GestureDetector(
                          onTap: _toggleMic,
                          child: _buildControlButton(_isMicMuted ? Icons.mic_off : Icons.mic, Colors.white24, iconColor: _isMicMuted ? Colors.redAccent : Colors.white),
                        ),
                        if (widget.isVideoCall) 
                          GestureDetector(
                            onTap: _toggleCamera,
                            child: _buildControlButton(_isVideoMuted ? Icons.videocam_off : Icons.videocam, Colors.white24, iconColor: _isVideoMuted ? Colors.redAccent : Colors.white),
                          ),
                      ],
                      
                      GestureDetector(
                        onTap: _endCall,
                        child: _buildControlButton(Icons.call_end, Colors.redAccent, isLarge: true),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, Color bgColor, {bool isLarge = false, Color iconColor = Colors.white}) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 20 : 16),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: isLarge ? 36 : 28),
    );
  }
}
