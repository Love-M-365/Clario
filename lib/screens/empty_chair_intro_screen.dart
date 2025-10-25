// lib/screens/empty_chair_intro_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'dart:math';

// --- Data model for our background particles ---
class Particle {
  Offset position;
  double radius;
  double speed;
  Color color;

  Particle({
    required this.position,
    required this.radius,
    required this.speed,
    required this.color,
  });
}

class EmptyChairIntroScreen extends StatefulWidget {
  const EmptyChairIntroScreen({super.key});

  @override
  _EmptyChairIntroScreenState createState() => _EmptyChairIntroScreenState();
}

class _EmptyChairIntroScreenState extends State<EmptyChairIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late AnimationController _particleAnimationController;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _lottieScaleAnimation;
  late Animation<double> _buttonScaleAnimation;
  List<Particle> particles = [];

  @override
  void initState() {
    super.initState();

    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // --- Particle Animation Setup ---
    _particleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _initParticles();

    // --- UI Entrance Animations ---
    _setupUIAnimations();

    _mainAnimationController.forward();
  }

  void _setupUIAnimations() {
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _lottieScaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    _buttonScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  void _initParticles() {
    final random = Random();
    for (int i = 0; i < 25; i++) {
      particles.add(Particle(
        position: Offset(random.nextDouble(), random.nextDouble()),
        radius: random.nextDouble() * 4 + 2,
        speed: random.nextDouble() * 0.2 + 0.1,
        color: Colors.white.withOpacity(random.nextDouble() * 0.2 + 0.05),
      ));
    }
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _particleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // --- NEW: Animated Particle Background ---
          _AnimatedParticles(
            controller: _particleAnimationController,
            particles: particles,
          ),

          // --- Main Content ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  _buildLottieAnimation(),
                  const SizedBox(height: 40),
                  _buildAnimatedText(theme),
                  const Spacer(),
                  _buildAnimatedButton(theme),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLottieAnimation() {
    return Center(
      child: ScaleTransition(
        scale: _lottieScaleAnimation,
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Lottie.asset(
            'assets/animations/chair.json',
            width: 250,
            height: 250,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedText(ThemeData theme) {
    return FadeTransition(
      opacity: _mainAnimationController,
      child: SlideTransition(
        position: _textSlideAnimation,
        child: Column(
          children: [
            Text(
              "Your Space for Reflection",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "The Empty Chair mode helps you process emotions by exploring different perspectives in a safe, private space.",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedButton(ThemeData theme) {
    return ScaleTransition(
      scale: _buttonScaleAnimation,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        onPressed: () => context.go('/home/chatbot'),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Get Started"),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET FOR PARTICLE ANIMATION ---
class _AnimatedParticles extends StatelessWidget {
  final AnimationController controller;
  final List<Particle> particles;

  const _AnimatedParticles({required this.controller, required this.particles});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ParticlePainter(
            animationValue: controller.value,
            particles: particles,
          ),
        );
      },
    );
  }
}

// --- CUSTOM PAINTER FOR PARTICLES ---
class _ParticlePainter extends CustomPainter {
  final double animationValue;
  final List<Particle> particles;

  _ParticlePainter({required this.animationValue, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      // Animate particle position
      final yPos = (p.position.dy + (animationValue * p.speed)) % 1.0;
      final xPos = p.position.dx;

      paint.color = p.color;
      canvas.drawCircle(
        Offset(xPos * size.width, yPos * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
