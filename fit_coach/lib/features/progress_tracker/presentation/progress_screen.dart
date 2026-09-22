import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/progress_tracker/application/progress_providers.dart';
import 'package:fit_coach/features/progress_tracker/domain/workout_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A student's training history: how much they have done, and when.
///
/// Every date and number is rendered through the language helpers, so the
/// same data reads as Jalali/Persian in Persian and Gregorian in English.
///
/// The same screen serves both readers. Only the title differs, because "my
/// progress" is wrong when a coach is the one reading it — so the coach entry
/// point goes through [ProgressScreen.forCoach].
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key, required this.studentId}) : _studentName = null;

  /// The coach's view of [studentName]'s history.
  ///
  /// Same data and same providers as the student's own screen; the student is
  /// named in the title so a coach looking at several students knows whose
  /// history this is.
  const ProgressScreen.forCoach({
    super.key,
    required this.studentId,
    required String studentName,
  }) : _studentName = studentName;

  final int studentId;

  /// Null when the student is reading their own history.
  final String? _studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(studentStatsProvider(studentId));
    final locale = Localizations.localeOf(context);
    final l10n = context.l10n;
    final studentName = _studentName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          studentName == null
              ? l10n.myProgress
              : l10n.studentProgress(studentName),
        ),
      ),
      body: stats == null
          ? const Center(child: CircularProgressIndicator())
          : !stats.hasHistory
              ? Center(child: Text(l10n.noHistoryYet))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _summary(context, stats),
                    const SizedBox(height: 24),
                    _sectionTitle(context, l10n.weeklyTrend),
                    for (final week in stats.weeklyVolume(locale))
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          l10n.weekStart(localizeDate(locale, week.weekStart)),
                        ),
                        trailing: Text(l10n.setsCount(localizeNumber(locale, week.sets))),
                      ),
                    const SizedBox(height: 24),
                    _sectionTitle(context, l10n.volumeByMovement),
                    for (final entry in stats.volumeByMovement())
                      ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(entry.key),
                        trailing: Text(
                          l10n.setsCount(localizeNumber(locale, entry.value)),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _summary(BuildContext context, WorkoutStats stats) {
    final locale = Localizations.localeOf(context);
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _metric(
          context,
          l10n.completedWorkouts,
          localizeNumber(locale, stats.completedWorkouts),
        ),
        _metric(
          context,
          l10n.totalSetsDone,
          localizeNumber(locale, stats.totalSets),
        ),
      ],
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
