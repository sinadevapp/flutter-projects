/// The rest between sets.
///
/// Pure arithmetic over elapsed time: no clock, no `Timer`, no widget. The
/// screen owns the ticking and calls [advance] with however much time passed,
/// which is what makes the rules testable without waiting in real time.
///
/// Immutable — every operation returns a new timer.
class RestTimer {
  const RestTimer({
    required this.total,
    this.elapsed = Duration.zero,
    this.isRunning = true,
  });

  /// How long the rest lasts (the preset the coach or student chose).
  final Duration total;

  /// How much of it has already passed.
  final Duration elapsed;

  /// False once paused, skipped, or finished. This is what the *user* wants,
  /// not whether time remains — a paused timer still has time on it.
  final bool isRunning;

  Duration get remaining {
    final left = total - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  bool get isFinished => remaining == Duration.zero;

  /// Whole seconds left, rounded up so a running rest never displays `0` while
  /// time remains.
  int get secondsRemaining =>
      isFinished ? 0 : (remaining.inMilliseconds / 1000).ceil();

  /// How much of the rest is done, for the progress ring. 1.0 when finished,
  /// and on a zero-length rest — which must not be a division by zero.
  double get progress {
    if (total <= Duration.zero) return 1.0;
    final ratio = elapsed.inMilliseconds / total.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  /// Accounts for [delta] of elapsed time.
  ///
  /// Ignored while paused, or once finished — a finished rest cannot be
  /// advanced into negative time.
  RestTimer advance(Duration delta) {
    if (!isRunning || isFinished) return this;
    final next = elapsed + delta;
    return copyWith(elapsed: next > total ? total : next);
  }

  RestTimer pause() => isRunning ? copyWith(isRunning: false) : this;

  RestTimer resume() => isFinished ? this : copyWith(isRunning: true);

  /// Ends the rest now — the "skip" the user asked for.
  RestTimer skip() => copyWith(elapsed: total, isRunning: false);

  RestTimer copyWith({
    Duration? total,
    Duration? elapsed,
    bool? isRunning,
  }) =>
      RestTimer(
        total: total ?? this.total,
        elapsed: elapsed ?? this.elapsed,
        isRunning: isRunning ?? this.isRunning,
      );
}
