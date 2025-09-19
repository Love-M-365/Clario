import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class EmptyChairIntroScreen extends StatefulWidget {
  const EmptyChairIntroScreen({super.key});

  @override
  _EmptyChairIntroScreenState createState() => _EmptyChairIntroScreenState();
}

class _EmptyChairIntroScreenState extends State<EmptyChairIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _lottieScaleAnimation;
  // late Animation<double> _imageFadeAnimation; // Removed
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();

    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _lottieScaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    // _imageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    //   CurvedAnimation(
    //     parent: _mainAnimationController,
    //     curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    //   ),
    // ); // Removed

    _buttonScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.bounceOut),
      ),
    );

    _mainAnimationController.forward();
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF141E30),
              Color(0xFF243B55),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Hero Animation
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                                radius: 0.9,
                              ),
                            ),
                          ),
                          ScaleTransition(
                            scale: _lottieScaleAnimation,
                            child: Lottie.asset(
                              'assets/animations/chair.json',
                              width: 250,
                              height: 250,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Headline
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: FadeTransition(
                        opacity: _mainAnimationController,
                        child: Text(
                          "Your Partner in\nSelf-Reflection",
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 34,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subtext
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: FadeTransition(
                        opacity: _mainAnimationController,
                        child: Text(
                          "The empty chair mode helps you process emotions and unresolved conflicts by exploring different perspectives.",
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white70,
                                    fontSize: 18,
                                    height: 1.5,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100), // Adjusted spacing
                  ],
                ),
              ),

              // Floating Action Button → Modern Rounded Button
              Positioned(
                bottom: 40,
                left: 24,
                right: 24,
                child: ScaleTransition(
                  scale: _buttonScaleAnimation,
                  child: GestureDetector(
                    onTap: () => context.go('/home/empty-chair-setup'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Get Started",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
