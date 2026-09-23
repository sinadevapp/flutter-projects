import 'package:fit_coach/core/widgets/states.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/features/auth/application/active_session_provider.dart';
import 'package:fit_coach/features/auth/presentation/role_picker_screen.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:fit_coach/features/student_hub/presentation/student_picker_screen.dart';
import 'package:fit_coach/features/student_hub/presentation/student_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Central application router.
///
/// Routes will grow as features are added; each feature registers its own
/// branch later (auth, coach_hub, ...).
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _HomeGate(),
      ),
    ],
  );
}

/// Shows the role picker until a session exists, then the screen that belongs
/// to the signed-in role.
class _HomeGate extends ConsumerWidget {
  const _HomeGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);

    return session.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Scaffold(body: ErrorState()),
      data: (session) {
        if (session == null) return const RolePickerScreen();
        if (session.role == UserRole.coach) return const CoachHubScreen();

        // Student: pick which record is theirs before showing a plan.
        final studentId = session.studentId;
        return studentId == null
            ? const StudentPickerScreen()
            : StudentPlanScreen(studentId: studentId);
      },
    );
  }
}
