import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../services/ai_service.dart';
import '../../widgets/chat_bubble.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();

  List<Map<String, dynamic>> _messages = [];
  String? _sessionId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    setState(() => _isLoading = true);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demoUser';

    try {
      final res = await _aiService.startSession(
        userId,
        personInChair: "The Other Side",
        userGoal: "Find clarity",
      );
      _sessionId = res["sessionId"];
      _addMessage("AI", res["initialAiMessage"] ?? "Let's begin.", false);
    } catch (e) {
      _addMessage("AI", "Error starting session: $e", false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addMessage(String sender, String text, bool isUser,
      {bool isBlueChair = false}) {
    setState(() {
      _messages.add({
        "sender": sender,
        "text": text,
        "isUser": isUser,
        "isBlueChair": isBlueChair,
      });
    });

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

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _sessionId == null) return;
    _addMessage("You", text, true);
    _controller.clear();
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demoUser';
      final res =
          await _aiService.analyzeInitialProblem(userId, _sessionId!, text);

      // AI response handling
      String aiMessage =
          res["aiMessage"] ?? "Thanks for sharing. What else comes to mind?";
      bool isBlueChairPrompt = res["sessionPhase"] == "empty_chair_ready";

      _addMessage("AI", aiMessage, false, isBlueChair: isBlueChairPrompt);

      // Optional: Show a dialog if BLUE Chair prompt
      if (isBlueChairPrompt) {
        _showBlueChairPrompt(aiMessage);
      }
    } catch (e) {
      _addMessage("AI", "Error: $e", false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showBlueChairPrompt(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("BLUE Chair Prompt"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Got it"),
            ),
          ],
        ),
      );
    });
  }

  void _goToEmptyChair() {
    if (_sessionId == null) {
      _addMessage("AI", "Session not ready yet.", false);
      return;
    }

    context.push('/home/emptyChair', extra: _sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "AI Chatbot Session",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                return ChatBubble(
                  text: msg["text"],
                  isUser: msg["isUser"],
                  isBlueChair: msg["isBlueChair"] ?? false,
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type your thoughts...",
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _goToEmptyChair,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
            ),
            child: const Text("Go to Empty Chair Session"),
          ),
        ],
      ),
    );
  }
}
