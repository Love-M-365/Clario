// lib/widgets/weekly_mood_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/journal_service.dart';

class WeeklyMoodChart extends StatelessWidget {
  final List<MoodData> moodTrend;
  const WeeklyMoodChart({super.key, required this.moodTrend});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50.withOpacity(0.5),
            Colors.blue.shade100.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title section
                Row(
                  children: [
                    const Icon(Icons.show_chart_rounded,
                        color: Colors.blueAccent, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "Weekly Mood Trend",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Line chart section
                AspectRatio(
                  aspectRatio: 1.8,
                  child: LineChart(
                    LineChartData(
                      backgroundColor: Colors.transparent,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.blueAccent.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              const labels = {
                                1: "😔",
                                2: "😟",
                                3: "😐",
                                4: "🙂",
                                5: "😄"
                              };
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  labels[value.toInt()] ?? '',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < moodTrend.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    moodTrend[value.toInt()].day,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: Colors.blueAccent,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueAccent,
                              Colors.purpleAccent.shade100,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          barWidth: 4,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, _, __, ___) =>
                                FlDotCirclePainter(
                              radius: 5,
                              color: Colors.white,
                              strokeWidth: 3,
                              strokeColor: Colors.blueAccent,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blueAccent.withOpacity(0.3),
                                Colors.purpleAccent.withOpacity(0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          spots: [
                            for (int i = 0; i < moodTrend.length; i++)
                              FlSpot(
                                  i.toDouble(), moodTrend[i].score.toDouble()),
                          ],
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipMargin: 8,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          tooltipPadding: const EdgeInsets.all(8),
                          tooltipBorder: BorderSide(
                            color: Colors.blueAccent.withOpacity(0.3),
                            width: 1,
                          ),
                          getTooltipColor: (touchedSpot) =>
                              Colors.white.withOpacity(0.9),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              return LineTooltipItem(
                                'Mood: ${touchedSpot.y.toInt()}',
                                const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOutCubic,
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
