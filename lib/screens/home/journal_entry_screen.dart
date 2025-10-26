// lib/screens/home/journal_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';

class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({super.key});

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _journalController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();
  final Dio _dio = Dio();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSaving = false;
  // String _textBeforeListening = ''; // No longer needed with append logic

  late AnimationController _fabPulseController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _journalController.dispose();
    _speechToText.cancel();
    _fabPulseController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (error) =>
            _showSpeechError('Recognizer Error: ${error.errorMsg}'),
        onStatus: _speechStatusListener,
      );
    } catch (e) {
      _showSpeechError('Could not initialize speech recognition: $e');
    }
    if (mounted) setState(() {});
  }

  void _toggleListening() {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    if (!_speechAvailable) {
      _showSpeechError('Speech recognition is not available.');
      return;
    }
    _isListening ? _stopListening() : _startListening();
  }

  void _startListening() async {
    if (!_speechAvailable || _isListening) return;
    // _textBeforeListening = _journalController.text; // Store text if needed for complex logic, but not for simple append

    bool success = await _speechToText.listen(
      onResult: (result) {
        // ✅ FIX: Append final results to current text
        if (result.finalResult) {
          String recognized = result.recognizedWords;
          String currentText = _journalController.text;
          // Add a space only if current text is not empty and doesn't end with space
          String separator =
              (currentText.isEmpty || currentText.endsWith(' ')) ? '' : ' ';
          setState(() {
            _journalController.text = currentText + separator + recognized;
            _moveCursorToEnd(); // Keep cursor at the end
          });
        }
      },
      listenFor: const Duration(minutes: 2), // Listen longer
      pauseFor: const Duration(seconds: 55), // Allow for pauses
      localeId: 'en_US', // Force English
      cancelOnError: true,
      partialResults: false,
    );
    if (!success && mounted) {
      _showSpeechError("Failed to start listening. Mic busy?");
      setState(() {
        _isListening = false;
      });
      _fabPulseController.stop();
      _fabPulseController.value = 0.0;
    }
    // State handled by listener
  }

  void _stopListening() async {
    if (!_isListening) return;
    await _speechToText.stop();
    // State handled by listener
  }

  void _speechStatusListener(String status) {
    bool listening = status == SpeechToText.listeningStatus;
    print(
        "Speech status: $status, Current Listening State: $_isListening, New Status Listening: $listening");

    // Only update state if it actually changed
    if (listening != _isListening) {
      setState(() {
        _isListening = listening;
      });

      if (_isListening) {
        _fabPulseController.repeat(reverse: true);
      } else {
        _fabPulseController.stop();
        _fabPulseController.value = 0.0;
      }
    }

    // Handle final stop explicitly if needed (sometimes status updates lag)
    if (status == SpeechToText.notListeningStatus && _isListening) {
      print("Detected final 'notListening' state. Updating state.");
      setState(() {
        _isListening = false;
      });
      _fabPulseController.stop();
      _fabPulseController.value = 0.0;
    }
  }

  void _showSpeechError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ));
    }
  }

  void _moveCursorToEnd() {
    _journalController.selection = TextSelection.fromPosition(
      TextPosition(offset: _journalController.text.length),
    );
  }

  // --- Save Journal Logic (Unchanged) ---
  Future<void> _saveJournal() async {
    if (_journalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Journal can't be empty!")));
      return;
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated.");
      final idToken = await user.getIdToken(true);
      final journalText = _journalController.text.trim();
      const moodFunctionUrl = "https://analyzemood-6q2ddbi5pa-uc.a.run.app";
      final response = await _dio.post(moodFunctionUrl,
          data: {'text': journalText},
          options: Options(headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken'
          }));
      if (response.statusCode != 200)
        throw Exception(
            "Failed to analyze mood. Server returned ${response.statusCode}");
      final moodData = response.data;
      final double moodScore = (moodData['score'] as num?)?.toDouble() ?? 0.0;
      final String moodTag = moodData['tag'] ?? 'Neutral';
      final journalEntry = {
        'text': journalText,
        'timestamp': DateTime.now().toIso8601String(),
        'moodScore': moodScore,
        'moodTag': moodTag
      };
      final dbRef = FirebaseDatabase.instance.ref("users/${user.uid}/journals");
      await dbRef.push().set(journalEntry);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Journal entry saved successfully!'),
            backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving journal: ${e.toString()}'),
            backgroundColor: Colors.red.shade600));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fabScale = 1.0 + (_fabPulseController.value * 0.1);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        // ✅ Removed centerTitle: true (or set it to false)
        centerTitle: false,
        // ✅ Title is just the Text widget now, without Flexible
        title: Text(
          'New Journal Entry',
          style: TextStyle(
            fontSize: 16, // Adjust size as needed
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.iconTheme.color),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveJournal,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 80.0),
          // ✅ FIX: Use SingleChildScrollView for better keyboard handling
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMMd().add_jm().format(DateTime.now()),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.hintColor,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),
                // Ensure TextField has enough space but can scroll
                TextField(
                  controller: _journalController,
                  autofocus: true,
                  maxLines: null, // Allows infinite lines based on content
                  minLines: 10, // Give it a decent minimum height
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: "What's on your mind?...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 18, color: theme.hintColor),
                  ),
                  style: const TextStyle(fontSize: 18, height: 1.6),
                  textAlignVertical: TextAlignVertical.top,
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isSaving
          ? null
          : Animate(
              delay: 600.ms,
              effects: const [ScaleEffect(), FadeEffect()],
              child: Transform.scale(
                scale: fabScale,
                child: FloatingActionButton(
                  onPressed: _toggleListening,
                  tooltip: _isListening ? 'Stop Listening' : 'Start Listening',
                  backgroundColor: _isListening
                      ? Colors.red.shade400
                      : theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      key: ValueKey<bool>(_isListening),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
