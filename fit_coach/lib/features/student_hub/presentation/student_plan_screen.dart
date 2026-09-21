import 'package:drift/drift.dart' show OrderingTerm;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/features/auth/presentation/switch_role_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live stream of one student's training plans (student-side view).
final myPlansProvider =
    StreamProvider.autoDispose.family<List<WorkoutPlan>, int>((ref, studentId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.workoutPlans)
        ..where((p) => p.studentId.equals(studentId))
        ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
      .watch();
});

/// The movements of one plan.
final planExercisesProvider =
    StreamProvider.autoDispose.family<List<Exercise>, int>((ref, planId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.exercises)
        ..where((e) => e.planId.equals(planId))
        ..orderBy([(e) => OrderingTerm.asc(e.position)]))
      .watch();
});

/// What the student sees: the plans their coach built for them.
class StudentPlanScreen extends ConsumerWidget {
  const StudentPlanScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(myPlansProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('برنامه‌های من'),
        actions: const [SwitchRoleButton()],
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('هنوز برنامه‌ای برایت ساخته نشده'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text(list[i].title),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlanDetailScreen(plan: list[i]),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The movements of one plan, in order (e.g. squat — 4 × 10).
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(planExercisesProvider(plan.id));

    return Scaffold(
      appBar: AppBar(title: Text(plan.title)),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('این برنامه حرکتی ندارد'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(list[i].name),
                  trailing: Text('${list[i].sets} × ${list[i].reps}'),
                ),
              ),
      ),
    );
  }
}
