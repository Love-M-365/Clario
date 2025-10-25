// lib/screens/home/journal_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dio/dio.dart';

class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({super.key});

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final TextEditingController _journalController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();
  final Dio _dio = Dio();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isSaving = false; // State to show loading indicator

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _journalController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  /// Starts listening to the user's voice.
  void _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available.')),
      );
      return;
    }
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          // Append the recognized words to the existing text
          _journalController.text = result.recognizedWords;
          // Move cursor to the end
          _journalController.selection = TextSelection.fromPosition(
              TextPosition(offset: _journalController.text.length));
        });
      },
    );
    setState(() {
      _isListening = true;
    });
  }

  /// Stops the listening session.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  /// Saves the journal by analyzing mood and pushing to Firebase.
  Future<void> _saveJournal() async {
    if (_journalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Journal can't be empty!")),
      );
      return;
    }
    if (_isSaving) return; // Prevent multiple saves

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Get User and Authentication Token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated.");
      final idToken = await user.getIdToken(true);
      final journalText = _journalController.text.trim();

      // 2. Call AI Cloud Function to analyze mood
      // IMPORTANT: Replace with your actual Cloud Function URL
      const moodFunctionUrl = "https://analyzemood-6q2ddbi5pa-uc.a.run.app";

      final response = await _dio.post(
        moodFunctionUrl,
        data: {'text': journalText},
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            "Failed to analyze mood. Server returned ${response.statusCode}");
      }

      final moodData = response.data;
      final double moodScore = (moodData['score'] as num?)?.toDouble() ?? 0.0;
      final String moodTag = moodData['tag'] ?? 'Neutral';

      // 3. Prepare data structure for Realtime Database
      final journalEntry = {
        'text': journalText,
        'timestamp': DateTime.now().toIso8601String(),
        'moodScore': moodScore,
        'moodTag': moodTag,
      };

      // 4. Save to Firebase Realtime Database under the user's UID
      final dbRef = FirebaseDatabase.instance.ref("users/${user.uid}/journals");
      await dbRef.push().set(journalEntry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Journal entry saved successfully!'),
          backgroundColor: Colors.green,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving journal: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New Journal Entry'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isSaving ? null : _saveJournal,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMMd().format(DateTime.now()),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _journalController,
                  autofocus: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: "What's on your mind?...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 18),
                  ),
                  style: const TextStyle(fontSize: 18, height: 1.5),
                ),
              ],
            ),
          ),
          // Loading overlay
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Analyzing and saving...",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isSaving
          ? null
          : FloatingActionButton(
              onPressed: _toggleListening,
              tooltip: 'Listen',
              backgroundColor: _isListening
                  ? Colors.red.shade400
                  : theme.colorScheme.secondary,
              child: Icon(
                _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: Colors.white,
              ),
            ),
    );
  }
}
