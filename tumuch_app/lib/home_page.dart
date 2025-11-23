import 'dart:math';

import 'package:flutter/material.dart';

import 'usage_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const int maxHealthyMinutes = 120;

  // Fake 30-day history from current 24h usage (until we have real history).
  List<int> _deriveDailyMinutesFromUsage(List<dynamic> usage) {
    final apps = usage
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    final totalMinutesToday = apps.fold<int>(
      0,
      (sum, app) => sum + (app['totalMinutes'] as num? ?? 0).toInt(),
    );

    final rand = Random();
    return List.generate(30, (i) {
      final factor = 0.6 + rand.nextDouble() * 0.8; // 0.6–1.4
      return max(0, (totalMinutesToday * factor).round());
    });
  }

  List<int> _minutesToScores(List<int> minutes) {
    return minutes
        .map((m) =>
            ((m / maxHealthyMinutes) * 100).clamp(0, 100).round())
        .toList();
  }

  Color _scoreColor(double averageScore) {
    if (averageScore <= 30) return Colors.green.shade600;
    if (averageScore <= 65) return Colors.amber.shade700;
    return Colors.red.shade600;
  }

  Color _heatmapColor(int minutes, int maxMinutes) {
    if (minutes <= 0 || maxMinutes <= 0) {
      return Colors.grey.shade200;
    }
    final t = (minutes / maxMinutes).clamp(0.0, 1.0);
    if (t < 0.25) return Colors.green.shade100;
    if (t < 0.5) return Colors.green.shade300;
    if (t < 0.75) return Colors.green.shade500;
    return Colors.green.shade800;
  }

  Widget _buildNavigationCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String routeName,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, routeName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: UsageService.getUsageSummary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Could not load usage data.',
                  style: TextStyle(color: Colors.red.shade400),
                ),
              );
            }

            final usage = snapshot.data ?? [];
            final last30Minutes = _deriveDailyMinutesFromUsage(usage);
            final last10Minutes = last30Minutes.length <= 10
                ? last30Minutes
                : last30Minutes.sublist(last30Minutes.length - 10);

            final last10Scores = _minutesToScores(last10Minutes);
            final averageScore = last10Scores.isEmpty
                ? 0.0
                : last10Scores.reduce((a, b) => a + b) /
                    last10Scores.length;
            final averageScoreString = averageScore.toStringAsFixed(1);
            final scoreColor = _scoreColor(averageScore);

            final maxMinutesForBars = last10Minutes.isEmpty
                ? 0
                : last10Minutes.reduce(max);
            final maxMinutesHeatmap = last30Minutes.isEmpty
                ? 0
                : last30Minutes.reduce(max);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Centered Naughty Score card
                  Center(
                    child: SizedBox(
                      width: 260,
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                averageScore <= 30
                                    ? Icons.mood
                                    : (averageScore <= 65
                                        ? Icons.sentiment_neutral
                                        : Icons.mood_bad),
                                color: scoreColor,
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Naughty Score',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                averageScoreString,
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== HEATMAP ABOVE COLUMNS =====
                  if (last30Minutes.isNotEmpty) ...[
                    Text(
                      'Last 30 days',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    _buildHeatmapGrid(last30Minutes, maxMinutesHeatmap),
                    const SizedBox(height: 8),
                    _buildHeatmapLegend(),
                    const SizedBox(height: 30),
                  ],

                  // ===== LAST 10 DAYS BAR CHART =====
                  Container(
                    height: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: last10Minutes.isEmpty
                        ? const Center(
                            child: Text(
                              'No history yet – use your phone normally for a few days.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children:
                                last10Minutes.asMap().entries.map((entry) {
                              final index = entry.key; // 0..9
                              final minutes = entry.value.toDouble();
                              final hours = minutes / 60.0;

                              // left = 9 days ago, right = today
                              final delta =
                                  last10Minutes.length - 1 - index;
                              final dayLabel = delta == 0
                                  ? 'Today'
                                  : '${delta}d ago';

                              final double barHeight =
                                  maxMinutesForBars == 0
                                      ? 0
                                      : (minutes / maxMinutesForBars) * 150;

                              final ratio = maxMinutesForBars == 0
                                  ? 0.0
                                  : minutes / maxMinutesForBars;
                              Color barColor;
                              if (ratio <= 0.33) {
                                barColor = Colors.green.shade400;
                              } else if (ratio <= 0.66) {
                                barColor = Colors.amber.shade400;
                              } else {
                                barColor = Colors.red.shade400;
                              }

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: barHeight,
                                    width: 20,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius:
                                          const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    dayLabel,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${hours.toStringAsFixed(1)}h',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.black45,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              );
                            }).toList(),
                          ),
                  ),

                  const SizedBox(height: 30),

                  // Single English settings card
                  _buildNavigationCard(
                    context: context,
                    title: 'Adjust long-term goals',
                    subtitle: 'Review your targets and usage limits.',
                    icon: Icons.track_changes,
                    color: Theme.of(context).colorScheme.primary,
                    routeName: '/goals',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Heatmap: 7 rows (like weekdays) x N columns, with bigger cells and no overflow.
  Widget _buildHeatmapGrid(List<int> dailyMinutes, int maxMinutes) {
    const double cellSize = 18;
    const int rows = 7;
    final int days = dailyMinutes.length;
    final int columns = (days / rows).ceil();
    final double totalHeight = rows * (cellSize + 6); // cell + padding

    return SizedBox(
      height: totalHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(columns, (col) {
            return Column(
              children: List.generate(rows, (row) {
                final int index = col * rows + row;
                if (index >= days) {
                  return const SizedBox(
                    width: cellSize,
                    height: cellSize,
                  );
                }
                final minutes = dailyMinutes[index];
                final color = _heatmapColor(minutes, maxMinutes);
                return Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHeatmapLegend() {
    const double cellSize = 14;
    return Row(
      children: [
        const Text(
          'Less',
          style: TextStyle(fontSize: 11),
        ),
        const SizedBox(width: 6),
        _legendCell(Colors.grey.shade200, cellSize),
        _legendCell(Colors.green.shade100, cellSize),
        _legendCell(Colors.green.shade300, cellSize),
        _legendCell(Colors.green.shade500, cellSize),
        _legendCell(Colors.green.shade800, cellSize),
        const SizedBox(width: 6),
        const Text(
          'More',
          style: TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _legendCell(Color color, double size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
    );
  }
}

