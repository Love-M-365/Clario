import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:clario/providers/theme_provider.dart';
import 'package:clario/utils/theme_data.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _currentSound = '';
  int _sleepGoal = 8;
  double _lastNightSleep = 7.5;

  final List<Map<String, dynamic>> _sleepSounds = [
    {
      'name': 'Rain',
      'icon': Icons.grain,
      'color': const Color(0xFF2196F3),
      'url': 'sounds/rain.mp3',
    },
    {
      'name': 'Ocean',
      'icon': Icons.waves,
      'color': const Color(0xFF00BCD4),
      'url': 'sounds/ocean.mp3',
    },
    {
      'name': 'Forest',
      'icon': Icons.park,
      'color': const Color(0xFF4CAF50),
      'url': 'sounds/forest.mp3',
    },
    {
      'name': 'White Noise',
      'icon': Icons.blur_on,
      'color': const Color(0xFF9E9E9E),
      'url': 'sounds/white_noise.mp3',
    },
  ];

  final List<double> _weeklyData = [6.5, 7.0, 8.0, 6.0, 7.5, 8.5, 7.5];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playSound(String soundUrl, String soundName) async {
    if (_isPlaying && _currentSound == soundName) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _currentSound = '';
      });
    } else {
      await _audioPlayer.stop();
      // In a real app, you would play the actual sound file
      // await _audioPlayer.play(AssetSource(soundUrl));
      setState(() {
        _isPlaying = true;
        _currentSound = soundName;
      });

      // Simulate playing for demo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing $soundName (Demo mode)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sleep Tracker',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Better sleep, better mind',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.bedtime,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(
                          duration: 800.ms,
                        )
                        .slideX(
                          begin: -0.3,
                          duration: 800.ms,
                          curve: Curves.easeOut,
                        ),

                    const SizedBox(height: 32),

                    // Sleep Goal Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Sleep Goal',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${_sleepGoal}h',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Slider(
                            value: _sleepGoal.toDouble(),
                            min: 6,
                            max: 10,
                            divisions: 8,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white.withOpacity(0.3),
                            onChanged: (value) {
                              setState(() {
                                _sleepGoal = value.round();
                              });
                            },
                          ),
                        ],
                      ),
                    ).animate().fadeIn(
                          duration: 800.ms,
                          delay: 200.ms,
                        ),

                    const SizedBox(height: 24),

                    // Last Night Sleep
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last Night',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: _getSleepQualityColor(_lastNightSleep),
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                child: Center(
                                  child: Text(
                                    '${_lastNightSleep}h',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getSleepQualityText(_lastNightSleep),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getSleepAdvice(_lastNightSleep),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(
                          duration: 800.ms,
                          delay: 400.ms,
                        )
                        .slideY(
                          begin: 0.3,
                          duration: 800.ms,
                          curve: Curves.easeOut,
                        ),

                    const SizedBox(height: 24),

                    // Weekly Chart
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weekly Sleep Pattern',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        const days = [
                                          'Mon',
                                          'Tue',
                                          'Wed',
                                          'Thu',
                                          'Fri',
                                          'Sat',
                                          'Sun'
                                        ];
                                        return Text(
                                          days[value.toInt()],
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _weeklyData.asMap().entries.map((e) {
                                      return FlSpot(e.key.toDouble(), e.value);
                                    }).toList(),
                                    isCurved: true,
                                    color: Theme.of(context).primaryColor,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.1),
                                    ),
                                  ),
                                ],
                                minY: 5,
                                maxY: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(
                          duration: 800.ms,
                          delay: 600.ms,
                        ),

                    const SizedBox(height: 24),

                    // Sleep Sounds
                    const Text(
                      'Sleep Sounds',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(
                          duration: 800.ms,
                          delay: 800.ms,
                        ),

                    const SizedBox(height: 16),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: _sleepSounds.length,
                      itemBuilder: (context, index) {
                        final sound = _sleepSounds[index];
                        final isPlaying =
                            _isPlaying && _currentSound == sound['name'];

                        return GestureDetector(
                          onTap: () => _playSound(sound['url'], sound['name']),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? sound['color'].withOpacity(0.2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isPlaying
                                    ? sound['color']
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: sound['color'].withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    isPlaying ? Icons.pause : sound['icon'],
                                    size: 32,
                                    color: sound['color'],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  sound['name'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isPlaying
                                        ? sound['color']
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(
                              duration: 800.ms,
                              delay: (1000 + index * 100).ms,
                            )
                            .scale(
                              duration: 800.ms,
                              delay: (1000 + index * 100).ms,
                              curve: Curves.elasticOut,
                            );
                      },
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getSleepQualityColor(double hours) {
    if (hours >= 8) return Colors.green;
    if (hours >= 7) return Colors.orange;
    return Colors.red;
  }

  String _getSleepQualityText(double hours) {
    if (hours >= 8) return 'Excellent Sleep';
    if (hours >= 7) return 'Good Sleep';
    if (hours >= 6) return 'Fair Sleep';
    return 'Poor Sleep';
  }

  String _getSleepAdvice(double hours) {
    if (hours >= 8) return 'Keep up the great sleep routine!';
    if (hours >= 7) return 'Try to get a bit more rest tonight.';
    if (hours >= 6) return 'Consider going to bed earlier.';
    return 'Your sleep needs attention. Try relaxation techniques.';
  }
}
