import 'package:drift/drift.dart' show OrderingTerm;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/features/workout_builder/presentation/add_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live stream of one student's training plans.
final studentPlansProvider =
    StreamProvider.autoDispose.family<List<WorkoutPlan>, int>((ref, studentId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.workoutPlans)
        ..where((p) => p.studentId.equals(studentId))
        ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
      .watch();
});

/// Coach view of one student: their training plans and the way to add more.
class StudentDetailScreen extends ConsumerWidget {
  const StudentDetailScreen({super.key, required this.student});

  final User student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(studentPlansProvider(student.id));

    return Scaffold(
      appBar: AppBar(title: Text(student.name)),
      floatingActionButton: FloatingActionButton(
        tooltip: 'برنامه جدید',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddPlanScreen(student: student)),
        ),
        child: const Icon(Icons.add),
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('هنوز برنامه‌ای ساخته نشده'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text(list[i].title),
                ),
              ),
      ),
    );
  }
}
