// lib/screens/weekly_mood_section.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/journal_service.dart';
import '../widgets/weekly_mood_chart.dart';

class WeeklyMoodSection extends StatefulWidget {
  const WeeklyMoodSection({super.key});

  @override
  State<WeeklyMoodSection> createState() => _WeeklyMoodSectionState();
}

class _WeeklyMoodSectionState extends State<WeeklyMoodSection> {
  List<MoodData> _moodTrend = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadMoodData();
  }

  Future<void> loadMoodData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final weeklyEntries = await fetchWeeklyJournals(user.uid);
    final mapped = mapMoodData(weeklyEntries);

    setState(() {
      _moodTrend = mapped;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_moodTrend.isEmpty) {
      return const Center(child: Text("No mood entries for this week 😶"));
    }

    return WeeklyMoodChart(moodTrend: _moodTrend);
  }
}
