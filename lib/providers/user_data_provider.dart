// lib/providers/user_data_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // For Completer
import '../../models/journal_entry.dart';
import '../../models/clario_user.dart'; // Make sure this path is correct

// Network and Data Handling Imports
import 'dart:convert'; // For base64Decode
import 'dart:typed_data'; // For Uint8List
import 'package:firebase_storage/firebase_storage.dart'; // For image upload
import 'package:dio/dio.dart'; // For HTTP requests to Cloud Function
import 'package:http/http.dart' as http; // For Relations API calls

// --- User Data Model ---
// (Ensure this class definition is in 'models/clario_user.dart')

class ClarioUser {
  final String uid;
  final String name;
  final int age;
  final String? selectedAvatarId; // Potentially legacy
  final String? baseAvatarPrompt;
  final Map<String, String>?
      avatarUrls; // Stores {'happy': 'url', 'sad': 'url'}

  ClarioUser({
    required this.uid,
    required this.name,
    required this.age,
    this.selectedAvatarId,
    this.avatarUrls,
    this.baseAvatarPrompt,
  });

  factory ClarioUser.fromMap(String uid, Map<String, dynamic> map) {
    // Safely parse the avatarUrls map
    Map<String, String>? urls;
    if (map.containsKey('avatarUrls') && map['avatarUrls'] is Map) {
      // Ensure keys and values are Strings
      try {
        urls = Map<String, String>.from(map['avatarUrls']);
      } catch (e) {
        print("Warning: Could not parse avatarUrls map: $e");
        urls = null;
      }
    }

    return ClarioUser(
      uid: uid,
      name: map['name'] as String? ?? 'No Name',
      age: map['age'] as int? ?? 18,
      selectedAvatarId: map['selectedAvatarId'] as String?,
      avatarUrls: urls,
      baseAvatarPrompt: map['baseAvatarPrompt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'selectedAvatarId': selectedAvatarId,
      'avatarUrls': avatarUrls,
      'baseAvatarPrompt': baseAvatarPrompt,
    };
  }
}

// --- Relation Data Model ---
class Relation {
  final String name;
  final String sentiment;
  final int timesMentioned;
  final String lastMentioned;

  Relation({
    required this.name,
    required this.sentiment,
    required this.timesMentioned,
    required this.lastMentioned,
  });

  factory Relation.fromJson(Map<String, dynamic> json) {
    return Relation(
      name: json['name'] as String? ?? 'Unknown',
      sentiment: json['sentiment'] as String? ?? 'Neutral',
      timesMentioned: json['times_mentioned'] as int? ?? 0,
      lastMentioned: json['last_mentioned'] as String? ?? '',
    );
  }
}

// --- Main Data Provider ---
class UserDataProvider with ChangeNotifier {
  // Firebase Service Instances
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // HTTP Client
  final Dio _dio = Dio();

  // --- State Properties ---
  ClarioUser? _user;
  // TODO: Consolidate _dailyReflections and _journalEntries if possible.
  List<Map<String, dynamic>> _dailyReflections =
      []; // Legacy reflection format?
  List<JournalEntry> _journalEntries = []; // Parsed journal entries
  Map<String, dynamic>? _currentMoodData;
  String _currentEmotion = 'neutral'; // Emotion string for avatar
  Map<String, String> _avatarUrls = {}; // Cache for emotion->URL
  String? _baseAvatarPrompt; // User-defined base description
  List<Relation> _relations = []; // State for Relations feature
  bool _isRelationsLoading = false; // Loading state for Relations

  bool _isLoading = false; // General loading state
  String? _errorMessage; // Stores last error message

  // --- Getters ---
  ClarioUser? get user => _user;
  List<JournalEntry> get journalEntries => _journalEntries;
  List<Map<String, dynamic>> get dailyReflections => _dailyReflections;
  Map<String, dynamic>? get currentMoodData => _currentMoodData;
  String get currentEmotion => _currentEmotion;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get baseAvatarPrompt => _baseAvatarPrompt;
  List<Relation> get relations => _relations;
  bool get isRelationsLoading => _isRelationsLoading;

  /// Returns the URL for the avatar matching the current emotion.
  /// Falls back to 'neutral' or a local placeholder asset if not found.
  String get currentAvatarUrl {
    // Prioritize current emotion, then neutral, then fallback asset
    return _avatarUrls[_currentEmotion] ??
        _avatarUrls['neutral'] ??
        'assets/avatars/default_neutral.jpg'; // Ensure this matches your asset file
  }

  // --- Core Data Fetching ---

