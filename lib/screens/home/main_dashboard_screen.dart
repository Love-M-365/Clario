// lib/screens/main_dashboard_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui'; // ⭐️ For ImageFilter.blur
import 'dart:math' as math; // For graph calculations
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

// 🟢 Make sure this import path is correct for your project
import '../weekly_mood_section.dart';

// 🟢 Make sure this import path is correct for your project
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

  // ✨ ADDED: Animation controller for the graph
  late AnimationController _graphAnimationController;

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

    // ✨ ADDED: Initialize graph controller
    _graphAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
    _graphAnimationController.dispose(); // ✨ ADDED: Dispose controller
    super.dispose();
  }

  // ✨ ADDED: Helper method to show relation details
  // --- ✨ REPLACEMENT for _showRelationDetails ---

  void _showRelationDetails(BuildContext context, Relation relation) {
    final sentimentColor = _getSentimentColor(relation.sentiment);
    String lastInteractionDate = 'No interactions yet';
    final theme = Theme.of(context); // Get the theme

    // Define text colors for light mode
    final primaryTextColor = Colors.grey[900];
    final secondaryTextColor = Colors.grey[700];

    // Try to parse and format the date
    try {
      if (relation.lastMentioned.isNotEmpty) {
        // Assuming lastMentioned is a full ISO 8601 string
        final dateTime = DateTime.parse(relation.lastMentioned);
        // Format it nicely
        lastInteractionDate = DateFormat.yMMMd().add_jm().format(dateTime);
      }
    } catch (e) {
      // Fallback if date parsing fails
      lastInteractionDate = relation.lastMentioned;
    }

    showModalBottomSheet(
      context: context,
      // ✨ FIX: Use the theme's canvas color (white)
      backgroundColor: theme.canvasColor,
      isScrollControlled: true, // Important for dynamic content
      // ✨ FIX: Modern rounded corners
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        // ✨ FIX: Removed BackdropFilter and dark gradient
        return Container(
          // ✨ FIX: Added padding for the content AND the bottom safe area
          padding: EdgeInsets.fromLTRB(
            24.0,
            16.0, // Reduced top padding for drag handle
            24.0,
            MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          decoration: BoxDecoration(
            color: theme.canvasColor, // Solid white background
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            // ✨ FIX: Soft shadow for a "card" effect
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fixes sizing
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✨ UI: Added a drag handle for polish
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // ✨ FIX: Dark text color
              Text(
                relation.name,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow(
                Icons.favorite_rounded,
                'Last Sentiment',
                relation.sentiment,
                sentimentColor, // This color is dynamic (red/green)
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                Icons.stacked_line_chart_rounded,
                'Times Mentioned',
                '${relation.timesMentioned}x',
                primaryTextColor, // ✨ FIX: Use dark text
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

// --- ✨ REPLACEMENT for _buildDetailRow ---
  Widget _buildDetailRow(
      IconData icon, String label, String value, Color? valueColor) {
    final theme = Theme.of(context);
    // ✨ FIX: Use a default dark color if valueColor is null
    final Color finalValueColor = valueColor ?? Colors.grey[900]!;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start, // Align top for wrapped text
      children: [
        // ✨ FIX: Use a softer grey for the icon
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 16),
        // ✨ FIX: Use a softer grey for the label
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 16,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 16), // Add spacing before the value
        // ✨ 🟢 SIZE ERROR FIX 🟢 ✨
        // Wrap the value text in Flexible so it can wrap to a new line
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right, // Keep text aligned to the right
            overflow: TextOverflow.ellipsis, // Add ellipsis if it's too long
            maxLines: 3, // Allow up to 3 lines
            style: TextStyle(
              color: finalValueColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildAppDrawer(context),
      drawerDragStartBehavior: DragStartBehavior.down,
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
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                      // ✨ ADDED: Trigger graph animation on open
                      _graphAnimationController.forward(from: 0.0);
                    },
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
                    child: _buildHeader(),
                  ),
                  const SizedBox(height: 30),
                  _buildMoodAvatar(),
                  const SizedBox(height: 30),
                  _buildActionList(_listAnimationController),
                  const SizedBox(height: 40),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ✨ MODIFIED FOR LIGHT MODE ---
  Widget _buildAppDrawer(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.9, // Make it wide
      backgroundColor:
          theme.canvasColor, // Uses your theme's canvas color (usually white)
      elevation: 4.0, // Add a subtle shadow
      child: SafeArea(
        // We call the graph-building widget here
        child: _buildRelationshipGraph(),
      ),
    );
  }

// --- ✨ MODIFIED FOR LIGHT MODE ---
  Widget _buildRelationshipGraph() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Social Connection Map',
              style: TextStyle(
                color: Colors.grey[800], // Dark text
                fontWeight: FontWeight.bold,
                fontSize: 24,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Your network based on your AI Chats.',
              style: TextStyle(
                color: Colors.grey[600], // Softer dark text
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Consumer<UserDataProvider>(
              builder: (context, provider, child) {
                if (provider.isRelationsLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary, // Use theme color
                    ),
                  );
                }

                final relations = provider.relations;
                if (relations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'No social relationships mapped yet.\nStart reflecting to reveal your network!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700], fontSize: 16),
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    const double nodeSize = 60;
                    final centerPoint = Offset(
                      constraints.maxWidth / 2,
                      constraints.maxHeight * 0.45,
                    );

                    final double radius =
                        (math.min(constraints.maxWidth, constraints.maxHeight) /
                                2) -
                            (nodeSize / 2) -
                            20;

                    final relationPositions = _calculateNodePositions(
                        relations.length, radius, centerPoint);

                    final centerRelation = Relation(
                      name: 'You',
                      sentiment: 'Neutral',
                      timesMentioned: 0,
                      lastMentioned: '',
                    );

                    final List<Widget> positionedNodes = [];

                    // Center Node
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

                    // Other Nodes
                    for (int i = 0; i < relations.length; i++) {
                      final relation = relations[i];
                      final position = relationPositions[i];

                      // ✨ ADDED: Staggered animation for each node
                      final double delay =
                          (i.toDouble() / relations.length.toDouble()) * 0.5;
                      final double end = math.min(delay + 0.6, 1.0);
                      final interval =
                          Interval(delay, end, curve: Curves.easeOut);

                      positionedNodes.add(
                        Positioned(
                          left: position.dx - nodeSize / 2,
                          top: position.dy - nodeSize / 2,
                          child: ScaleTransition(
                            scale: _graphAnimationController.drive(
                              CurveTween(curve: interval),
                            ),
                            child: FadeTransition(
                              opacity: _graphAnimationController.drive(
                                CurveTween(curve: interval),
                              ),
                              child: GraphNode(
                                relation: relation,
                                isCenter: false,
                                onTap: () {
                                  // ✨ ADDED: Tappable nodes
                                  _showRelationDetails(context, relation);
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100], // Light grey background
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey[300]!, // Subtle border
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // ✨ ADDED: Animate the painter too
                          FadeTransition(
                            opacity: _graphAnimationController,
                            child: CustomPaint(
                              size: Size(
                                  constraints.maxWidth, constraints.maxHeight),
                              painter: GraphLinkPainter(
                                relations: relations,
                                relationPositions: relationPositions,
                                center: centerPoint,
                              ),
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
      ),
    );
  }

  // --- BUILDER WIDGETS (UNCHANGED) ---
  // (Omitted for brevity, paste them in from your file)
  Widget _buildHeader() {
    // ... (Your existing _buildHeader code)
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
    // ... (Your existing _buildMoodAvatar code)
    return Consumer<UserDataProvider>(
      builder: (context, userDataProvider, child) {
        if (userDataProvider.isLoading && userDataProvider.user == null) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Get current avatar URL or fall back to default
        final String? avatarUrl = userDataProvider.currentAvatarUrl;
        final String safeAvatarUrl = (avatarUrl != null && avatarUrl.isNotEmpty)
            ? avatarUrl
            : 'assets/avatars/default_neutral.png';
        final bool isNetworkImage = safeAvatarUrl.startsWith('http');
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
                    // === Multicolor circular ring ===
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
                            Colors.red,
                          ],
                          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                        ),
                      ),
                    ),

                    // Inner white spacing
                    Container(
                      width: 182,
                      height: 182,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),

                    // === Avatar image ===
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
                                safeAvatarUrl,
                                key: ValueKey(safeAvatarUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // 🟢 Always show default avatar on error
                                  return Image.asset(
                                    'assets/avatars/default_neutral.png',
                                    fit: BoxFit.cover,
                                  );
                                },
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              )
                            : Image.asset(
                                safeAvatarUrl,
                                key: ValueKey(safeAvatarUrl),
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
    // ... (Your existing _buildActionList code)
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

// --- HELPER & ANIMATION WIDGETS ---
// (Paste your existing _DecorativeBlob, _AnimatedFeatureButton,
// _FeatureButton, and _GenerateAvatarButtonExample widgets here)
// ...
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
    final provider = Provider.of<UserDataProvider>(context, listen: false);

    try {
      await provider.generateAndSaveAvatars(_basePrompt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
    final provider = context.watch<UserDataProvider>();
    final bool avatarsExist = provider.user?.avatarUrls?.isNotEmpty ?? false;

    if (avatarsExist) {
      return const SizedBox.shrink();
    }

    return _isGenerating
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text("Generate My Avatars"),
            onPressed: _handleGeneration,
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
          );
  }
}
// ---

// ---
// --- ⭐️ GRAPH HELPER WIDGETS AND PAINTER ⭐️
// ---

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

List<Offset> _calculateNodePositions(int count, double radius, Offset center) {
  List<Offset> positions = [];
  double startAngle = -math.pi / 2 - (math.pi / 20);
  double angleIncrement = (2 * math.pi) / count;

  for (int i = 0; i < count; i++) {
    double angle = startAngle + (i * angleIncrement);
    double x = center.dx + radius * math.cos(angle);
    double y = center.dy + radius * math.sin(angle);
    positions.add(Offset(x, y));
  }
  return positions;
}

// ✨ CONVERTED TO STATEFULWIDGET FOR PULSE ANIMATION
// --- ⭐️ GRAPH HELPER WIDGETS AND PAINTER (LIGHT MODE) ⭐️ ---

// ... (Your _getSentimentColor and _calculateNodePositions functions) ...
// (They don't need to change)

/// A widget representing a single person node in the graph.
class GraphNode extends StatefulWidget {
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
  State<GraphNode> createState() => _GraphNodeState();
}

class _GraphNodeState extends State<GraphNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Only animate if it's the center node
    if (widget.isCenter) {
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat(reverse: true);

      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (widget.isCenter) {
      _pulseController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentimentColor = _getSentimentColor(widget.relation.sentiment);
    const double size = 60;
    final String displayName = widget.isCenter ? 'You' : widget.relation.name;
    final theme = Theme.of(context);

    Widget nodeContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // ✨ MODIFIED: Center node uses theme color, others are clean white
        color:
            widget.isCenter ? theme.colorScheme.primaryContainer : Colors.white,
        border: Border.all(
          color: widget.isCenter ? theme.colorScheme.primary : sentimentColor,
          width: widget.isCenter ? 3.0 : 2.0,
        ),
        boxShadow: [
          // ✨ MODIFIED: Center node gets its glow, others get a soft shadow
          widget.isCenter
              ? BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.7),
                  blurRadius: 10,
                  spreadRadius: 3,
                )
              : BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
          // Add sentiment glow *under* the shadow for non-center nodes
          if (!widget.isCenter)
            BoxShadow(
              color: sentimentColor.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 0,
            ),
        ],
      ),
      child: Center(
        child: widget.isCenter
            ? Icon(
                Icons.person_pin,
                color: theme.colorScheme.onPrimaryContainer,
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
                        // ✨ MODIFIED: Dark text
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.relation.sentiment,
                      style: TextStyle(
                        color: sentimentColor, // Sentiment color is still good
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );

    // If it's the center node, wrap it in the pulse animation
    if (widget.isCenter) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(size),
          child: nodeContent,
        ),
      );
    }

    // Otherwise, just return the standard node
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(size),
      child: nodeContent,
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
    // ✨ MODIFIED: Label background is now a soft white
    final labelBackgroundPaint = Paint()..color = Colors.white.withOpacity(0.8);

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

      // ... (Curve logic is unchanged) ...
      final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final perpDx = -dy;
      final perpDy = dx;
      final length = math.sqrt(perpDx * perpDx + perpDy * perpDy);
      final controlOffset =
          length != 0 ? Offset(perpDx / length, perpDy / length) : Offset(0, 0);

      final offsetFactor = size.width * (0.02 + (i % 5) * 0.01);
      final controlPoint = midPoint + controlOffset * offsetFactor;

      final path = Path();
      path.moveTo(start.dx, start.dy);
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, end.dx, end.dy);
      canvas.drawPath(path, linePaint);

      // ✨ MODIFIED: Draw a soft white background for readability
    }
  }

  @override
  bool shouldRepaint(covariant GraphLinkPainter oldDelegate) {
    return oldDelegate.relations != relations ||
        oldDelegate.relationPositions != relationPositions;
  }
}
