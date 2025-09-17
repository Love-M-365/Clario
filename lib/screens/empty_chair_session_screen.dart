// lib/screens/empty_chair_session_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../providers/user_data_provider.dart';

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
  bool _isUserTurn = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addMessage(
      sender: 'AI',
      text:
          "Hello. I am ${widget.chairMemberName}. What do you want to talk about today and what do you hope to achieve?",
      isUser: false,
    );
  }

  void _addMessage(
      {required String sender, required String text, required bool isUser}) {
    setState(() {
      _messages.add(
        ChatMessage(
          sender: sender,
          text: text,
          isUser: isUser,
          timestamp: DateTime.now(),
        ),
      );
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

  void _handleSubmitted(String text) {
    if (text.isNotEmpty && !_isSaving) {
      _addMessage(
          sender: _isUserTurn ? 'You' : widget.chairMemberName,
          text: text,
          isUser: _isUserTurn);
      _textController.clear();

      setState(() {
        _isUserTurn = !_isUserTurn; // Toggle turn
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'It is now the turn of ${_isUserTurn ? "You" : widget.chairMemberName}.'),
        ),
      );
    }
  }

  Future<void> _saveConversation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final databaseReference = FirebaseDatabase.instance
          .ref('users/${user.uid}/emptyChairConversations')
          .push();
      final chatData = _messages
          .map((m) => {
                'sender': m.sender,
                'text': m.text,
                'isUser': m.isUser,
                'timestamp': m.timestamp.toIso8601String(),
              })
          .toList();

      await databaseReference.set({
        'chairMemberName': widget.chairMemberName,
        'conversation': chatData,
        'endedAt': DateTime.now().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving conversation: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _endSession() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
            'Are you sure you want to end and save this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      await _saveConversation();
      if (mounted) {
        context.go('/home'); // Navigate back to the main dashboard
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Conversation with ${widget.chairMemberName}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _endSession,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C1324),
              Color(0xFF131A2D),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    final hintText = _isUserTurn
        ? 'Speak as yourself...'
        : 'Speak as ${widget.chairMemberName}...';

    return Container(
      color: Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleSubmitted,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration.collapsed(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
            ),
          ),
          IconButton(
            icon:
                Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
            onPressed:
                _isSaving ? null : () => _handleSubmitted(_textController.text),
          ),
        ],
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
