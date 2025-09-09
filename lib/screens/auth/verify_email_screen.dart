import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../questionnaire/questionnaire_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isChecking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // auto-check every 5 seconds
    _timer = Timer.periodic(
        const Duration(seconds: 5), (_) => _checkVerification(auto: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification({bool auto = false}) async {
    setState(() => _isChecking = true);
    await _auth.currentUser?.reload();
    final user = _auth.currentUser;

    if (user != null && user.emailVerified) {
      _timer?.cancel();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
        );
      }
    } else {
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Email not verified yet. Please check again.")),
        );
      }
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Verify Your Email",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "We sent a verification link to your email.\nPlease verify before continuing.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed:
                    _isChecking ? null : () => _checkVerification(auto: false),
                child: _isChecking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("I have verified"),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await _auth.currentUser?.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Verification email re-sent.")),
                  );
                },
                child: const Text("Resend email"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
