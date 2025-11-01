import 'dart:convert';
import 'package:clario/screens/sleep_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'sleep_report_screen.dart'; // Make sure this path is correct
// For animations
import 'sleep_input_screen.dart'; // Make sure this path is correct

// --- 1. ORIGINAL IMPORT ---
import '../services/sleep_sounds_screen.dart'; // To navigate to your new screen

// --- 2. ADD THIS NEW IMPORT ---
// (Make sure this path matches where your chat screen file is)
import '../screens/sleep_chat_screen.dart';
// --- END OF NEW IMPORT ---

class SleepDashboardScreen extends StatefulWidget {
  const SleepDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SleepDashboardScreen> createState() => _SleepDashboardScreenState();
}

class _SleepDashboardScreenState extends State<SleepDashboardScreen> {
  // --- All your existing state and logic ---
  // (initState, _fetchSleepData, etc. remain unchanged)
  // ... (omitted for brevity) ...

  bool _loading = true;
  List<dynamic> _sleepData = [];
  double _averageSleep = 0;
  double _averageStress = 0;
  int _nightmareCount = 0;

  final String endpoint =
      'https://us-central1-clario-f60b0.cloudfunctions.net/getSleepData';

  @override
  void initState() {
    super.initState();
    _fetchSleepData();
  }

