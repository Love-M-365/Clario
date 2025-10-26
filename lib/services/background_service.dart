import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'sensor_service.dart';
import 'firebase_service.dart';
import 'screen_time_service.dart';

const String hourlyCheck = "clarioHourlyCheck";

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      "1",
      hourlyCheck,
      frequency: const Duration(hours: 1),
    );
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == hourlyCheck) {
      // --- REQUIRED INITIALIZATION ---
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();

      final firebaseService = FirebaseService();
      final sensorService = SensorService();
      final screenService = ScreenTimeService();

      // Run screen time analysis (this already sends data to Cloud Function)
      await screenService.analyzeUsage();

      // Fetch sensor data (past 1 hour)
      final snapshot = await firebaseService.firestore
          .collection('sensorEvents')
          .where('timestamp',
              isGreaterThan: DateTime.now().subtract(const Duration(hours: 1)))
          .get();

      int steps = 0;
      int shakes = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'step') steps += (data['value'] as num).toInt();
        if (data['type'] == 'shake') shakes += 1;
      }

      await firebaseService.updateDailySummary(steps, shakes);

      // --- LOCAL REMINDERS ---
      if (shakes > 2) {
        await sensorService.showNotification(
          'Clario Check-In',
          'You’ve seemed restless lately. Try a short reflection.',
        );
      }
      if (steps < 2000) {
        await sensorService.showNotification(
          'Health Reminder',
          'You’ve walked only $steps steps today. A quick walk could help clear your mind!',
        );
      }

      // --- CLOUD FUNCTION INTEGRATION ---
      await _sendToCloudFunction({
        'type': 'daily_summary',
        'timestamp': DateTime.now().toIso8601String(),
        'steps': steps,
        'shakes': shakes,
      });
    }
    return Future.value(true);
  });
}

/// Uploads summary data to Cloud Function for AI processing
Future<void> _sendToCloudFunction(Map<String, dynamic> data) async {
  const String cloudFunctionUrl =
      'https://us-central1-clario-f60b0.cloudfunctions.net/processSensorData';

  try {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();

    final response = await http.post(
      Uri.parse(cloudFunctionUrl),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      print('✅ Background summary sent to Cloud Function');
    } else {
      print(
          '⚠️ Cloud Function response: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('🚨 Error sending background data: $e');
  }
}
