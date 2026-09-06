import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';

const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonBlue = Color(0xFF00FFD1);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1E293B);

class MatchVoiceRecorderDialog extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchVoiceRecorderDialog({super.key, this.userModel});

  @override
  State<MatchVoiceRecorderDialog> createState() => _MatchVoiceRecorderDialogState();
}

class _MatchVoiceRecorderDialogState extends State<MatchVoiceRecorderDialog> {
  final Record _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPlaying = false;
  bool _isUploading = false;
  
  String? _audioPath;
  String _selectedPrompt = "What's your favorite thing about campus?";
  
  final List<String> _prompts = [
    "What's your favorite thing about campus?",
    "A controversial opinion I hold is...",
    "My go-to order at the cafeteria is...",
    "If I wasn't in my current major, I'd study...",
    "The best way to spend a Friday night is...",
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'my_voice_prompt_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _audioRecorder.start(path: path);
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _audioPath = null;
        });
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _pauseResumeRecording() async {
    if (!_isRecording) return;
    try {
      if (_isPaused) {
        await _audioRecorder.resume();
        setState(() => _isPaused = false);
      } else {
        await _audioRecorder.pause();
        setState(() => _isPaused = true);
      }
    } catch (e) {
      debugPrint('Error pausing/resuming record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _audioPath = path;
      });
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  Future<void> _playPauseAudio() async {
    if (_audioPath == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  void _deleteRecording() {
    setState(() {
      _audioPath = null;
      _isRecording = false;
      _isPaused = false;
    });
    _audioPlayer.stop();
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
          'voiceIntroPrompt': _selectedPrompt,
        });
      }

      if (mounted) {
        Navigator.pop(context, downloadUrl);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice Intro Saved! 🎤'), backgroundColor: _neonPink));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isRecording ? Icons.mic : Icons.mic_none, color: _isRecording ? Colors.red : _neonPink, size: 64),
              const SizedBox(height: 16),
              const Text('Voice Intro', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Record a short audio answering a prompt to show off your vibe.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 24),
              
              // Prompt Selector
              if (!_isRecording && _audioPath == null) ...[
                const Align(alignment: Alignment.centerLeft, child: Text('Choose a Prompt:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButton<String>(
                    value: _selectedPrompt,
                    isExpanded: true,
                    dropdownColor: _surfaceLight,
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: _prompts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedPrompt = v);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (_isRecording || _audioPath != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _neonBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      const Text('Answering:', style: TextStyle(color: _neonBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('"$_selectedPrompt"', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Audio Playback
              if (_audioPath != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: _neonPink),
                        onPressed: _playPauseAudio,
                      ),
                      const Text('Listen to Recording', style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Recording Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white54), 
                    onPressed: (_audioPath != null || _isRecording) ? _deleteRecording : null,
                  ),
                  
                  if (_audioPath == null) ...[
                    if (_isRecording)
                      IconButton(
                        icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.orangeAccent),
                        onPressed: _pauseResumeRecording,
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
                        child: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white, size: 32),
                      ),
                    ),
                  ],

                  IconButton(
                    icon: _isUploading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.green))
                        : Icon(Icons.check, color: _audioPath != null ? Colors.green : Colors.white24, size: 32), 
                    onPressed: _audioPath != null && !_isUploading ? _uploadRecording : null,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
