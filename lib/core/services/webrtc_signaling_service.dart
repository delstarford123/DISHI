import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class WebRTCSignalingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Multi-STUN configuration for robust cellular & Wi-Fi NAT traversal across African networks
  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302',
        ]
      },
      {
        'urls': [
          'stun:global.stun.twilio.com:3478',
          'stun:stun.services.mozilla.com',
        ]
      }
    ],
    'sdpSemantics': 'unified-plan',
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;

  StreamStateCallback? onAddRemoteStream;
  Function(RTCPeerConnectionState)? onConnectionState;

  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescriptionSet = false;

  Future<String> createRoom(
    RTCVideoRenderer remoteRenderer, {
    required String calleeId,
    required String callerName,
    required String callerAvatar,
    required bool isVideo,
  }) async {
    final DocumentReference roomRef = _db.collection('active_calls').doc();
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;

    debugPrint('[WebRTC] Creating PeerConnection...');
    peerConnection = await createPeerConnection(configuration);

    _registerPeerConnectionListeners(remoteRenderer);

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    // Collect ICE candidates and push to Firestore subcollection
    final callerCandidatesCollection = roomRef.collection('callerCandidates');
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        callerCandidatesCollection.add(candidate.toMap());
      }
    };

    // Create SDP Offer
    final RTCSessionDescription offer = await peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideo,
    });
    await peerConnection!.setLocalDescription(offer);

    final Map<String, dynamic> roomWithOffer = {
      'offer': offer.toMap(),
      'callerId': FirebaseAuth.instance.currentUser?.uid ?? 'guest',
      'calleeId': calleeId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'isVideo': isVideo,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await roomRef.set(roomWithOffer);
    roomId = roomRef.id;
    debugPrint('[WebRTC] Call room created: $roomId');

    // Listen for callee's SDP Answer
    roomRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists || peerConnection == null) return;
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;

      if (!_remoteDescriptionSet && data['answer'] != null) {
        final signalingState = await peerConnection?.getSignalingState();
        if (signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          _remoteDescriptionSet = true;
          final answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          debugPrint('[WebRTC] Setting remote description with answer');
          await peerConnection?.setRemoteDescription(answer);

          // Flush queued ICE candidates
          for (final candidate in _pendingRemoteCandidates) {
            await peerConnection?.addCandidate(candidate);
          }
          _pendingRemoteCandidates.clear();
        }
      }
    });

    // Listen for callee ICE candidates
    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          if (_remoteDescriptionSet && peerConnection != null) {
            await peerConnection?.addCandidate(candidate);
          } else {
            _pendingRemoteCandidates.add(candidate);
          }
        }
      }
    });

    return roomId!;
  }

  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteRenderer) async {
    final DocumentReference roomRef = _db.collection('active_calls').doc(roomId);
    final roomSnapshot = await roomRef.get();
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;

    if (!roomSnapshot.exists) {
      debugPrint('[WebRTC] Call room $roomId does not exist');
      return;
    }

    debugPrint('[WebRTC] Joining call room: $roomId');
    peerConnection = await createPeerConnection(configuration);
    _registerPeerConnectionListeners(remoteRenderer);

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    final calleeCandidatesCollection = roomRef.collection('calleeCandidates');
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        calleeCandidatesCollection.add(candidate.toMap());
      }
    };

    // Set caller's offer as remote description
    final data = roomSnapshot.data() as Map<String, dynamic>;
    final offer = data['offer'];
    final bool isVideo = data['isVideo'] ?? false;

    await peerConnection?.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    _remoteDescriptionSet = true;

    // Create SDP Answer
    final answer = await peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideo,
    });
    await peerConnection!.setLocalDescription(answer);

    final Map<String, dynamic> roomWithAnswer = {
      'answer': {'type': answer.type, 'sdp': answer.sdp},
      'status': 'answered',
      'answeredAt': FieldValue.serverTimestamp(),
    };
    await roomRef.update(roomWithAnswer);

    // Flush any pending candidates
    for (final candidate in _pendingRemoteCandidates) {
      await peerConnection?.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();

    // Listen for caller ICE candidates
    roomRef.collection('callerCandidates').snapshots().listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final candData = change.doc.data() as Map<String, dynamic>;
          final candidate = RTCIceCandidate(
            candData['candidate'],
            candData['sdpMid'],
            candData['sdpMLineIndex'],
          );
          if (peerConnection != null) {
            await peerConnection?.addCandidate(candidate);
          }
        }
      }
    });
  }

  Future<void> openUserMedia(RTCVideoRenderer localVideo, RTCVideoRenderer remoteVideo, bool isVideo) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo
          ? {
              'facingMode': 'user',
              'mandatory': {
                'minWidth': '480',
                'minHeight': '360',
                'minFrameRate': '25',
              },
            }
          : false,
    };

    try {
      final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localVideo.srcObject = stream;
      localStream = stream;
      remoteVideo.srcObject = await createLocalMediaStream('remote_stream');
    } catch (e) {
      debugPrint('[WebRTC] Media stream access error: $e');
      // Fallback: audio only if video camera fails
      if (isVideo) {
        final audioStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
        localVideo.srcObject = audioStream;
        localStream = audioStream;
        remoteVideo.srcObject = await createLocalMediaStream('remote_stream');
      }
    }
  }

  Future<void> hangUp(RTCVideoRenderer localVideo) async {
    try {
      if (localVideo.srcObject != null) {
        for (var track in localVideo.srcObject!.getTracks()) {
          track.stop();
        }
      }

      if (remoteStream != null) {
        for (var track in remoteStream!.getTracks()) {
          track.stop();
        }
      }

      if (localStream != null) {
        for (var track in localStream!.getTracks()) {
          track.stop();
        }
      }

      await peerConnection?.close();
      peerConnection = null;

      if (roomId != null) {
        final roomRef = _db.collection('active_calls').doc(roomId);
        final calleeDocs = await roomRef.collection('calleeCandidates').get();
        for (var doc in calleeDocs.docs) {
          await doc.reference.delete();
        }
        final callerDocs = await roomRef.collection('callerCandidates').get();
        for (var doc in callerDocs.docs) {
          await doc.reference.delete();
        }
        await roomRef.update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }

      localStream?.dispose();
      remoteStream?.dispose();
      localStream = null;
      remoteStream = null;
    } catch (e) {
      debugPrint('[WebRTC] hangUp cleanup error: $e');
    }
  }

  void _registerPeerConnectionListeners(RTCVideoRenderer remoteRenderer) {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('[WebRTC] ICE gathering state: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state: $state');
      onConnectionState?.call(state);
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      debugPrint('[WebRTC] Signaling state: $state');
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      debugPrint('[WebRTC] Remote stream added with ${stream.getTracks().length} tracks');
      onAddRemoteStream?.call(stream);
      remoteStream = stream;
      remoteRenderer.srcObject = stream;
    };
  }
}
