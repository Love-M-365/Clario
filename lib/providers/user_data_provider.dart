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

  // New properties for avatar
  String? _selectedAvatarId;
  String _currentEmotion = 'neutral'; // AI-driven emotion state

  Map<String, dynamic>? get userData => _userData;
  List<Map<String, dynamic>> get dailyReflections => _dailyReflections;
  Map<String, dynamic>? get currentMoodData => _currentMoodData;
  bool get isLoading => _isLoading;
  String? get selectedAvatarId => _selectedAvatarId;
  String get currentEmotion => _currentEmotion;

  Future<void> loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final userSnapshot = await _dbRef.child("users/${user.uid}").get();
      if (userSnapshot.exists && userSnapshot.value is Map) {
        _userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        // Load the selected avatar ID from the database
        _selectedAvatarId = _userData?['selectedAvatarId'];
      }

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
          ..sort((a, b) {
            final aTime =
                DateTime.tryParse(a["timestamp"] ?? "") ?? DateTime(1970);
            final bTime =
                DateTime.tryParse(b["timestamp"] ?? "") ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });
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
        // Set the emotion based on the mood score
        setCurrentEmotionFromScore(_currentMoodData!['mood_score'] ?? 5);
      }
    } catch (e) {
      print('Error loading mood data: $e');
    }
  }

  // New method to set the avatar and update the database
  Future<void> setSelectedAvatar(String avatarId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _selectedAvatarId = avatarId;
      await _dbRef.child("users/${user.uid}/selectedAvatarId").set(avatarId);
      notifyListeners();
    } catch (e) {
      print('Error setting avatar: $e');
    }
  }

  // Method to set the AI-driven emotion
  void setCurrentEmotionFromScore(int moodScore) {
    if (moodScore >= 8) {
      _currentEmotion = 'happy';
    } else if (moodScore >= 6) {
      _currentEmotion = 'content';
    } else if (moodScore >= 4) {
      _currentEmotion = 'neutral';
    } else if (moodScore >= 2) {
      _currentEmotion = 'sad';
    } else {
      _currentEmotion = 'very_sad';
    }
    notifyListeners();
  }

  Future<void> saveReflection(String text, String type) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Generate a new push key under user's reflections
      final reflectionRef =
          _dbRef.child("users/${user.uid}/reflections").push();

      // Set the reflection data
      await reflectionRef.set({
        'text': text,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'mood_score': _calculateMoodScore(text),
      });

      // Refresh local state
      await loadUserData(); // This reloads the latest reflections
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
      setCurrentEmotionFromScore(moodData['mood_score'] ?? 5);
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

  // Refactored to use the selected avatar and current emotion
  String getMoodAvatarAsset() {
    if (_selectedAvatarId == null) {
      // Use a default neutral avatar if none is selected
      return 'assets/images/default_neutral_avatar.png';
    }

    // Example: assets/avatars/avatar_1_happy.png
    return 'assets/avatars/${_selectedAvatarId!.split('/').last.split('.').first}_$_currentEmotion.png';
  }

  Future<void> addEmptyChairMember(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // This will create a list of previous chair members
      final newMemberRef =
          _dbRef.child("users/${user.uid}/emptyChairMembers").push();
      await newMemberRef.set({
        'name': name,
        'createdAt': DateTime.now().toIso8601String(),
      });
      notifyListeners();
    } catch (e) {
      print('Error saving empty chair member: $e');
    }
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
