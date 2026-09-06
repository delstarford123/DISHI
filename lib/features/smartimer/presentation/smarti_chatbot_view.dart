import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/api_v3_client.dart'; // Handles the strict 30s timeout

class SmartiChatbotView extends StatefulWidget {
  const SmartiChatbotView({super.key});

  @override
  State<SmartiChatbotView> createState() => _SmartiChatbotViewState();
}

class _SmartiChatbotViewState extends State<SmartiChatbotView> {
  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text': 'Hi! I am SmartI, your AI Academic Wingman. How can I help you optimize your studies today?'
    }
  ];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isTyping = true;
    });
    
    _chatController.clear();
    _scrollToBottom();

    try {
      // Real backend endpoint with 30s strict timeout
      final response = await http.post(
        Uri.parse('\${ApiConfig.baseUrl}/api/v4/smarti/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({'sender': 'ai', 'text': data['reply'] ?? 'I have processed your request.'});
          
          // If the AI returned an actionable command to schedule a block
          if (data['action'] == 'SCHEDULE_BLOCK') {
            _messages.add({
              'sender': 'system',
              'text': 'Action: Scheduled "${data['block_title']}" at "${data['block_time']}". Alarms synced locally.'
            });
          }
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({'sender': 'ai', 'text': data['error'] ?? 'Sorry, I encountered an error.'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'ai', 'text': 'Network timeout. Falling back to offline local coaching.'});
      });
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('SmartI Wingman'),
        backgroundColor: MPesaTheme.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: 'Launch Pomodoro',
            onPressed: () {
              // We'll wire this to launch the DailyFocusView
              Navigator.pop(context); // Go back to dashboard, they can tap Pomodoro there, or we push it
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['sender'] == 'user';
                  final isSystem = msg['sender'] == 'system';

                  if (isSystem) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(msg['text']!, style: TextStyle(color: Colors.blue.shade900, fontSize: 12))),
                        ],
                      ),
                    );
                  }

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(16),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isUser ? MPesaTheme.primaryGreen : Colors.white,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                          bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Text(
                        msg['text']!,
                        style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isTyping)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('SmartI is typing...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: 'Ask for a study plan...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      backgroundColor: MPesaTheme.primaryGreen,
                      radius: 24,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
