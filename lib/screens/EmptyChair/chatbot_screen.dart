import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../services/ai_service.dart';

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

  // --- UI Theme Colors ---
  final Color backgroundColor = const Color(0xFFF3F0FF); // Light purple
  final Color userBubbleColor = const Color(0xFF4A55A2); // A deep blue
  final Color aiBubbleColor = Colors.white;
  final Color blueChairBubbleColor = const Color(0xFFE3F2FD); // Light blue
  final Color blueChairBorderColor = Colors.blue.shade300;
  final Color primaryTextColor = Colors.grey.shade900;
  final Color secondaryTextColor = Colors.grey.shade700;
  final Color accentColor = Colors.blue.shade700;

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

      String aiMessage =
          res["aiMessage"] ?? "Thanks for sharing. What else comes to mind?";
      bool isBlueChairPrompt = res["sessionPhase"] == "empty_chair_ready";

      _addMessage("AI", aiMessage, false, isBlueChair: isBlueChairPrompt);

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
        // --- UI Enhancement ---
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: Colors.white,
          title: Text(
            "Time to Reflect",
            style:
                TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: TextStyle(color: secondaryTextColor, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Got it",
                  style: TextStyle(
                      color: accentColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        // ---------------------
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
      // --- UI Enhancement ---
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Clarity Session",
          style: TextStyle(
            color: primaryTextColor, // Changed color
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent, // Changed background
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close,
              color: secondaryTextColor), // Added close button
          onPressed: () => context.pop(),
        ),
        actions: [
          // Moved button to AppBar for cleaner UI
          TextButton(
            onPressed: _goToEmptyChair,
            child: Text(
              "Empty Chair",
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      // ---------------------
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0), // Added padding
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                // Using the new styled bubble
                return _ChatBubble(
                  text: msg["text"],
                  isUser: msg["isUser"],
                  isBlueChair: msg["isBlueChair"] ?? false,
                  theme: this, // Pass theme data
                );
              },
            ),
          ),
          if (_isLoading) LinearProgressIndicator(color: accentColor),
          // --- UI Enhancement: Styled Text Input Area ---
          _buildTextInputArea(),
          // ------------------------------------------
        ],
      ),
    );
  }

  // --- UI Enhancement: New Widget for Text Input ---
  Widget _buildTextInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)
          .copyWith(bottom: MediaQuery.of(context).padding.bottom + 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: primaryTextColor, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Type your thoughts...",
                hintStyle: TextStyle(color: secondaryTextColor),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 14.0, horizontal: 20.0),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: accentColor,
            borderRadius: BorderRadius.circular(18.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(18.0),
              onTap: () => _sendMessage(_controller.text),
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 24.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // -----------------------------------------------
}

// --- UI Enhancement: Re-styled ChatBubble Widget ---
class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isBlueChair;
  final _ChatbotScreenState theme; // To access theme colors

  const _ChatBubble({
    required this.text,
    required this.isUser,
    required this.isBlueChair,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isUser
        ? theme.userBubbleColor
        : (isBlueChair ? theme.blueChairBubbleColor : theme.aiBubbleColor);
    final textColor = isUser ? Colors.white : theme.primaryTextColor;
    final borderRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          );

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: isBlueChair
                ? Border.all(color: theme.blueChairBorderColor, width: 1.5)
                : null,
            boxShadow: isUser
                ? null
                : [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 16, height: 1.3),
          ),
        ),
      ],
    );
  }
}
