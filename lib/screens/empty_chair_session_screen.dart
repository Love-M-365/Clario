import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/ai_service.dart';

class EmptyChairSessionScreen extends StatefulWidget {
  final String chairMemberName;
  const EmptyChairSessionScreen({super.key, required this.chairMemberName});

  @override
  State<EmptyChairSessionScreen> createState() =>
      _EmptyChairSessionScreenState();
}

class _EmptyChairSessionScreenState extends State<EmptyChairSessionScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  final AIService _aiService = AIService();
  String? _sessionId;
  bool _isLoading = false;

  // 🔹 Always BLUE or RED (never "user"/"chair")
  String _currentPerspective = 'BLUE';

  @override
  void initState() {
    super.initState();
    _startIntroSession();
  }

  // 1️⃣ AI Introduction before starting session
  Future<void> _startIntroSession() async {
    setState(() => _isLoading = true);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demoUser';

    try {
      final response = await _aiService.startSession(
        userId,
        personInChair: widget.chairMemberName,
        userGoal: "Explore your thoughts",
      );

      _sessionId = response['sessionId'];

      _addMessage(
        sender: widget.chairMemberName,
        text:
            "Hello! I am ${widget.chairMemberName}. Today I will guide you through this session. Answer my questions honestly, and I will help you reflect and explore your thoughts.",
        isUser: false,
      );

      // Add first AI question
      _addMessage(
        sender: widget.chairMemberName,
        text: response['initialAiMessage'] ??
            "Let's start. What do you want to talk about today?",
        isUser: false,
      );
    } catch (e) {
      _addMessage(
        sender: widget.chairMemberName,
        text: "Error starting session: $e",
        isUser: false,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addMessage(
      {required String sender, required String text, required bool isUser}) {
    setState(() {
      _messages.add(ChatMessage(
        sender: sender,
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 2️⃣ Handle user input and AI follow-ups
  Future<void> _handleSubmitted(String text) async {
    if (text.isEmpty || _isLoading) return;

    final isUserPerspective = _currentPerspective == 'BLUE';
    _addMessage(
      sender: isUserPerspective ? 'You' : widget.chairMemberName,
      text: text,
      isUser: isUserPerspective,
    );

    _textController.clear();
    setState(() => _isLoading = true);

    if (_sessionId != null) {
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demoUser';

        final aiResponse = await _aiService.processMessage(
          userId,
          _sessionId!,
          text,
          _currentPerspective, // always BLUE or RED
        );

        // 3️⃣ AI automatically generates follow-up question
        final aiText = aiResponse['aiMessage'] ??
            "I have another question for you: How does that make you feel?";

        _addMessage(
          sender: isUserPerspective ? widget.chairMemberName : 'You',
          text: aiText,
          isUser: !isUserPerspective,
        );

        // 🔄 Toggle perspective after every exchange
        _currentPerspective = _currentPerspective == 'BLUE' ? 'RED' : 'BLUE';
      } catch (e) {
        _addMessage(
          sender: widget.chairMemberName,
          text: "Error getting AI response: $e",
          isUser: false,
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _togglePerspective() {
    setState(() {
      _currentPerspective = _currentPerspective == 'BLUE' ? 'RED' : 'BLUE';
    });
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF4facfe), Color(0xFF00f2fe)])
              : const LinearGradient(
                  colors: [Color(0xFFff6a6a), Color(0xFFff3b3b)]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    final hintText = _currentPerspective == 'BLUE'
        ? 'Type as yourself...'
        : 'Type as ${widget.chairMemberName}...';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleSubmitted,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            onPressed: _togglePerspective,
          ),
          InkWell(
            onTap: _isLoading
                ? null
                : () => _handleSubmitted(_textController.text),
            borderRadius: BorderRadius.circular(30),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              radius: 26,
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Talking with ${widget.chairMemberName}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 24.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
            _buildChatInput(),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String sender;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
