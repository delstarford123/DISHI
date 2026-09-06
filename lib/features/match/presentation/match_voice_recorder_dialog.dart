import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

const Color _neonPink = Color(0xFFFF2A6D);
const Color _cardColor = Color(0xFF131A2A);

class MatchVoiceRecorderDialog extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchVoiceRecorderDialog({super.key, this.userModel});

  @override
  State<MatchVoiceRecorderDialog> createState() => _MatchVoiceRecorderDialogState();
}

class _MatchVoiceRecorderDialogState extends State<MatchVoiceRecorderDialog> {
  final Record _audioRecorder = Record();
  bool _isRecording = false;
  String? _audioPath;
  bool _isUploading = false;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'my_voice_prompt_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _audioRecorder.start(
          path: path,
        );
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  Future<void> _uploadRecording() async {
    if (_audioPath == null) return;
    setState(() => _isUploading = true);

    final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      final storageRef = FirebaseStorage.instance.ref().child('voice_intros/${uid}_$timestamp.m4a');
      await storageRef.putFile(File(_audioPath!), SettableMetadata(contentType: 'audio/m4a'));
      final downloadUrl = await storageRef.getDownloadURL();

      if (uid != 'guest') {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'voiceIntroUrl': downloadUrl,
        });
      }

      if (mounted) {
        Navigator.pop(context, downloadUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isRecording ? Icons.mic : Icons.mic_none, color: _neonPink, size: 64),
            const SizedBox(height: 16),
            const Text('Voice Prompt', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Answer a prompt in 5 seconds to show off your vibe!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white54), 
                  onPressed: () => setState(() => _audioPath = null)
                ),
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      _stopRecording();
                    } else {
                      _startRecording();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _isRecording ? Colors.red : _neonPink, shape: BoxShape.circle),
                    child: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: _isUploading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.green))
                      : Icon(Icons.check, color: _audioPath != null ? Colors.green : Colors.white24), 
                  onPressed: _audioPath != null && !_isUploading ? _uploadRecording : null,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
