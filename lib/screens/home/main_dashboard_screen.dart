// lib/screens/main_dashboard_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui'; // For blur effect
import 'dart:math' as math; // For graph calculations

// Ensure this path is correct
import '../../providers/user_data_provider.dart';
// Import the Relation class
import '../../providers/user_data_provider.dart' show Relation;

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<UserDataProvider>(context, listen: false);

      // Fetch base data
      await provider.fetchUserData();
      await provider.fetchRelations();

      // 🔥 NEW: Update avatar according to latest journal entry
      await provider.updateAvatarFromLatestJournal();
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

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _listAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _avatarAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // --- MODIFIED: The drawer is now the graph itself ---
      drawer: _buildAppDrawer(context),
      drawerDragStartBehavior: DragStartBehavior.down,
      // --- REMOVED: GestureDetector for swipe-left navigation ---
      body: Stack(
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
                        color: iconColor)),
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.account_tree_outlined, color: iconColor),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    tooltip: 'Relationship Map', // Updated tooltip
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: iconColor),
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
                  _buildMoodAvatar(),
                  const SizedBox(height: 40),
                  _buildActionList(_listAnimationController),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MODIFIED: This now builds the graph inside the drawer ---
  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
      // Use the dark theme for the graph background
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 245, 245, 245), // Dark blue
              Color.fromARGB(255, 217, 224, 243), // Slightly lighter dark blue
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            // We call the graph-building widget here
            child: _buildRelationshipGraph(),
          ),
        ),
      ),
    );
  }

  // --- NEW: This method is moved from relation_map_screen.dart ---
  /// Builds the interactive relationship graph
  Widget _buildRelationshipGraph() {
    return Column(
      children: [
        const Text(
          'Social Connection Map',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Consumer<UserDataProvider>(
            builder: (context, provider, child) {
              if (provider.isRelationsLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                );
              }

              final relations = provider.relations;
              if (relations.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'No social relationships mapped yet. Start reflecting to see your network!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  const double nodeSize = 60;
                  final centerPoint = Offset(
                      constraints.maxWidth / 2, constraints.maxHeight / 2);

                  final double radius =
                      (math.min(constraints.maxWidth, constraints.maxHeight) /
                              2) -
                          (nodeSize / 2) -
                          10;

                  final relationPositions = _calculateNodePositions(
                      relations.length, radius, centerPoint);

                  final centerRelation = Relation(
                    name: 'You',
                    sentiment: 'Neutral',
                    timesMentioned: 0,
                    lastMentioned: '',
                  );

                  final List<Widget> positionedNodes = [];

                  // 1. Center Node (The User)
                  positionedNodes.add(
                    Positioned(
                      left: centerPoint.dx - nodeSize / 2,
                      top: centerPoint.dy - nodeSize / 2,
                      child: GraphNode(
                        relation: centerRelation,
                        isCenter: true,
                        onTap: () {},
                      ),
                    ),
                  );

                  // 2. Relation Nodes
                  for (int i = 0; i < relations.length; i++) {
                    final relation = relations[i];
                    final position = relationPositions[i];
                    positionedNodes.add(
                      Positioned(
                        left: position.dx - nodeSize / 2,
                        top: position.dy - nodeSize / 2,
                        child: GraphNode(
                          relation: relation,
                          isCenter: false,
                          onTap: () {
                            // TODO: Show relation detail
                          },
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size:
                              Size(constraints.maxWidth, constraints.maxHeight),
                          painter: GraphLinkPainter(
                            relations: relations,
                            relationPositions: relationPositions,
                            center: centerPoint,
                          ),
                        ),
                        ...positionedNodes,
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- BUILDER WIDGETS (UNCHANGED) ---

  Widget _buildHeader() {
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

  Widget _buildMoodAvatar() {
    return Consumer<UserDataProvider>(
      builder: (context, userDataProvider, child) {
        if (userDataProvider.isLoading && userDataProvider.user == null) {
          return const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()));
        }

        final String avatarUrl = userDataProvider.currentAvatarUrl;
        final bool isNetworkImage = avatarUrl.startsWith('http');
        final Color moodColor = userDataProvider.getMoodColor();

        return Center(
          child: AnimatedBuilder(
            animation: _avatarPulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _avatarPulseAnimation.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // === NEW: Multicolor circular ring ===
                    Container(
                      width: 205,
                      height: 205,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.red,
                            Colors.yellow,
                            Colors.green,
                            Colors.blue,
                            Colors.red, // closes the loop
                          ],
                          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                        ),
                      ),
                    ),

                    // Inner white gap for spacing
                    Container(
                      width: 182,
                      height: 182,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),

                    // === Original glowing mood avatar ===
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: moodColor.withOpacity(0.5),
                            blurRadius: 50,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: isNetworkImage
                            ? Image.network(
                                avatarUrl,
                                key: ValueKey(avatarUrl),
                                fit: BoxFit.cover,
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
                                errorBuilder: (context, error, stackTrace) {
                                  print("Error loading avatar: $error");
                                  return Image.asset(
                                    'assets/avatars/default_neutral.png',
                                    fit: BoxFit.cover,
                                  );
                                },
                              )
                            : Image.asset(
                                avatarUrl,
                                key: ValueKey(avatarUrl),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionList(AnimationController animation) {
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
            onTap: () => context.go('/home/clario-AI'),
          ),
          const SizedBox(height: 16),
          _AnimatedFeatureButton(
            animation: animation,
            interval: const Interval(0.4, 0.8, curve: Curves.easeOut),
            icon: Icons.edit_note_rounded,
            label: 'My Journal',
            description: 'Reflect on your day',
            color: Colors.green.shade400,
            onTap: () => context.go('/home/journal-entry'),
          ),
          const SizedBox(height: 16),
          _GenerateAvatarButtonExample(),
        ],
      ),
    );
  }
} // End of _MainDashboardScreenState

// --- HELPER & ANIMATION WIDGETS (UNCHANGED) ---

class _DecorativeBlob extends StatelessWidget {
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

// --- EXAMPLE WIDGET (FIXED) ---
class _GenerateAvatarButtonExample extends StatefulWidget {
  const _GenerateAvatarButtonExample({super.key});

  @override
  State<_GenerateAvatarButtonExample> createState() =>
      _GenerateAvatarButtonExampleState();
}

class _GenerateAvatarButtonExampleState
    extends State<_GenerateAvatarButtonExample> {
  bool _isGenerating = false;
  final String _basePrompt = "A 3D avatar of a friendly student, cartoon style";

  void _handleGeneration() async {
    setState(() => _isGenerating = true);
    // --- FIX: Corrected 'new_context' to 'context' ---
    final provider = Provider.of<UserDataProvider>(context, listen: false);

    try {
      await provider.generateAndSaveAvatars(_basePrompt);
      if (mounted) {
        // --- FIX: Corrected 'new_context' to 'context' ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Avatars generated!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        // --- FIX: Corrected 'new_context' to 'context' ---
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
    // --- FIX: Corrected 'new_context' to 'context' ---
    // --- FIX: Corrected 'new_context' to 'context' ---
    final provider = context.watch<UserDataProvider>();
    final bool avatarsExist = provider.user?.avatarUrls?.isNotEmpty ?? false;

    if (avatarsExist) {
      return SizedBox.shrink();
    }

    return _isGenerating
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton.icon(
            icon: Icon(Icons.auto_awesome),
            label: Text("Generate My Avatars"),
            onPressed: _handleGeneration,
            style: ElevatedButton.styleFrom(
              // --- FIX: Corrected 'new_context' to 'context' ---
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
          );
  }
}

// ---
// --- NEW: GRAPH HELPER WIDGETS AND PAINTER
// --- (Moved from relation_map_screen.dart)
// ---

/// Helper function to convert sentiment string to a color
Color _getSentimentColor(String sentiment) {
  switch (sentiment.toLowerCase()) {
    case 'conflict':
      return Colors.redAccent.shade400;
    case 'supportive':
      return Colors.greenAccent.shade400;
    case 'neutral':
      return Colors.blueGrey.shade300;
    default:
      return Colors.amber.shade400;
  }
}

/// Helper function to calculate node positions in a circle
List<Offset> _calculateNodePositions(int count, double radius, Offset center) {
  List<Offset> positions = [];
  double startAngle = -math.pi / 2 - (math.pi / 20);
  double angleIncrement = 2 * math.pi / count;

  for (int i = 0; i < count; i++) {
    double angle = startAngle + (i * angleIncrement);
    double x = center.dx + radius * math.cos(angle);
    double y = center.dy + radius * math.sin(angle);
    positions.add(Offset(x, y));
  }
  return positions;
}

/// A widget representing a single person node in the graph.
class GraphNode extends StatelessWidget {
  final Relation relation;
  final bool isCenter;
  final VoidCallback onTap;

  const GraphNode({
    super.key,
    required this.relation,
    required this.isCenter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sentimentColor = _getSentimentColor(relation.sentiment);
    const double size = 60;
    final String displayName = isCenter ? 'You' : relation.name;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCenter
              ? Colors.deepPurple.shade900
              : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isCenter ? Colors.white : sentimentColor,
            width: isCenter ? 3.0 : 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isCenter
                  ? Colors.deepPurpleAccent.withOpacity(0.7)
                  : sentimentColor.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: isCenter ? 3 : 1,
            ),
          ],
        ),
        child: Center(
          child: isCenter
              ? const Icon(
                  Icons.star,
                  color: Colors.amberAccent,
                  size: 30,
                )
              : Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        relation.sentiment,
                        style: TextStyle(
                          color: sentimentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// CustomPainter to draw the curved "hand-drawn" links between nodes
class GraphLinkPainter extends CustomPainter {
  final List<Relation> relations;
  final List<Offset> relationPositions;
  final Offset center;

  GraphLinkPainter({
    required this.relations,
    required this.relationPositions,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < relations.length; i++) {
      final relation = relations[i];
      final start = center;
      final end = relationPositions[i];
      final color = _getSentimentColor(relation.sentiment);

      final linePaint = Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final perpDx = -dy;
      final perpDy = dx;
      final length = math.sqrt(perpDx * perpDx + perpDy * perpDy);
      final controlOffset =
          length != 0 ? Offset(perpDx / length, perpDy / length) : Offset(0, 0);

      final offsetFactor = size.width * (0.02 + i * 0.005);
      final controlPoint = midPoint + controlOffset * offsetFactor;

      final path = Path();
      path.moveTo(start.dx, start.dy);
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, end.dx, end.dy);
      canvas.drawPath(path, linePaint);

      final labelText = '${relation.timesMentioned}x';
      const labelTextSize = 12.0;
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: labelTextSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(blurRadius: 3.0, color: color, offset: const Offset(0.5, 0.5)),
        ],
      );

      final textPainter = TextPainter(
        text: TextSpan(text: labelText, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelPosition = controlPoint.translate(
        -textPainter.width / 2,
        -textPainter.height - 8,
      );

      textPainter.paint(canvas, labelPosition);
    }
  }

  @override
  bool shouldRepaint(covariant GraphLinkPainter oldDelegate) {
    return oldDelegate.relations != relations ||
        oldDelegate.relationPositions != relationPositions;
  }
}
