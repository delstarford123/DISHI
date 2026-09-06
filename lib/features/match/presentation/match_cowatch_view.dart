import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchCowatchView extends StatefulWidget {
  const MatchCowatchView({super.key});

  @override
  State<MatchCowatchView> createState() => _MatchCowatchViewState();
}

class _MatchCowatchViewState extends State<MatchCowatchView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPlaying = false;

  final List<Map<String, dynamic>> _messages = [
    {'text': 'Did you see that plot twist?!', 'isMe': false},
    {'text': 'I know right! Crazy!', 'isMe': true},
  ];

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'text': _textController.text.trim(), 'isMe': true});
    });
    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Co-Watch Party', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Simulated YouTube / Video Player Area
          GestureDetector(
            onTap: () => setState(() => _isPlaying = !_isPlaying),
            child: Container(
              height: 250,
              decoration: const BoxDecoration(
                color: _surfaceLight,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Center(child: Text('Simulated Video Stream', style: TextStyle(color: Colors.white54))),
                  if (!_isPlaying)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(value: 0.3, backgroundColor: Colors.white24, color: _neonPink),
                  )
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: _cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YouTube: Best Campus Moments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Synced with Jessica', style: TextStyle(color: _neonPink, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    const CircleAvatar(radius: 16, backgroundColor: _surfaceLight, child: Icon(Icons.person, size: 16, color: _textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                      child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    )
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg['text'], msg['isMe']);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: _cardColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Chat while watching...',
                      hintStyle: const TextStyle(color: _textSecondary),
                      filled: true,
                      fillColor: _surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: _neonPink), onPressed: _sendMessage)
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isMe ? _neonPink : _surfaceLight, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
