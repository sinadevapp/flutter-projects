import 'package:fit_coach/features/coach_hub/presentation/add_student_screen.dart';
import 'package:fit_coach/features/auth/presentation/switch_role_button.dart';
import 'package:fit_coach/features/workout_builder/presentation/student_detail_screen.dart';
import 'package:fit_coach/core/database/students_provider.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:fit_coach/core/widgets/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coach dashboard: list of students and (later) workout management.
class CoachHubScreen extends ConsumerWidget {
  const CoachHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider);

    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.coach),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: l10n.addStudent,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddStudentScreen()),
            ),
          ),
          const SwitchRoleButton(),
        ],
      ),
      body: students.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(onRetry: () => ref.invalidate(studentsProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.groups_outlined,
                message: l10n.noStudentsRegistered,
                hint: l10n.noStudentsHint,
                action: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddStudentScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.person_add),
                  label: Text(l10n.addStudent),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        list[i].name.characters.first,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      list[i].name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    // Mirrored deliberately: in RTL a left chevron points at
                    // the next screen.
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentDetailScreen(student: list[i]),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
