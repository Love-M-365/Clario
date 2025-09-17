import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home/home_screen.dart'; // No longer needed, as navigation is handled by router.

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final PageController _pageController = PageController();
  int _currentQuestionIndex = 0;
  final Map<String, dynamic> _answers = {};
  bool _isSubmitting = false;

  final List<Question> _questions = [
    Question(
      id: 'mood_frequency',
      text: 'How often do you experience mood swings or emotional changes?',
      type: QuestionType.multipleChoice,
      options: ['Rarely', 'Sometimes', 'Often', 'Very Often', 'Daily'],
    ),
    Question(
      id: 'stress_level',
      text: 'On a scale of 1-10, how would you rate your current stress level?',
      type: QuestionType.scale,
      minValue: 1,
      maxValue: 10,
    ),
    Question(
      id: 'sleep_quality',
      text: 'How would you describe your sleep quality?',
      type: QuestionType.multipleChoice,
      options: ['Excellent', 'Good', 'Fair', 'Poor', 'Very Poor'],
    ),
    Question(
      id: 'social_anxiety',
      text: 'Do you feel anxious in social situations?',
      type: QuestionType.multipleChoice,
      options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
    ),
    Question(
      id: 'support_system',
      text: 'How strong is your support system (family, friends)?',
      type: QuestionType.multipleChoice,
      options: ['Very Strong', 'Strong', 'Moderate', 'Weak', 'Very Weak'],
    ),
    Question(
      id: 'coping_mechanisms',
      text: 'What are your current coping mechanisms? (Select all that apply)',
      type: QuestionType.multipleSelect,
      options: [
        'Exercise',
        'Music',
        'Art',
        'Talking to friends',
        'Meditation',
        'Gaming',
        'Reading',
        'Other'
      ],
    ),
    Question(
      id: 'therapy_experience',
      text: 'Have you had any previous experience with therapy or counseling?',
      type: QuestionType.multipleChoice,
      options: [
        'Yes, positive experience',
        'Yes, negative experience',
        'Yes, mixed experience',
        'No, but interested',
        'No, not interested'
      ],
    ),
    Question(
      id: 'main_concerns',
      text:
          'What are your main mental health concerns? (Select all that apply)',
      type: QuestionType.multipleSelect,
      options: [
        'Anxiety',
        'Depression',
        'Stress',
        'Self-esteem',
        'Relationships',
        'Academic pressure',
        'Family issues',
        'Other'
      ],
    ),
    Question(
      id: 'goals',
      text: 'What do you hope to achieve with Clario?',
      type: QuestionType.multipleSelect,
      options: [
        'Better mood management',
        'Stress reduction',
        'Improved sleep',
        'Better relationships',
        'Increased confidence',
        'Coping skills',
        'Self-understanding'
      ],
    ),
    Question(
      id: 'communication_preference',
      text: 'How do you prefer to communicate about your feelings?',
      type: QuestionType.multipleChoice,
      options: [
        'Text/Writing',
        'Voice/Speaking',
        'Visual/Art',
        'Music',
        'No preference'
      ],
    ),
  ];

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitQuestionnaire();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitQuestionnaire() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');

        await userRef.update({
          'questionnaire_answers': _answers,
          'questionnaire_completed_at': ServerValue.timestamp,
          'registration_completed': true,
        });

        // Use a PostFrameCallback to safely navigate after the build finishes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/home');
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting questionnaire: $e')),
      );
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              // Progress bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          '${((_currentQuestionIndex + 1) / _questions.length * 100).round()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: (_currentQuestionIndex + 1) / _questions.length,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),
              // Questions
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    return _buildQuestionPage(_questions[index]);
                  },
                ),
              ),
              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentQuestionIndex > 0)
                      ElevatedButton(
                        onPressed: _previousQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Previous'),
                      )
                    else
                      const SizedBox(width: 80),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator()
                          : Text(_currentQuestionIndex == _questions.length - 1
                              ? 'Complete'
                              : 'Next'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionPage(Question question) {
    return Padding(
      padding: const EdgeInsets.all(20),
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
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.text,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: _buildQuestionInput(question),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionInput(Question question) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        return _buildMultipleChoice(question);
      case QuestionType.multipleSelect:
        return _buildMultipleSelect(question);
      case QuestionType.scale:
        return _buildScale(question);
      case QuestionType.text:
        return _buildTextInput(question);
    }
  }

  Widget _buildMultipleChoice(Question question) {
    return ListView.builder(
      itemCount: question.options!.length,
      itemBuilder: (context, index) {
        final option = question.options![index];
        final isSelected = _answers[question.id] == option;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              setState(() {
                _answers[question.id] = option;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2) // Highlight color
                    : null,
                border: Border.all(
                  color:
                      isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: option,
                    groupValue: _answers[question.id],
                    onChanged: (value) {
                      setState(() {
                        _answers[question.id] = value;
                      });
                    },
                    fillColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return Colors.white; // Selected radio button color
                        }
                        return Colors.white
                            .withOpacity(0.5); // Unselected color
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultipleSelect(Question question) {
    final selectedOptions = _answers[question.id] as List<String>? ?? [];

    return ListView.builder(
      itemCount: question.options!.length,
      itemBuilder: (context, index) {
        final option = question.options![index];
        final isSelected = selectedOptions.contains(option);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  selectedOptions.remove(option);
                } else {
                  selectedOptions.add(option);
                }
                _answers[question.id] = selectedOptions;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : null,
                border: Border.all(
                  color:
                      isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedOptions.add(option);
                        } else {
                          selectedOptions.remove(option);
                        }
                        _answers[question.id] = selectedOptions;
                      });
                    },
                    fillColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return Colors.white; // Selected checkbox color
                        }
                        return Colors.white
                            .withOpacity(0.5); // Unselected color
                      },
                    ),
                    checkColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScale(Question question) {
    final currentValue =
        _answers[question.id] as double? ?? question.minValue!.toDouble();

    return Column(
      children: [
        Text(
          currentValue.round().toString(),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 20),
        Slider(
          value: currentValue,
          min: question.minValue!.toDouble(),
          max: question.maxValue!.toDouble(),
          divisions: question.maxValue! - question.minValue!,
          onChanged: (value) {
            setState(() {
              _answers[question.id] = value;
            });
          },
          activeColor: Colors.white,
          inactiveColor: Colors.white.withOpacity(0.5),
          thumbColor: Theme.of(context).colorScheme.secondary,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${question.minValue}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              '${question.maxValue}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextInput(Question question) {
    return TextFormField(
      maxLines: 5,
      style: const TextStyle(color: Colors.white),
      initialValue: _answers[question.id] as String?,
      decoration: InputDecoration(
        hintText: 'Type your answer here...',
        hintStyle: TextStyle(color: Colors.grey[500]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      onChanged: (value) {
        _answers[question.id] = value;
      },
    );
  }
}

class Question {
  final String id;
  final String text;
  final QuestionType type;
  final List<String>? options;
  final int? minValue;
  final int? maxValue;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options,
    this.minValue,
    this.maxValue,
  });
}

enum QuestionType {
  multipleChoice,
  multipleSelect,
  scale,
  text,
}
