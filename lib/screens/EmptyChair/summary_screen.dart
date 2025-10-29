import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/ai_service.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final AIService _aiService = AIService();
  Map<String, dynamic>? _summary;
  bool _loading = true;
  late String _sessionId;

  // --- UI Theme Colors ---
  final Color backgroundColor = const Color(0xFFF3F0FF); // Light purple
  final Color blueColor = const Color(0xFF4A55A2); // Theme blue
  final Color redColor = const Color(0xFFD9534F); // A soft red
  final Color primaryTextColor = Colors.grey.shade900;
  final Color secondaryTextColor = Colors.grey.shade700;
  final Color accentColor = Colors.blue.shade700;
  // -----------------------

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is String) {
      _sessionId = extra;
      _fetchSummary();
    } else {
      setState(() {
        _summary = {"error": "No sessionId passed"};
        _loading = false;
      });
    }
  }

  Future<void> _fetchSummary() async {
    try {
      final res = await _aiService.generateSessionSummaries(
        "demoUser", // replace with FirebaseAuth later
        _sessionId,
      );
      setState(() => _summary = res);
    } catch (e) {
      setState(() => _summary = {"error": "$e"});
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- UI Enhancement ---
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Session Summary",
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back arrow
      ),
      // ---------------------
      body: _loading
          // --- UI Enhancement ---
          ? Center(child: CircularProgressIndicator(color: accentColor))
          // ---------------------
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        _buildCard(
                          "Blue Chair (You)",
                          _summary?["blueSummary"] ?? "No summary generated.",
                          titleColor: blueColor, // Pass color
                        ),
                        _buildCard(
                          "Red Chair (Other)",
                          _summary?["redSummary"] ?? "No summary generated.",
                          titleColor: redColor, // Pass color
                        ),
                        _buildCard(
                          "Overall Reflection",
                          _summary?["overallReflection"] ??
                              "No summary generated.",
                          titleColor: primaryTextColor, // Pass color
                        ),
                        if (_summary?["error"] != null)
                          _buildCard(
                            "Error",
                            _summary?["error"] ?? "Unknown error",
                            titleColor: redColor, // Pass color
                          ),
                      ],
                    ),
                  ),
                  // --- UI Enhancement: Added Navigation Button ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        shadowColor: Colors.grey.withOpacity(0.5),
                      ),
                      onPressed: () {
                        // Navigate back to the main intro screen (root)
                        context.go('/');
                      },
                      child: const Text(
                        "Back to Home",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
                  // ------------------------------------------
                ],
              ),
            ),
    );
  }

  // --- UI Enhancement: Restyled Card Widget ---
  Widget _buildCard(String title, String content, {required Color titleColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: titleColor, // Use dynamic color
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content.isEmpty ? "No content available." : content,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
  // ---------------------------------------------
}
