// lib/screens/main_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui'; // For blur effect

// Ensure this path is correct
import '../../providers/user_data_provider.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _avatarAnimationController;
  late Animation<double> _avatarPulseAnimation;
  late AnimationController _listAnimationController;
  late AnimationController _swipeHintController;
  late Animation<double> _swipeHintFade;
  late Animation<Offset> _swipeHintSlide;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // fetchUserData now also loads avatarUrls
      Provider.of<UserDataProvider>(context, listen: false).fetchUserData();
    });

    _avatarAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _avatarPulseAnimation =
        Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(
      parent: _avatarAnimationController,
      curve: Curves.easeInOut,
    ));

    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _swipeHintController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _swipeHintFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(
        CurvedAnimation(parent: _swipeHintController, curve: Curves.easeInOut));

    _swipeHintSlide =
        Tween<Offset>(begin: const Offset(-0.2, 0), end: const Offset(0.2, 0))
            .animate(CurvedAnimation(
                parent: _swipeHintController, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _listAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _swipeHintController.forward();
    });
  }

  @override
  void dispose() {
    _avatarAnimationController.dispose();
    _listAnimationController.dispose();
    _swipeHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            context.go('/home/relationship-mapping');
          }
        },
        child: Stack(
          children: [
            const _DecorativeBlob(),
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  title: Text('CLARIO',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: isDarkMode ? Colors.white : Colors.black87)),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.settings_outlined,
                          color: isDarkMode ? Colors.white : Colors.black87),
                      onPressed: () => context.go('/home/settings'),
                    ),
                  ],
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 10),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildHeader()),
                    const SizedBox(height: 30),
                    // *** THIS WIDGET IS NOW UPDATED ***
                    _buildMoodAvatar(),
                    const SizedBox(height: 40),
                    _buildActionList(_listAnimationController),
                  ]),
                ),
              ],
            ),
            _buildSwipeHint(),
          ],
        ),
      ),
    );
  }

  // --- BUILDER WIDGETS ---

  Widget _buildSwipeHint() {
    // ... (This widget remains unchanged)
    return Positioned(
      bottom: 20, // Position it above the main navigation bar
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _swipeHintFade,
        child: SlideTransition(
          position: _swipeHintSlide,
          child: Icon(
            Icons.swipe_right_alt_outlined,
            color: Colors.grey.withOpacity(0.5),
            size: 42,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // ... (This widget remains unchanged)
    return Consumer<UserDataProvider>(
      builder: (context, userData, child) {
        final name = userData.user?.name.split(' ').first ?? 'Friend';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, $name',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('How are you feeling today?',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey.shade600)),
          ],
        );
      },
    );
  }

  // --- UPDATED AVATAR WIDGET ---
  Widget _buildMoodAvatar() {
    return Consumer<UserDataProvider>(
      // Consumes the provider
      builder: (context, userDataProvider, child) {
        if (userDataProvider.isLoading && userDataProvider.user == null) {
          // Show loading only if user data isn't available yet
          return const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()));
        }

        // Get the dynamic URL based on current emotion
        final String avatarUrl = userDataProvider.currentAvatarUrl;
        final bool isNetworkImage = avatarUrl.startsWith('http');
        final Color moodColor =
            userDataProvider.getMoodColor(); // Get mood color for shadow

        return Center(
          child: AnimatedBuilder(
            animation: _avatarPulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _avatarPulseAnimation.value,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: moodColor.withOpacity(0.5), // Use mood color
                        blurRadius: 50,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    // Conditional image loading based on URL type
                    child: isNetworkImage
                        ? Image.network(
                            // Loads from Firebase URL
                            avatarUrl,
                            key: ValueKey(
                                avatarUrl), // Add key for smooth updates
                            fit: BoxFit.cover,
                            // Show placeholder/indicator while loading
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            // Show fallback asset on error
                            errorBuilder: (context, error, stackTrace) {
                              print(
                                  "Error loading avatar: $error"); // Log error
                              return Image.asset(
                                'assets/avatars/default_neutral.png', // Fallback
                                fit: BoxFit.cover,
                              );
                            },
                          )
                        : Image.asset(
                            // Loads local fallback asset
                            avatarUrl,
                            key: ValueKey(avatarUrl), // Add key
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  // --- END UPDATED AVATAR WIDGET ---

  Widget _buildActionList(AnimationController animation) {
    // ... (This widget remains unchanged)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          _AnimatedFeatureButton(
            animation: animation,
            interval: const Interval(0.2, 0.6, curve: Curves.easeOut),
            icon: Icons.chat_bubble_rounded,
            label: 'Talk to Clario',
            description: 'Your personal AI companion',
            color: Colors.blue.shade400,
            onTap: () =>
                context.go('/home/clario-AI'), // Ensure route is correct
          ),
          const SizedBox(height: 16),
          _AnimatedFeatureButton(
            animation: animation,
            interval: const Interval(0.4, 0.8, curve: Curves.easeOut),
            icon: Icons.edit_note_rounded,
            label: 'My Journal',
            description: 'Reflect on your day',
            color: Colors.green.shade400,
            onTap: () =>
                context.go('/home/journal-entry'), // Ensure route is correct
          ),
          // --- ADD BUTTON TO TRIGGER GENERATION (Example) ---
          // You might place this elsewhere (e.g., settings page)
          const SizedBox(height: 16),
          _GenerateAvatarButtonExample(), // Add this button temporarily for testing
        ],
      ),
    );
  }
} // End of _MainDashboardScreenState

