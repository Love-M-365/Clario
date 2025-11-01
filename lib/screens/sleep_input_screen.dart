import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// ✅ Two different endpoints for your projects
const String kRealtimeEndpoint =
    'https://us-central1-clario-4558.cloudfunctions.net/storeSleepData';
const String kCloudSqlEndpoint =
    'https://us-central1-clario-f60b0.cloudfunctions.net/storeSleepData';

class SleepInputScreen extends StatefulWidget {
  const SleepInputScreen({Key? key}) : super(key: key);

  @override
  State<SleepInputScreen> createState() => _SleepInputScreenState();
}

class _SleepInputScreenState extends State<SleepInputScreen> {
  DateTime? _bedDate;
  TimeOfDay? _bedTime;
  DateTime? _wakeDate;
  TimeOfDay? _wakeTime;

  String _sleepQuality = 'good';
  double _stressLevel = 5.0;
  bool _hadNightmares = false;
  bool _loading = false;

  final _formKey = GlobalKey<FormState>();

  Future<DateTime?> _pickDate(BuildContext ctx, DateTime initial) async {
    return await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  Future<TimeOfDay?> _pickTime(BuildContext ctx, TimeOfDay initial) async {
    return await showTimePicker(context: ctx, initialTime: initial);
  }

  DateTime? _combine(DateTime? d, TimeOfDay? t) {
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  double _computeDurationHours(DateTime bedtime, DateTime wakeTime) {
    if (wakeTime.isBefore(bedtime)) {
      wakeTime = wakeTime.add(const Duration(days: 1));
    }
    return wakeTime.difference(bedtime).inMinutes / 60.0;
  }

  /// 🔹 This method sends the same data to BOTH endpoints
  Future<void> _submitToBothDatabases() async {
    final bedtime = _combine(_bedDate, _bedTime);
    final wakeTime = _combine(_wakeDate, _wakeTime);

    if (bedtime == null || wakeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick both bedtime and wake time')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final durationHours = _computeDurationHours(bedtime, wakeTime);
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';

      final body = {
        'user_id': userId,
        'sleep_date': DateTime.now().toIso8601String(),
        'bedtime': bedtime.toIso8601String(),
        'wake_time': wakeTime.toIso8601String(),
        'sleep_duration_hours': double.parse(durationHours.toStringAsFixed(2)),
        'sleep_quality': _sleepQuality,
        'stress_level': _stressLevel.toInt(),
        'nightmares': _hadNightmares,
      };

      /// ✅ Send requests to both projects in parallel
      final responses = await Future.wait([
        http.post(
          Uri.parse(kRealtimeEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        http.post(
          Uri.parse(kCloudSqlEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      ]);

      /// ✅ Check if both succeeded
      if (responses.every((r) => r.statusCode == 200)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('✅ Sleep data sent to both databases successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ One or both requests failed:\n'
              'Realtime: ${responses[0].statusCode}, Cloud SQL: ${responses[1].statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final defaultTime = const TimeOfDay(hour: 23, minute: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Sleep')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ListTile(
                title: const Text('Bed Date'),
                subtitle: Text(_bedDate == null
                    ? 'Not set'
                    : _bedDate!.toLocal().toString().split(' ')[0]),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await _pickDate(context, today);
                    if (picked != null) setState(() => _bedDate = picked);
                  },
                ),
              ),
              ListTile(
                title: const Text('Bed Time'),
                subtitle: Text(
                    _bedTime == null ? 'Not set' : _bedTime!.format(context)),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final picked = await _pickTime(context, defaultTime);
                    if (picked != null) setState(() => _bedTime = picked);
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Wake Date'),
                subtitle: Text(_wakeDate == null
                    ? 'Not set'
                    : _wakeDate!.toLocal().toString().split(' ')[0]),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: () async {
                    final picked = await _pickDate(context, today);
                    if (picked != null) setState(() => _wakeDate = picked);
                  },
                ),
              ),
              ListTile(
                title: const Text('Wake Time'),
                subtitle: Text(
                    _wakeTime == null ? 'Not set' : _wakeTime!.format(context)),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time_outlined),
                  onPressed: () async {
                    final picked = await _pickTime(
                        context, const TimeOfDay(hour: 7, minute: 0));
                    if (picked != null) setState(() => _wakeTime = picked);
                  },
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _sleepQuality,
                decoration: const InputDecoration(labelText: 'Sleep Quality'),
                items: const [
                  DropdownMenuItem(value: 'good', child: Text('Good')),
                  DropdownMenuItem(value: 'fair', child: Text('Fair')),
                  DropdownMenuItem(value: 'poor', child: Text('Poor')),
                ],
                onChanged: (v) => setState(() => _sleepQuality = v ?? 'good'),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stress Level (0 = low, 10 = high)'),
                  Slider(
                    min: 0,
                    max: 10,
                    divisions: 10,
                    value: _stressLevel,
                    label: _stressLevel.toInt().toString(),
                    onChanged: (v) => setState(() => _stressLevel = v),
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('Had nightmares'),
                value: _hadNightmares,
                onChanged: (v) => setState(() => _hadNightmares = v),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loading ? null : _submitToBothDatabases,
                icon: _loading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Icon(Icons.cloud_upload),
                label: Text(_loading ? 'Sending...' : 'Submit Sleep Data'),
              ),
              const SizedBox(height: 20),
              Builder(builder: (ctx) {
                final bedtime = _combine(_bedDate, _bedTime);
                final wakeTime = _combine(_wakeDate, _wakeTime);
                if (bedtime != null && wakeTime != null) {
                  final d = _computeDurationHours(bedtime, wakeTime);
                  return Text(
                      '🕒 Estimated sleep duration: ${d.toStringAsFixed(2)} hours');
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }
}
