import 'dart:async';
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
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _callsSubscription;
  String? _currentUserId;
  final Set<String> _processedCallIds = {};

  @override
  void initState() {
    super.initState();
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid != _currentUserId) {
        _currentUserId = user?.uid;
        _listenForCalls(_currentUserId);
      }
    });
  }

  void _listenForCalls(String? uid) {
    _callsSubscription?.cancel();
    if (uid == null || uid.isEmpty) return;

    _callsSubscription = FirebaseFirestore.instance
        .collection('active_calls')
        .where('calleeId', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final callId = change.doc.id;
            if (_processedCallIds.contains(callId)) continue;

            final data = change.doc.data();
            if (data != null) {
              // Ignore calls created more than 60 seconds ago
              final createdAt = data['createdAt'] as Timestamp?;
              if (createdAt != null) {
                final diff = DateTime.now().difference(createdAt.toDate());
                if (diff.inSeconds > 60) continue;
              }

              _processedCallIds.add(callId);
              _showIncomingCallScreen(
                callId: callId,
                callerName: data['callerName'] ?? 'DISHI Comrade',
                callerAvatar: data['callerAvatar'] ?? '',
                isVideoCall: data['isVideo'] ?? false,
              );
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('[IncomingCallListener] Firestore listener error: $e');
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
  void dispose() {
    _authSubscription?.cancel();
    _callsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
