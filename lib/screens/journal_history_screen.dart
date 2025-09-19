import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Import the collection package for firstWhereOrNull
import '../../providers/user_data_provider.dart';

class JournalHistoryScreen extends StatefulWidget {
  const JournalHistoryScreen({super.key});

  @override
  State<JournalHistoryScreen> createState() => _JournalHistoryScreenState();
}

class _JournalHistoryScreenState extends State<JournalHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isShowingAll = true;

  @override
  void initState() {
    super.initState();
    // In a real app, you would load data for the current week here
    // Provider.of<UserDataProvider>(context, listen: false).loadJournalsForWeek(_selectedDate);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.blue,
              accentColor: Colors.blueAccent,
              cardColor: const Color(0xFF131A2D),
              backgroundColor: const Color(0xFF0C132D),
            ).copyWith(
              onSurface: Colors.white,
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white),
            ),
            dialogBackgroundColor: const Color(0xFF131A2D),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isShowingAll = false;
      });
      // In a real app, you would fetch data for the selected date
      // Provider.of<UserDataProvider>(context, listen: false).loadJournalsForDate(_selectedDate);
    }
  }

  void _showAllJournals() {
    setState(() {
      _isShowingAll = true;
      _selectedDate = DateTime.now();
    });
    // In a real app, you would fetch the last 7 days again
    // Provider.of<UserDataProvider>(context, listen: false).loadJournalsForWeek(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Journal History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
          ),
          if (!_isShowingAll)
            TextButton(
              onPressed: _showAllJournals,
              child: const Text(
                'Show All',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C1324), // Dark blue
              Color(0xFF131A2D), // Slightly lighter dark blue
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<UserDataProvider>(
            builder: (context, userDataProvider, child) {
              if (userDataProvider.isLoading) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }

              // Use this sample data for now
              final allReflections = [
                {
                  'timestamp': DateTime.now().toIso8601String(),
                  'mood_score': 8,
                  'text':
                      'Today was a great day! I felt very productive and happy. I had a lot of energy and was able to accomplish all my tasks. I also spent some quality time with my friends, which made me feel grateful and content. Looking forward to tomorrow!',
                },
                {
                  'timestamp': DateTime.now()
                      .subtract(Duration(days: 1))
                      .toIso8601String(),
                  'mood_score': 5,
                  'text':
                      'I felt a bit stressed at work, but managed to get through it. The deadline for the project is approaching, so there\'s a lot of pressure. I tried some breathing exercises to stay calm, and it helped a little. I hope tomorrow is a bit more relaxed.',
                },
                {
                  'timestamp': DateTime.now()
                      .subtract(Duration(days: 2))
                      .toIso8601String(),
                  'mood_score': 3,
                  'text':
                      'I was feeling down today, but I talked to a friend and it helped. The weather has been gloomy, and it\'s affecting my mood. I\'m going to try to get some sunlight tomorrow to see if it helps.',
                },
                {
                  'timestamp': DateTime.now()
                      .subtract(Duration(days: 3))
                      .toIso8601String(),
                  'mood_score': 9,
                  'text':
                      'Had an amazing weekend trip. Feeling grateful and full of energy! The change of scenery was exactly what I needed. I feel refreshed and ready to take on the week.',
                },
                {
                  'timestamp': DateTime.now()
                      .subtract(Duration(days: 4))
                      .toIso8601String(),
                  'mood_score': 6,
                  'text':
                      'A quiet day at home. Spent some time reading and relaxing. It was nice. I appreciate the slow pace and the opportunity to just be. Sometimes, doing nothing is the best thing you can do for yourself.',
                },
              ];

              final reflections = userDataProvider.dailyReflections.isNotEmpty
                  ? userDataProvider.dailyReflections
                  : allReflections;

              final displayedReflections = _isShowingAll
                  ? reflections.where((entry) {
                      final entryDate = DateTime.parse(entry['timestamp']);
                      return DateTime.now().difference(entryDate).inDays < 7;
                    }).toList()
                  : reflections.where((entry) {
                      final entryDate = DateTime.parse(entry['timestamp']);
                      return entryDate.year == _selectedDate.year &&
                          entryDate.month == _selectedDate.month &&
                          entryDate.day == _selectedDate.day;
                    }).toList();

              if (displayedReflections.isEmpty) {
                return Center(
                  child: Text(
                    'No journal entries for this period.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: displayedReflections.length,
                itemBuilder: (context, index) {
                  final entry = displayedReflections[index];
                  return _buildJournalCard(context, entry);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildJournalCard(BuildContext context, Map<String, dynamic> entry) {
    final DateTime date = DateTime.parse(entry['timestamp']);
    final int moodScore = entry['mood_score'] ?? 5;
    final String moodText = _getMoodText(moodScore);
    final Color moodColor = _getMoodColor(moodScore);
    final String entryText = entry['text'];

    return GestureDetector(
      onTap: () {
        _showFullEntryModal(context, date, moodText, moodColor, entryText);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: moodColor.withOpacity(0.5),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: moodColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    moodText,
                    style: TextStyle(color: moodColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Text(
              entryText.length > 100
                  ? '${entryText.substring(0, 100)}...'
                  : entryText,
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullEntryModal(BuildContext context, DateTime date, String mood,
      Color color, String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF131A2D),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(date),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      mood,
                      style: TextStyle(color: color, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                text,
                style: TextStyle(color: Colors.grey[300], fontSize: 16),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getMoodText(int moodScore) {
    if (moodScore >= 8) return 'Happy';
    if (moodScore >= 6) return 'Content';
    if (moodScore >= 4) return 'Neutral';
    if (moodScore >= 2) return 'Sad';
    return 'Very Sad';
  }

  Color _getMoodColor(int moodScore) {
    if (moodScore >= 8) return Colors.green;
    if (moodScore >= 6) return Colors.lightGreen;
    if (moodScore >= 4) return Colors.orange;
    if (moodScore >= 2) return Colors.red;
    return Colors.deepOrange;
  }
}
