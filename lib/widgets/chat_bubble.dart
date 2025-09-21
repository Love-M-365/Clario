import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isBlueChair; // <-- new parameter

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isBlueChair = false, // default to false
  });

  @override
  Widget build(BuildContext context) {
    Color bubbleColor;
    Color textColor = Colors.white;

    if (isBlueChair) {
      bubbleColor = Colors.blueAccent.shade700;
    } else if (isUser) {
      bubbleColor = Colors.green.shade700;
    } else {
      bubbleColor = Colors.grey.shade800;
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor, fontSize: 16),
        ),
      ),
    );
  }
}
