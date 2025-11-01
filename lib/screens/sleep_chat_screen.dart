import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SleepDashboardScreen extends StatefulWidget {
  const SleepDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SleepDashboardScreen> createState() => _SleepDashboardScreenState();
}

class _SleepDashboardScreenState extends State<SleepDashboardScreen> {
  bool _loading = true;
  List<dynamic> _sleepData = [];
  double _averageSleep = 0;
  double _averageStress = 0;
  int _nightmareCount = 0;

  final String endpoint =
      'https://us-central1-clario-f60b0.cloudfunctions.net/storeSleepData';

  @override
  void initState() {
    super.initState();
    _fetchSleepData();
  }

  Future<void> _fetchSleepData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';

      final response = await http.get(Uri.parse('$endpoint?user_id=$userId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _sleepData = data;
          if (_sleepData.isNotEmpty) {
            _averageSleep = _sleepData
                    .map((e) => (e['sleep_duration_hours'] ?? 0).toDouble())
                    .reduce((a, b) => a + b) /
                _sleepData.length;

            _averageStress = _sleepData
                    .map((e) => (e['stress_level'] ?? 0).toDouble())
                    .reduce((a, b) => a + b) /
                _sleepData.length;

            _nightmareCount = _sleepData
                .where((e) => e['nightmares'] == true)
                .toList()
                .length;
          }
          _loading = false;
        });
      } else {
        throw Exception('Failed to fetch data: ${response.body}');
      }
    } catch (e) {
      print("Error fetching data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e')),
      );
      setState(() => _loading = false);
    }
  }

  Widget _buildSummaryCard(
      {required String title, required String value, required IconData icon}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.indigo, size: 36),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(fontSize: 15, color: Colors.black54)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepList() {
    if (_sleepData.isEmpty) {
      return const Center(child: Text("No sleep data found"));
    }
    return ListView.builder(
      itemCount: _sleepData.length,
      itemBuilder: (context, index) {
        final d = _sleepData[index];
        final date =
            DateFormat('MMM d, yyyy').format(DateTime.parse(d['sleep_date']));
        final duration = d['sleep_duration_hours'] ?? 0;
        final quality = d['sleep_quality'] ?? 'unknown';
        final stress = d['stress_level'] ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.bedtime, color: Colors.indigo.shade300),
            title: Text('$date - ${duration.toStringAsFixed(1)} hrs'),
            subtitle: Text('Quality: $quality | Stress: $stress'),
            trailing: Icon(
              (d['nightmares'] ?? false)
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle,
              color: (d['nightmares'] ?? false)
                  ? Colors.redAccent
                  : Colors.greenAccent.shade700,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sleep Analysis Dashboard"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  _buildSummaryCard(
                    title: 'Average Sleep Duration',
                    value: "${_averageSleep.toStringAsFixed(1)} hrs",
                    icon: Icons.timelapse,
                  ),
                  _buildSummaryCard(
                    title: 'Average Stress Level',
                    value: _averageStress.toStringAsFixed(1),
                    icon: Icons.self_improvement,
                  ),
                  _buildSummaryCard(
                    title: 'Nightmares Recorded',
                    value: '$_nightmareCount times',
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 8),
                  const Text("Recent Sleep Logs",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(child: _buildSleepList()),
                ],
              ),
            ),
    );
  }
}
