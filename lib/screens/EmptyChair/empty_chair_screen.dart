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

  // --- FIX: Add a flag to prevent re-running on keyboard open ---
  bool _isFirstLoad = true;
  // -------------------------------------------------------------

  // --- UI Theme Colors (For styling) ---
  final Color backgroundColor = const Color(0xFFF3F0FF); // Light purple
  final Color blueBubbleColor = const Color(0xFF4A55A2); // Theme blue
  final Color redBubbleColor = const Color(0xFFD9534F); // A soft red
  final Color aiFloatingBubbleColor = Colors.white;
  final Color primaryTextColor = Colors.grey.shade900;
  final Color secondaryTextColor = Colors.grey.shade700;
  final Color accentColor = Colors.blue.shade700;
  // ------------------------------------------

  // --- YOUR ORIGINAL LOGIC (with the _isFirstLoad fix) ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstLoad) {
      final extra = GoRouterState.of(context).extra;
      _sessionId = extra is String ? extra : "invalid_session";
      _userId =
          "demoUser"; // Replace with FirebaseAuth.instance.currentUser?.uid if needed
      _prepareSession();
      setState(() {
        _isFirstLoad = false;
      });
    }
  }

  // --- YOUR ORIGINAL LOGIC ---
  Future<void> _prepareSession() async {
    if (_sessionId == "invalid_session") return;
    setState(() => _isPreparing = true);

    try {
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

  // --- YOUR ORIGINAL LOGIC ---
  void _togglePerspective() {
    setState(() {
      _perspective = _perspective == "blue" ? "red" : "blue";
    });
  }

  // --- YOUR ORIGINAL LOGIC (with timer ID for safety) ---
  void _addMessage(String sender, String text, {bool isFloating = false}) {
    final msg = {
      "sender": sender,
      "text": text,
      "floating": isFloating,
      "id": DateTime.now().millisecondsSinceEpoch // Unique ID
    };
    setState(() => _messages.add(msg));

    // Scroll to bottom for *all* new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    if (isFloating) {
      Timer(const Duration(seconds: 5), () {
        if (mounted) {
          // Remove the specific message by its ID
          setState(() => _messages.removeWhere((m) => m["id"] == msg["id"]));
        }
      });
    }
  }

  // --- YOUR ORIGINAL LOGIC ---
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

  // --- BUILD METHOD IS THE ONLY MAJOR CHANGE ---
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          // --- UI Enhancement: Themed Scaffold and AppBar ---
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text(
              "Empty Chair Dialogue",
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: secondaryTextColor),
              onPressed: () => context.pop(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  context.push('/home/summary', extra: _sessionId);
                },
                child: Text(
                  "Get Summary",
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
          // ---------------------------------------------
          body: Column(
            children: [
              Expanded(
                // --- NO MORE STACK HERE ---
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  // --- RENDER *ALL* MESSAGES ---
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = _messages[i];
                    final isFloating = msg["floating"] ?? false;

                    // --- RENDER BASED ON TYPE ---
                    if (isFloating) {
                      // RENDER INLINE FLOATING MESSAGE
                      return Align(
                        alignment: Alignment.center,
                        child: _FloatingMessage(text: msg["text"], theme: this),
                      );
                    } else {
                      // RENDER DIALOGUE BUBBLE
                      final isBlue = msg["sender"] == "BLUE";
                      final alignment =
                          isBlue ? Alignment.centerRight : Alignment.centerLeft;

                      return Align(
                        alignment: alignment,
                        child: _DialogueBubble(
                          text: msg["text"],
                          isBlue: isBlue,
                          isError: msg["sender"] == "AI", // For AI errors
                          theme: this,
                        ),
                      );
                    }
                    // -----------------------------
                  },
                ),
              ),
              // --- UI Enhancement: Themed Loader ---
              if (_isLoading) LinearProgressIndicator(color: accentColor),
              // --- UI Enhancement: Styled Text Input ---
              _buildInputArea(context), // Pass context
              // ---------------------------------------
            ],
          ),
        ),
        // --- UI Enhancement: Styled Loading Overlay ---
        if (_isPreparing)
          Container(
            color: backgroundColor.withOpacity(0.9),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: accentColor),
                  const SizedBox(height: 20),
                  Text(
                    "Preparing session...",
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 18,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // -----------------------------------------
      ],
    );
  }

  // --- UI WIDGET (Unchanged) ---
  Widget _buildInputArea(BuildContext context) {
    final bool isBlue = _perspective == "blue";
    final Color hintColor = isBlue ? blueBubbleColor : redBubbleColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)
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
          IconButton(
            icon: Icon(
              Icons.swap_horiz,
              color: hintColor,
              size: 28,
            ),
            onPressed: _togglePerspective,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: primaryTextColor, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Speak as ${_perspective.toUpperCase()}",
                hintStyle: TextStyle(
                    color: hintColor.withOpacity(0.8),
                    fontWeight: FontWeight.bold),
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
}

// --- UI WIDGET (Unchanged) ---
class _DialogueBubble extends StatelessWidget {
  final String text;
  final bool isBlue;
  final bool isError;
  final _EmptyChairScreenState theme;

  const _DialogueBubble({
    required this.text,
    required this.isBlue,
    required this.isError,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (isBlue) {
      color = theme.blueBubbleColor;
    } else if (isError) {
      color = theme.redBubbleColor.withOpacity(0.7);
    } else {
      color = theme.redBubbleColor;
    }

    final borderRadius = isBlue
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

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3),
      ),
    );
  }
}

// --- UI WIDGET (Unchanged) ---
class _FloatingMessage extends StatelessWidget {
  final String text;
  final _EmptyChairScreenState theme;

  const _FloatingMessage({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      // This is now an INLINE message, so it needs vertical margin
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: theme.aiFloatingBubbleColor,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1), // Softer shadow
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.secondaryTextColor,
          fontSize: 15,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
