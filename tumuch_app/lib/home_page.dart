import 'dart:math';
import 'package:flutter/material.dart';

import 'usage_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const int maxHealthyMinutes = 120;

  // Map/minutes → score 0..100
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

  static const _monthNames = [
    '', // dummy for 0
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

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
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: UsageService.getDailyUsageHistory(),
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

            final raw = snapshot.data ?? [];

            // Parse into _DayUsage, sort by date
            final history = raw
                .map((m) {
                  final dateStr = m['date'] as String?;
                  final minutes = (m['totalMinutes'] as num? ?? 0).toInt();
                  if (dateStr == null) return null;
                  final date = DateTime.parse(dateStr); // yyyy-MM-dd
                  return _DayUsage(date, minutes);
                })
                .whereType<_DayUsage>()
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));

            if (history.isEmpty) {
              return const Center(
                child: Text(
                  'No history yet – use your phone normally for a few days.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            // --- Naughty Score from last 10 days ---
            final last10 = history.length <= 10
                ? history
                : history.sublist(history.length - 10);
            final last10Minutes =
                last10.map((d) => d.minutes).toList(growable: false);
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
            final maxMinutesHeatmap =
                history.map((d) => d.minutes).reduce(max);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // --- Naughty Score card (centered) ---
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

                  // --- GitHub-like heatmap ABOVE the columns ---
                  Text(
                    'Last ${history.length} days',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildGithubHeatmap(history, maxMinutesHeatmap),
                  const SizedBox(height: 8),
                  _buildHeatmapLegend(),
                  const SizedBox(height: 30),

                  // --- Last 10 days bar chart: left = 9 days ago, right = today ---
                  Container(
                    height: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: last10.asMap().entries.map((entry) {
                        final index = entry.key;
                        final day = entry.value;
                        final minutes = day.minutes.toDouble();
                        final hours = minutes / 60.0;

                        // left = 9 days ago, right = today
                        final delta = last10.length - 1 - index;
                        final dayLabel =
                            delta == 0 ? 'Today' : '${delta}d ago';

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
                                borderRadius: const BorderRadius.only(
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

                  // Single settings card, English
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

  /// GitHub-like heatmap: columns = weeks, rows = weekdays (Mon–Sun),
  /// with month labels along the top and weekday labels on the left.
  Widget _buildGithubHeatmap(List<_DayUsage> history, int maxMinutes) {
    const double cellSize = 14;
    const int rows = 7; // Mon..Sun

    // 1) Build a continuous date range from Monday..Sunday boundaries
    history.sort((a, b) => a.date.compareTo(b.date));
    DateTime first = history.first.date;
    DateTime last = history.last.date;

    // Normalize to midnight
    first = DateTime(first.year, first.month, first.day);
    last = DateTime(last.year, last.month, last.day);

    // Start at previous Monday
    while (first.weekday != DateTime.monday) {
      first = first.subtract(const Duration(days: 1));
    }
    // End at next Sunday
    while (last.weekday != DateTime.sunday) {
      last = last.add(const Duration(days: 1));
    }

    final int totalDays = last.difference(first).inDays + 1;
    final int weeks = (totalDays / rows).ceil();

    // Map from date (yyyy-MM-dd) to minutes
    final Map<String, int> minutesByDate = {
      for (final d in history)
        '${d.date.year.toString().padLeft(4, '0')}-'
            '${d.date.month.toString().padLeft(2, '0')}-'
            '${d.date.day.toString().padLeft(2, '0')}': d.minutes,
    };

    // 2) Build grid data
    final List<List<_DayUsage?>> grid = List.generate(
      weeks,
      (col) => List<_DayUsage?>.filled(rows, null, growable: false),
      growable: false,
    );

    for (int i = 0; i < totalDays; i++) {
      final date = first.add(Duration(days: i));
      final col = i ~/ rows;
      final row = i % rows;
      final key =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final minutes = minutesByDate[key] ?? 0;
      grid[col][row] = _DayUsage(date, minutes);
    }

    // 3) Month labels on top (similar to GitHub)
    final List<String?> monthLabels = List<String?>.filled(weeks, null);
    int? lastMonth;
    for (int col = 0; col < weeks; col++) {
      // use Monday of that week for labeling
      final cell = grid[col][0];
      if (cell == null) continue;
      final m = cell.date.month;
      if (lastMonth != m && cell.date.day <= 7) {
        monthLabels[col] = _monthNames[m];
        lastMonth = m;
      }
    }

    // 4) Weekday labels (Mon/Wed/Fri)
    const weekdayLabels = ['Mon', '', 'Wed', '', 'Fri', '', ''];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: weekday labels
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(rows, (row) {
            final label = weekdayLabels[row];
            return SizedBox(
              height: cellSize + 6,
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            );
          }),
        ),
        const SizedBox(width: 4),
        // Right: months + heatmap grid
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month labels row
                Row(
                  children: List.generate(weeks, (col) {
                    final label = monthLabels[col] ?? '';
                    return SizedBox(
                      width: cellSize + 6,
                      child: Text(
                        label,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black54),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                // Heatmap cells
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(weeks, (col) {
                    return Column(
                      children: List.generate(rows, (row) {
                        final day = grid[col][row];
                        if (day == null) {
                          return const SizedBox(
                            width: cellSize,
                            height: cellSize,
                          );
                        }
                        final color =
                            _heatmapColor(day.minutes, maxMinutes);
                        return Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
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

// small helper
class _DayUsage {
  final DateTime date;
  final int minutes;
  _DayUsage(this.date, this.minutes);
}

