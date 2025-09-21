// lib/screens/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../auth/login_screen.dart';

// Extension to mix a color with another color (e.g., black)
extension MixColor on Color {
  Color mixWith(Color color, [double amount = 0.5]) {
    return Color.lerp(this, color, amount)!;
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Clario',
      description:
          'Your personal AI-powered mental health companion designed specifically for youth.',
      icon: Icons.psychology,
      color: const Color(0xFF6B73FF),
    ),
    OnboardingPage(
      title: 'AI Therapy Sessions',
      description:
          'Experience personalized therapy sessions with our advanced AI that understands your unique needs.',
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFF4ECDC4),
    ),
    OnboardingPage(
      title: 'Mood Tracking',
      description:
          'Track your daily emotions and see patterns in your mental health journey.',
      icon: Icons.favorite,
      color: const Color(0xFFFF6B6B),
    ),
    OnboardingPage(
      title: 'Sleep Analysis',
      description:
          'Monitor your sleep patterns and get personalized recommendations for better rest.',
      icon: Icons.bedtime,
      color: const Color(0xFF9C27B0),
    ),
    OnboardingPage(
      title: 'Color Therapy',
      description:
          'Customize your app experience with therapeutic colors that match your mood.',
      icon: Icons.palette,
      color: const Color(0xFFFF9F43),
    ),
    // ✅ New Empty Chair feature page
    OnboardingPage(
      title: 'Empty Chair Sessions',
      description:
          'Talk to your thoughts and emotions in a safe space. The Empty Chair feature helps you express and heal.',
      icon: Icons.chair_alt,
      color: const Color(0xFF2E86AB),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Use the mixWith() extension to create a two-color gradient
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _pages[_currentPage].color,
              // Mix the current color with black to create a shaded gradient
              _pages[_currentPage].color.mixWith(Colors.black, 0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: _pages.length,
                      effect: WormEffect(
                        dotColor: Colors.white.withOpacity(0.5),
                        activeDotColor: Colors.white,
                        dotHeight: 12,
                        dotWidth: 12,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          TextButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text(
                              'Previous',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          )
                        else
                          const SizedBox(width: 80),
                        ElevatedButton(
                          onPressed: () async {
                            if (_currentPage == _pages.length - 1) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                  'has_completed_onboarding', true);

                              if (mounted) {
                                context.go('/login');
                              }
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _pages[_currentPage].color,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(75),
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 50),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
