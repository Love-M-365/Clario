import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String baseUrl =
      "https://us-central1-clario-4558.cloudfunctions.net";

  String? _sessionPhase; // Tracks current phase
  bool _emptyChairStarted = false; // Tracks if empty chair session is ready

  /// Helper for POST requests
  Future<Map<String, dynamic>> _postRequest(
      String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse("$baseUrl/$endpoint");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("API Error (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      throw Exception("Request to $endpoint failed: $e");
    }
  }

  /// Start a new session
  Future<Map<String, dynamic>> startSession(String userId,
      {String personInChair = "the issue",
      String userGoal = "find some clarity"}) async {
    final response = await _postRequest("startSession", {
      "userId": userId,
      "personInChair": personInChair,
      "userGoal": userGoal,
    });

    // Update local session state
    _sessionPhase = response['sessionPhase'] ?? "initial_analysis";
    return response;
  }

  /// Analyze the initial problem
  Future<Map<String, dynamic>> analyzeInitialProblem(
      String userId, String sessionId, String message) async {
    final response = await _postRequest("analyzeInitialProblem", {
      "userId": userId,
      "sessionId": sessionId,
      "message": message,
    });

    // Update phase if returned
    _sessionPhase = response['sessionPhase'] ?? _sessionPhase;
    return response;
  }

  /// Prepare session for Empty Chair dialogue
  Future<void> startEmptyChairSession(String userId, String sessionId) async {
    if (_emptyChairStarted) return; // Already prepared

    final response = await _postRequest("startEmptyChairSession", {
      "userId": userId,
      "sessionId": sessionId,
    });

    // Mark as ready
    _emptyChairStarted = true;
    _sessionPhase = response['sessionPhase'] ?? _sessionPhase;
  }

  /// Process a message in the empty chair session
  Future<Map<String, dynamic>> processMessage(String userId, String sessionId,
      String message, String perspective) async {
    // Make sure the empty chair session is prepared
    if (!_emptyChairStarted) {
      await startEmptyChairSession(userId, sessionId);
    }

    final safePerspective = (perspective.toLowerCase() == "blue" ||
            perspective.toLowerCase() == "red")
        ? perspective.toLowerCase()
        : "blue";

    final response = await _postRequest("processMessage", {
      "userId": userId,
      "sessionId": sessionId,
      "message": message,
      "perspective": safePerspective,
    });

    // Update session phase if returned
    _sessionPhase = response['sessionPhase'] ?? _sessionPhase;
    return response;
  }

  /// Generate session summaries
  Future<Map<String, dynamic>> generateSessionSummaries(
      String userId, String sessionId) async {
    final response = await _postRequest("generateSessionSummaries", {
      "userId": userId,
      "sessionId": sessionId,
    });

    // Phase can now be considered ended
    _sessionPhase = "completed";
    return response;
  }

  /// Get current session phase
  String get sessionPhase => _sessionPhase ?? "unknown";
}
