// lib/screens/empty_chair_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'dart:ui';
import 'dart:math';

// --- Data model for our background particles (reused for consistency) ---
class Particle {
  Offset position;
  double radius;
  double speed;
  Color color;
  Particle(
      {required this.position,
      required this.radius,
      required this.speed,
      required this.color});
}

class EmptyChairSetupScreen extends StatefulWidget {
  const EmptyChairSetupScreen({super.key});

  @override
  State<EmptyChairSetupScreen> createState() => _EmptyChairSetupScreenState();
}

class _EmptyChairSetupScreenState extends State<EmptyChairSetupScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  late AnimationController _animationController;
  late AnimationController _particleController;
  List<Particle> particles = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Setup for the animated background
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _initParticles();

    _animationController.forward();

    // Request focus for the text field after the animation starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_nameFocusNode);
    });
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
    _animationController.dispose();
    _particleController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _startSession() {
    if (_nameController.text.trim().isNotEmpty) {
      final userDataProvider =
          Provider.of<UserDataProvider>(context, listen: false);
      // This functionality is unchanged
      userDataProvider.addEmptyChairMember(_nameController.text.trim());
      context.go('/home/empty-chair-session/${_nameController.text.trim()}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name or role.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // --- NEW: Animated Particle Background ---
          _AnimatedParticles(
              controller: _particleController, particles: particles),

          // --- Main Content ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  _buildContentCard(theme),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BUILDER WIDGETS ---

  Widget _buildContentCard(ThemeData theme) {
    // A single animated container for all the content
    return FadeTransition(
      opacity: CurvedAnimation(
          parent: _animationController, curve: const Interval(0.0, 0.6)),
      child: ScaleTransition(
        scale: CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.cardColor.withOpacity(0.7)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAnimatedHeader(theme),
                  const SizedBox(height: 24),
                  _buildAnimatedTextField(theme),
                  const SizedBox(height: 24),
                  _buildAnimatedSuggestions(theme),
                  const SizedBox(height: 32),
                  _buildAnimatedButton(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(ThemeData theme) {
    return FadeTransition(
      opacity: CurvedAnimation(
          parent: _animationController, curve: const Interval(0.2, 0.8)),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(
          CurvedAnimation(
              parent: _animationController,
              curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)),
        ),
        child: Text(
          "Who is on the Empty Chair?",
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField(ThemeData theme) {
    return FadeTransition(
      opacity: CurvedAnimation(
          parent: _animationController, curve: const Interval(0.4, 1.0)),
      child: TextField(
        controller: _nameController,
        focusNode: _nameFocusNode,
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.person_outline, color: theme.hintColor),
          labelText: 'Enter a name or a role...',
          labelStyle: TextStyle(color: theme.hintColor),
          filled: true,
          fillColor: theme.scaffoldBackgroundColor.withOpacity(0.5),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
        onSubmitted: (_) => _startSession(),
      ),
    );
  }

  Widget _buildAnimatedSuggestions(ThemeData theme) {
    return FadeTransition(
      opacity: CurvedAnimation(
          parent: _animationController, curve: const Interval(0.5, 1.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Suggestions",
              style:
                  theme.textTheme.titleSmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              _SuggestionChip(label: 'My Anxiety', controller: _nameController),
              _SuggestionChip(label: 'My Dad', controller: _nameController),
              _SuggestionChip(
                  label: 'My Future Self', controller: _nameController),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton(ThemeData theme) {
    return FadeTransition(
      opacity: CurvedAnimation(
          parent: _animationController, curve: const Interval(0.6, 1.0)),
      child: ScaleTransition(
        scale: CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.6, 1.0, curve: Curves.elasticOut)),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 50),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onPressed: _startSession,
          child: const Text("Start Conversation"),
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _SuggestionChip extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _SuggestionChip({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        controller.text = label;
      },
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
    );
  }
}

class _AnimatedParticles extends StatelessWidget {
  final AnimationController controller;
  final List<Particle> particles;
  const _AnimatedParticles({required this.controller, required this.particles});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ParticlePainter(
            animationValue: controller.value, particles: particles),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double animationValue;
  final List<Particle> particles;
  _ParticlePainter({required this.animationValue, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      final yPos = (p.position.dy + (animationValue * p.speed)) % 1.0;
      paint.color = p.color;
      canvas.drawCircle(Offset(p.position.dx * size.width, yPos * size.height),
          p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
