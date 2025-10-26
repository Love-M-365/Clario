import 'dart:convert';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

class ScreenTimeService {
  final _firebaseService = FirebaseService();
  final _notifications = FlutterLocalNotificationsPlugin();

  // Cloud Function URL
  final String _cloudFunctionUrl =
      'https://us-central1-clario-f60b0.cloudfunctions.net/processSensorData';

  /// Requests permission to access app usage stats (Android only)
  Future<void> requestPermissions() async {
    try {
      bool? hasPermission = await UsageStats.checkUsagePermission();
      if (hasPermission == null || hasPermission == false) {
        await UsageStats.grantUsagePermission();
      }
    } catch (e) {
      print("Screen time permission error: $e");
    }
  }

  /// Analyzes app usage and logs to Firebase + sends reminders + uploads to Cloud Function
  Future<void> analyzeUsage() async {
    try {
      // Ensure permission
      bool? hasPermission = await UsageStats.checkUsagePermission();
      if (hasPermission == null || hasPermission == false) {
        await UsageStats.grantUsagePermission();
        return;
      }

      // Collect last 1 hour of app usage
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(hours: 1));

      List<UsageInfo> usageStats =
          await UsageStats.queryUsageStats(startDate, endDate);

      for (var info in usageStats) {
        String pkg = info.packageName ?? 'Unknown';
        double minutes =
            (double.tryParse(info.totalTimeInForeground ?? '0') ?? 0) /
                (1000 * 60);

        // Focus only on distracting apps
        if (pkg.contains('instagram') ||
            pkg.contains('youtube') ||
            pkg.contains('tiktok') ||
            pkg.contains('twitter') ||
            pkg.contains('facebook')) {
          if (minutes > 0) {
            // Log locally to Firestore (optional)
            await _firebaseService.logAppUsage(pkg, minutes);

            // Send to Cloud Function
            await _sendToCloudFunction({
              'type': 'screen_time',
              'app': pkg,
              'duration_minutes': minutes,
              'timestamp': DateTime.now().toIso8601String(),
            });

            // Notify user if over limit
            if (minutes > 30) {
              await _showNotification(
                'Mindful Reminder',
                'You’ve spent ${minutes.toStringAsFixed(0)} mins on ${pkg.split('.').last}. Maybe take a break?',
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error analyzing screen time: $e');
    }
  }

  /// Sends data to your Cloud Function securely
  Future<void> _sendToCloudFunction(Map<String, dynamic> data) async {
    try {
      String? token = await FirebaseAuth.instance.currentUser?.getIdToken();

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        print('✅ Data sent to Cloud Function');
      } else {
        print(
            '⚠️ Cloud Function error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('🚨 Failed to send data to Cloud Function: $e');
    }
  }

  /// Shows a local notification on the device
  Future<void> _showNotification(String title, String body) async {
    const android = AndroidNotificationDetails(
      'clario_screen_channel',
      'Screen Time Alerts',
      channelDescription: 'Notifications for app usage reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const details = NotificationDetails(android: android);
    await _notifications.show(1, title, body, details);
  }
}
