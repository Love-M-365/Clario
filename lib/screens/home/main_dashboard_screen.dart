import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme_data.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _avatarAnimationController;
  late Animation<double> _avatarPulseAnimation;
  final TextEditingController _reflectionController = TextEditingController();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _avatarAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _avatarPulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _avatarAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _avatarAnimationController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Use dark blue and a slightly lighter dark blue for the gradient
            colors: [
              Color(0xFF0C1324), // Dark blue
              Color(0xFF131A2D), // Slightly lighter dark blue
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                _buildMoodAvatar(),
                const SizedBox(height: 30),
                // Modified Card widget for reflection input
                _buildReflectionInput(),
                const SizedBox(height: 30),
                // Modified Card widget for relationship mapping
                _buildRelationshipMapping(),
                const SizedBox(height: 30),
                // Modified Card widget for action buttons
                _buildActionButtons(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        // Set text color to white for visibility
                        color: Colors.white,
                      ),
                ),
                Text(
                  'How are you feeling today?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        // Set text color to a lighter grey
                        color: Colors.grey[400],
                      ),
                ),
              ],
            ),
            IconButton(
              onPressed: () {
                authProvider.signOut();
              },
              icon: const Icon(Icons.logout),
              color: Colors.white,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMoodAvatar() {
    return Consumer<UserDataProvider>(
      builder: (context, userDataProvider, child) {
        return Center(
          child: AnimatedBuilder(
            animation: _avatarPulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _avatarPulseAnimation.value,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        userDataProvider.getMoodColor().withOpacity(0.3),
                        userDataProvider.getMoodColor().withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: userDataProvider.getMoodColor().withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: userDataProvider.getMoodColor(),
                      ),
                      child: Icon(
                        _getMoodIcon(
                            userDataProvider.currentMoodData?['mood_score'] ??
                                5),
                        size: 80,
                        color: Colors.white,
                      ),
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

  IconData _getMoodIcon(int moodScore) {
    if (moodScore >= 8) return Icons.sentiment_very_satisfied;
    if (moodScore >= 6) return Icons.sentiment_satisfied;
    if (moodScore >= 4) return Icons.sentiment_neutral;
    if (moodScore >= 2) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }

  Widget _buildReflectionInput() {
    return Card(
      // The image does not have an elevation on its widgets, so we'll set it to 0
      elevation: 0,
      color: Colors.white.withOpacity(
          0.05), // A semi-transparent white for the "frosted" effect
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        // Add a subtle border to match the image
        side: BorderSide(
          color: Colors.white.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Reflection',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _reflectionController,
              maxLines: 4,
              style: const TextStyle(
                  color: Colors.white), // Set text color to white
              decoration: InputDecoration(
                hintText:
                    'How was your day? Share your thoughts and feelings...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                // Make the TextField fill color slightly darker or transparent
                fillColor: Colors.white.withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveReflection,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Reflection'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _toggleVoiceInput,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening
                        ? Colors.red
                        : Theme.of(context).colorScheme.secondary,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(15),
                  ),
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipMapping() {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Relationship Network',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 200,
              decoration: BoxDecoration(
                // Use a slightly different semi-transparent color for the inner container
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_tree,
                      size: 60,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Relationship mapping will appear here',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[400],
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            color: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1.0,
              ),
            ),
            child: InkWell(
              onTap: _showAIChatDialog,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.chat,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Talk to AI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Card(
            elevation: 0,
            color: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1.0,
              ),
            ),
            child: InkWell(
              onTap: _showEmptyChairDialog,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.chair,
                      size: 40,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Empty Chair',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Card(
            elevation: 0,
            color: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1.0,
              ),
            ),
            child: InkWell(
              onTap: _showSleepAnalysisDialog,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.bedtime,
                      size: 40,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sleep Analysis',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _saveReflection() async {
    if (_reflectionController.text.isNotEmpty) {
      final userDataProvider =
          Provider.of<UserDataProvider>(context, listen: false);
      await userDataProvider.saveReflection(_reflectionController.text, 'text');
      _reflectionController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reflection saved successfully!')),
      );
    }
  }

  void _toggleVoiceInput() {
    setState(() {
      _isListening = !_isListening;
    });

    // TODO: Implement speech-to-text functionality
    if (_isListening) {
      // Start listening
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Voice input started (feature coming soon)')),
      );
    } else {
      // Stop listening
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input stopped')),
      );
    }
  }

  void _showAIChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Chat'),
        content: const Text(
            'AI chat feature will be integrated with your Google AI Cloud services.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEmptyChairDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Chair Therapy'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Empty Chair Therapy is a powerful technique where you:'),
            SizedBox(height: 10),
            Text('1. Imagine someone sitting in an empty chair'),
            Text('2. Express your feelings to them'),
            Text('3. Switch perspectives and respond as them'),
            Text('4. Continue the dialogue for healing'),
            SizedBox(height: 10),
            Text('This helps process emotions and improve relationships.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Start Session'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSleepAnalysisDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sleep Analysis'),
        content: const Text(
            'Sleep tracking and analysis features will help you monitor your sleep patterns and provide personalized recommendations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
