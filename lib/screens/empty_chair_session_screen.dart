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

  void _handleSubmitted(String text) {
    if (text.isNotEmpty && !_isSaving) {
      _addMessage(
        sender: _isUserTurn ? 'You' : widget.chairMemberName,
        text: text,
        isUser: _isUserTurn,
      );
      _textController.clear();

      setState(() {
        _isUserTurn = !_isUserTurn; // Toggle turn
      });
    }
  }

  Future<void> _saveConversation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

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
      setState(() => _isSaving = false);
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
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End & Save'),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      await _saveConversation();
      if (mounted) {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Talking with ${widget.chairMemberName}',
          style: const TextStyle(color: Colors.white),
        ),
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
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 24.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
            // Input
            _buildChatInput(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _endSession,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.stop),
        label: const Text("End Session"),
      ),
    );
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
                  colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.white70,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    final hintText = _isUserTurn
        ? 'Speak as yourself...'
        : 'Speak as ${widget.chairMemberName}...';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
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
          const SizedBox(width: 8),
          InkWell(
            onTap:
                _isSaving ? null : () => _handleSubmitted(_textController.text),
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
