import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NotificationPanelScreen extends StatelessWidget {
  const NotificationPanelScreen({super.key});

  final List<Map<String, dynamic>> notifications = const [
    {
      'title': 'Daily Reflection Reminder',
      'body': 'Take a moment to reflect on your day and track your mood.',
      'timestamp': '2025-09-17T10:00:00Z',
      'isRead': false,
    },
    {
      'title': 'New Tool: Empty Chair Mode',
      'body':
          'Learn how to process complex emotions with our new Empty Chair Mode.',
      'timestamp': '2025-09-16T15:30:00Z',
      'isRead': true,
    },
    {
      'title': 'AI Chat Response',
      'body': 'Your AI therapist has a new insight for you.',
      'timestamp': '2025-09-16T09:00:00Z',
      'isRead': false,
    },
    {
      'title': 'Sleep Analysis Ready',
      'body': 'Your sleep data for last night is ready. View your report.',
      'timestamp': '2025-09-15T08:00:00Z',
      'isRead': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // This is the key fix
      backgroundColor: Colors.transparent, // And this one
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(context, notification);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, Map<String, dynamic> notification) {
    final bool isRead = notification['isRead'];
    final DateTime timestamp = DateTime.parse(notification['timestamp']);
    final String formattedTime = DateFormat('MMM d, h:mm a').format(timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: isRead
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isRead
              ? Colors.white.withOpacity(0.05)
              : Colors.blue.withOpacity(0.5),
          width: 1.0,
        ),
      ),
      child: ListTile(
        leading: Icon(
          isRead ? Icons.notifications_none : Icons.notifications_active,
          color: isRead ? Colors.white.withOpacity(0.6) : Colors.white,
        ),
        title: Text(
          notification['title'],
          style: TextStyle(
            color: Colors.white,
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(
          notification['body'],
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        trailing: Text(
          formattedTime,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        onTap: () {
          // TODO: Add logic to mark as read and navigate to relevant screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tapped on: ${notification['title']}')),
          );
        },
      ),
    );
  }
}
