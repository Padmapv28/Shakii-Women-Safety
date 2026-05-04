import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [
    _Message(
      text: 'Hi! I\'m Shakti Assistant. How can I help you stay safe?',
      isUser: false,
    ),
  ];
  bool _loading = false;

  // Quick help prompts
  static const _quickPrompts = [
    '🚨 I feel unsafe right now',
    '📞 How do I add a guardian?',
    '🗺️ Is my area safe?',
    '📋 Women\'s helpline numbers',
  ];

  // Quick offline responses (no internet needed for these)
  static const _offlineResponses = {
    'helpline': '''Emergency helplines (India):
• Police: 100
• Women Helpline: 1091  
• National Emergency: 112
• Bengaluru Police: 080-22942222
• iCall (counselling): 9152987821''',
    'guardian': 'Go to the Guardians tab → tap + → add their phone number. They will be auto-notified in any SOS.',
    'unsafe': 'Press the red SOS button immediately. I will alert your guardians with your live location.',
  };

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _loading = true;
    });
    _scrollDown();

    // Try offline responses first
    final lower = text.toLowerCase();
    String? offlineReply;
    if (lower.contains('helpline') || lower.contains('number') || lower.contains('police')) {
      offlineReply = _offlineResponses['helpline'];
    } else if (lower.contains('guardian') || lower.contains('add')) {
      offlineReply = _offlineResponses['guardian'];
    } else if (lower.contains('unsafe') || lower.contains('scared') || lower.contains('help')) {
      offlineReply = _offlineResponses['unsafe'];
    }

    if (offlineReply != null) {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _messages.add(_Message(text: offlineReply!, isUser: false));
        _loading = false;
      });
      _scrollDown();
      return;
    }

    // Online: call backend chatbot endpoint (which calls Claude API)
    try {
      final resp = await http.post(
        Uri.parse('https://your-backend.com/api/chatbot'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': text,
          'context': 'women_safety_app_bengaluru',
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _messages.add(_Message(text: data['reply'], isUser: false));
          _loading = false;
        });
      } else {
        _showOfflineDefault();
      }
    } catch (_) {
      _showOfflineDefault();
    }
    _scrollDown();
  }

  void _showOfflineDefault() {
    setState(() {
      _messages.add(_Message(
        text: 'I\'m here for you. If you\'re in danger, press the red SOS button. '
            'For helplines: Police 100, Women Helpline 1091.',
        isUser: false,
      ));
      _loading = false;
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(radius: 16, child: Icon(Icons.assistant, size: 18)),
            SizedBox(width: 10),
            Text('Shakti Assistant'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick prompts
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(_quickPrompts[i], style: const TextStyle(fontSize: 12)),
                onPressed: () => _send(_quickPrompts[i]),
              ),
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (_, i) {
                if (_loading && i == _messages.length) {
                  return _TypingBubble();
                }
                return _MessageBubble(msg: _messages[i]);
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask anything about safety...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: _send,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.red,
                  onPressed: () => _send(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  _Message({required this.text, required this.isUser});
}

class _MessageBubble extends StatelessWidget {
  final _Message msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isUser ? Colors.red[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(msg.text,
            style: TextStyle(
                color: msg.isUser ? Colors.white : Colors.black87)),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text('Typing...', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
