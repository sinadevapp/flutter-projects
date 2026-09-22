import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/progress_tracker/domain/workout_stats.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Charts of a student's training history.
///
/// The points come from [WorkoutStats] already in chart order and already
/// labelled — nothing here computes anything, it only draws. Axis labels go
/// through the locale helpers, so Persian shows Persian digits and Jalali
/// week starts while English stays plain.

/// Sets per week over time.
class WeeklyVolumeChart extends StatelessWidget {
  const WeeklyVolumeChart({super.key, required this.points});

  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = _axisMax(points);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxValue,
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _axisInterval(maxValue),
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.dividerColor, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: _axisInterval(maxValue),
                // Persian digits on the axis, like every other number.
                getTitlesWidget: (value, meta) => Text(
                  localizeNumber(locale, value.round()),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                // A point per week: label them all, but keep a single-point
                // series readable rather than hiding its only label.
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final week = points[index].weekStart;
                  if (week == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _shortDate(locale, week),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].value),
              ],
              isCurved: false,
              dotData: const FlDotData(show: true),
              color: theme.colorScheme.primary,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Total reps per movement.
class MovementVolumeChart extends StatelessWidget {
  const MovementVolumeChart({super.key, required this.points});

  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = _axisMax(points);
    final labels = _movementLabels(points);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxValue,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _axisInterval(maxValue),
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.dividerColor, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: _axisInterval(maxValue),
                getTitlesWidget: (value, meta) => Text(
                  localizeNumber(locale, value.round()),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SizedBox(
                      width: 64,
                      child: Text(
                        labels[index],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].value,
                    color: theme.colorScheme.primary,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A short date for a crowded axis: month/day, through the locale's calendar.
String _shortDate(Locale locale, DateTime date) {
  final full = localizeDate(locale, date);
  // localizeDate gives `yyyy/MM/dd` (Jalali or Gregorian); the axis only has
  // room for the month and day.
  final parts = full.split('/');
  return parts.length >= 3 ? '${parts[1]}/${parts[2]}' : full;
}

/// Movement names, shortened so they fit the bars.
List<String> _movementLabels(List<ChartPoint> points) => [
      for (final point in points) point.label ?? '',
    ];

/// A round number above the tallest point, so bars never touch the ceiling.
double _axisMax(List<ChartPoint> points) {
  final peak = points
      .map((p) => p.value)
      .fold<double>(0, (a, b) => a > b ? a : b);
  if (peak <= 0) return 1;
  final headroom = peak * 1.2;
  final interval = _axisInterval(headroom);
  return (headroom / interval).ceil() * interval;
}

/// A grid interval that keeps the axis to a readable handful of lines.
double _axisInterval(double maxValue) {
  if (maxValue <= 5) return 1;
  if (maxValue <= 20) return 5;
  if (maxValue <= 50) return 10;
  if (maxValue <= 200) return 25;
  return 50;
}
