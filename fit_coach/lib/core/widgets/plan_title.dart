import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:flutter/material.dart';

/// A plan's name in the app bar, with how long it runs when that was set.
///
/// Lives in `core/` because both the coach's review and the student's own
/// plan read it, and features must not import each other.
///
/// A null [durationWeeks] renders just the title — the length was never
/// decided, and inventing "0 weeks" or "open ended" would be saying
/// something the coach did not.
class PlanAppBarTitle extends StatelessWidget {
  const PlanAppBarTitle({
    super.key,
    required this.title,
    this.durationWeeks,
  });

  final String title;
  final int? durationWeeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    if (durationWeeks == null) return Text(title);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge,
        ),
        Text(
          context.l10n.programLength(
            localizeNumber(Localizations.localeOf(context), durationWeeks!),
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
