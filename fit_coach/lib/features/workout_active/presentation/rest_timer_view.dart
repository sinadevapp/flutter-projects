import 'dart:async';

import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/workout_active/domain/rest_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The rest between sets: a countdown the student can pause or skip.
///
/// The ticking lives here and the arithmetic lives in [RestTimer], which is
/// what keeps the rules unit-testable without waiting in real time.
class RestTimerView extends StatefulWidget {
  const RestTimerView({
    super.key,
    required this.total,
    this.onFinished,
  });

  final Duration total;

  /// Called once when the rest runs out, so the screen can move on.
  final VoidCallback? onFinished;

  @override
  State<RestTimerView> createState() => _RestTimerViewState();
}

class _RestTimerViewState extends State<RestTimerView> {
  static const _tick = Duration(milliseconds: 200);

  late RestTimer _timer = RestTimer(total: widget.total);
  Timer? _ticker;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _startTicking();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      setState(() => _timer = _timer.advance(_tick));
      if (_timer.isFinished) _finish();
    });
  }

  /// Fires once: a periodic timer keeps firing after the rest is over.
  void _finish() {
    if (_announced) return;
    _announced = true;
    _ticker?.cancel();
    // A short buzz at the end of a rest, so the student does not have to watch
    // the screen between sets.
    HapticFeedback.mediumImpact();
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(AppTheme.pagePadding),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _timer.isFinished ? l10n.restDone : l10n.resting,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              width: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      // The ring fills as the rest elapses. Orange is the
                      // design system's *live* accent, and this is the one
                      // place it belongs: something is actively running.
                      value: _timer.progress,
                      strokeWidth: 8,
                      color: AppTheme.live,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    // Big: this is read from across a gym, not held close.
                    localizeNumber(locale, _timer.secondsRemaining),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _timer.isFinished
                      ? null
                      : () => setState(() {
                            _timer = _timer.isRunning
                                ? _timer.pause()
                                : _timer.resume();
                          }),
                  icon: Icon(
                    _timer.isRunning ? Icons.pause : Icons.play_arrow,
                  ),
                  label: Text(
                    _timer.isRunning ? l10n.pauseRest : l10n.resumeRest,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _timer.isFinished
                      ? null
                      : () => setState(() {
                            _timer = _timer.skip();
                            _finish();
                          }),
                  icon: const Icon(Icons.skip_next),
                  label: Text(l10n.skipRest),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
