import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

class DailyQuoteSplashScreen extends StatefulWidget {
  const DailyQuoteSplashScreen({super.key});

  @override
  State<DailyQuoteSplashScreen> createState() => _DailyQuoteSplashScreenState();
}

class _DailyQuoteSplashScreenState extends State<DailyQuoteSplashScreen> {
  String _quoteText = "Loading your wellness quote...";
  bool _isLoading = true;

  // Replace with your actual deployed Cloud Run URL 👇
  static const String _apiUrl =
      "https://wellness-quote-service-1045577266956.us-central1.run.app/get-wellness-quote";

  @override
  void initState() {
    super.initState();
    _fetchAIQuote();
  }

  Future<void> _fetchAIQuote() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quote = data['quote'] ?? 'Take a deep breath and start fresh.';

        if (mounted) {
          setState(() {
            _quoteText = quote;
            _isLoading = false;
          });
          // Start timer AFTER quote is loaded
          _startNavigationTimer();
        }
      } else {
        _handleError();
      }
    } catch (e) {
      _handleError();
    }
  }

  void _handleError() {
    if (mounted) {
      setState(() {
        _quoteText = 'You’re stronger than you think.';
        _isLoading = false;
      });
      // Even in error, wait 3 seconds before navigation
      _startNavigationTimer();
    }
  }

  void _startNavigationTimer() {
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        context.goNamed('home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: _isLoading ? 0.6 : 1.0,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  '"$_quoteText"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                const Icon(Icons.favorite, color: Colors.pinkAccent, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
