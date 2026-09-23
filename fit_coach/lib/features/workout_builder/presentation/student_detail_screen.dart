import 'package:fit_coach/core/widgets/states.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/students_provider.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/features/coach_hub/presentation/edit_student_screen.dart';
import 'package:fit_coach/features/nutrition_budget/presentation/nutrition_screen.dart';
import 'package:fit_coach/features/progress_tracker/presentation/progress_screen.dart';
import 'package:fit_coach/features/workout_builder/presentation/add_plan_screen.dart';
import 'package:fit_coach/features/workout_builder/presentation/plan_detail_edit_screen.dart';
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
    // Re-read from the live roster rather than trusting the row this screen
    // was opened with: renaming a student elsewhere must not leave a stale
    // title here.
    final student = ref.watch(studentsProvider).value?.firstWhere(
              (u) => u.id == this.student.id,
              orElse: () => this.student,
            ) ??
        this.student;

    final plans = ref.watch(studentPlansProvider(student.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.editStudent,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditStudentScreen(student: student),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: context.l10n.progress,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProgressScreen.forCoach(
                  studentId: student.id,
                  studentName: student.name,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.restaurant),
            tooltip: context.l10n.nutrition,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NutritionScreen(student: student),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: context.l10n.newPlan,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddPlanScreen(student: student)),
        ),
        child: const Icon(Icons.add),
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const ErrorState(),
        data: (list) => list.isEmpty
            ? Center(child: Text(context.l10n.noPlansForStudent))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text(list[i].title),
                  trailing: PopupMenuButton<_PlanAction>(
                    onSelected: (action) => switch (action) {
                      _PlanAction.edit => _openPlan(context, list[i]),
                      _PlanAction.duplicate =>
                        _duplicate(context, ref, list[i]),
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _PlanAction.edit,
                        child: ListTile(
                          leading: const Icon(Icons.edit),
                          title: Text(context.l10n.edit),
                        ),
                      ),
                      PopupMenuItem(
                        value: _PlanAction.duplicate,
                        child: ListTile(
                          leading: const Icon(Icons.copy),
                          title: Text(context.l10n.duplicatePlan),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _openPlan(context, list[i]),
                ),
              ),
      ),
    );
  }

  void _openPlan(BuildContext context, WorkoutPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlanDetailEditScreen(plan: plan)),
    );
  }

  /// Copies a plan to another student.
  ///
  /// Asks which student, because a plan written for one person rarely suits
  /// another — making the coach choose is the point, not a hurdle.
  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    WorkoutPlan plan,
  ) async {
    final others = (await ref.read(studentsProvider.future))
        .where((s) => s.id != student.id)
        .toList();

    if (!context.mounted) return;
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noOtherStudents)),
      );
      return;
    }

    final target = await showDialog<User>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.l10n.duplicateTo),
        children: [
          for (final other in others)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(other),
              child: Text(other.name),
            ),
        ],
      ),
    );
    if (target == null || !context.mounted) return;

    await ref
        .read(appDatabaseProvider)
        .duplicatePlan(plan.id, forStudent: target.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.duplicated)));
    }
  }
}

enum _PlanAction { edit, duplicate }
