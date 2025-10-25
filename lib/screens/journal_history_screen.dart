// lib/screens/journal_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/journal_entry.dart';
import '../../providers/user_data_provider.dart';

class JournalHistoryScreen extends StatefulWidget {
  const JournalHistoryScreen({super.key});

  @override
  State<JournalHistoryScreen> createState() => _JournalHistoryScreenState();
}

class _JournalHistoryScreenState extends State<JournalHistoryScreen> {
  late PageController _pageController;
  Map<DateTime, List<JournalEntry>> _groupedEntries = {};
  List<DateTime> _sortedDates = [];
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Listen for page changes to update the header
    _pageController.addListener(() {
      final newIndex = _pageController.page?.round() ?? 0;
      if (_currentPageIndex != newIndex) {
        setState(() {
          _currentPageIndex = newIndex;
        });
      }
    });

    // Fetch and process journal data as soon as the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndProcessJournals();
    });
  }

  void _loadAndProcessJournals() async {
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    await provider.fetchAllJournals();

    final entries = provider.journalEntries;

    // Group entries by the date (ignoring time)
    final grouped = groupBy(entries, (entry) {
      return DateTime(
          entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
    });

    setState(() {
      _groupedEntries = grouped;
      // Sort the dates (keys of the map), most recent first
      _sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToDate(DateTime date) {
    // Normalize date to ignore time
    final targetDate = DateTime(date.year, date.month, date.day);
    final pageIndex = _sortedDates.indexOf(targetDate);
    if (pageIndex != -1) {
      _pageController.jumpToPage(pageIndex);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No journal entry found for this date.")),
      );
    }
  }

  void _jumpToMonth(DateTime date) {
    // Find the first entry in or after the selected month
    final targetDate = _sortedDates
        .firstWhereOrNull((d) => d.year == date.year && d.month == date.month);

    if (targetDate != null) {
      final pageIndex = _sortedDates.indexOf(targetDate);
      _pageController.jumpToPage(pageIndex);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No entries found for this month.")),
      );
    }
  }

  Future<void> _showFilterDialog() async {
    final selectedOption = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Journals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                title: const Text('Jump to Date'),
                onTap: () => Navigator.pop(context, 1)),
            ListTile(
                title: const Text('Jump to Month'),
                onTap: () => Navigator.pop(context, 2)),
          ],
        ),
      ),
    );

    if (selectedOption == 1) {
      // Pick Date
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: _sortedDates.isNotEmpty
            ? _sortedDates[_currentPageIndex]
            : DateTime.now(),
        firstDate: DateTime(2023),
        lastDate: DateTime.now(),
      );
      if (pickedDate != null) _jumpToDate(pickedDate);
    } else if (selectedOption == 2) {
      // Pick Month
      final pickedMonth = await showDatePicker(
        context: context,
        initialDate: _sortedDates.isNotEmpty
            ? _sortedDates[_currentPageIndex]
            : DateTime.now(),
        firstDate: DateTime(2023),
        lastDate: DateTime.now(),
        initialDatePickerMode: DatePickerMode.year,
      );
      if (pickedMonth != null) _jumpToMonth(pickedMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Journal'),
        backgroundColor: const Color(0xFFF1E9D8), // A creamy paper color
        foregroundColor: const Color(0xFF3C2E20), // Dark brown text
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.2),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background paper texture
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/paper_texture.jpg"),
                fit: BoxFit.cover,
                opacity: 0.8,
              ),
            ),
          ),
          Consumer<UserDataProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_sortedDates.isEmpty) {
                return const Center(
                  child: Text(
                    'Your journal is empty.\nStart by writing your first entry!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                );
              }

              return Column(
                children: [
                  _buildDateHeader(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _sortedDates.length,
                      itemBuilder: (context, index) {
                        final date = _sortedDates[index];
                        final entriesForDay = _groupedEntries[date]!;
                        return _JournalPage(entries: entriesForDay);
                      },
                    ),
                  ),
                  const SizedBox(height: 20), // Bottom padding
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    if (_sortedDates.isEmpty) return const SizedBox.shrink();

    final currentDate = _sortedDates[_currentPageIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon:
                const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5A4C3D)),
            onPressed: _currentPageIndex < _sortedDates.length - 1
                ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    )
                : null,
          ),
          Text(
            DateFormat.yMMMMd().format(currentDate), // "October 19, 2025"
            style: GoogleFonts.merriweather(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3C2E20),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF5A4C3D)),
            onPressed: _currentPageIndex > 0
                ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

Color _getMoodColor(double score) {
  if (score >= 0.25) return Colors.green.shade600; // Positive
  if (score <= -0.25) return Colors.red.shade400; // Negative
  return Colors.grey.shade500; // Neutral
}

// --- HELPER WIDGET FOR A SINGLE JOURNAL PAGE ---
class _JournalPage extends StatelessWidget {
  final List<JournalEntry> entries;
  const _JournalPage({required this.entries});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final moodColor = _getMoodColor(entry.moodScore);

        return Container(
          margin: const EdgeInsets.only(bottom: 24.0),
          // Use an IntrinsicHeight to ensure the side bar stretches correctly
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Colored Mood Side Bar
                Container(
                  width: 5.0,
                  decoration: BoxDecoration(
                    color: moodColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 16.0),
                // 2. Main Entry Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Mood Tag and Timestamp/Score
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Mood Tag Chip
                          Chip(
                            label: Text(
                              entry.moodTag,
                              style: TextStyle(
                                color: moodColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: moodColor.withOpacity(0.15),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            side: BorderSide.none,
                          ),
                          const Spacer(),
                          // Timestamp and Score
                          Text(
                            "${DateFormat.jm().format(entry.timestamp)} • Score: ${entry.moodScore.toStringAsFixed(2)}",
                            style: GoogleFonts.roboto(
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF5A4C3D).withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      // Journal Text
                      Text(
                        entry.text,
                        style: GoogleFonts.merriweather(
                          fontSize: 16,
                          height: 1.7, // Line spacing
                          color: const Color(0xFF3C2E20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
