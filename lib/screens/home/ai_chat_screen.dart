// lib/screens/home/ai_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
// --- MODIFIED ---: Import Firestore
import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatRole { user, ai, typing }

class ChatMessage {
  final String content;
  final ChatRole role;
  // --- MODIFIED ---: Added timestamp for ordering
  final Timestamp timestamp;

  ChatMessage({
    required this.content,
    required this.role,
    required this.timestamp,
  });

  // --- MODIFIED ---: Factory to create a message from a Firestore snapshot
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] as String,
      // Convert the stored string back to an enum
      role: ChatRole.values.firstWhere(
        (e) => e.toString() == json['role'] as String,
        orElse: () => ChatRole.ai, // Default fallback
      ),
      timestamp: json['timestamp'] as Timestamp,
    );
  }

  // --- MODIFIED ---: Method to convert a message to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'role': role.toString(), // Store the enum as a string
      'timestamp': timestamp,
    };
  }
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Dio _dio = Dio();

  // --- MODIFIED ---: Firebase and User instances
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _user;

  // --- MODIFIED ---: Local state for typing indicator, not saved to DB
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // --- MODIFIED ---: Get the current user on init
    _user = FirebaseAuth.instance.currentUser;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Auto-Scrolling Logic (Your code was already perfect) ---
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

  // --- Message Sending Logic ---
  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    // --- MODIFIED ---: Check if user is null
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to chat.")),
      );
      return;
    }

    final userMessage = ChatMessage(
      role: ChatRole.user,
      content: _controller.text.trim(),
      timestamp: Timestamp.now(), // Add timestamp
    );
    _controller.clear();

    // --- MODIFIED ---: Set local typing state
    setState(() {
      _isTyping = true;
    });
    _scrollToBottom(); // Scroll after user sends

    try {
      // --- MODIFIED ---: Save the user's message to Firestore
      final chatRef =
          _db.collection('users').doc(_user!.uid).collection('chats');
      await chatRef.add(userMessage.toJson());

      // --- Get AI Response ---
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in. Please log in first.");
      }
      String? idToken = await user.getIdToken();
      const chatFunctionUrl =
          "https://clario-ai-1045577266956.us-central1.run.app/chat";

      final response = await _dio.post(
        chatFunctionUrl,
        data: {"message": userMessage.content},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        ),
      );

      String aiContent;
      if (response.statusCode == 200) {
        final data = response.data;
        aiContent = data['reply'] ??
            data['question'] ??
            data['message'] ??
            "I'm not sure how to respond to that.";
      } else {
        aiContent =
            "Error: Could not connect to Clario. Please try again later.";
      }

      final aiMessage = ChatMessage(
        role: ChatRole.ai,
        content: aiContent,
        timestamp: Timestamp.now(),
      );
      // --- MODIFIED ---: Save AI response to Firestore
      await chatRef.add(aiMessage.toJson());
    } on DioException catch (e) {
      final errorMessage = ChatMessage(
        role: ChatRole.ai,
        content: "Network Error: ${e.message}",
        timestamp: Timestamp.now(),
      );
      // --- MODIFIED ---: Save error message to Firestore
      await _db
          .collection('users')
          .doc(_user!.uid)
          .collection('chats')
          .add(errorMessage.toJson());
    } catch (e) {
      final errorMessage = ChatMessage(
        role: ChatRole.ai,
        content: "An unexpected error occurred: ${e.toString()}",
        timestamp: Timestamp.now(),
      );
      // --- MODIFIED ---: Save error message to Firestore
      await _db
          .collection('users')
          .doc(_user!.uid)
          .collection('chats')
          .add(errorMessage.toJson());
    } finally {
      // --- MODIFIED ---: Stop typing indicator
      setState(() {
        _isTyping = false;
      });
      // Scroll again in case an error message was added
      _scrollToBottom();
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Clario AI"),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 1,
      ),
      body: Column(
        children: [
          // --- MODIFIED ---: Replaced Expanded(ListView) with a StreamBuilder
          Expanded(
            child: _user == null
                ? const Center(
                    child: Text("Please log in to see your chat history."))
                : StreamBuilder<QuerySnapshot>(
                    // Listen to the user's specific chat collection
                    stream: _db
                        .collection('users')
                        .doc(_user!.uid)
                        .collection('chats')
                        .orderBy('timestamp') // Order messages by time
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Center(
                            child: Text("Error loading messages."));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            "Start your conversation with Clario!",
                            style: theme.textTheme.bodyMedium,
                          ),
                        );
                      }

                      // We have data, so map docs to ChatMessage objects
                      final docs = snapshot.data!.docs;
                      final messages = docs
                          .map((doc) => ChatMessage.fromJson(
                              doc.data() as Map<String, dynamic>))
                          .toList();

                      // --- MODIFIED ---: Call scroll here to scroll when
                      // new messages arrive from the stream
                      _scrollToBottom();

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        // --- MODIFIED ---: Item count is list length + typing indicator
                        itemCount: messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          // --- MODIFIED ---: If it's the last item and we are typing, show indicator
                          if (index == messages.length) {
                            return const _TypingIndicator();
                          }
                          final message = messages[index];
                          // Your bubble widget works perfectly
                          return _ChatMessageBubble(message: message);
                        },
                      );
                    },
                  ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  // --- Helper Widget for the input area (Your code was already perfect) ---
  Widget _buildMessageComposer() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Type your message...",
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                fixedSize: const Size(50, 50),
              ),
              icon: const Icon(Icons.send_rounded),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Reusable Widget for Chat Bubbles (Your code was already perfect) ---
class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// --- Reusable Widget for Typing Indicator (Your code was already perfect) ---
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        // --- A small visual improvement ---
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text("Clario is typing..."),
          ],
        ),
      ),
    );
  }
}
