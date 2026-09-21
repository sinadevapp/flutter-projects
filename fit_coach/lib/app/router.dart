import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/features/auth/application/active_role_provider.dart';
import 'package:fit_coach/features/auth/presentation/role_picker_screen.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:fit_coach/features/student_hub/presentation/student_home_screen.dart';
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

/// Shows the role picker until a session exists, then the home screen that
/// belongs to the signed-in role.
class _HomeGate extends ConsumerWidget {
  const _HomeGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);

    return role.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (role) => switch (role) {
        null => const RolePickerScreen(),
        UserRole.coach => const CoachHubScreen(),
        UserRole.student => const StudentHomeScreen(),
      },
    );
  }
}
