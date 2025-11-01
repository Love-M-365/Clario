import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/sleep_ai_service.dart';

class SleepChatScreen extends StatefulWidget {
  const SleepChatScreen({Key? key}) : super(key: key);

  @override
  State<SleepChatScreen> createState() => _SleepChatScreenState();
}

class _SleepChatScreenState extends State<SleepChatScreen> {
  final SleepAIService _aiService = SleepAIService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  /// Initialize chat with current user
  void _initializeChat() {
    _currentUser = _auth.currentUser;

    if (_currentUser == null) {
      // User not authenticated - redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotAuthenticatedDialog();
      });
      return;
    }

    // Add welcome message
    setState(() {
      _messages.add({
        'sender': 'ai',
        'text': '👋 Hi ${_currentUser!.displayName ?? 'there'}! I\'m your Sleep Wellness AI.\n\n'
            'I can analyze your sleep patterns and provide personalized insights. Try asking:\n\n'
            '• "Analyze my sleep"\n'
            '• "Show my sleep trends"\n'
            '• "How is my sleep quality?"\n'
            '• "Any sleep recommendations for me?"',
      });
    });

    print('✅ Chat initialized for user: ${_currentUser!.email}');
  }

  /// Show dialog if user is not authenticated
  void _showNotAuthenticatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Not Signed In'),
        content: const Text(
          'You need to sign in with Google to use the Sleep AI chat.\n\n'
          'Please go back and sign in first.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close chat screen
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Send a message to the AI
  Future<void> _sendMessage() async {
    if (_currentUser == null) {
      _showSnackBar('⚠️ Please sign in first');
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      print('📤 Sending message: $text');
      final reply = await _aiService.askSleepAI(text);
      print('📥 Received reply: $reply');

      setState(() {
        _messages.add({
          'sender': 'ai',
          'text': reply.isNotEmpty
              ? reply
              : '🤔 Hmm... I couldn\'t generate a response. Try asking differently!',
        });
      });
    } catch (e) {
      print('❌ Error sending message: $e');
      setState(() {
        _messages.add({
          'sender': 'ai',
          'text': '⚠️ Error: Could not reach the AI service.\n\n'
              'Details: ${e.toString()}\n\n'
              'Please check your internet connection and try again.',
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  /// Smoothly scroll to bottom
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Show snackbar notification
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Reset the chat session
  void _resetSession() {
    setState(() {
      _messages.clear();
      _messages.add({
        'sender': 'ai',
        'text': '🔄 Session reset! How can I help you with your sleep?',
      });
    });
    _aiService.resetSession();
    _showSnackBar('Session reset successfully');
  }

  /// Show help dialog
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💤 Sleep AI Tips'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Try asking these questions:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildHelpItem('📊', 'Analyze my sleep'),
              _buildHelpItem('📈', 'Show my sleep trends'),
              _buildHelpItem('😴', 'How is my sleep quality?'),
              _buildHelpItem('💡', 'Any recommendations for me?'),
              _buildHelpItem('🌙', 'Do I have sleep issues?'),
              _buildHelpItem('✨', 'Show my lucid dream progress'),
              const SizedBox(height: 12),
              const Text(
                'The AI analyzes your sleep data and provides personalized insights based on your patterns.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// Show user info dialog
  void _showUserInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('👤 Your Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentUser?.photoURL != null)
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(_currentUser!.photoURL!),
                ),
              ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', _currentUser?.displayName ?? 'N/A'),
            _buildInfoRow('Email', _currentUser?.email ?? 'N/A'),
            _buildInfoRow('User ID', _currentUser?.uid ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _aiService.signOut();
              if (mounted) {
                Navigator.of(context).pop(); // Go back to previous screen
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Wellness AI 💤'),
        backgroundColor: Colors.deepPurple,
        elevation: 3,
        actions: [
          // User profile button
          IconButton(
            icon: _currentUser?.photoURL != null
                ? CircleAvatar(
                    radius: 14,
                    backgroundImage: NetworkImage(_currentUser!.photoURL!),
                  )
                : const Icon(Icons.account_circle_rounded),
            tooltip: 'Profile',
            onPressed: _showUserInfo,
          ),
          // Reset session button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Session',
            onPressed: _resetSession,
          ),
          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // User info banner
            if (_currentUser != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade50,
                      Colors.deepPurple.shade100,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Signed in as ${_currentUser!.email}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Connected',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Chat messages area
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bedtime_rounded,
                            size: 80,
                            color: Colors.deepPurple.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask me about your sleep!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['sender'] == 'user';
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(14),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Colors.deepPurpleAccent.withOpacity(0.9)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isUser
                                    ? const Radius.circular(16)
                                    : const Radius.circular(4),
                                bottomRight: isUser
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              msg['text'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: isUser ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Loading indicator
            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.deepPurpleAccent,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI is analyzing your data...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            // Message input field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: _currentUser != null && !_isLoading,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _currentUser != null
                            ? 'Ask about your sleep...'
                            : 'Please sign in first',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: Colors.deepPurpleAccent, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _currentUser != null && !_isLoading
                          ? Colors.deepPurpleAccent
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _currentUser != null && !_isLoading
                          ? _sendMessage
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
