import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../match_incoming_call_screen.dart';

class IncomingCallListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const IncomingCallListener({super.key, required this.child, this.navigatorKey});

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  
  @override
  void initState() {
    super.initState();
    _listenForCalls();
  }

  void _listenForCalls() {
    if (_uid == null) return;
    
    FirebaseFirestore.instance
        .collection('active_calls')
        .where('calleeId', isEqualTo: _uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              _showIncomingCallScreen(
                callId: change.doc.id,
                callerName: data['callerName'] ?? 'Unknown Caller',
                callerAvatar: data['callerAvatar'] ?? '',
                isVideoCall: data['isVideo'] ?? false,
              );
            }
          }
        }
      }
    });
  }

  void _showIncomingCallScreen({
    required String callId,
    required String callerName,
    required String callerAvatar,
    required bool isVideoCall,
  }) {
    if (!mounted) return;
    
    final navContext = widget.navigatorKey?.currentState?.context ?? context;
    
    Navigator.push(
      navContext,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MatchIncomingCallScreen(
          callId: callId,
          callerName: callerName,
          callerAvatar: callerAvatar,
          isVideoCall: isVideoCall,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
