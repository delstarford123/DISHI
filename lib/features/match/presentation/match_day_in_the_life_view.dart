import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color _bgColor = Color(0xFF0F172A);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonYellow = Colors.yellowAccent;

class MatchDayInTheLifeView extends StatefulWidget {
  const MatchDayInTheLifeView({super.key});

  @override
  State<MatchDayInTheLifeView> createState() => _MatchDayInTheLifeViewState();
}

class _MatchDayInTheLifeViewState extends State<MatchDayInTheLifeView> {
  final ImagePicker _picker = ImagePicker();
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  // 24 Hour Expiration Limit
  DateTime get _yesterday => DateTime.now().subtract(const Duration(hours: 24));

  Future<void> _openCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (image == null) return;
      if (!mounted) return;

      Navigator.push(context, MaterialPageRoute(builder: (_) => _StoryUploadPreview(imagePath: image.path)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        title: const Text('Day in the Life 📸', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Feature 15: 24 Hour expiration query
        stream: FirebaseFirestore.instance.collection('day_in_the_life_posts')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(_yesterday))
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonYellow));
          }

          final docs = snapshot.data?.docs ?? [];
          
          // Group by UID
          Map<String, List<QueryDocumentSnapshot>> userStories = {};
          for (var doc in docs) {
            final uid = doc['uid'];
            if (userStories[uid] == null) userStories[uid] = [];
            userStories[uid]!.add(doc);
          }

          final uids = userStories.keys.toList();
          
          // Ensure my story is always first
          if (uids.contains(_uid)) {
            uids.remove(_uid);
            uids.insert(0, _uid);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Feature 11: Instagram Style Horizontal Scrolling Stories
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: uids.length + (uids.contains(_uid) ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (index == 0 && !uids.contains(_uid)) {
                      return _buildAddStoryAvatar();
                    }
                    
                    final targetUid = uids.contains(_uid) ? uids[index] : uids[index - 1];
                    final stories = userStories[targetUid]!;
                    final isMe = targetUid == _uid;
                    
                    return _buildStoryAvatar(targetUid, stories, isMe);
                  },
                ),
              ),
              const Divider(color: Colors.white10),
              
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt, color: _neonYellow, size: 80),
                      const SizedBox(height: 20),
                      const Text('Show us what you\'re up to!', style: TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('Posts disappear after 24 hours.', style: TextStyle(color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _openCamera,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _neonYellow,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Post a Photo', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      )
                    ],
                  ),
                ),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildAddStoryAvatar() {
    return GestureDetector(
      onTap: _openCamera,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
              child: const Center(child: Icon(Icons.add, color: Colors.white, size: 30)),
            ),
            const SizedBox(height: 4),
            const Text('Your Story', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryAvatar(String targetUid, List<QueryDocumentSnapshot> stories, bool isMe) {
    // We would fetch user details in a real app, here we assume targetUid as name
    final recentStory = stories.first;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => _StoryViewer(stories: stories.reversed.toList(), isMe: isMe)));
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _neonYellow, width: 2)),
              child: ClipOval(
                child: Image.network(recentStory['imageUrl'], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 4),
            Text(isMe ? 'Your Story' : 'Student', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// FEATURE 13, 20: CAPTION AND FILTER PREVIEW
// ---------------------------------------------------------
class _StoryUploadPreview extends StatefulWidget {
  final String imagePath;
  const _StoryUploadPreview({required this.imagePath});

  @override
  State<_StoryUploadPreview> createState() => _StoryUploadPreviewState();
}

class _StoryUploadPreviewState extends State<_StoryUploadPreview> {
  bool _isUploading = false;
  final TextEditingController _captionController = TextEditingController();
  
  // Feature 20: Color Filters
  Color _selectedFilter = Colors.transparent;
  final List<Color> _filters = [Colors.transparent, Colors.red.withOpacity(0.3), Colors.blue.withOpacity(0.3), Colors.green.withOpacity(0.3), Colors.purple.withOpacity(0.3)];
  
  // Feature 12: Daily Prompts
  final List<String> _prompts = ["Study spot check! 📚", "What's for lunch? 🍔", "Current View 👀", "OOTD 👗"];
  late String _dailyPrompt;

  @override
  void initState() {
    super.initState();
    _dailyPrompt = _prompts[DateTime.now().day % _prompts.length];
  }

  Future<void> _upload() async {
    setState(() => _isUploading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final storageRef = FirebaseStorage.instance.ref().child('$uid/day_in_the_life_$timestamp.jpg');
      await storageRef.putFile(File(widget.imagePath), SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('day_in_the_life_posts').add({
        'uid': uid,
        'imageUrl': downloadUrl,
        'caption': _captionController.text,
        'prompt': _dailyPrompt,
        'filterValue': _selectedFilter.value,
        'timestamp': FieldValue.serverTimestamp(),
        'views': [], // Feature 18: View counts
        'likes': [], // Feature 16: Likes
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story Uploaded! 🚀'), backgroundColor: _neonYellow));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image with filter
          Positioned.fill(child: Image.file(File(widget.imagePath), fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: _selectedFilter)),
          
          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Text('Prompt: $_dailyPrompt', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
          
          // Caption input
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _captionController,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                decoration: const InputDecoration(hintText: 'Tap to add caption...', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
                maxLines: null,
              ),
            ),
          ),
          
          // Bottom Controls (Filters and Upload)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((c) => GestureDetector(
                        onTap: () => setState(() => _selectedFilter = c),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 40, height: 40,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(color: Colors.white, width: 2)),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _isUploading 
                    ? const CircularProgressIndicator(color: _neonYellow)
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _neonYellow, padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: _upload,
                          child: const Text('POST TO STORY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// FEATURE 14: STORY VIEWER WITH PROGRESS BAR
// ---------------------------------------------------------
class _StoryViewer extends StatefulWidget {
  final List<QueryDocumentSnapshot> stories;
  final bool isMe;

  const _StoryViewer({required this.stories, required this.isMe});

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
    _startStory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _startStory() {
    _progressController.reset();
    _progressController.forward();
    
    // Feature 18: Record view
    if (!widget.isMe) {
      final doc = widget.stories[_currentIndex];
      List views = doc['views'] ?? [];
      if (!views.contains(_uid)) {
        doc.reference.update({'views': FieldValue.arrayUnion([_uid])});
      }
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startStory();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }
  
  // Feature 16: Double Tap to Like
  void _likeStory() async {
    final doc = widget.stories[_currentIndex];
    await doc.reference.update({'likes': FieldValue.arrayUnion([_uid])});
    // Optional: Show heart animation
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❤️ Liked!'), duration: Duration(milliseconds: 500)));
  }

  // Feature 17: Reply to Story
  void _sendReply() async {
    if (_replyController.text.isEmpty) return;
    final text = _replyController.text;
    _replyController.clear();
    
    final targetUid = widget.stories[_currentIndex]['uid'];
    List<String> ids = [_uid, targetUid];
    ids.sort();
    final chatId = '${ids[0]}_${ids[1]}';
    
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'type': 'text',
      'text': 'Reply to story: $text',
      'senderId': _uid,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'reactions': {},
    });
    
    if (mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent!')));
    }
  }

  // Feature 19: Delete own story
  void _deleteStory() async {
    final doc = widget.stories[_currentIndex];
    await doc.reference.delete();
    if (mounted) {
      Navigator.pop(context); // Close viewer, list will rebuild
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDoc = widget.stories[_currentIndex];
    final imageUrl = currentDoc['imageUrl'];
    final caption = currentDoc['caption'] ?? '';
    final prompt = currentDoc['prompt'] ?? '';
    final filterValue = currentDoc['filterValue'] ?? Colors.transparent.value;
    
    final likes = List<String>.from(currentDoc['likes'] ?? []);
    final views = List<String>.from(currentDoc['views'] ?? []);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onDoubleTap: _likeStory,
        onLongPressStart: (_) => _progressController.stop(),
        onLongPressEnd: (_) => _progressController.forward(),
        child: Stack(
          children: [
            // Background Image & Filter
            Positioned.fill(child: Image.network(imageUrl, fit: BoxFit.cover)),
            Positioned.fill(child: Container(color: Color(filterValue))),
            
            // Progress Bars
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: List.generate(widget.stories.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            double value = 0;
                            if (index < _currentIndex) {
                              value = 1;
                            } else if (index == _currentIndex) value = _progressController.value;
                            
                            return LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.white38,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 2,
                            );
                          }
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            
            // Header Info
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
                child: Row(
                  children: [
                    const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
                    const SizedBox(width: 8),
                    Text(widget.isMe ? 'You' : 'Student', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (prompt.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                        child: Text(prompt, style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
                  ],
                ),
              ),
            ),
            
            // Caption
            if (caption.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    caption, 
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                  ),
                ),
              ),
              
            // Floating Like Animation Context (Implicit via double tap)
            if (likes.contains(_uid))
               const Positioned(
                 bottom: 120, right: 24,
                 child: Icon(Icons.favorite, color: Colors.red, size: 40, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
               ),
              
            // Bottom Controls
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16
                ),
                child: widget.isMe 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.remove_red_eye, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('${views.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                            const Icon(Icons.favorite, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text('${likes.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: _deleteStory,
                        )
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Reply to story...',
                              hintStyle: const TextStyle(color: Colors.white70),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              filled: true,
                              fillColor: Colors.black45,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.white54)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.white54)),
                            ),
                            onTap: () => _progressController.stop(), // Pause when typing
                            onSubmitted: (_) {
                              _sendReply();
                              _progressController.forward();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () { _sendReply(); _progressController.forward(); }),
                      ],
                    ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