  Future<void> _fetchSleepData() async {
    // Show loading spinner only if it's not a refresh
    if (!_loading) {
      setState(() {}); // Allows refresh indicator to show
    }

    try {
      // --- FIX FOR SECURE CLOUD FUNCTION ---
      // We need to get the user and token to make a secure call
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in.");
      }
      final userId = user.uid;
      final idToken = await user.getIdToken();
      // --- END OF FIX ---

      final response = await http.get(
        Uri.parse('$endpoint?user_id=$userId'), // user_id is a fallback
        headers: {
          'Authorization': 'Bearer $idToken', // This is the secure way
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _sleepData = data;
          if (_sleepData.isNotEmpty) {
            _averageSleep = _sleepData
                    .map((e) => (e['sleep_duration_hours'] ?? 0).toDouble())
                    .reduce((a, b) => a + b) /
                _sleepData.length;

            _averageStress = _sleepData
                    .map((e) => (e['stress_level'] ?? 0).toDouble())
                    .reduce((a, b) => a + b) /
                _sleepData.length;

            _nightmareCount = _sleepData
                .where((e) => e['nightmares'] == true)
                .toList()
                .length;
          } else {
            // Reset stats if no data
            _averageSleep = 0;
            _averageStress = 0;
            _nightmareCount = 0;
          }
          _loading = false;
        });
      } else {
        throw Exception('Failed to fetch data: ${response.body}');
      }
    } catch (e) {
      print("Error fetching data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Error: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC), // Google-like app bg color
      appBar: _buildAppBar(),
      floatingActionButton: _buildFAB(),
      body: _buildBody(),
    );
  }

  /// Builds the new white, Google-style AppBar
  PreferredSizeWidget _buildAppBar() {
    // ... (Your existing _buildAppBar code, unchanged) ...
    return AppBar(
      title: const Text(
        "Sleep Analysis",
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0, // Flat, modern look
      centerTitle: false,
      actions: [
        // Refresh button
        IconButton(
          icon: const Icon(Icons.assessment_outlined, color: Colors.black54),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const WeeklySleepReportScreen()),
            );
          },
          tooltip: 'View AI Reports',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black54),
          onPressed: _loading ? null : _fetchSleepData,
        ),
      ],
    );
  }

  /// Builds the new "Add Sleep Data" Floating Action Button
  Widget _buildFAB() {
    // ... (Your existing _buildFAB code, unchanged) ...
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const SleepInputScreen(), // Assumes this is your screen name
          ),
        );
        // Removed the placeholder SnackBar
      },
      backgroundColor: Colors.blue.shade700, // Google Blue
      child: const Icon(Icons.add, color: Colors.white, size: 28),
    ).animate().scale(delay: 500.ms); // Simple animation
  }

  // --- 3. EDIT THE _buildBody METHOD ---
  /// Builds the main body, handling loading and pull-to-refresh
  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Pull-to-refresh
    return RefreshIndicator(
      onRefresh: _fetchSleepData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- 1. Analysis Report Card (Existing) ---
          _buildHeader("Analysis Report"),
          const SizedBox(height: 8),
          _buildAnalysisReportCard()
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1, end: 0),

          // --- 2. Sleep Sounds Card (Existing) ---
          const SizedBox(height: 24),
          _buildHeader("Sleep Sounds"),
          const SizedBox(height: 8),
          _buildSleepSoundsCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms) // Staggered animation
              .slideY(begin: 0.1, end: 0),

          // --- 3. (NEW) MCP AI CHAT CARD ---
          const SizedBox(height: 24),
          _buildHeader("AI Assistant"),
          const SizedBox(height: 8),
          _buildMcpChatCard() // This is your new widget
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms) // Staggered animation
              .slideY(begin: 0.1, end: 0),
          // --- END OF NEW SECTION ---

          const SizedBox(height: 24),

          // --- 4. Recent Logs List (Existing) ---
          _buildHeader("Recent Logs"),
          const SizedBox(height: 8),
          _buildSleepList(), // This will now build the expandable list
        ],
      ),
    );
  }
  // --- END OF EDITED METHOD ---

  /// Helper for section headers (e.g., "Analysis Report")
  Widget _buildHeader(String title) {
    // ... (Your existing _buildHeader code, unchanged) ...
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  /// This is the new widget that depicts the analysis report, as requested.
  Widget _buildAnalysisReportCard() {
    // ... (Your existing _buildAnalysisReportCard code, unchanged) ...
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Metrics Column ---
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Weekly Averages", // Note: This is based on all data fetched
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetricItem(
                    Icons.timelapse,
                    'Average Sleep',
                    "${_averageSleep.toStringAsFixed(1)} hrs",
                    Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricItem(
                    Icons.self_improvement,
                    'Average Stress',
                    _averageStress.toStringAsFixed(1),
                    Colors.orange.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricItem(
                    Icons.warning_amber_rounded,
                    'Nightmares',
                    '$_nightmareCount times',
                    Colors.red.shade600,
                  ),
                ],
              ),
            ),
            // --- Chart Placeholder ---
            Expanded(
              flex: 2,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    // Placeholder for a chart. You can replace this with a real chart widget.
                    child: CircularProgressIndicator(
                      value: _averageSleep / 10, // Example: 8/10 hours
                      strokeWidth: 6,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                      backgroundColor: Colors.blue.shade100,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget for a single metric item inside the analysis card
  Widget _buildMetricItem(
      IconData icon, String label, String value, Color color) {
    // ... (Your existing _buildMetricItem code, unchanged) ...
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  /// Builds a card to navigate to the Sleep Sounds screen
  Widget _buildSleepSoundsCard() {
    // ... (Your existing _buildSleepSoundsCard code, unchanged) ...
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // For the InkWell ripple effect
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SleepSoundsScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.music_note_outlined,
                  color: Colors.purple.shade400, size: 36),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sleep Sounds",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Listen to relaxing sounds for a better sleep.",
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.black38, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- 4. ADD THIS NEW HELPER METHOD ---
  // (You can paste this right after your _buildSleepSoundsCard method)

  /// Builds a card to navigate to the MCP AI Chat screen
  Widget _buildMcpChatCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // For the InkWell ripple effect
      child: InkWell(
        onTap: () {
          // This is where you navigate to your chat screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SleepChatScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.smart_toy_outlined, // New Icon
                  color: Colors.teal.shade400,
                  size: 36), // New Color
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AI Assistant", // New Title
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Chat with your MCP server AI.", // New Subtitle
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.black38, size: 16),
            ],
          ),
        ),
      ),
    );
  }
  // --- END OF ADDED METHOD ---

  Widget _buildSleepList() {
    // ... (Your existing _buildSleepList code, unchanged) ...
    // (omitted for brevity)
    if (_sleepData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            "No sleep data found.\nTap the '+' button to add your first log.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    // We return a Column because this is already inside a ListView
    return Column(
      children: _sleepData.map((d) {
        // --- 1. Extract all the sleep data ---
        final date =
            DateFormat('MMM d, yyyy').format(DateTime.parse(d['sleep_date']));
        final duration = d['sleep_duration_hours'] ?? 0.0;
        final quality = d['sleep_quality'] ?? 'N/A';
        final stress = d['stress_level'] ?? 0;
        final hadNightmare = (d['nightmares'] ?? false);

        // --- 2. Extract all the daily AI analysis data ---
        final analysis = d['analysis'] ?? {};
        final aiData = analysis['ai'] ?? {};
        final aiSummary = aiData['summary'] ?? '';
        final suggestions = _parseList(aiData['suggestions']);
        final interventions = _parseList(aiData['interventions']);
        final bool hasAiData = aiSummary.isNotEmpty ||
            suggestions.isNotEmpty ||
            interventions.isNotEmpty;

        // --- 3. Build the new ExpansionTile ---
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.05),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias, // Ensures the tile clips neatly
          child: ExpansionTile(
            // --- The "Header" part (always visible) ---
            leading: Icon(
              Icons.bedtime_outlined,
              color: Colors.blue.shade300,
              size: 32,
            ),
            title: Text(
              date,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${duration.toStringAsFixed(1)} hrs | Quality: $quality | Stress: $stress',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: hadNightmare
                ? Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent.shade400)
                : const Icon(Icons.expand_more, color: Colors.black54),

            // --- The "Expanded" part (hidden by default) ---
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show the AI Summary first
                    if (aiSummary.isNotEmpty)
                      Text(
                        aiSummary,
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),

                    // Show Daily Suggestions
                    if (suggestions.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildSectionHeader(Icons.lightbulb_outline,
                          "Daily Suggestions", Colors.orange),
                      const SizedBox(height: 8),
                      ...suggestions.map((s) => _buildListItem(s)),
                    ],

                    // Show Daily Interventions
                    if (interventions.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildSectionHeader(Icons.healing_outlined,
                          "Daily Interventions", Colors.green),
                      const SizedBox(height: 8),
                      ...interventions.map((i) => _buildListItem(i)),
                    ],

                    // Fallback message
                    if (!hasAiData)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "No specific AI feedback for this entry.",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              )
            ],
          ),
        )
            .animate()
            .fadeIn(delay: (100 * _sleepData.indexOf(d)).ms)
            .slideX(begin: -0.1, end: 0);
      }).toList(),
    );
  }

  // --- All other helper methods (_parseList, _buildSectionHeader, _buildListItem) ---
  // ... (remain unchanged) ...
  List<String> _parseList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      // It's already a list
      return data.map((e) => e.toString()).toList();
    }
    if (data is Map) {
      // It's a map like {"0": "text", "1": "text"}
      // Sort by key to keep order
      var sortedKeys = data.keys.toList()..sort();
      return sortedKeys.map((k) => data[k].toString()).toList();
    }
    return []; // Not a list or map, return empty
  }

  // Helper for section headers
  Widget _buildSectionHeader(IconData icon, String title, MaterialColor color) {
    // --- THIS WIDGET IS NOW FIXED FOR OVERFLOW ---
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
        ),
      ],
    );
  }

  // Helper for bulleted list items (Fixes UI Overflow)
  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
