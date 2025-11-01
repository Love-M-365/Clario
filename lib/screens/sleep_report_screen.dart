// --- NEW IMPORTS ---
import 'dart:convert';
import 'package:http/http.dart' as http;
// --- END NEW IMPORTS ---

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Still needed for user ID
import 'package:flutter_animate/flutter_animate.dart'; // For animations
import 'package:intl/intl.dart'; // <-- ADDED FOR DATE FORMATTING

class WeeklySleepReportScreen extends StatefulWidget {
  const WeeklySleepReportScreen({Key? key}) : super(key: key);

  @override
  State<WeeklySleepReportScreen> createState() =>
      _WeeklySleepReportScreenState();
}

class _WeeklySleepReportScreenState extends State<WeeklySleepReportScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _reports = [];

  // --- THIS IS THE NEW, UPDATED FETCH METHOD ---
  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    if (!_loading) {
      setState(() {}); // Show refresh indicator
    }

    // TODO: Add your Cloud Function URL from the GCP console here
    final String endpoint =
        'https://us-central1-clario-f60b0.cloudfunctions.net/getSleepReports';

    try {
      // --- THIS IS THE FIX ---
      // 1. Get the current user object (which is nullable User?)
      final user = FirebaseAuth.instance.currentUser;

      // 2. Check if the user object *itself* is null.
      if (user == null) {
        // This is the check that was missing.
        throw Exception("User not logged in.");
      }

      // 3. Now that Dart knows 'user' is not null, we can safely get the ID
      final userId = user.uid;
      // --- END OF FIX ---

      // This line is now safe because Dart knows 'user' is not null
      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('$endpoint?user_id=$userId'), // user_id is a fallback
        headers: {
          'Authorization': 'Bearer $idToken', // This is the secure way
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _reports =
              data.map((item) => Map<String, dynamic>.from(item)).toList();
          _loading = false;
        });
      } else {
        throw Exception('Failed to fetch reports: ${response.body}');
      }
    } catch (e) {
      print("Error fetching reports: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Error fetching reports: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  // --- THIS IS THE NEW, GOOGLE-STYLE UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC), // Match dashboard
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "AI Sleep Reports",
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black54),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // Refresh button
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black54),
          onPressed: _loading ? null : _fetchReports,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchReports,
      child: _reports.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reports.length,
              itemBuilder: (context, i) => _buildReportCard(_reports[i], i),
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text(
          "No AI reports found.\nCheck back after a week of logging data.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
        ),
      ),
    );
  }

  /// This helper function safely parses lists from Firebase,
  /// which are sometimes Maps {"0": "...", "1": "..."}
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

  // --- WIDGET CHANGED ---
  // The Row containing the stats now uses Expanded to prevent overflow.
  Widget _buildReportCard(Map<String, dynamic> report, int index) {
    // --- NEW: Extracting stats data ---
    final computed = report['computed'] ?? {};
    final avgDuration = computed['avg_duration'] ?? 0.0;
    final avgStress = computed['avg_stress'] ?? 0.0;
    final nightmareCount = computed['nightmares_count'] ?? 0;

    final createdAt = report['created_at'] ?? '';
    String formattedDate = 'Weekly Report';
    if (createdAt.isNotEmpty) {
      try {
        formattedDate =
            'Report from ${DateFormat('MMMM d, yyyy').format(DateTime.parse(createdAt))}';
      } catch (e) {/* ignore format error */}
    }

    // --- NEW: Extracting AI data ---
    final aiData = report['ai'] ?? {};
    final summary = aiData['summary'] ?? 'No summary available';
    final suggestions = _parseList(aiData['weekly_suggestions']);
    final interventions = _parseList(aiData['weekly_interventions']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- NEW: Date Title ---
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // --- THIS ROW IS NOW FIXED ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded( // <-- ADDED Expanded
                  child: _buildStatItem(Icons.timelapse,
                      avgDuration.toStringAsFixed(1), 'Avg Hours'),
                ),
                Expanded( // <-- ADDED Expanded
                  child: _buildStatItem(Icons.self_improvement,
                      avgStress.toStringAsFixed(1), 'Avg Stress'),
                ),
                Expanded( // <-- ADDED Expanded
                  child: _buildStatItem(Icons.warning_amber_rounded,
                      nightmareCount.toString(), 'Nightmares'),
                ),
              ],
            ),
            // --- END OF FIX ---
            const Divider(height: 30),

            // --- AI Summary (Existing) ---
            _buildSectionHeader(Icons.auto_awesome, "AI Summary", Colors.blue),
            const SizedBox(height: 8),
            Text(summary, style: const TextStyle(fontSize: 15, height: 1.4)),

            // --- Suggestions (Existing) ---
            if (suggestions.isNotEmpty) ...[
              const Divider(height: 30),
              _buildSectionHeader(
                  Icons.lightbulb_outline, "Weekly Suggestions", Colors.orange),
              const SizedBox(height: 12),
              ...suggestions.map((s) => _buildListItem(s)),
            ],

            // --- Interventions (Existing) ---
            if (interventions.isNotEmpty) ...[
              const Divider(height: 30),
              _buildSectionHeader(Icons.healing_outlined,
                  "Recommended Interventions", Colors.green),
              const SizedBox(height: 12),
              ...interventions.map((i) => _buildListItem(i)),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.1, end: 0);
  }

  // --- HELPER WIDGET CHANGED ---
  // Added TextAlign.center to the label to handle wrapping gracefully.
  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.black54, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center, // <-- ADDED THIS
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  // --- (Existing Helper) ---
  // --- THIS WIDGET IS NOW FIXED ---
  Widget _buildSectionHeader(IconData icon, String title, MaterialColor color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // <-- ADDED
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Expanded( // <-- ADDED
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

  // --- (Existing Helper - Already Fixes Overflow) ---
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