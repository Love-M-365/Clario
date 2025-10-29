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

    _pageController.addListener(() {
      final newIndex = _pageController.page?.round() ?? 0;
      if (_currentPageIndex != newIndex) {
        setState(() => _currentPageIndex = newIndex);
      }
    });

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadAndProcessJournals());
  }

  void _loadAndProcessJournals() async {
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    await provider.fetchAllJournals();

    final entries = provider.journalEntries;
    final grouped = groupBy(
        entries,
        (entry) => DateTime(
            entry.timestamp.year, entry.timestamp.month, entry.timestamp.day));

    setState(() {
      _groupedEntries = grouped;
      _sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  void _jumpToDate(DateTime date) {
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F6F0),
        appBar: AppBar(
          title: const Text('My Journal'),
          backgroundColor: const Color(0xFFF1E9D8),
          foregroundColor: const Color(0xFF3C2E20),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.2),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              onPressed: _showFilterDialog,
            ),
          ],
        ),
        body: Consumer<UserDataProvider>(
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
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    if (_sortedDates.isEmpty) return const SizedBox.shrink();

    final currentDate = _sortedDates[_currentPageIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
          Flexible(
            child: Text(
              DateFormat.yMMMMd().format(currentDate),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.merriweather(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3C2E20),
              ),
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

Color _getMoodColor(String moodType, double score) {
  switch (moodType.toLowerCase()) {
    case 'happy':
      return Colors.greenAccent.shade700;
    case 'calm':
      return Colors.blueAccent.shade200;
    case 'neutral':
      return Colors.grey.shade400;
    case 'sad':
      return Colors.blueGrey.shade400;
    case 'anxious':
      return Colors.orangeAccent.shade400;
    case 'angry':
      return Colors.redAccent.shade400;
    case 'mixed':
      return Colors.purpleAccent.shade200;
    default:
      return Colors.teal.shade200;
  }
}

class _JournalPage extends StatelessWidget {
  final List<JournalEntry> entries;
  const _JournalPage({required this.entries});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final moodColor = _getMoodColor(entry.moodTag, entry.moodScore);

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: moodColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: moodColor.withOpacity(0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: moodColor.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(
                      entry.moodTag.toUpperCase(),
                      style: TextStyle(
                        color: moodColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: moodColor.withOpacity(0.15),
                  ),
                  const Spacer(),
                  Text(
                    "${DateFormat.jm().format(entry.timestamp)} • ${entry.moodScore.toStringAsFixed(0)}",
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.text,
                style: GoogleFonts.merriweather(
                  fontSize: 16,
                  height: 1.6,
                  color: const Color(0xFF3C2E20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
