import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/workout_active/domain/workout_summary.dart';
import 'package:fit_coach/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// What the student sees when the workout is done.
class WorkoutSummaryView extends StatelessWidget {
  const WorkoutSummaryView({
    super.key,
    required this.summary,
    required this.onDone,
  });

  final WorkoutSummary summary;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);

    String digits(num value) => localizeNumber(locale, value.round());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.workoutSummary,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        // Say plainly whether the plan was finished: a "partial" workout that
        // looks identical to a complete one would be misleading.
        Text(
          summary.isComplete ? l10n.summaryComplete : l10n.summaryPartial,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _metric(
              context,
              l10n.summaryDuration,
              _duration(l10n, locale, summary.duration),
            ),
            _metric(
              context,
              l10n.summarySets,
              digits(summary.totalSets),
            ),
            _metric(
              context,
              l10n.summaryReps,
              digits(summary.totalReps),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (final movement in summary.movementBreakdown())
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fitness_center),
            title: Text(movement.name),
            trailing: Text(
              '${digits(movement.sets)} × ${digits(movement.reps)}',
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onDone, child: Text(l10n.finishWorkout)),
      ],
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  /// Hours and minutes for a long workout, minutes alone for a short one.
  String _duration(AppLocalizations l10n, Locale locale, Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return l10n.durationHoursMinutes(
        localizeNumber(locale, hours),
        localizeNumber(locale, minutes),
      );
    }
    return l10n.durationMinutes(localizeNumber(locale, minutes));
  }
}
