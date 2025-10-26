import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import '../services/screen_time_service.dart';
import '../services/sensor_service.dart';
import 'package:http/http.dart' as http;

/// Debug UI to test notifications, steps, shakes and screen-time.
///
/// Add route to MaterialApp and open while signed-in to quickly validate behavior.
class DebugMonitorScreen extends StatefulWidget {
  const DebugMonitorScreen({Key? key}) : super(key: key);

  @override
  State<DebugMonitorScreen> createState() => _DebugMonitorScreenState();
}

class _DebugMonitorScreenState extends State<DebugMonitorScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _notifPlugin = FlutterLocalNotificationsPlugin();

  StreamSubscription<StepCount>? _stepSub;
  int _liveSteps = 0;
  Map<String, double> _latestUsage = {};
  DateTime? _lastShake;
  String _cloudFunctionUrl =
      'https://us-central1-YOUR_PROJECT.cloudfunctions.net/analyzeUserState'; // set your URL

  // Instances (using same services you have)
  final SensorService _sensorService = SensorService();
  final ScreenTimeService _screenTimeService = ScreenTimeService();

  // Firestore listeners
  StreamSubscription<DocumentSnapshot>? _sensorDocSub;
  StreamSubscription<QuerySnapshot>? _usageSessionSub;

  @override
  void initState() {
    super.initState();
    _initNotificationsLocal();
    _startLocalStepListener();
    _subscribeSensorDoc();
    _subscribeUsageSessions();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _sensorDocSub?.cancel();
    _usageSessionSub?.cancel();
    super.dispose();
  }

  Future<void> _initNotificationsLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _notifPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );
  }

  void _startLocalStepListener() {
    // quick local step display using pedometer package (same as SensorService)
    try {
      _stepSub = Pedometer.stepCountStream.listen((event) {
        setState(() => _liveSteps = event.steps);
      }, onError: (err) {
        debugPrint('Step stream error: $err');
      });
    } catch (e) {
      debugPrint('Start step listener failed: $e');
    }
  }

  void _subscribeSensorDoc() {
    final u = _auth.currentUser;
    if (u == null) return;
    final docRef = _firestore.collection('sensorData').doc(u.uid);
    _sensorDocSub = docRef.snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      // parse lastShake if present (serverTimestamp stored)
      if (data['lastShake'] != null) {
        final ts = data['lastShake'] as Timestamp;
        setState(() => _lastShake = ts.toDate());
      }
      if (data['steps'] != null) {
        // prefer Firestore steps if available
        final stepsVal = data['steps'];
        if (stepsVal is int)
          setState(() => _liveSteps = stepsVal);
        else if (stepsVal is double)
          setState(() => _liveSteps = stepsVal.toInt());
      }
    }, onError: (e) => debugPrint('sensorDocSub error: $e'));
  }

  void _subscribeUsageSessions() {
    final u = _auth.currentUser;
    if (u == null) return;
    final sessionsRef = _firestore
        .collection('appUsageSummary')
        .doc(u.uid)
        .collection('sessions')
        .orderBy('timestamp', descending: true)
        .limit(5);

    _usageSessionSub = sessionsRef.snapshots().listen((snap) {
      // merge the most recent session's usage map into readable map for UI
      if (snap.docs.isEmpty) {
        setState(() => _latestUsage = {});
        return;
      }
      final doc = snap.docs.first;
      final usage = <String, double>{};
      final raw = doc.data()['usage'];
      if (raw is Map) {
        raw.forEach((k, v) {
          try {
            double minutes =
                (v is num) ? v.toDouble() : double.parse(v.toString());
            usage[k.toString()] = minutes;
          } catch (_) {}
        });
      }
      setState(() => _latestUsage = usage);
    }, onError: (e) => debugPrint('usageSessionSub error: $e'));
  }

  Future<void> _triggerLocalNotification() async {
    const android = AndroidNotificationDetails('debug_channel', 'Debug',
        importance: Importance.high, priority: Priority.high);
    final details = NotificationDetails(android: android);
    await _notifPlugin.show(1001, 'Clario (test)',
        'This is a test notification from Clario debug screen', details);
  }

  Future<void> _simulateShake() async {
    final u = _auth.currentUser;
    if (u == null) return;
    // Write lastShake to Firestore (this mimics SensorService behavior)
    await _firestore.collection('sensorData').doc(u.uid).set({
      'lastShake': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Immediately show a notification to simulate the real flow
    await _sensorService.showNotification(
        'Are you feeling nervous? (simulated)',
        'We detected a simulated shake. Try a breathing exercise.');
  }

  Future<void> _runScreenTimeCheckNow() async {
    // Ensure the plugin has permission then analyze usage (the ScreenTimeService handles permission)
    await _screenTimeService.requestPermissions();
    await _screenTimeService.analyzeUsage();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Screen time check completed (see logs / Firestore).')));
  }

  Future<void> _callAnalyzeCloudFunction() async {
    final u = _auth.currentUser;
    if (u == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No user logged in')));
      return;
    }
    try {
      final token = await u.getIdToken();
      final resp = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': u.uid}),
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final msg = body['message'] ?? body['aiMessage'] ?? 'OK';
        // show the message as notification too
        await _notifPlugin.show(
            2001,
            'Clario Insight',
            msg,
            const NotificationDetails(
                android: AndroidNotificationDetails('debug_channel', 'Debug',
                    importance: Importance.high, priority: Priority.high)));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cloud function success: $msg')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cloud error: ${resp.statusCode}')));
      }
    } catch (e) {
      debugPrint('callAnalyze error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calling Cloud Function: $e')));
    }
  }

  Future<void> _resetTestData() async {
    final u = _auth.currentUser;
    if (u == null) return;
    // remove lastShake and steps value (testing only)
    await _firestore.collection('sensorData').doc(u.uid).set({
      'lastShake': null,
      'steps': 0,
    }, SetOptions(merge: true));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Test data reset')));
  }

  Widget _buildUsageList() {
    if (_latestUsage.isEmpty)
      return const Text('No recent usage sessions found');
    final entries = _latestUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map((e) => Text(
              '${e.key.split('.').last}: ${e.value.toStringAsFixed(1)} min'))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid ?? 'not-signed-in';
    return Scaffold(
      appBar: AppBar(title: const Text('Clario — Debug Monitor')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('User: $uid',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: const Text('Live steps'),
                subtitle: Text('$_liveSteps steps'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    // force-read from Firestore doc if present
                    final u = _auth.currentUser;
                    if (u != null) {
                      final snap = await _firestore
                          .collection('sensorData')
                          .doc(u.uid)
                          .get();
                      if (snap.exists && snap.data()?['steps'] != null) {
                        setState(() {
                          final s = snap.data()!['steps'];
                          _liveSteps = (s is int)
                              ? s
                              : (s is double)
                                  ? s.toInt()
                                  : _liveSteps;
                        });
                      }
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: const Text('Last shake event'),
                subtitle: Text(_lastShake?.toLocal().toString() ??
                    'No shake detected yet'),
                trailing: ElevatedButton(
                  onPressed: _simulateShake,
                  child: const Text('Simulate Shake'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Latest screen usage (most recent session)'),
                      const SizedBox(height: 8),
                      _buildUsageList(),
                      const SizedBox(height: 10),
                      Row(children: [
                        ElevatedButton(
                          onPressed: _runScreenTimeCheckNow,
                          child: const Text('Run screen-time check now'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            await _screenTimeService.requestPermissions();
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Requested usage permission (open settings if needed)')));
                          },
                          child: const Text('Request Usage Permission'),
                        ),
                      ]),
                    ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Test & Cloud'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.notifications),
                        label: const Text('Trigger local test notification'),
                        onPressed: _triggerLocalNotification,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cloud),
                        label: const Text('Call analyzeUserState (cloud)'),
                        onPressed: _callAnalyzeCloudFunction,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Reset test sensor data'),
                        onPressed: _resetTestData,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                      ),
                    ]),
              ),
            ),
            const SizedBox(height: 16),
            Text(
                'Tip: open Android Settings → Usage access to grant permission if needed.',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
      ),
    );
  }
}
