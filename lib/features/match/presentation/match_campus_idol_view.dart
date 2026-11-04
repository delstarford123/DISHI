import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/dishi_voice_service.dart';
import 'match_chat_view.dart';

class MatchCampusIdolView extends StatefulWidget {
  const MatchCampusIdolView({super.key});

  @override
  State<MatchCampusIdolView> createState() => _MatchCampusIdolViewState();
}

class _MatchCampusIdolViewState extends State<MatchCampusIdolView> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _waveformController;
  final PageController _pageController = PageController();

  // Audio engines
  final Record _audioRecorder = Record();
  final AudioPlayer _feedAudioPlayer = AudioPlayer();
  final AudioPlayer _previewAudioPlayer = AudioPlayer();
  final AudioPlayer _leaderboardPlayer = AudioPlayer();

  // Studio Recording state
  bool _isRecording = false;
  double _recordingProgress = 0.0;
  int _recordingDurationMs = 0;
  Timer? _recordingTimer;
  String? _recordedFilePath;
  bool _isUploading = false;

  // Feed Playback state
  String? _currentlyPlayingDocId;
  bool _isPlayingFeed = false;
  Duration _feedAudioPosition = Duration.zero;
  Duration _feedAudioDuration = Duration.zero;

  // Leaderboard playback state
  String? _playingLeaderboardDocId;

  String _selectedFilter = 'Normal';
  final List<String> _filters = ['Normal', 'Autotune 🎤', 'Deep 👹', 'Chipmunk 🐿️', 'Echo 🌊'];

  final List<Color> _coverColors = [
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
    Colors.orangeAccent,
    Colors.tealAccent,
    Colors.cyanAccent,
  ];
  Color _selectedCover = Colors.blueAccent;

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Listen to feed player events
    _feedAudioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlayingFeed = state == PlayerState.playing;
        if (state == PlayerState.playing) {
          _waveformController.repeat(reverse: true);
        } else {
          _waveformController.stop();
        }
      });
    });

    _feedAudioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _feedAudioPosition = pos);
    });

    _feedAudioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _feedAudioDuration = dur);
    });

    _leaderboardPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        setState(() => _playingLeaderboardDocId = null);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _waveformController.dispose();
    _pageController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _feedAudioPlayer.dispose();
    _previewAudioPlayer.dispose();
    _leaderboardPlayer.dispose();
    super.dispose();
  }

  // ==================== STUDIO RECORDING ====================
  Future<void> _startRecording() async {
    try {
      // Temporarily release microphone from background voice service
      await DishiVoiceService.instance.stopListening();
      await _feedAudioPlayer.stop();
      await _previewAudioPlayer.stop();
      await _leaderboardPlayer.stop();

      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'campus_idol_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _audioRecorder.start(path: path);

        setState(() {
          _isRecording = true;
          _recordingProgress = 0.0;
          _recordingDurationMs = 0;
          _recordedFilePath = path;
        });

        HapticFeedback.heavyImpact();

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            _recordingDurationMs += 100;
            _recordingProgress = _recordingDurationMs / 10000.0; // 10s max
            if (_recordingProgress >= 1.0) {
              _stopRecording();
            }
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required to record auditions')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      HapticFeedback.mediumImpact();

      if (_recordingDurationMs >= 1000 && path != null) {
        _recordedFilePath = path;
        _showUploadModal();
      } else {
        setState(() => _recordingProgress = 0.0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audition too short! Record for at least 1 second.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isRecording = false);
      debugPrint('Error stopping recording: $e');
    }
  }

  void _showUploadModal() {
    final titleController = TextEditingController(text: 'Campus Audition 🎶');
    _previewAudioPlayer.stop();
    bool isPreviewing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Publish Audition 🎤', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () {
                              _previewAudioPlayer.stop();
                              Navigator.pop(sheetCtx);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Audio Preview Player
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _selectedCover.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isPreviewing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: _selectedCover,
                                size: 38,
                              ),
                              onPressed: () async {
                                if (_recordedFilePath == null) return;
                                if (isPreviewing) {
                                  await _previewAudioPlayer.pause();
                                  setModalState(() => isPreviewing = false);
                                } else {
                                  setModalState(() => isPreviewing = true);
                                  await _previewAudioPlayer.play(DeviceFileSource(_recordedFilePath!));
                                  _previewAudioPlayer.onPlayerComplete.listen((_) {
                                    if (sheetCtx.mounted) {
                                      setModalState(() => isPreviewing = false);
                                    }
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPreviewing ? 'Playing recorded voice...' : 'Preview Voice Audition',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Duration: ${(_recordingDurationMs / 1000.0).toStringAsFixed(1)}s (10s max)',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Ready', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Audition Title', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'e.g. Swahili Afrobeats, Baritone cover...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Select Voice Filter', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filters.length,
                          itemBuilder: (context, i) {
                            final f = _filters[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f, style: TextStyle(color: _selectedFilter == f ? Colors.black : Colors.white)),
                                selected: _selectedFilter == f,
                                selectedColor: _selectedCover,
                                backgroundColor: Colors.black26,
                                onSelected: (val) => setModalState(() => _selectedFilter = f),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Select Cover Color', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _coverColors.map((c) => GestureDetector(
                          onTap: () => setModalState(() => _selectedCover = c),
                          child: CircleAvatar(
                            backgroundColor: c,
                            radius: _selectedCover == c ? 20 : 15,
                            child: _selectedCover == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedCover,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isUploading ? null : () async {
                            if (_recordedFilePath == null) return;
                            final messenger = ScaffoldMessenger.of(context);
                            setModalState(() => _isUploading = true);
                            await _previewAudioPlayer.stop();

                            try {
                              String artistName = 'Comrade Singer';
                              String? artistPhoto;
                              try {
                                final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
                                if (userDoc.exists) {
                                  artistName = userDoc.data()?['name'] ?? userDoc.data()?['displayName'] ?? 'Comrade Singer';
                                  artistPhoto = userDoc.data()?['photoUrl'] ?? userDoc.data()?['avatarUrl'];
                                }
                              } catch (_) {}

                              // Upload audio to Firebase Storage
                              final timestamp = DateTime.now().millisecondsSinceEpoch;
                              final storageRef = FirebaseStorage.instance
                                  .ref()
                                  .child('voice_intros/campus_idol_${currentUid}_$timestamp.m4a');

                              await storageRef.putFile(
                                File(_recordedFilePath!),
                                SettableMetadata(contentType: 'audio/m4a'),
                              );
                              final audioUrl = await storageRef.getDownloadURL();

                              final auditionTitle = titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'Campus Audition';
                              // Create document in Firestore
                              final docRef = await FirebaseFirestore.instance.collection('campus_idols').add({
                                'uid': currentUid,
                                'userName': artistName,
                                'userPhoto': artistPhoto,
                                'title': auditionTitle,
                                'audioUrl': audioUrl,
                                'durationSeconds': (_recordingDurationMs / 1000.0),
                                'filter': _selectedFilter,
                                'colorHex': _selectedCover.toARGB32(),
                                'likes': 0,
                                'likedBy': [],
                                'createdAt': FieldValue.serverTimestamp(),
                                'isAnonymous': true,
                              });

                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              if (mounted) {
                                setState(() {
                                  _recordingProgress = 0.0;
                                  _recordingDurationMs = 0;
                                  _recordedFilePath = null;
                                  _isUploading = false;
                                });
                                _shareAudition(
                                  id: docRef.id,
                                  artistName: artistName,
                                  title: auditionTitle,
                                );
                                _tabController.animateTo(0);
                              }
                            } catch (e) {
                              setModalState(() => _isUploading = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed to publish audition: $e')),
                              );
                            }
                          },
                          child: _isUploading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('Submit Audition 🎤', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== FEED PLAYBACK & JUDGING ====================
  Future<void> _playFeedAudio(String docId, String audioUrl) async {
    if (_currentlyPlayingDocId == docId && _isPlayingFeed) {
      await _feedAudioPlayer.pause();
      setState(() => _isPlayingFeed = false);
      _waveformController.stop();
    } else {
      await DishiVoiceService.instance.stopListening();
      await _feedAudioPlayer.stop();
      setState(() {
        _currentlyPlayingDocId = docId;
        _isPlayingFeed = true;
      });
      _waveformController.repeat(reverse: true);
      await _feedAudioPlayer.play(UrlSource(audioUrl));
    }
  }

  void _turnChair(String docId, String creatorUid, Map<String, dynamic> data) async {
    HapticFeedback.heavyImpact();

    // Increment like in Firestore
    final List likedBy = (data['likedBy'] as List?) ?? [];
    final bool alreadyLiked = likedBy.contains(currentUid);

    if (!alreadyLiked) {
      FirebaseFirestore.instance.collection('campus_idols').doc(docId).update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([currentUid]),
      });
    }

    final artistName = data['userName'] ?? 'Comrade Singer';
    final artistPhoto = data['userPhoto'] as String?;
    final title = data['title'] ?? 'Campus Voice Audition';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.chair, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('CHAIR TURNED! 🔴', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You pressed the buzzer and turned your chair for this voice!', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 46,
              backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
              backgroundImage: (artistPhoto != null && artistPhoto.isNotEmpty) ? NetworkImage(artistPhoto) : null,
              child: (artistPhoto == null || artistPhoto.isEmpty)
                  ? const Icon(Icons.person, size: 46, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(artistName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
              child: Text('Filter: ${data['filter'] ?? 'Normal'}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Listening', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.chat_bubble, size: 16, color: Colors.white),
            label: const Text('Chat with Artist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              _feedAudioPlayer.stop();

              // Generate deterministic chat ID
              final sortedUids = [currentUid, creatorUid]..sort();
              final chatId = '${sortedUids[0]}_${sortedUids[1]}';

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchChatView(
                    chatId: chatId,
                    myUid: currentUid,
                    matchName: artistName,
                    matchAvatar: artistPhoto,
                    matchId: creatorUid,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _hitBuzzer() {
    HapticFeedback.heavyImpact();
    _feedAudioPlayer.stop();
    setState(() {
      _isPlayingFeed = false;
      _currentlyPlayingDocId = null;
    });
    _waveformController.stop();

    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Buzzed! ❌ Next audition...'), duration: Duration(milliseconds: 800)),
    );
  }

  void _openComments(String docId) {
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          height: 480,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Audition Feedback 🎵', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('campus_idols')
                      .doc(docId)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No comments yet. Leave the first cheer!', style: TextStyle(color: Colors.white38)),
                      );
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, i) {
                        final cDoc = snapshot.data!.docs[i];
                        final cData = cDoc.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                            child: const Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                          title: Text(cData['userName'] ?? 'Comrade', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(cData['text'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Cheer on this singer...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: () async {
                      final text = commentCtrl.text.trim();
                      if (text.isEmpty) return;
                      commentCtrl.clear();
                      await FirebaseFirestore.instance
                          .collection('campus_idols')
                          .doc(docId)
                          .collection('comments')
                          .add({
                        'text': text,
                        'uid': currentUid,
                        'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'Comrade',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Campus Idol 🎤', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Blind Feed'),
            Tab(text: 'Studio'),
            Tab(text: 'Leaderboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildBlindFeed(),
          _buildStudio(),
          _buildLeaderboard(),
        ],
      ),
    );
  }

  Widget _buildBlindFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('campus_idols').orderBy('createdAt', descending: true).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_none, size: 64, color: Colors.white30),
                const SizedBox(height: 16),
                const Text('No auditions yet.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Go to Studio tab and be the first Campus Idol!', style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  icon: const Icon(Icons.mic, color: Colors.white),
                  label: const Text('Record in Studio', style: TextStyle(color: Colors.white)),
                  onPressed: () => _tabController.animateTo(1),
                ),
              ],
            ),
          );
        }

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: snapshot.data!.docs.length,
          onPageChanged: (index) {
            _feedAudioPlayer.stop();
            setState(() {
              _currentlyPlayingDocId = null;
              _isPlayingFeed = false;
              _feedAudioPosition = Duration.zero;
            });
            _waveformController.stop();
          },
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final Color coverColor = data['colorHex'] != null ? Color(data['colorHex']) : Colors.blueAccent;
            final String? audioUrl = data['audioUrl'] as String?;
            final bool isThisPlaying = _currentlyPlayingDocId == doc.id && _isPlayingFeed;
            final List likedBy = (data['likedBy'] as List?) ?? [];
            final bool isLiked = likedBy.contains(currentUid);

            return Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Blurry Cover Art Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [coverColor.withValues(alpha: 0.45), Colors.black],
                        radius: 1.4,
                      ),
                    ),
                  ),

                  // Center Waveform Visualizer & Playback Control
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Interactive Vinyl Disc / Play Button
                      GestureDetector(
                        onTap: () {
                          if (audioUrl != null && audioUrl.isNotEmpty) {
                            _playFeedAudio(doc.id, audioUrl);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No audio file found for this audition.')),
                            );
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black45,
                                border: Border.all(
                                  color: isThisPlaying ? coverColor : Colors.white24,
                                  width: isThisPlaying ? 4 : 2,
                                ),
                                boxShadow: [
                                  if (isThisPlaying)
                                    BoxShadow(
                                      color: coverColor.withValues(alpha: 0.6),
                                      blurRadius: 30,
                                      spreadRadius: 4,
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              isThisPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 64,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        data['title'] ?? 'Campus Voice Audition',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isThisPlaying ? 'Audition Playing 🎶' : 'Tap disc to listen to voice',
                        style: TextStyle(color: isThisPlaying ? coverColor : Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),

                      // Animated Waveform
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(18, (i) {
                          return AnimatedBuilder(
                            animation: _waveformController,
                            builder: (context, child) {
                              final baseHeight = 14.0;
                              final randomOffset = ((math.sin(i + (_waveformController.value * math.pi * 2)) + 1.0) / 2.0);
                              final dynamicHeight = isThisPlaying ? (baseHeight + (randomOffset * 48.0)) : 16.0;

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 6,
                                height: dynamicHeight,
                                decoration: BoxDecoration(
                                  color: isThisPlaying ? coverColor : Colors.white38,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),

                      if (isThisPlaying)
                        Text(
                          '${_feedAudioPosition.inSeconds}s / ${_feedAudioDuration.inSeconds > 0 ? _feedAudioDuration.inSeconds : 10}s',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 12),

                      if (data['filter'] != null && data['filter'] != 'Normal')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: Text('Voice Filter: ${data['filter']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                    ],
                  ),

                  // Side Actions (Likes, Feedback, Share)
                  Positioned(
                    right: 16,
                    bottom: 120,
                    child: Column(
                      children: [
                        _buildSideAction(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          '${data['likes'] ?? 0}',
                          isLiked ? Colors.redAccent : Colors.white,
                          () => _turnChair(doc.id, data['uid'], data),
                        ),
                        const SizedBox(height: 24),
                        _buildSideAction(
                          Icons.chat_bubble_outline,
                          'Feedback',
                          Colors.white,
                          () => _openComments(doc.id),
                        ),
                        const SizedBox(height: 24),
                        _buildSideAction(
                          Icons.share_outlined,
                          'Share',
                          Colors.white,
                          () => _shareAudition(
                            id: doc.id,
                            artistName: data['userName'] ?? 'Anonymous Comrade',
                            title: data['title'] ?? 'Campus Voice Audition',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Judging Buttons (Buzzer & Chair Turn)
                  Positioned(
                    bottom: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FloatingActionButton.extended(
                          heroTag: 'buzzer_${doc.id}',
                          backgroundColor: Colors.redAccent.shade700,
                          onPressed: _hitBuzzer,
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text('Pass (Buzzer)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 24),
                        FloatingActionButton.extended(
                          heroTag: 'turn_${doc.id}',
                          backgroundColor: Colors.blueAccent,
                          onPressed: () => _turnChair(doc.id, data['uid'], data),
                          icon: const Icon(Icons.chair, color: Colors.white),
                          label: const Text('I Want You! 🔴', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _shareAudition({
    required String id,
    required String artistName,
    required String title,
    int? rank,
  }) {
    HapticFeedback.lightImpact();
    final shareUrl = 'https://dishi.delstarfordworks.co.ke/idol?id=$id';
    final rankPrefix = rank != null ? '🏆 Ranked #$rank on Campus Idol!\n' : '';
    final shareText = '$rankPrefix🎤 Listen to "$title" by $artistName on DISHI Campus Idol!\n\n'
        'Turn your chair & vote: $shareUrl';

    Clipboard.setData(ClipboardData(text: shareText));

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Audition link copied to clipboard! 🎶',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Paste anywhere to invite friends to listen & vote',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSideAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStudio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Audition Recording Studio 🎙️', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Hold the microphone to record up to 10 seconds of your voice.\nYour identity stays anonymous until a listener turns their chair!',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: CircularProgressIndicator(
                    value: _recordingProgress,
                    backgroundColor: Colors.white12,
                    color: Colors.redAccent,
                    strokeWidth: 8,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      _stopRecording();
                    } else {
                      _startRecording();
                    }
                  },
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  child: CircleAvatar(
                    radius: 64,
                    backgroundColor: _isRecording ? Colors.redAccent : const Color(0xFF1E293B),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            if (_isRecording || _recordingProgress > 0)
              Column(
                children: [
                  Text(
                    '${(_recordingDurationMs / 1000.0).toStringAsFixed(1)}s / 10.0s',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text('TAP TO FINISH RECORDING ⏹️', style: TextStyle(color: Colors.redAccent, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              )
            else
              const Column(
                children: [
                  Text('TAP OR HOLD TO RECORD', style: TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 6),
                  Text('Record up to 10 seconds of your voice to audition', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('campus_idols').orderBy('likes', descending: true).limit(15).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No ranked singers yet.', style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String? audioUrl = data['audioUrl'] as String?;
            final bool isPlayingThis = _playingLeaderboardDocId == doc.id;
            final String artistName = data['userName'] ?? 'Anonymous Voice #${index + 1}';
            final Color coverColor = data['colorHex'] != null ? Color(data['colorHex']) : Colors.blueAccent;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: coverColor.withValues(alpha: 0.25),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(color: coverColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    data['title'] ?? artistName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Filter: ${data['filter'] ?? 'Normal'} • $artistName',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${data['likes'] ?? 0} ',
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 20),
                        tooltip: 'Share Audition',
                        onPressed: () => _shareAudition(
                          id: doc.id,
                          artistName: artistName,
                          title: data['title'] ?? 'Campus Voice Audition',
                          rank: index + 1,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPlayingThis ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: Colors.blueAccent,
                          size: 32,
                        ),
                        onPressed: () async {
                          if (audioUrl == null || audioUrl.isEmpty) return;
                          if (isPlayingThis) {
                            await _leaderboardPlayer.stop();
                            setState(() => _playingLeaderboardDocId = null);
                          } else {
                            await DishiVoiceService.instance.stopListening();
                            await _feedAudioPlayer.stop();
                            await _leaderboardPlayer.stop();
                            setState(() => _playingLeaderboardDocId = doc.id);
                            await _leaderboardPlayer.play(UrlSource(audioUrl));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