  /// Fetches essential user data concurrently.
  Future<void> fetchUserData() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _errorMessage = "User not logged in.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Notify UI that loading has started

    try {
      await Future.wait([
        _fetchUserProfile(firebaseUser.uid),
        _fetchReflections(firebaseUser.uid),
        _fetchCurrentMood(firebaseUser.uid),
        // fetchRelations(), // Optionally fetch relations on initial load
      ]);
    } catch (e) {
      _errorMessage = 'Failed to load dashboard data: ${e.toString()}';
      print("ERROR: $_errorMessage");
      // Keep existing data, but show error
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify UI that loading is complete (success or fail)
    }
  }

  /// Fetches all journal entries for the history screen.
  Future<void> fetchAllJournals() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      print("WARN: fetchAllJournals called without logged-in user.");
      return; // Exit if no user
    }

    _isLoading = true; // Use main loading state or a specific one
    notifyListeners();

    try {
      final dbPath = "users/${firebaseUser.uid}/journals";
      final snapshot = await _dbRef.child(dbPath).get();

      if (snapshot.exists && snapshot.value != null) {
        // Handle potential Map<Object?, Object?>
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _journalEntries = data.entries
            .map((entry) {
              try {
                return JournalEntry.fromMap(
                  entry.key, // Firebase push ID
                  Map<String, dynamic>.from(entry.value), // Journal data
                );
              } catch (e) {
                print("ERROR parsing journal entry ${entry.key}: $e");
                return null; // Return null for invalid entries
              }
            })
            .whereType<JournalEntry>()
            .toList(); // Filter out nulls

        // Sort entries by timestamp, newest first
        _journalEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        print("INFO: Fetched ${_journalEntries.length} journal entries.");
      } else {
        _journalEntries = [];
        print("INFO: No journal entries found for user ${firebaseUser.uid}.");
      }
    } catch (e) {
      print("ERROR fetching all journals: $e");
      _journalEntries = []; // Clear local list on error
      _errorMessage = "Could not load journal history.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches relation data from the external API.
  Future<void> fetchRelations() async {
    final idToken = await _getIdToken();
    if (idToken == null) {
      print('WARN: Skipping relations fetch. User not authenticated.');
      _relations = [];
      _isRelationsLoading = false;
      notifyListeners();
      return;
    }

    _isRelationsLoading = true;
    notifyListeners();

    // TODO: Move API URL to a configuration file/environment variable
    const String relationsApiUrl =
        'https://clario-ai-1045577266956.us-central1.run.app';

    try {
      final response = await http.get(
        Uri.parse('$relationsApiUrl/relations'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      print('DEBUG: Relations API call status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic data =
            json.decode(response.body); // Use dynamic type first

        if (data is Map<String, dynamic> && data['relations'] is List) {
          final List relationsList = data['relations'];
          _relations = relationsList
              // Add error handling during parsing
              .map((item) {
                try {
                  return Relation.fromJson(item as Map<String, dynamic>);
                } catch (e) {
                  print("ERROR parsing relation item: $item, Error: $e");
                  return null;
                }
              })
              .whereType<Relation>() // Filter out nulls
              .toList();
          print('DEBUG: Successfully parsed ${_relations.length} relations.');
        } else {
          _relations = [];
          print(
              'ERROR: Relations API response format incorrect. Expected Map with "relations" list. Body: ${response.body}');
        }
      } else {
        print(
            'ERROR: Failed to load relations. Status: ${response.statusCode}, Response: ${response.body}');
        _relations = [];
        _errorMessage = "Could not load relationships.";
      }
    } catch (e) {
      print('EXCEPTION: Error fetching relations: $e');
      _relations = [];
      _errorMessage = "Error connecting to relationships service.";
    } finally {
      _isRelationsLoading = false;
      notifyListeners();
    }
  }

  // --- Private Helper Methods for Fetching ---

  /// Fetches user profile, including avatar URLs and base prompt from RTDB.
  Future<void> _fetchUserProfile(String uid) async {
    try {
      final userSnapshot = await _dbRef.child("users/$uid").get();
      if (userSnapshot.exists && userSnapshot.value is Map) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        _user = ClarioUser.fromMap(
            uid, userData); // Uses updated ClarioUser factory

        // Update local state directly from the parsed user object
        _avatarUrls = _user?.avatarUrls ?? {};
        _baseAvatarPrompt = _user?.baseAvatarPrompt;
        print("INFO: User profile loaded for $uid.");
      } else {
        print("WARN: User profile not found for UID: $uid");
        _user = null; // Ensure user is null if profile doesn't exist
        _avatarUrls = {};
        _baseAvatarPrompt = null;
      }
    } catch (e) {
      print("ERROR fetching user profile for $uid: $e");
      // Reset state on error
      _user = null;
      _avatarUrls = {};
      _baseAvatarPrompt = null;
      // Propagate error if needed by fetchUserData
      throw Exception("Could not fetch user profile: ${e.toString()}");
    }
  }

  /// Fetches the last 10 reflections (legacy format?).
  Future<void> _fetchReflections(String uid) async {
    // ... (Existing code is okay, keeping try-catch) ...
    try {
      final snapshot = await _dbRef
          .child("users/$uid/reflections")
          .orderByChild("timestamp") // Requires .indexOn rule in RTDB
          .limitToLast(10)
          .get();

      if (snapshot.exists && snapshot.value is Map) {
        final reflectionsMap = Map<String, dynamic>.from(snapshot.value as Map);
        _dailyReflections = reflectionsMap.entries.map((entry) {
          return {"id": entry.key, ...Map<String, dynamic>.from(entry.value)};
        }).toList()
          ..sort(
              (a, b) => (b["timestamp"] ?? "").compareTo(a["timestamp"] ?? ""));
      } else {
        _dailyReflections = [];
      }
    } catch (e) {
      print("ERROR fetching reflections for $uid: $e");
      _dailyReflections = [];
      if (e.toString().contains('index-not-defined')) {
        print(
            " HINT: Add '.indexOn': ['timestamp'] to the rules for '/users/\$uid/reflections'");
      }
      // Don't throw here to allow other fetches in Future.wait to complete
    }
  }

  /// Fetches mood data for the current day.
  Future<void> _fetchCurrentMood(String uid) async {
    final dateKey = _getTodayDateKey();
    try {
      final moodSnapshot =
          await _dbRef.child("users/$uid/mood_data/$dateKey").get();

      if (moodSnapshot.exists && moodSnapshot.value is Map) {
        _currentMoodData = Map<String, dynamic>.from(moodSnapshot.value as Map);
        // Use safe casting and default value
        setCurrentEmotionFromScore(
            _currentMoodData!['mood_score'] as int? ?? 5);
      } else {
        _currentMoodData = null;
        _currentEmotion = 'neutral'; // Reset emotion if no mood data for today
      }
    } catch (e) {
      print("ERROR fetching current mood for $uid on $dateKey: $e");
      _currentMoodData = null;
      _currentEmotion = 'neutral'; // Reset on error
      // Don't throw here
    }
    // Need to notify if emotion changed even if called within Future.wait
    // setCurrentEmotionFromScore handles notifyListeners internally
  }

  // --- Data Mutation Methods ---

  /// Updates the selected avatar ID in the database (legacy?).
  // TODO: Determine if `selectedAvatarId` is still needed or can be removed.
  Future<void> setSelectedAvatar(String avatarId) async {
    // ... (Existing code is okay, added null checks) ...
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || _user == null) {
      print("WARN: setSelectedAvatar called when user is null.");
      return;
    }
    _user = ClarioUser(
      uid: _user!.uid,
      name: _user!.name,
      age: _user!.age,
      selectedAvatarId: avatarId,
      avatarUrls: _user!.avatarUrls,
      baseAvatarPrompt: _user!.baseAvatarPrompt,
    );
    notifyListeners();
    try {
      await _dbRef
          .child("users/${firebaseUser.uid}/selectedAvatarId")
          .set(avatarId);
    } catch (e) {
      print('ERROR setting selected avatar ID: $e');
    }
  }

  /// Saves a new reflection entry (legacy format?).
  // TODO: Consider migrating reflections to use JournalEntry model if consistent.
  Future<void> saveReflection(String text, String type) async {
    // ... (Existing code is okay, added null check) ...
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;
    final newReflection = {
      'text': text,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      'mood_score': _calculateMoodScore(text),
    };
    try {
      final reflectionRef =
          _dbRef.child("users/${firebaseUser.uid}/reflections").push();
      await reflectionRef.set(newReflection);
      final newEntryWithId = {"id": reflectionRef.key!, ...newReflection};
      _dailyReflections.insert(0, newEntryWithId);
      if (_dailyReflections.length > 10) _dailyReflections.removeLast();
      notifyListeners();
    } catch (e) {
      print('ERROR saving reflection: $e');
    }
  }

  /// Updates or creates mood data for the current day.
  Future<void> updateMoodData(Map<String, dynamic> moodData) async {
    // ... (Existing code is okay, added null check) ...
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;
    final dateKey = _getTodayDateKey();
    final score = moodData['mood_score'] as int? ?? 5;
    final dataToSave = {
      ...moodData,
      'mood_score': score,
      'date': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      await _dbRef
          .child("users/${firebaseUser.uid}/mood_data/$dateKey")
          .set(dataToSave);
      _currentMoodData = dataToSave;
      setCurrentEmotionFromScore(score); // This calls notifyListeners
    } catch (e) {
      print('ERROR updating mood data: $e');
    }
  }

  /// Saves the base avatar prompt and triggers generation of emotion variants.
  Future<void> saveBasePromptAndGenerateAvatars(String newPrompt) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in.");
    if (newPrompt.trim().isEmpty)
      throw Exception("Avatar prompt cannot be empty.");

    _isLoading = true; // Indicate loading specifically for this operation
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Save the new base prompt to RTDB
      await _dbRef
          .child("users/${user.uid}/baseAvatarPrompt")
          .set(newPrompt.trim());
      print("INFO: Base avatar prompt saved for user ${user.uid}.");

      // 2. Update local state immediately
      _baseAvatarPrompt = newPrompt.trim();
      if (_user != null) {
        _user = ClarioUser(
          uid: _user!.uid, name: _user!.name, age: _user!.age,
          selectedAvatarId: _user!.selectedAvatarId,
          avatarUrls: _user!.avatarUrls,
          baseAvatarPrompt: _baseAvatarPrompt, // Update the model instance
        );
      }
      // Don't notify yet, wait for generation to finish or fail

      // 3. Trigger the generation (this handles its own loading/notify)
      await generateAndSaveAvatars(
          _baseAvatarPrompt!); // Use the confirmed non-null prompt
      // Success message is handled within generateAndSaveAvatars or UI calling this
    } catch (e) {
      final errorMsg =
          "Failed to save prompt/generate avatars: ${e.toString()}";
      print("ERROR: $errorMsg");
      _errorMessage = errorMsg;
      _isLoading = false; // Turn off loading on error
      notifyListeners(); // Notify UI about the error
      throw Exception(errorMsg); // Re-throw for UI handling
    } finally {
      // Ensure loading is turned off even if generateAndSaveAvatars has its own finally
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Generates avatars ('neutral', 'happy', 'sad'), saves to Storage, updates RTDB URLs.
  Future<void> generateAndSaveAvatars(String basePrompt) async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception("Cannot generate avatars: No user logged in");
    // Base prompt emptiness already checked by caller

    final idToken = await _getIdToken();
    if (idToken == null)
      throw Exception("Cannot generate avatars: Failed to get auth token");

    // !!! Ensure this URL is correct !!!
    final functionUrl = "https://generateavatar-6q2ddbi5pa-uc.a.run.app";
    if (functionUrl.contains("YOUR-URL")) {
      throw Exception(
          "Configuration Error: generateAvatar Cloud Function URL is not set!");
    }

    final emotions = ['neutral', 'happy', 'sad']; // Target emotions
    Map<String, String> newAvatarUrls = {};

    // Use a separate loading state or reuse _isLoading
    _isLoading = true;
    _errorMessage = null; // Clear previous errors
    notifyListeners();

    try {
      for (String emotion in emotions) {
        final prompt =
            "$basePrompt, $emotion expression, 3D avatar, simple background";
        print("INFO: Generating avatar for '$emotion'...");

        final response = await _dio.post(
          functionUrl,
          data: {'prompt': prompt},
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            sendTimeout: const Duration(seconds: 60),
            receiveTimeout:
                const Duration(seconds: 120), // Allow 2 mins for generation
            validateStatus: (status) =>
                status != null &&
                status < 500, // Handle 4xx as errors but not exceptions
          ),
        );

        if (response.statusCode != 200 ||
            response.data == null ||
            response.data is! Map ||
            response.data['image_base64'] == null ||
            response.data['image_base64'] is! String) {
          String serverErrorMsg = "Unknown server error";
          if (response.data is Map && response.data['error'] != null) {
            serverErrorMsg = response.data['error'];
          } else if (response.statusMessage != null) {
            serverErrorMsg = response.statusMessage!;
          }
          throw Exception(
              "Failed to generate '$emotion' avatar. Status: ${response.statusCode}. Server: $serverErrorMsg");
        }

        final base64String = response.data['image_base64'];
        final Uint8List imageBytes = base64Decode(base64String);
        final storagePath = 'avatars/${user.uid}/${emotion}.png';
        final storageRef = _storage.ref(storagePath);
        print("INFO: Uploading $emotion avatar to $storagePath...");
        await storageRef.putData(
            imageBytes, SettableMetadata(contentType: 'image/png'));
        final downloadURL = await storageRef.getDownloadURL();
        newAvatarUrls[emotion] = downloadURL;
        print("SUCCESS: Avatar saved for: $emotion -> $downloadURL");
      } // End emotion loop

      // Save all URLs to Realtime Database
      await _dbRef.child("users/${user.uid}/avatarUrls").set(newAvatarUrls);

      // Update local state
      _avatarUrls = newAvatarUrls;
      if (_user != null) {
        _user = ClarioUser(
          uid: _user!.uid, name: _user!.name, age: _user!.age,
          selectedAvatarId: _user!.selectedAvatarId,
          baseAvatarPrompt: _baseAvatarPrompt, // Keep the prompt
          avatarUrls: newAvatarUrls, // Update URLs in the user model
        );
      }
      print("INFO: All avatar URLs saved to RTDB and local state updated.");
      _errorMessage = null; // Clear error on success
    } catch (e) {
      final errorMsg =
          "Failed during avatar generation/saving: ${e.toString()}";
      print("ERROR: $errorMsg");
      _errorMessage = errorMsg;
      // Re-throw the exception to be caught by the calling function/UI
      throw Exception(errorMsg);
    } finally {
      _isLoading = false;
      notifyListeners(); // Update UI after loading finishes or error occurs
    }
  }

  // --- Utility Methods ---

  /// Returns the appropriate avatar URL based on the current emotion.
  String getMoodAvatarAsset() {
    // Use the dynamic URL getter now
    return currentAvatarUrl;
  }

  /// Returns a color representing the current mood score.
  Color getMoodColor() {
    final moodScore = _currentMoodData?['mood_score'] as int? ??
        5; // Default to neutral score 5
    if (moodScore >= 8) return const Color(0xFF4CAF50); // Cheerful Green
    if (moodScore >= 6) return const Color(0xFF8BC34A); // Calm Lime
    if (moodScore >= 4) return const Color(0xFFFFC107); // Neutral Amber
    if (moodScore >= 2) return const Color(0xFF607D8B); // Sad Blue Grey
    return const Color(0xFFF44336); // Very Sad Red
  }

  /// Updates the `_currentEmotion` state based on a mood score.
  void setCurrentEmotionFromScore(int moodScore) {
    String newEmotion;
    // Map score ranges to the available avatar emotions
    if (moodScore >= 7) {
      // 7, 8, 9, 10 -> happy
      newEmotion = 'happy';
    } else if (moodScore >= 4) {
      // 4, 5, 6 -> neutral
      newEmotion = 'neutral';
    } else {
      // 1, 2, 3 -> sad
      newEmotion = 'sad';
    }

    if (_currentEmotion != newEmotion) {
      _currentEmotion = newEmotion;
      print(
          "INFO: Current emotion set to: $_currentEmotion (from score $moodScore)");
      notifyListeners(); // Update UI if emotion changes
    }
  }

  /// Simple keyword-based mood score calculation (Placeholder).
  // TODO: Replace with call to analyzeMood Cloud Function for better accuracy.
  int _calculateMoodScore(String text) {
    // Keep existing simple logic for now
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

  /// Adds a member for the Empty Chair feature.
  Future<void> addEmptyChairMember(String name) async {
    // ... (Existing code is okay) ...
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final newMemberRef =
          _dbRef.child("users/${user.uid}/emptyChairMembers").push();
      await newMemberRef
          .set({'name': name, 'createdAt': DateTime.now().toIso8601String()});
      // notifyListeners(); // Only if needed
    } catch (e) {
      print('ERROR saving empty chair member: $e');
    }
  }

  /// Generates a date key string in 'YYYY-MM-DD' format using UTC.
  String _getTodayDateKey() {
    final today =
        DateTime.now().toUtc(); // Use UTC for consistency across timezones
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  /// Helper to get Firebase Auth ID token, forcing refresh.
  Future<String?> _getIdToken() async {
    try {
      // Force refresh to ensure the token is valid, especially for longer operations
      final token = await _auth.currentUser?.getIdToken(true);
      if (token == null) print('WARN: ID Token is null.');
      // else print('DEBUG: ID Token retrieved successfully.'); // Keep logging minimal
      return token;
    } catch (e) {
      print('ERROR retrieving ID Token: $e');
      return null;
    }
  }
} // End of UserDataProvider class
