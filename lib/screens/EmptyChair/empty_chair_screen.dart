import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/ai_service.dart';

class EmptyChairScreen extends StatefulWidget {
  const EmptyChairScreen({super.key});

  @override
  State<EmptyChairScreen> createState() => _EmptyChairScreenState();
}

class _EmptyChairScreenState extends State<EmptyChairScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  String _perspective = "blue"; // default perspective
  bool _isLoading = false;
  bool _isPreparing = true; // Preparing overlay
  late String _sessionId;
  late String _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    _sessionId = extra is String ? extra : "invalid_session";
    _userId =
        "demoUser"; // Replace with FirebaseAuth.instance.currentUser?.uid if needed
    _prepareSession();
  }

  /// Show preparing overlay until first AI response
  Future<void> _prepareSession() async {
    if (_sessionId == "invalid_session") return;
    setState(() => _isPreparing = true);

    try {
      // Send a dummy message to initialize AI for empty chair
      final res = await _aiService.processMessage(
        _userId,
        _sessionId,
        "Hello",
        _perspective,
      );

      if (res["aiMessage"] != null) {
        _addMessage("AI", res["aiMessage"], isFloating: true);
      }
    } catch (e) {
      _addMessage("AI", "Failed to prepare session: $e", isFloating: true);
    } finally {
      setState(() => _isPreparing = false);
    }
  }

  void _togglePerspective() {
    setState(() {
      _perspective = _perspective == "blue" ? "red" : "blue";
    });
  }

  void _addMessage(String sender, String text, {bool isFloating = false}) {
    final msg = {"sender": sender, "text": text, "floating": isFloating};
    setState(() => _messages.add(msg));

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }

    if (isFloating) {
      Timer(const Duration(seconds: 5), () {
        setState(() => _messages.remove(msg));
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _sessionId == "invalid_session") return;

    _addMessage(_perspective.toUpperCase(), text);
    _controller.clear();
    setState(() => _isLoading = true);

    try {
      final res = await _aiService.processMessage(
        _userId,
        _sessionId,
        text,
        _perspective,
      );

      if (res["aiMessage"] != null) {
        _addMessage("AI", res["aiMessage"], isFloating: true);
      } else {
        _addMessage("AI", "How does that feel?", isFloating: true);
      }
    } catch (e) {
      _addMessage("AI", "Error: $e", isFloating: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text("Empty Chair Dialogue")),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = _messages[i];
                    final isUser =
                        msg["sender"] == "BLUE" || msg["sender"] == "RED";
                    Color bubbleColor;
                    if (msg["sender"] == "BLUE") {
                      bubbleColor = Colors.blue.shade200;
                    } else if (msg["sender"] == "RED") {
                      bubbleColor = Colors.red.shade200;
                    } else {
                      bubbleColor = Colors.grey.shade300;
                    }
                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg["text"]),
                      ),
                    );
                  },
                ),
              ),
              if (_isLoading) const LinearProgressIndicator(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "Speak as ${_perspective.toUpperCase()}",
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: _togglePerspective,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _sendMessage(_controller.text),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  context.push('/home/summary', extra: _sessionId);
                },
                child: const Text("Get Summary"),
              ),
            ],
          ),
        ),
        if (_isPreparing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Preparing session...",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
