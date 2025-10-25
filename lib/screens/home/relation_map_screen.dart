import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

// Make sure this import path is correct for your project structure
import '../../providers/user_data_provider.dart';
// Assuming Relation class is defined here or in a models file
import '../../providers/user_data_provider.dart' show Relation;

// --- START: GRAPH WIDGETS AND HELPERS ---
// (These are moved from main_dashboard_screen.dart)

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
  // Start the first node slightly offset to improve aesthetics
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
                          fontSize: 10,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        relation.sentiment,
                        style: TextStyle(
                          color: sentimentColor,
                          fontSize: 8,
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

      // --- 1. Line Paint ---
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

      // --- 2. Label Paint (Times Mentioned) ---
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
// --- END: GRAPH WIDGETS AND HELPERS ---

/// A dedicated screen to display the social connection map.
class RelationMapScreen extends StatefulWidget {
  const RelationMapScreen({super.key});

  @override
  State<RelationMapScreen> createState() => _RelationMapScreenState();
}

class _RelationMapScreenState extends State<RelationMapScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch relations data when this screen is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserDataProvider>(context, listen: false).fetchRelations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use the same dark gradient for a seamless, cool look
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C1324), // Dark blue
              Color(0xFF131A2D), // Slightly lighter dark blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // A custom app bar to match the theme
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Social Connection Map',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balances the back button
                  ],
                ),
              ),
              // The graph takes up the remaining space
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildRelationshipGraph(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// This is the logic from your original _buildRelationshipMapping method
  Widget _buildRelationshipGraph() {
    return Consumer<UserDataProvider>(
      builder: (context, provider, child) {
        if (provider.isRelationsLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 150.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final relations = provider.relations;
        final count = relations.length;
        // Give it more vertical space on its own screen
        const double graphHeight = 500;
        const double nodeSize = 60;

        if (relations.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
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
            final centerPoint =
                Offset(constraints.maxWidth / 2, graphHeight / 2);
            final double radius =
                (constraints.maxWidth / 2) - (nodeSize / 2) - 10;
            final relationPositions =
                _calculateNodePositions(count, radius, centerPoint);

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
            for (int i = 0; i < count; i++) {
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
                      // TODO: Navigate to relation detail screen
                    },
                  ),
                ),
              );
            }

            return Container(
              height: graphHeight,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(constraints.maxWidth, graphHeight),
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
    );
  }
}
