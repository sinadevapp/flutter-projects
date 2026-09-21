import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a plan with exercises is stored for one student and read back',
      () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final studentId = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );

    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه حجم'),
    );
    await db.insertExercise(ExercisesCompanion.insert(
      planId: planId,
      name: 'اسکوات',
      sets: 4,
      reps: 10,
    ));
    await db.insertExercise(ExercisesCompanion.insert(
      planId: planId,
      name: 'پرس سینه',
      sets: 3,
      reps: 12,
    ));

    final plans = await db.getPlansForStudent(studentId);
    expect(plans.length, 1);
    expect(plans.first.title, 'برنامه حجم');

    final exercises = await db.getExercisesForPlan(planId);
    expect(exercises.map((e) => e.name).toList(), ['اسکوات', 'پرس سینه']);
    expect(exercises.first.sets, 4);
    expect(exercises.first.reps, 10);
  });

  test('clearing the local user also clears their plans and exercises',
      () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final studentId = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه حجم'),
    );
    await db.insertExercise(ExercisesCompanion.insert(
      planId: planId,
      name: 'اسکوات',
      sets: 4,
      reps: 10,
    ));

    // Must not trip the users <- workout_plans foreign key.
    await db.deleteAllUsers();

    expect(await db.getAllUsers(), isEmpty);
    expect(await db.getPlansForStudent(studentId), isEmpty);
    expect(await db.getExercisesForPlan(planId), isEmpty);
  });

  test('plans are scoped to their student', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final ali = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    final reza = await db.insertUser(
      UsersCompanion.insert(name: 'رضا', role: UserRole.student),
    );
    await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: ali, title: 'برنامه علی'),
    );

    expect((await db.getPlansForStudent(ali)).length, 1);
    expect(await db.getPlansForStudent(reza), isEmpty);
  });
}
