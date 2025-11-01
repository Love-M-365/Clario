import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class SleepAIService {
  static const String baseUrl =
      'https://sleep-wellness-coach-1081335572417.us-central1.run.app';
  static const String appName = 'sleep-agent-app';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _cachedSessionId;
  bool _introMessageSent =
      false; // ✅ Tracks if intro message was sent this session

  /// Get current authenticated user ID from Firebase
  String get userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in. Please authenticate first.');
    }
    return user.uid;
  }

  String? get userName => _auth.currentUser?.displayName;
  String? get userEmail => _auth.currentUser?.email;
  bool get isAuthenticated => _auth.currentUser != null;

  /// Create or reuse a session for the current user
  Future<String> _getOrCreateSession() async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    if (_cachedSessionId != null && _cachedSessionId!.isNotEmpty) {
      print('♻️ Reusing session: $_cachedSessionId');
      return _cachedSessionId!;
    }

    try {
      final currentUserId = userId;
      final sessionUrl =
          Uri.parse('$baseUrl/apps/$appName/users/$currentUserId/sessions');

      print('🔄 Creating session for user: $currentUserId');

      final sessionResponse = await http
          .post(
            sessionUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'metadata': {
                'user_id': currentUserId,
                'user_email': userEmail,
                'user_name': userName,
              }
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('📥 Session Response: ${sessionResponse.statusCode}');

      if (sessionResponse.statusCode != 200 &&
          sessionResponse.statusCode != 201) {
        throw Exception('Session creation failed: ${sessionResponse.body}');
      }

      final sessionData = jsonDecode(sessionResponse.body);
      _cachedSessionId = sessionData['id'];

      print('✅ Session created: $_cachedSessionId');
      _introMessageSent = false; // reset intro for new session
      return _cachedSessionId!;
    } catch (e) {
      print('❌ Session error: $e');
      rethrow;
    }
  }

  /// Send a message to the AI agent
  Future<String> askSleepAI(String prompt) async {
    try {
      if (!isAuthenticated) {
        return '⚠️ Error: Not logged in. Please sign in with Google first.';
      }

      final currentUserId = userId;
      final sessionId = await _getOrCreateSession();

      final runUrl = Uri.parse('$baseUrl/run');

      // ✅ Add intro message before first message of the session
      String finalPrompt = prompt;
      if (!_introMessageSent) {
        final intro =
            "This is my user id: $currentUserId.\nUser Name: ${userName ?? 'Unknown'}\nEmail: ${userEmail ?? 'Unknown'}\n"
            "Start by greeting me briefly and asking about my sleep today.";
        finalPrompt = "$intro\n\n$prompt";
        _introMessageSent = true;
        print('👋 Intro message sent with user info.');
      }

      print('📤 Sending to: $runUrl');
      print('📤 User: $currentUserId');
      print('📤 Session: $sessionId');
      print('📤 Message: $finalPrompt');

      final requestBody = {
        'app_name': appName,
        'user_id': currentUserId,
        'session_id': sessionId,
        'new_message': {
          'role': 'user',
          'parts': [
            {'text': finalPrompt}
          ]
        },
      };

      print('📤 Request body: ${jsonEncode(requestBody)}');

      final runResponse = await http
          .post(
        runUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 260),
        onTimeout: () {
          throw Exception('Request timeout after 60 seconds');
        },
      );

      print('📥 Response Code: ${runResponse.statusCode}');
      print('📥 Response Body: ${runResponse.body}');

      if (runResponse.statusCode != 200 && runResponse.statusCode != 201) {
        if (runResponse.statusCode == 404 ||
            runResponse.statusCode == 400 ||
            runResponse.statusCode == 500) {
          print('⚠️ Error detected, clearing session cache');
          _cachedSessionId = null;
          _introMessageSent = false;
        }

        return '⚠️ Server Error (${runResponse.statusCode})\n\n'
            'The AI agent encountered an issue. This might be a database or configuration problem.\n\n'
            'Please contact support if this persists.\n\n'
            'Error: ${runResponse.body}';
      }

      // Clean the raw response body before parsing
      final cleanedBody = runResponse.body
          .replaceAll(RegExp(r'data:\s*'), '')
          .replaceAll(RegExp(r'event:\s*\w+'), '')
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
          .trim();

      dynamic decoded;
      try {
        decoded = jsonDecode(cleanedBody);
      } catch (e) {
        print('⚠️ JSON parse fallback, returning cleaned text');
        return cleanedBody;
      }

      print('📥 Parsed response: $decoded');

      String? responseText;

      if (decoded is Map<String, dynamic>) {
        if (decoded['response'] != null) {
          responseText = decoded['response'].toString();
        } else if (decoded['events'] != null && decoded['events'] is List) {
          final events = decoded['events'] as List;
          for (var event in events.reversed) {
            if (event is Map<String, dynamic>) {
              if (event['content'] != null) {
                final content = event['content'];
                if (content is Map) {
                  if (content['text'] != null) {
                    responseText = content['text'].toString();
                    break;
                  }
                  if (content['parts'] != null && content['parts'] is List) {
                    final parts = content['parts'] as List;
                    if (parts.isNotEmpty &&
                        parts[0] is Map &&
                        parts[0]['text'] != null) {
                      responseText = parts[0]['text'].toString();
                      break;
                    }
                  }
                } else {
                  responseText = content.toString();
                  break;
                }
              } else if (event['text'] != null) {
                responseText = event['text'].toString();
                break;
              }
            }
          }
        } else if (decoded['content'] != null) {
          responseText = decoded['content'].toString();
        } else if (decoded['text'] != null) {
          responseText = decoded['text'].toString();
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        for (var item in decoded.reversed) {
          if (item is Map<String, dynamic>) {
            if (item['content'] != null) {
              responseText = item['content'].toString();
              break;
            }
            if (item['text'] != null) {
              responseText = item['text'].toString();
              break;
            }
          }
        }
      }

      // Final cleanup before returning to UI
      if (responseText != null && responseText.isNotEmpty) {
        responseText = responseText
            .replaceAll(RegExp(r'data:\s*'), '')
            .replaceAll(RegExp(r'event:\s*\w+'), '')
            .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
            .trim();

        return responseText;
      }

      print('⚠️ Could not extract response from: $decoded');
      return '🤔 Received a response but couldn\'t parse it.\n\n'
          'Raw response: ${cleanedBody.substring(0, cleanedBody.length > 300 ? 300 : cleanedBody.length)}...';
    } on FirebaseAuthException catch (e) {
      print('❌ Auth error: ${e.message}');
      _cachedSessionId = null;
      _introMessageSent = false;
      return '⚠️ Authentication error: ${e.message}';
    } catch (e) {
      print('❌ Error: $e');
      _cachedSessionId = null;
      _introMessageSent = false;
      return '⚠️ Error: $e\n\nPlease try again.';
    }
  }

  void resetSession() {
    _cachedSessionId = null;
    _introMessageSent = false;
    print('🔄 Session reset');
  }

  void clearCache() {
    _cachedSessionId = null;
    _introMessageSent = false;
    print('🧹 Cache cleared');
  }

  Future<void> signOut() async {
    clearCache();
    await _auth.signOut();
    print('👋 User signed out');
  }
}
