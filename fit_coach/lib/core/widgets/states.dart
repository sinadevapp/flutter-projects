import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';

/// What the app shows when something is empty or has gone wrong.
///
/// Both replace the raw `Text('$e')` and bare `Text('هیچی نیست')` that the
/// screens started with: a raw exception string is not something a coach can
/// act on, and a bare "nothing here" does not say whether it is a problem or
/// simply the beginning.

/// A screen with nothing in it yet.
///
/// Every empty state says *why* it is empty and, where there is one, the
/// action that fills it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String message;

  /// One line explaining how to fill it. Optional but usually worth having.
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A screen that failed to load.
///
/// Shows the localized message plus a retry, and keeps the raw error behind
/// "details" rather than in the coach's face — it is a debugging aid, not
/// something to read. Nothing here leaks a stack trace into the UI.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.somethingWentWrong,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tryAgainHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A labeled figure — the design system's signature element.
///
/// A quiet label above a large value, with an optional unit beneath. Used for
/// sets, reps, cost per gram of protein, weekly volume. The caller supplies
/// the already-localized value, because what counts as a number here differs
/// per screen (a duration is not a count).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;

  /// Draws the value in teal. Used for the recommended option in a ranking.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: emphasized ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(
                caption!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
