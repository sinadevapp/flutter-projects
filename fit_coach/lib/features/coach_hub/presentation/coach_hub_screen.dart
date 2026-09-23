import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/students_provider.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:fit_coach/core/widgets/states.dart';
import 'package:fit_coach/core/widgets/student_avatar.dart';
import 'package:fit_coach/features/auth/presentation/switch_role_button.dart';
import 'package:fit_coach/features/coach_hub/domain/student_filter.dart';
import 'package:fit_coach/features/coach_hub/presentation/add_student_screen.dart';
import 'package:fit_coach/features/workout_builder/presentation/student_detail_screen.dart';
import 'package:fit_coach/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coach dashboard: the roster, split by the kind of student.
class CoachHubScreen extends ConsumerWidget {
  const CoachHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider);
    final l10n = context.l10n;

    return DefaultTabController(
      // One tab per [StudentFilter], in declaration order.
      length: StudentFilter.values.length,
      child: Scaffold(
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
          bottom: TabBar(
            tabs: [
              for (final filter in StudentFilter.values)
                Tab(text: _tabLabel(l10n, filter)),
            ],
          ),
        ),
        body: students.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              ErrorState(onRetry: () => ref.invalidate(studentsProvider)),
          data: (all) => TabBarView(
            children: [
              for (final filter in StudentFilter.values)
                _RosterPane(
                  students: filterStudents(all, filter),
                  filter: filter,
                  totalRosterSize: all.length,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _tabLabel(AppLocalizations l10n, StudentFilter filter) =>
      switch (filter) {
        StudentFilter.all => l10n.tabAll,
        StudentFilter.private => l10n.tabPrivate,
        StudentFilter.public => l10n.tabPublic,
      };
}

/// One tab's worth of the roster.
///
/// Separate from the screen so each tab owns its own empty state — an empty
/// private tab and an empty roster are not the same thing.
class _RosterPane extends ConsumerWidget {
  const _RosterPane({
    required this.students,
    required this.filter,
    required this.totalRosterSize,
  });

  final List<User> students;
  final StudentFilter filter;
  final int totalRosterSize;

  void _addStudent(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
    );
  }

  String _emptyMessage(AppLocalizations l10n) => switch (filter) {
        // Nobody at all: the coach's first use, so explain and offer the fix.
        StudentFilter.all => l10n.noStudentsRegistered,
        StudentFilter.private => l10n.noPrivateStudents,
        StudentFilter.public => l10n.noPublicStudents,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // Nobody in the roster at all: the action matters more than the tab, since
    // every tab is equally empty.
    if (totalRosterSize == 0) {
      return EmptyState(
        icon: Icons.groups_outlined,
        message: l10n.noStudentsRegistered,
        hint: l10n.noStudentsHint,
        action: FilledButton.icon(
          onPressed: () => _addStudent(context),
          icon: const Icon(Icons.person_add),
          label: Text(l10n.addStudent),
        ),
      );
    }

    if (students.isEmpty) {
      // The roster exists, this tab just has nobody in it. No action needed:
      // the students are under another tab, so the message says so.
      return EmptyState(
        icon: switch (filter) {
          StudentFilter.all => Icons.groups_outlined,
          StudentFilter.private => Icons.person_outline,
          StudentFilter.public => Icons.groups_outlined,
        },
        message: _emptyMessage(l10n),
        hint: l10n.emptyTabHint,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => Card(
        child: ListTile(
          leading: StudentAvatar(student: students[i]),
          title: Text(
            students[i].name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          // The same fact as the tab, restated so a glance at one row is
          // enough — the tabs are a filter, not a legend.
          subtitle: Text(
            students[i].visibility == StudentVisibility.private
                ? l10n.privateStudent
                : l10n.publicStudent,
          ),
          // Mirrored deliberately: in RTL a left chevron points at the next
          // screen.
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(student: students[i]),
            ),
          ),
        ),
      ),
    );
  }
}
