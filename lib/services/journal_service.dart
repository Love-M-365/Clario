// lib/services/journal_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

/// Fetch journals from last 7 days
Future<List<Map<String, dynamic>>> fetchWeeklyJournals(String userId) async {
  final ref = FirebaseDatabase.instance.ref('users/$userId/journals');
  final snapshot = await ref.get();

  if (!snapshot.exists) return [];

  final now = DateTime.now();
  final oneWeekAgo = now.subtract(const Duration(days: 7));

  List<Map<String, dynamic>> weeklyData = [];

  for (final entry in snapshot.children) {
    final data = Map<String, dynamic>.from(entry.value as Map);
    final entryDate = DateTime.parse(data['timestamp']);
    if (entryDate.isAfter(oneWeekAgo)) {
      weeklyData.add({
        'date': entryDate,
        'mood': data['moodTag'] ?? 'neutral',
      });
    }
  }

  // Sort by date
  weeklyData.sort((a, b) => a['date'].compareTo(b['date']));
  return weeklyData;
}

/// Mood intensity scores
Map<String, int> moodScores = {
  "happy": 5,
  "calm": 4,
  "neutral": 3,
  "anxious": 2,
  "sad": 1,
  "angry": 1,
  "mixed": 3,
};

class MoodData {
  final String day;
  final int score;
  final String mood;

  MoodData(this.day, this.score, this.mood);
}

/// Convert Firebase entries to mood data
List<MoodData> mapMoodData(List<Map<String, dynamic>> weeklyData) {
  return weeklyData.map((entry) {
    final day = DateFormat('EEE').format(entry['date']); // Mon, Tue, ...
    final mood = entry['mood'];
    final score = moodScores[mood] ?? 3;
    return MoodData(day, score, mood);
  }).toList();
}
