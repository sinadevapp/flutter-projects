import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:flutter/widgets.dart';

/// One week of training history.
class WeekVolume {
  const WeekVolume({required this.weekStart, required this.sets});

  /// First day of the week, using the language's own week boundary
  /// (Saturday for Persian, Monday for English).
  final DateTime weekStart;

  final int sets;
}

/// One point on a chart.
///
/// [label] is what the chart draws on its axis; [weekStart] is set instead for
/// series measured in time, so the axis can format it through the locale
/// helpers rather than a chart widget guessing at a calendar.
class ChartPoint {
  const ChartPoint._({
    required this.value,
    this.label,
    this.weekStart,
  });

  ChartPoint.forWeek({required DateTime weekStart, required num value})
      : this._(value: value.toDouble(), weekStart: weekStart);

  ChartPoint.forLabel({required String label, required num value})
      : this._(value: value.toDouble(), label: label);

  final double value;
  final String? label;
  final DateTime? weekStart;
}

/// Aggregates one student's training history.
///
/// Pure domain logic over rows the database already holds: no widgets, no
/// queries. Dates are grouped by the *language's* week boundary, so the same
/// history reads correctly in Persian (week starts Saturday) and English
/// (week starts Monday).
class WorkoutStats {
  const WorkoutStats({
    required this.sessions,
    required this.logs,
    required this.exercises,
  });

  /// Every workout session of the student, finished or not.
  final List<WorkoutSession> sessions;

  /// Every set logged across those sessions.
  final List<SetLog> logs;

  /// The movements those sets refer to (for names and reps).
  final List<Exercise> exercises;

  List<WorkoutSession> get finishedSessions =>
      sessions.where((s) => s.finishedAt != null).toList();

  int get completedWorkouts => finishedSessions.length;

  int get totalSets => logs.length;

  bool get hasHistory => logs.isNotEmpty;

  /// Total reps performed per movement name, most trained first.
  ///
  /// A set is worth the movement's prescribed reps, which is what the coach
  /// wrote in the plan.
  List<MapEntry<String, int>> volumeByMovement() {
    final byId = {
      for (final exercise in exercises)
        exercise.id: (name: exercise.name, reps: exercise.reps),
    };
    final volume = <String, int>{};
    for (final log in logs) {
      final exercise = byId[log.exerciseId];
      if (exercise == null) continue;
      volume[exercise.name] = (volume[exercise.name] ?? 0) + exercise.reps;
    }
    return volume.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Sets per week, most recent week first.
  List<WeekVolume> weeklyVolume(Locale locale) {
    final byWeek = <DateTime, int>{};
    for (final log in logs) {
      final week = startOfWeek(locale, log.completedAt);
      byWeek[week] = (byWeek[week] ?? 0) + 1;
    }
    final weeks = byWeek.entries
        .map((e) => WeekVolume(weekStart: e.key, sets: e.value))
        .toList()
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return weeks;
  }

  /// Sets per week, **oldest first** — the order a trend is read in.
  ///
  /// [weeklyVolume] returns newest first, which is right for a list but
  /// backwards for a chart. Reversing in the widget would be logic in
  /// `build()`, so the chart's own order is derived here instead.
  List<ChartPoint> weeklyVolumeSeries(Locale locale) => weeklyVolume(locale)
      .reversed
      .map((week) => ChartPoint.forWeek(
            weekStart: week.weekStart,
            value: week.sets,
          ))
      .toList();

  /// Total reps per movement, busiest first — the order a bar chart reads in.
  List<ChartPoint> movementVolumeSeries() => volumeByMovement()
      .map((entry) => ChartPoint.forLabel(
            label: entry.key,
            value: entry.value,
          ))
      .toList();
}
