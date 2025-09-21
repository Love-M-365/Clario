// lib/screens/chat/summary_screen.dart

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ get sessionId from router extra
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
      appBar: AppBar(title: const Text("Session Summary")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  _buildCard(
                      "Blue Chair (You)", _summary?["blueSummary"] ?? ""),
                  _buildCard(
                      "Red Chair (Other)", _summary?["redSummary"] ?? ""),
                  _buildCard("Overall Reflection",
                      _summary?["overallReflection"] ?? ""),
                  if (_summary?["error"] != null)
                    _buildCard("Error", _summary?["error"] ?? "Unknown error"),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
