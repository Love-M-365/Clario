// lib/screens/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// A data class for a single onboarding page
class OnboardingPage {
  final String title;
  final String description;
  final String imagePath; // Changed from IconData to use illustrations
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.color,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // --- Onboarding Content ---
  // 🚨 ACTION REQUIRED: Replace image paths with your actual asset illustrations
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Clario',
      description:
          'Your personal AI-powered mental health companion, designed for you.',
      imagePath: 'assets/images/onboarding_welcome.jpg', // Example path
      color: const Color(0xFF6B73FF),
    ),
    OnboardingPage(
      title: 'AI Therapy Sessions',
      description:
          'Experience personalized sessions with our advanced AI that understands your needs.',
      imagePath: 'assets/images/onboarding_chat.jpg', // Example path
      color: const Color(0xFF4ECDC4),
    ),
    OnboardingPage(
      title: 'Track Your Mood',
      description:
          'Log your daily emotions to discover patterns in your mental wellness journey.',
      imagePath: 'assets/images/onboarding_mood.jpg', // Example path
      color: const Color(0xFFFF6B6B),
    ),
    OnboardingPage(
      title: 'Empty Chair Sessions',
      description:
          'Talk to your thoughts in a safe space. A feature to help you express and heal.',
      imagePath: 'assets/images/onboarding_chair.jpg', // Example path
      color: const Color(0xFF2E86AB),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- Navigation Logic ---
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    if (mounted) {
      context.go('/login');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  // --- UI Build Method ---
  @override
  Widget build(BuildContext context) {
    bool isLastPage = _currentPage == _pages.length - 1;

    // AnimatedContainer provides a smooth background color transition
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: _pages[_currentPage].color,
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Important for the animation to be visible
        body: SafeArea(
          child: Column(
            children: [
              // The main content area with illustrations
              Expanded(
                flex: 3,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) =>
                      OnboardingPageContent(page: _pages[index]),
                ),
              ),
              // The bottom card with text and navigation
              Expanded(
                flex: 2,
                child: OnboardingNavigation(
                  pageController: _pageController,
                  pages: _pages,
                  currentPage: _currentPage,
                  isLastPage: isLastPage,
                  onSkip: _completeOnboarding,
                  onNext: () {
                    if (isLastPage) {
                      _completeOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper Widgets for Cleaner Code ---

// Displays the illustration for a page
class OnboardingPageContent extends StatelessWidget {
  final OnboardingPage page;
  const OnboardingPageContent({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0).copyWith(bottom: 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Image.asset(
              page.imagePath,
              // Add a fallback in case the image fails to load
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.image_not_supported,
                      color: Colors.white, size: 80),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Displays the bottom navigation card
class OnboardingNavigation extends StatelessWidget {
  final PageController pageController;
  final List<OnboardingPage> pages;
  final int currentPage;
  final bool isLastPage;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const OnboardingNavigation({
    super.key,
    required this.pageController,
    required this.pages,
    required this.currentPage,
    required this.isLastPage,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40.0),
          topRight: Radius.circular(40.0),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            pages[currentPage].title,
            style:
                textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            pages[currentPage].description,
            style: textTheme.bodyLarge
                ?.copyWith(color: Colors.grey[600], height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip Button
              TextButton(
                onPressed: onSkip,
                child: Text('Skip', style: TextStyle(color: Colors.grey[600])),
              ),

              // Page Indicator
              SmoothPageIndicator(
                controller: pageController,
                count: pages.length,
                effect: WormEffect(
                  dotColor: Colors.grey[300]!,
                  activeDotColor: pages[currentPage].color,
                  dotHeight: 10,
                  dotWidth: 10,
                ),
              ),

              // Next / Get Started Button
              SizedBox(
                width: 80, // Ensures consistent button size
                child: isLastPage
                    ? TextButton(onPressed: onNext, child: const Text("Start"))
                    : IconButton.filled(
                        onPressed: onNext,
                        style: IconButton.styleFrom(
                            backgroundColor: pages[currentPage].color),
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
