import 'package:fit_coach/features/coach_hub/presentation/add_student_screen.dart';
import 'package:fit_coach/features/auth/presentation/switch_role_button.dart';
import 'package:fit_coach/features/workout_builder/presentation/student_detail_screen.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live stream of the students table for the coach dashboard.
final studentsProvider = StreamProvider.autoDispose<List<User>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.users)
        ..where((u) => u.role.equalsValue(UserRole.student)))
      .watch();
});

/// Coach dashboard: list of students and (later) workout management.
class CoachHubScreen extends ConsumerWidget {
  const CoachHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مربی'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'افزودن شاگرد',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddStudentScreen()),
            ),
          ),
          const SwitchRoleButton(),
        ],
      ),
      body: students.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('هنوز شاگردی اضافه نشده'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(list[i].name),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudentDetailScreen(student: list[i]),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
