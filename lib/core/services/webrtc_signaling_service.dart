import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef void StreamStateCallback(MediaStream stream);

class WebRTCSignalingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302'
        ]
      }
    ]
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;

  StreamStateCallback? onAddRemoteStream;
  Function(RTCPeerConnectionState)? onConnectionState;

  Future<String> createRoom(
    RTCVideoRenderer remoteRenderer, {
    required String calleeId,
    required String callerName,
    required String callerAvatar,
    required bool isVideo,
  }) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('active_calls').doc();

    print('Create PeerConnection with configuration: $configuration');
    peerConnection = await createPeerConnection(configuration);

    _registerPeerConnectionListeners(remoteRenderer);

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    // Code for collecting ICE candidates below
    var callerCandidatesCollection = roomRef.collection('callerCandidates');
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('Got candidate: ${candidate.toMap()}');
      callerCandidatesCollection.add(candidate.toMap());
    };

    // Add the SDP offer to the room
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    
    Map<String, dynamic> roomWithOffer = {
      'offer': offer.toMap(),
      'callerId': FirebaseAuth.instance.currentUser?.uid ?? 'guest',
      'calleeId': calleeId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'isVideo': isVideo,
      'status': 'ringing',
      'timestamp': FieldValue.serverTimestamp(),
    };
    await roomRef.set(roomWithOffer);
    roomId = roomRef.id;
    print('New room created with SDP offer. Room ID: $roomId');

    // Listen for remote answer
    roomRef.snapshots().listen((snapshot) async {
      print('Got updated room: ${snapshot.data()}');
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        if (peerConnection?.getRemoteDescription() != null && data['answer'] != null) {
          var answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          print("Someone tried to connect");
          await peerConnection?.setRemoteDescription(answer);
        }
      }
    });

    // Listen for remote ICE candidates
    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
          print('Got new remote ICE candidate: $data');
          peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });

    return roomId!;
  }

  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteRenderer) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('active_calls').doc(roomId);
    var roomSnapshot = await roomRef.get();
    print('Got room ${roomSnapshot.exists}');

    if (roomSnapshot.exists) {
      print('Create PeerConnection with configuration: $configuration');
      peerConnection = await createPeerConnection(configuration);

      _registerPeerConnectionListeners(remoteRenderer);

      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });

      // Code for collecting ICE candidates below
      var calleeCandidatesCollection = roomRef.collection('calleeCandidates');
      peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        print('Got candidate: ${candidate.toMap()}');
        calleeCandidatesCollection.add(candidate.toMap());
      };

      // Set remote description (caller's offer)
      var data = roomSnapshot.data() as Map<String, dynamic>;
      var offer = data['offer'];
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      // Create answer and set local description
      var answer = await peerConnection!.createAnswer();
      print('Created Answer $answer');
      await peerConnection!.setLocalDescription(answer);

      Map<String, dynamic> roomWithAnswer = {
        'answer': {'type': answer.type, 'sdp': answer.sdp}
      };
      await roomRef.update(roomWithAnswer);

      // Listen for remote ICE candidates
      roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
            print('Got new remote ICE candidate: $data');
            peerConnection!.addCandidate(
              RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              ),
            );
          }
        }
      });
    }
  }

  Future<void> openUserMedia(RTCVideoRenderer localVideo, RTCVideoRenderer remoteVideo, bool isVideo) async {
    var stream = await navigator.mediaDevices.getUserMedia({
      'video': isVideo,
      'audio': true,
    });
    
    localVideo.srcObject = stream;
    localStream = stream;
    remoteVideo.srcObject = await createLocalMediaStream('key');
  }

  Future<void> hangUp(RTCVideoRenderer localVideo) async {
    List<MediaStreamTrack> tracks = localVideo.srcObject!.getTracks();
    tracks.forEach((track) {
      track.stop();
    });

    if (remoteStream != null) {
      remoteStream!.getTracks().forEach((track) => track.stop());
    }
    
    if (peerConnection != null) {
      peerConnection!.close();
    }

    if (roomId != null) {
      var db = FirebaseFirestore.instance;
      var roomRef = db.collection('active_calls').doc(roomId);
      var calleeDocs = await roomRef.collection('calleeCandidates').get();
      for (var doc in calleeDocs.docs) {
        await doc.reference.delete();
      }
      var callerDocs = await roomRef.collection('callerCandidates').get();
      for (var doc in callerDocs.docs) {
        await doc.reference.delete();
      }
      await roomRef.delete();
    }

    localStream!.dispose();
    remoteStream?.dispose();
  }

  void _registerPeerConnectionListeners(RTCVideoRenderer remoteRenderer) {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state change: $state');
      if (onConnectionState != null) {
        onConnectionState!(state);
      }
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state change: $state');
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      print("Add remote stream");
      onAddRemoteStream?.call(stream);
      remoteStream = stream;
      remoteRenderer.srcObject = stream;
    };
  }
}
