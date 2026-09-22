import 'package:fit_coach/features/workout_active/domain/rest_timer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rest timer between sets.
///
/// Pure arithmetic over elapsed time, so the rules are unit-testable without a
/// clock or a widget. The screen only renders what this reports.
void main() {
  const preset = Duration(seconds: 90);

  test('a fresh timer is full and running', () {
    final timer = RestTimer(total: preset);

    expect(timer.total, preset);
    expect(timer.remaining, preset);
    expect(timer.isRunning, isTrue);
    expect(timer.isFinished, isFalse);
  });

  test('it counts down as time passes', () {
    final timer = RestTimer(total: preset)
        .advance(const Duration(seconds: 30));

    expect(timer.remaining, const Duration(seconds: 60));
    expect(timer.isFinished, isFalse);
  });

  test('it stops at zero rather than going negative', () {
    final timer = RestTimer(total: preset)
        .advance(const Duration(seconds: 200));

    // Overshooting must not produce negative time for the UI to render.
    expect(timer.remaining, Duration.zero);
    expect(timer.isFinished, isTrue);
  });

  test('advancing by exactly the total finishes it', () {
    expect(
      RestTimer(total: preset).advance(preset).isFinished,
      isTrue,
    );
  });

  test('an elapsed fraction drives the progress ring', () {
    final halfway =
        RestTimer(total: preset).advance(const Duration(seconds: 45));

    expect(halfway.progress, closeTo(0.5, 0.001));
    expect(RestTimer(total: preset).progress, closeTo(0.0, 0.001));
    expect(
      RestTimer(total: preset).advance(preset).progress,
      closeTo(1.0, 0.001),
    );
  });

  test('progress on a zero-length rest is complete, not a division by zero',
      () {
    final instant = RestTimer(total: Duration.zero);

    expect(instant.progress, 1.0);
    expect(instant.isFinished, isTrue);
  });

  test('a paused timer ignores the clock', () {
    final paused = RestTimer(total: preset)
        .advance(const Duration(seconds: 30))
        .pause()
        .advance(const Duration(seconds: 60));

    // Time passing while paused must not burn the rest down.
    expect(paused.remaining, const Duration(seconds: 60));
    expect(paused.isRunning, isFalse);
    expect(paused.isFinished, isFalse);
  });

  test('resuming continues from where it stopped', () {
    final resumed = RestTimer(total: preset)
        .advance(const Duration(seconds: 30))
        .pause()
        .advance(const Duration(seconds: 60))
        .resume()
        .advance(const Duration(seconds: 10));

    expect(resumed.remaining, const Duration(seconds: 50));
    expect(resumed.isRunning, isTrue);
  });

  test('skipping ends the rest immediately', () {
    final skipped = RestTimer(total: preset)
        .advance(const Duration(seconds: 10))
        .skip();

    expect(skipped.remaining, Duration.zero);
    expect(skipped.isFinished, isTrue);
    // A skipped rest is not running: nothing left to count down.
    expect(skipped.isRunning, isFalse);
  });

  test('a finished timer cannot be resumed into negative time', () {
    final done = RestTimer(total: preset).advance(preset).resume();

    expect(done.remaining, Duration.zero);
    expect(done.isFinished, isTrue);
  });

  test('a custom rest length is respected', () {
    final short = RestTimer(total: const Duration(seconds: 45))
        .advance(const Duration(seconds: 15));

    expect(short.remaining, const Duration(seconds: 30));
  });

  test('the timer reports whole seconds left for the countdown display', () {
    final timer = RestTimer(total: preset)
        .advance(const Duration(milliseconds: 1500));

    // 88.5 s left reads as 89 — round up so the last second is not shown as 0
    // while time remains.
    expect(timer.secondsRemaining, 89);
    expect(RestTimer(total: preset).advance(preset).secondsRemaining, 0);
  });
}
