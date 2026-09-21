import 'package:fit_coach/core/database/students_provider.dart';
import 'package:fit_coach/features/auth/application/active_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase 1 has no real student login: the student picks which record is theirs.
///
/// The picked id is stored in the session, so the choice survives restarts.
class StudentPickerScreen extends ConsumerWidget {
  const StudentPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('شاگرد')),
      body: students.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('هنوز شاگردی ثبت نشده'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(list[i].name),
                  onTap: () => ref
                      .read(activeSessionProvider.notifier)
                      .pickStudent(list[i].id),
                ),
              ),
      ),
    );
  }
}
