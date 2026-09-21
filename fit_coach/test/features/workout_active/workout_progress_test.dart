import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/features/workout_active/domain/workout_progress.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise exercise(int id, String name, int sets) => Exercise(
      id: id,
      planId: 1,
      name: name,
      sets: sets,
      reps: 10,
      position: id,
    );

SetLog log(int exerciseId, int setNumber) => SetLog(
      id: exerciseId * 100 + setNumber,
      sessionId: 1,
      exerciseId: exerciseId,
      setNumber: setNumber,
      completedAt: DateTime(2026, 9, 21),
    );

void main() {
  final plan = [exercise(1, 'اسکوات', 2), exercise(2, 'پرس سینه', 3)];

  test('an untouched workout starts at the first movement, first set',
      () {
    final progress = WorkoutProgress(exercises: plan, logs: []);

    expect(progress.currentExercise!.name, 'اسکوات');
    expect(progress.currentSetNumber, 1);
    expect(progress.completedSets, 0);
    expect(progress.totalSets, 5);
    expect(progress.isComplete, isFalse);
  });

  test('the set number follows the sets logged for that movement', () {
    final progress = WorkoutProgress(
      exercises: plan,
      logs: [log(1, 1), log(1, 2)],
    );

    // Squat is done (2 of 2), so the workout moved on to the bench press.
    expect(progress.currentExercise!.name, 'پرس سینه');
    expect(progress.currentSetNumber, 1);
    expect(progress.completedSetsFor(1), 2);
    expect(progress.completedSets, 2);
  });

  test('a partly finished movement keeps its own set count', () {
    final progress = WorkoutProgress(
      exercises: plan,
      logs: [log(1, 1), log(2, 1), log(2, 2)],
    );

    expect(progress.currentExercise!.name, 'اسکوات');
    expect(progress.currentSetNumber, 2);
  });

  test('the workout is complete once every set of every movement is logged',
      () {
    final progress = WorkoutProgress(
      exercises: plan,
      logs: [log(1, 1), log(1, 2), log(2, 1), log(2, 2), log(2, 3)],
    );

    expect(progress.isComplete, isTrue);
    expect(progress.currentExercise, isNull);
    expect(progress.currentSetNumber, 0);
    expect(progress.completedSets, 5);
  });

  test('a plan with no movements is complete immediately', () {
    final progress = WorkoutProgress(exercises: [], logs: []);

    expect(progress.isComplete, isTrue);
    expect(progress.totalSets, 0);
  });
}
