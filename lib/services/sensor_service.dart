import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';

class SensorService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _timer;

  int _steps = 0;
  double _shakeThreshold = 20.0;
  DateTime _lastShake = DateTime.now();

  // ---------------------- INIT ----------------------
  Future<void> init() async {
    await _initNotifications();
    await _requestUsagePermission();
    _initStepCounter();
    _initShakeDetection();
    _startScreenTimeTracking();
  }

  // ---------------------- NOTIFICATIONS ----------------------
  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _notifications.initialize(initSettings);

    // iOS/macOS permissions
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final macPlugin = _notifications.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();

    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    await macPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showNotification(String title, String body) async {
    const android = AndroidNotificationDetails(
      'clario_channel',
      'Clario Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: android),
    );
  }

  // ---------------------- STEP COUNTER ----------------------
  void _initStepCounter() {
    try {
      _stepSub = Pedometer.stepCountStream.listen((event) {
        _steps = event.steps;
        _saveStepData(_steps);
      });
    } catch (e) {
      debugPrint('Step counter error: $e');
    }
  }

  Future<void> _saveStepData(int steps) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('sensorData').doc(user.uid).set({
      'steps': steps,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (steps < 2000) {
      showNotification(
        'Time for a walk 🏃‍♀️',
        'You’ve walked only $steps steps today. A short walk can refresh your mind!',
      );
    }
  }

  // ---------------------- SHAKE DETECTION ----------------------
  void _initShakeDetection() {
    _accelSub = accelerometerEvents.listen((event) {
      double accel = event.x * event.x + event.y * event.y + event.z * event.z;
      double magnitude = accel / (9.8 * 9.8);

      if (magnitude > _shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShake).inSeconds > 5) {
          _lastShake = now;
          showNotification(
            'Are you feeling nervous? 😟',
            'We noticed some sudden movements. Maybe take a deep breath or open Clario.',
          );
          _saveShakeEvent();
        }
      }
    });
  }

  Future<void> _saveShakeEvent() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('sensorData').doc(user.uid).set({
      'lastShake': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------- USAGE STATS ----------------------
  Future<void> _requestUsagePermission() async {
    bool granted = await UsageStats.checkUsagePermission() ?? false;
    if (!granted) {
      await UsageStats.grantUsagePermission();
    }
  }

  void _startScreenTimeTracking() {
    // Run every 30 minutes
    _timer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _analyzeUsageStats(),
    );
  }

  Future<void> _analyzeUsageStats() async {
    try {
      DateTime end = DateTime.now();
      DateTime start = end.subtract(const Duration(minutes: 30));

      List<UsageInfo> usageStats = await UsageStats.queryUsageStats(start, end);

      final user = _auth.currentUser;
      if (user == null) return;

      Map<String, double> usageSummary = {};

      for (var info in usageStats) {
        final pkg = info.packageName ?? 'Unknown';
        final totalTime =
            double.tryParse(info.totalTimeInForeground ?? '0') ?? 0;

        // Convert milliseconds → minutes
        double minutes = totalTime / (1000 * 60);
        if (minutes > 0) {
          usageSummary[pkg] = (usageSummary[pkg] ?? 0) + minutes;
        }
      }

      // Store summarized usage
      await _firestore
          .collection('appUsageSummary')
          .doc(user.uid)
          .collection('sessions')
          .add({
        'usage': usageSummary,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Detect heavy app usage
      for (var entry in usageSummary.entries) {
        if (entry.value > 60 &&
            (entry.key.contains('instagram') ||
                entry.key.contains('youtube') ||
                entry.key.contains('twitter') ||
                entry.key.contains('tiktok'))) {
          showNotification(
            'Mindful moment 📱',
            'You’ve spent over ${entry.value.toInt()} minutes on ${entry.key.split(".").last}. Maybe take a short break?',
          );
        }
      }
    } catch (e) {
      debugPrint('Usage stats error: $e');
    }
  }

  // ---------------------- CLEANUP ----------------------
  void dispose() {
    _stepSub?.cancel();
    _accelSub?.cancel();
    _timer?.cancel();
  }
}
