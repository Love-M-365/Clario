// lib/screens/home/ai_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- NEW ---: Import STT and TTS packages
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum ChatRole { user, ai, typing }

class ChatMessage {
  final String content;
  final ChatRole role;
  final Timestamp timestamp;

  ChatMessage({
    required this.content,
    required this.role,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] as String,
      role: ChatRole.values.firstWhere(
        (e) => e.toString() == json['role'] as String,
        orElse: () => ChatRole.ai,
      ),
      timestamp: json['timestamp'] as Timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'role': role.toString(),
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

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _user;

  // --- NEW ---: State variables for STT and TTS
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isAiMuted = false;

  bool _isTyping = false;
  bool _isInitialScroll = true; // <-- This is correct

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    // --- NEW ---: Initialize speech and TTS
    _initSpeech();
    _initTts();
  }

  // --- NEW ---: Initialize Text-to-Speech
  void _initTts() {
    // You can set language, pitch, etc. here if needed
    _flutterTts.setLanguage("en-US");
    _flutterTts.setPitch(1.0);
  }

  // --- NEW ---: Initialize Speech-to-Text
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    // --- NEW ---: Stop STT and TTS
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  // --- MODIFIED: This is the new "smart" scrolling function ---
  void _scrollToBottom() {
    // This callback runs *after* the UI has been built for the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return; // Not built yet

      if (_isInitialScroll) {
        // --- INITIAL LOAD ---
        // On the first load, just JUMP to the end instantly.
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _isInitialScroll = false; // Only do this once
      } else {
        // --- NEW MESSAGE ---
        // For all new messages, animate to the end.
        // We check if we are already near the bottom, to avoid annoying scrolls
        // if the user has scrolled up to read old messages.
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        // The "200.0" is a buffer. If the user is within 200 pixels
        // of the bottom, we auto-scroll. Otherwise, we don't.
        if (maxScroll - currentScroll <= 200.0) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }
  // --- END OF MODIFIED FUNCTION ---

  // --- NEW ---: Text-to-Speech "speak" function
  Future<void> _speak(String text) async {
    if (_isAiMuted) return; // Don't speak if muted
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.speak(text);
  }

  // --- NEW ---: STT Start Listening function
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {
      _isListening = true;
    });
  }

  // --- NEW ---: STT Stop Listening function
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  // --- NEW ---: STT Result callback
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _controller.text = result.recognizedWords;
      if (result.finalResult) {
        _isListening = false;
      }
    });
  }

  // --- Message Sending Logic ---
  Future<void> _sendMessage() async {
    // --- NEW ---: Stop listening if user hits send
    if (_isListening) {
      _stopListening();
    }

    if (_controller.text.trim().isEmpty) return;
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to chat.")),
      );
      return;
    }

    final userMessage = ChatMessage(
      role: ChatRole.user,
      content: _controller.text.trim(),
      timestamp: Timestamp.now(),
    );
    _controller.clear();

    setState(() {
      _isTyping = true;
    });
    // _scrollToBottom(); // <--- REMOVED THIS LINE

    try {
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
          "https://clario-ai-v2-1045577266956.us-central1.run.app/chat";

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

      // --- NEW ---: Speak the AI's response
      _speak(aiContent);

      final aiMessage = ChatMessage(
        role: ChatRole.ai,
        content: aiContent,
        timestamp: Timestamp.now(),
      );
      await chatRef.add(aiMessage.toJson());
    } on DioException catch (e) {
      final errorMessageContent = "Network Error: ${e.message}";
      // --- NEW ---: Speak the error message
      _speak(errorMessageContent);
      final errorMessage = ChatMessage(
        role: ChatRole.ai,
        content: errorMessageContent,
        timestamp: Timestamp.now(),
      );
      await _db
          .collection('users')
          .doc(_user!.uid)
          .collection('chats')
          .add(errorMessage.toJson());
    } catch (e) {
      final errorMessageContent =
          "An unexpected error occurred: ${e.toString()}";
      // --- NEW ---: Speak the error message
      _speak(errorMessageContent);
      final errorMessage = ChatMessage(
        role: ChatRole.ai,
        content: errorMessageContent,
        timestamp: Timestamp.now(),
      );
      await _db
          .collection('users')
          .doc(_user!.uid)
          .collection('chats')
          .add(errorMessage.toJson());
    } finally {
      setState(() {
        _isTyping = false;
      });
      // _scrollToBottom(); // <--- REMOVED THIS LINE
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ Fix keyboard push issue
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Clario AI"),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(
              _isAiMuted ? Icons.volume_off : Icons.volume_up,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() {
                _isAiMuted = !_isAiMuted;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        // ✅ Prevent content from jumping or hiding
        child: Column(
          children: [
            Expanded(
              child: _user == null
                  ? const Center(
                      child: Text("Please log in to see your chat history."))
                  : StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('users')
                          .doc(_user!.uid)
                          .collection('chats')
                          .orderBy('timestamp',
                              descending: true) // ✅ Reverse order
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
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

                        final docs = snapshot.data!.docs;
                        final messages = docs
                            .map((doc) => ChatMessage.fromJson(
                                doc.data() as Map<String, dynamic>))
                            .toList();

                        // ✅ Smooth scroll to bottom after new message
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true, // ✅ Makes chat feel like WhatsApp
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          itemCount: messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == 0 && _isTyping) {
                              return const _TypingIndicator();
                            }
                            final message =
                                messages[_isTyping ? index - 1 : index];
                            return _ChatMessageBubble(message: message);
                          },
                        );
                      },
                    ),
            ),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED ---: Updated the message composer
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
                  hintText:
                      _isListening ? "Listening..." : "Type your message...",
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
            // --- NEW ---: Microphone Button
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: _isListening
                    ? theme.colorScheme.primary.withOpacity(0.5)
                    : theme.scaffoldBackgroundColor,
                fixedSize: const Size(50, 50),
              ),
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              // Toggle listening state
              // Disable button if speech is not enabled
              onPressed: _speechEnabled
                  ? (_speechToText.isNotListening
                      ? _startListening
                      : _stopListening)
                  : null,
            ),
            const SizedBox(width: 8.0),
            // --- Send Button (Unchanged) ---
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

// --- Reusable Widget for Chat Bubbles (Unchanged) ---
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

// --- Reusable Widget for Typing Indicator (Unchanged) ---
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