// --- HELPER & ANIMATION WIDGETS (UNCHANGED) ---

class _DecorativeBlob extends StatelessWidget {
  // ... (Keep as is)
  const _DecorativeBlob();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Positioned(
      top: -100,
      right: -150,
      child: Container(
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color.withOpacity(0.4), color.withOpacity(0.0)]),
        ),
      ),
    );
  }
}

class _AnimatedFeatureButton extends StatelessWidget {
  // ... (Keep as is)
  final AnimationController animation;
  final Interval interval;
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedFeatureButton({
    required this.animation,
    required this.interval,
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final animValue = interval.transform(animation.value);
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animValue)),
          child: Opacity(
            opacity: animValue,
            child: _FeatureButton(
                icon: icon,
                label: label,
                description: description,
                color: color,
                onTap: onTap),
          ),
        );
      },
    );
  }
}

class _FeatureButton extends StatelessWidget {
  // ... (Keep as is)
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _FeatureButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey.shade800 : Colors.white;

    return Card(
      elevation: isDarkMode ? 1 : 5,
      shadowColor: Colors.black.withOpacity(0.1),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Row(
            children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, size: 28, color: color)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// --- EXAMPLE WIDGET TO TRIGGER AVATAR GENERATION ---
// You should move this logic to a more appropriate place like settings
class _GenerateAvatarButtonExample extends StatefulWidget {
  const _GenerateAvatarButtonExample({super.key});

  @override
  State<_GenerateAvatarButtonExample> createState() =>
      _GenerateAvatarButtonExampleState();
}

class _GenerateAvatarButtonExampleState
    extends State<_GenerateAvatarButtonExample> {
  bool _isGenerating = false;
  // Example prompt - get this from user data or settings
  final String _basePrompt = "A 3D avatar of a friendly student, cartoon style";

  void _handleGeneration() async {
    setState(() => _isGenerating = true);
    final provider = Provider.of<UserDataProvider>(context, listen: false);

    try {
      await provider.generateAndSaveAvatars(_basePrompt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Avatars generated!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: ${e.toString()}"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show button if avatars haven't been generated yet (basic check)
    final provider = context.watch<UserDataProvider>();
    final bool avatarsExist = provider.user?.avatarUrls?.isNotEmpty ?? false;

    if (avatarsExist) {
      return SizedBox.shrink(); // Hide if avatars exist
    }

    return _isGenerating
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton.icon(
            icon: Icon(Icons.auto_awesome),
            label: Text("Generate My Avatars"),
            onPressed: _handleGeneration,
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor:
                  Theme.of(context).colorScheme.primary, // Text color
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
          );
  }
}
