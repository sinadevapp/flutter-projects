import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Editing the plans a coach already built.
///
/// Deleting is the dangerous half: a plan that has been trained has sessions
/// and set logs hanging off it, and `PRAGMA foreign_keys = ON` means those
/// must be removed leaf-first or the delete fails outright.
void main() {
  late AppDatabase db;
  late int ali;
  late int reza;

  setUp(() async {
    db = createTestDatabase();
    ali = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    reza = await db.insertUser(
      UsersCompanion.insert(name: 'رضا', role: UserRole.student),
    );
  });
  tearDown(() => db.close());

  Future<int> makePlan({
    int? studentId,
    String title = 'برنامه حجم',
    List<(String, int, int)> movements = const [('اسکوات', 4, 10)],
  }) async {
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(
        studentId: studentId ?? ali,
        title: title,
      ),
    );
    for (final (name, sets, reps) in movements) {
      await db.insertExercise(ExercisesCompanion.insert(
        planId: planId,
        name: name,
        sets: sets,
        reps: reps,
      ));
    }
    return planId;
  }

  group('renaming', () {
    test('a plan can be renamed without touching its movements', () async {
      final planId = await makePlan();

      await db.renamePlan(planId, 'برنامه قدرتی');

      expect((await db.getPlansForStudent(ali)).single.title, 'برنامه قدرتی');
      expect((await db.getExercisesForPlan(planId)).single.name, 'اسکوات');
    });
  });

  group('editing a movement', () {
    test('sets and reps can be corrected', () async {
      final planId = await makePlan();
      final exercise = (await db.getExercisesForPlan(planId)).single;

      await db.updateExercise(exercise.id, sets: 5, reps: 8);

      final after = (await db.getExercisesForPlan(planId)).single;
      expect(after.sets, 5);
      expect(after.reps, 8);
      // Everything not passed is left alone.
      expect(after.name, 'اسکوات');
    });

    test('a movement can be renamed on its own', () async {
      final planId = await makePlan();
      final exercise = (await db.getExercisesForPlan(planId)).single;

      await db.updateExercise(exercise.id, name: 'اسکوات وزنه');

      final after = (await db.getExercisesForPlan(planId)).single;
      expect(after.name, 'اسکوات وزنه');
      expect(after.sets, 4);
      expect(after.reps, 10);
    });

    test('a movement can be removed from the plan', () async {
      final planId = await makePlan(movements: [
        ('اسکوات', 4, 10),
        ('پرس سینه', 3, 8),
      ]);
      final squat = (await db.getExercisesForPlan(planId)).first;

      await db.deleteExercise(squat.id);

      final left = await db.getExercisesForPlan(planId);
      expect(left.map((e) => e.name).toList(), ['پرس سینه']);
    });

    test('removing a movement removes the sets logged against it', () async {
      final planId = await makePlan();
      final exercise = (await db.getExercisesForPlan(planId)).single;
      final sessionId = await db.startWorkoutSession(
        planId: planId,
        studentId: ali,
      );
      await db.logSet(
        sessionId: sessionId,
        exerciseId: exercise.id,
        setNumber: 1,
      );

      // A movement with logged sets is referenced by set_logs, so the delete
      // has to take them with it — `PRAGMA foreign_keys` is on and would
      // otherwise refuse.
      //
      // This *is* data loss, and the tradeoff is deliberate: an orphaned log
      // would still count towards `totalSets` while contributing no name to
      // the volume breakdown (`WorkoutStats` skips a log whose movement is
      // gone), so the student's own history would disagree with itself. If
      // keeping that history matters more later, the answer is to archive a
      // movement rather than delete it.
      await db.deleteExercise(exercise.id);

      expect(await db.getExercisesForPlan(planId), isEmpty);
      expect(await db.getSetLogs(sessionId), isEmpty);
    });
  });

  group('deleting a plan', () {
    test('removes the plan and its movements', () async {
      final planId = await makePlan(movements: [
        ('اسکوات', 4, 10),
        ('پرس سینه', 3, 8),
      ]);

      await db.deletePlan(planId);

      expect(await db.getPlansForStudent(ali), isEmpty);
      expect(await db.getExercisesForPlan(planId), isEmpty);
    });

    test('a trained plan also takes its sessions and set logs with it',
        () async {
      final planId = await makePlan();
      final exercise = (await db.getExercisesForPlan(planId)).single;
      final sessionId = await db.startWorkoutSession(
        planId: planId,
        studentId: ali,
      );
      await db.logSet(
        sessionId: sessionId,
        exerciseId: exercise.id,
        setNumber: 1,
      );
      await db.finishWorkoutSession(sessionId);

      // Foreign keys are on: this must delete leaf-first or fail.
      await db.deletePlan(planId);

      expect(await db.getPlansForStudent(ali), isEmpty);
      expect(
        await db.select(db.workoutSessions).get(),
        isEmpty,
        reason: 'the plan was deleted, so its sessions cannot outlive it',
      );
      expect(await db.select(db.setLogs).get(), isEmpty);
    });

    test('deleting one plan leaves the student\'s other plans alone', () async {
      final first = await makePlan(title: 'برنامه اول');
      await makePlan(title: 'برنامه دوم');

      await db.deletePlan(first);

      expect(
        (await db.getPlansForStudent(ali)).map((p) => p.title).toList(),
        ['برنامه دوم'],
      );
    });
  });

  group('duplicating a plan', () {
    test('copies the movements to another student', () async {
      final planId = await makePlan(movements: [
        ('اسکوات', 4, 10),
        ('پرس سینه', 3, 8),
      ]);

      final copyId = await db.duplicatePlan(planId, forStudent: reza);

      final rezaPlans = await db.getPlansForStudent(reza);
      expect(rezaPlans, hasLength(1));
      expect(rezaPlans.single.title, 'برنامه حجم');

      final copied = await db.getExercisesForPlan(copyId);
      expect(copied.map((e) => e.name).toList(), ['اسکوات', 'پرس سینه']);
      expect(copied.map((e) => e.sets).toList(), [4, 3]);
      expect(copied.map((e) => e.reps).toList(), [10, 8]);
    });

    test('the original is untouched, and the copy is independent', () async {
      final planId = await makePlan();
      final copyId = await db.duplicatePlan(planId, forStudent: reza);

      await db.updateExercise(
        (await db.getExercisesForPlan(copyId)).single.id,
        sets: 99,
      );

      // Editing the copy must not reach back into the original.
      expect((await db.getExercisesForPlan(planId)).single.sets, 4);
      expect((await db.getExercisesForPlan(copyId)).single.sets, 99);
    });

    test('the copy belongs to the target student, not the source', () async {
      final planId = await makePlan();

      await db.duplicatePlan(planId, forStudent: reza);

      expect((await db.getPlansForStudent(reza)).single.studentId, reza);
      expect((await db.getPlansForStudent(ali)).single.studentId, ali);
    });

    test('a plan with no movements copies as an empty plan', () async {
      final empty = await makePlan(movements: const []);

      final copyId = await db.duplicatePlan(empty, forStudent: reza);

      expect(await db.getExercisesForPlan(copyId), isEmpty);
      expect(await db.getPlansForStudent(reza), hasLength(1));
    });
  });

  group('resetting the coach\'s data', () {
    test('deleteAllUsers clears plans, sessions and nutrition targets',
        () async {
      final planId = await makePlan();
      final exercise = (await db.getExercisesForPlan(planId)).single;
      final sessionId = await db.startWorkoutSession(
        planId: planId,
        studentId: ali,
      );
      await db.logSet(
        sessionId: sessionId,
        exerciseId: exercise.id,
        setNumber: 1,
      );
      await db.saveNutritionTarget(
        NutritionTargetsCompanion.insert(
          studentId: Value(ali),
          sex: 0,
          age: 30,
          heightCm: 180,
          weightKg: 80,
          activity: 2,
          goal: 1,
        ),
      );

      await db.deleteAllUsers();

      expect(await db.getAllUsers(), isEmpty);
      expect(await db.select(db.workoutPlans).get(), isEmpty);
      expect(await db.select(db.exercises).get(), isEmpty);
      expect(await db.select(db.workoutSessions).get(), isEmpty);
      expect(await db.select(db.setLogs).get(), isEmpty);
      expect(await db.select(db.nutritionTargets).get(), isEmpty);
    });
  });
}
