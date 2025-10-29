import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class EmptyChairTutorialScreen extends StatefulWidget {
  const EmptyChairTutorialScreen({super.key});

  @override
  State<EmptyChairTutorialScreen> createState() =>
      _EmptyChairTutorialScreenState();
}

class _EmptyChairTutorialScreenState extends State<EmptyChairTutorialScreen> {
  final PageController _pageController = PageController();

  // --- Define consistent styles based on your images ---
  final TextStyle headlineStyle = TextStyle(
    fontSize: 28, // Slightly larger for more impact
    fontWeight: FontWeight.bold,
    color: Colors.grey[900], // Dark, almost black
  );
  final TextStyle subtitleStyle = TextStyle(
    fontSize: 15, // Slightly smaller
    color: Colors.grey[700],
  );
  // This style is for text *inside* the white cards
  final TextStyle bodyStyle = TextStyle(
    fontSize: 16, // Adjusted for better readability and space
    color: Colors.grey[800],
    height: 1.4,
  );
  // This style is for text *outside* the cards (like slide 4)
  final TextStyle standaloneBodyStyle = TextStyle(
    fontSize: 15, // Adjusted for hierarchy
    color: Colors.grey[800],
    height: 1.4,
  );
  final Color backgroundColor =
      const Color(0xFFF3F0FF); // Light purple background
  final Color shadowColor =
      const Color(0xFFD9D2E9); // A soft, darker purple for the shadow

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.grey[700]),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. PageView for the slides
            Expanded(
              child: PageView(
                controller: _pageController,
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildPage4(),
                ],
              ),
            ),

            // 2. Page Indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0, top: 20.0),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: 4, // 4 pages total
                effect: WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  activeDotColor: Colors.blue.shade700,
                  dotColor: Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Reusable widget for the white info cards ---
  Widget _buildInfoCard(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(24.0),
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
      child: Text(
        text,
        style: bodyStyle,
        textAlign: TextAlign.center,
      ),
    );
  }

  // --- Reusable widget for the image "glow" effect ---
  Widget _buildImageWithEffect(String imagePath, double height) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.7),
            blurRadius: 60.0,
            spreadRadius: 5.0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        imagePath,
        height: height,
      ),
    );
  }

  // --- SLIDE 1 ---
  Widget _buildPage1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text("Understand Your Feelings",
                  style: headlineStyle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("We help you find the root!",
                  style: subtitleStyle, textAlign: TextAlign.center),
            ],
          ),
          _buildImageWithEffect(
            'assets/images/slide1_graphic.png',
            250,
          ),
          _buildInfoCard(
              "First, describe what's on mind. We'll help identify a the core emotion."),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              );
            },
            child: const Text("Type \"ANALYZE\" to begin",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 2 --- (Image 1, Left)
  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text("Talk it Out & Switch",
                  style: headlineStyle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("Express yourself freely, then step into their shoes.",
                  style: subtitleStyle, textAlign: TextAlign.center),
            ],
          ),
          _buildImageWithEffect(
            'assets/images/slide2a_graphic.png',
            250,
          ),
          _buildInfoCard(
              "First, say what's on your mind. Then tap \"Switch\" button to talk as the are them."),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              );
            },
            child: const Text("Switch Roles",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 3 --- (Image 1, Right)
  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text("Talk it Out & Switch",
                  style: headlineStyle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("Express freely, then step into their shoes.",
                  style: subtitleStyle, textAlign: TextAlign.center),
            ],
          ),
          _buildImageWithEffect(
            'assets/images/slide2b_graphic.png',
            250,
          ),
          _buildInfoCard(
              "First, say what's on your mind. Then tap \"Switch\" button to talk if are them."),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              },
              child: Text(
                "Next",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable widget for the perspective cards on slide 4 ---
  Widget _buildPerspectiveCard(String title, String content) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SLIDE 4 ---
  Widget _buildPage4() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text("Gain Clarity & Insight",
                  style: headlineStyle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("Talk it out, from next steps!",
                  style: subtitleStyle, textAlign: TextAlign.center),
            ],
          ),
          _buildImageWithEffect(
            'assets/images/slide3_graphic.png',
            200,
          ),
          Row(
            children: [
              _buildPerspectiveCard(
                "YOUR Perspective",
                "Feeling: Frustrated.\nRoot Cause: Communication.\nInsight: Express needs clearly.",
              ),
              const SizedBox(width: 16),
              _buildPerspectiveCard(
                "THEIR Perspective (Simulated)",
                "Feeling: Misconflicted.\nFears: Conflict.\nWants: Open dialogue.",
              ),
            ],
          ),
          Text(
            "We provide insights from both sides, & helping you understand the situation better.",
            style: standaloneBodyStyle, // Use the standalone style
            textAlign: TextAlign.center,
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              shadowColor: Colors.grey.withOpacity(0.5),
            ),
            onPressed: () {
              // This will take the user to the chatbot screen
              context.go('/home/chatbot');
            },
            child: const Text("Continue Your Journey",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
