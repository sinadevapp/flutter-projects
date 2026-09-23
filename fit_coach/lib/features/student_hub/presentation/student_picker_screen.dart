import 'package:fit_coach/core/database/students_provider.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:fit_coach/core/widgets/states.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.student)),
      body: students.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          onRetry: () => ref.invalidate(studentsProvider),
        ),
        data: (list) => list.isEmpty
            // Nothing the student can do here — the coach has not registered
            // anyone yet — so this explains rather than offering an action.
            ? EmptyState(
                icon: Icons.person_search_outlined,
                message: l10n.noStudentsRegistered,
                hint: l10n.askCoachToAddYou,
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
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => ref
                        .read(activeSessionProvider.notifier)
                        .pickStudent(list[i].id),
                  ),
                ),
              ),
      ),
    );
  }
}
