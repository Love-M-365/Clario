// lib/services/sleep_data_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class SleepDataService {
  /// ✅ Replace this with YOUR deployed Cloud Function URL
  /// Example:
  /// https://asia-south1-your-project-id.cloudfunctions.net/storeSleepData
  final String cloudFunctionUrl =
      'https://us-central1-clario-f60b0.cloudfunctions.net/storeSleepData';

  Future<void> sendSleepData({
    required DateTime bedtime,
    required DateTime wakeTime,
    required double sleepDuration,
    required String sleepQuality,
    required int stressLevel,
    required bool hadNightmares,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      final userId = user?.uid ?? 'anonymous';
      final body = {
        'user_id': userId,
        'sleep_date': DateTime.now().toIso8601String(),
        'bedtime': bedtime.toIso8601String(),
        'wake_time': wakeTime.toIso8601String(),
        'sleep_duration_hours': double.parse(sleepDuration.toStringAsFixed(2)),
        'sleep_quality': sleepQuality,
        'stress_level': stressLevel,
        'nightmares': hadNightmares,
      };

      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print('✅ Sleep data sent successfully!');
      } else {
        print('⚠️ Failed to send sleep data: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('🔥 Error sending sleep data: $e');
    }
  }
}
