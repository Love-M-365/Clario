import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDataProvider with ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _dailyReflections = [];
  Map<String, dynamic>? _currentMoodData;
  bool _isLoading = false;

  Map<String, dynamic>? get userData => _userData;
  List<Map<String, dynamic>> get dailyReflections => _dailyReflections;
  Map<String, dynamic>? get currentMoodData => _currentMoodData;
  bool get isLoading => _isLoading;

  Future<void> loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Load basic user data
      final userSnapshot = await _dbRef.child("users/${user.uid}").get();
      if (userSnapshot.exists && userSnapshot.value is Map) {
        _userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      }

      // Load last 10 reflections
      final reflectionsSnapshot = await _dbRef
          .child("users/${user.uid}/reflections")
          .orderByChild("timestamp")
          .limitToLast(10)
          .get();

      if (reflectionsSnapshot.exists && reflectionsSnapshot.value is Map) {
        final reflectionsMap =
            Map<String, dynamic>.from(reflectionsSnapshot.value as Map);
        _dailyReflections = reflectionsMap.entries.map((entry) {
          return {"id": entry.key, ...Map<String, dynamic>.from(entry.value)};
        }).toList()
          ..sort(
              (a, b) => (b["timestamp"] ?? "").compareTo(a["timestamp"] ?? ""));
      }

      await _loadCurrentMoodData();
    } catch (e) {
      print('Error loading user data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCurrentMoodData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final moodSnapshot =
          await _dbRef.child("users/${user.uid}/mood_data/$dateKey").get();

      if (moodSnapshot.exists && moodSnapshot.value is Map) {
        _currentMoodData = Map<String, dynamic>.from(moodSnapshot.value as Map);
      }
    } catch (e) {
      print('Error loading mood data: $e');
    }
  }

  Future<void> saveReflection(String text, String type) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final reflectionRef =
          _dbRef.child("users/${user.uid}/reflections").push();
      await reflectionRef.set({
        'text': text,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'mood_score': _calculateMoodScore(text),
      });

      await loadUserData(); // Refresh
    } catch (e) {
      print('Error saving reflection: $e');
    }
  }

  Future<void> updateMoodData(Map<String, dynamic> moodData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _dbRef.child("users/${user.uid}/mood_data/$dateKey").set({
        ...moodData,
        'date': today.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      _currentMoodData = moodData;
      notifyListeners();
    } catch (e) {
      print('Error updating mood data: $e');
    }
  }

  int _calculateMoodScore(String text) {
    final positiveWords = [
      'happy',
      'good',
      'great',
      'amazing',
      'wonderful',
      'excited',
      'grateful'
    ];
    final negativeWords = [
      'sad',
      'bad',
      'terrible',
      'awful',
      'depressed',
      'anxious',
      'worried'
    ];

    final lowerText = text.toLowerCase();
    int score = 5;

    for (String word in positiveWords) {
      if (lowerText.contains(word)) score += 1;
    }

    for (String word in negativeWords) {
      if (lowerText.contains(word)) score -= 1;
    }

    return score.clamp(1, 10);
  }

  String getMoodAvatarAsset() {
    if (_currentMoodData == null) return 'assets/images/avatar_neutral.png';

    final moodScore = _currentMoodData!['mood_score'] ?? 5;

    if (moodScore >= 8) return 'assets/images/avatar_happy.png';
    if (moodScore >= 6) return 'assets/images/avatar_content.png';
    if (moodScore >= 4) return 'assets/images/avatar_neutral.png';
    if (moodScore >= 2) return 'assets/images/avatar_sad.png';
    return 'assets/images/avatar_very_sad.png';
  }

  Color getMoodColor() {
    if (_currentMoodData == null) return Colors.grey;

    final moodScore = _currentMoodData!['mood_score'] ?? 5;

    if (moodScore >= 8) return Colors.green;
    if (moodScore >= 6) return Colors.lightGreen;
    if (moodScore >= 4) return Colors.orange;
    if (moodScore >= 2) return Colors.red;
    return Colors.deepOrange;
  }
}
