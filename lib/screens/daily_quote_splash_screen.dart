import 'dart:async';
import 'package:flutter/material.dart'; // <-- FIXED
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- FIXED
import 'package:go_router/go_router.dart';

class DailyQuoteSplashScreen extends StatefulWidget {
  const DailyQuoteSplashScreen({super.key});

  @override
  State<DailyQuoteSplashScreen> createState() => _DailyQuoteSplashScreenState();
}

class _DailyQuoteSplashScreenState extends State<DailyQuoteSplashScreen> {
  String _quoteText = "Loading your daily quote...";
  String _quoteAuthor = "";

  @override
  void initState() {
    super.initState();
    _fetchDailyQuote();
    _startNavigationTimer();
  }

  Future<void> _fetchDailyQuote() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('dailyQuote')
          .get();

      if (mounted && doc.exists) {
        setState(() {
          _quoteText = doc.data()?['text'] ?? 'Be kind to your mind.';
          _quoteAuthor = doc.data()?['author'] ?? 'Clario';
        });
      } else if (mounted) {
        setState(() {
          _quoteText = 'Welcome back.';
          _quoteAuthor = 'Take a deep breath';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _quoteText = 'Every day is a new beginning.';
          _quoteAuthor = 'Anonymous';
        });
      }
    }
  }

  void _startNavigationTimer() {
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        // Use go_router to navigate and replace the stack
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
              Text(
                '"$_quoteText"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              if (_quoteAuthor.isNotEmpty)
                Text(
                  '- $_quoteAuthor',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
