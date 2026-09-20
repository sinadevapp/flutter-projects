import 'package:fit_coach/features/auth/presentation/role_picker_screen.dart';
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

/// Shows the role picker until an active user exists, then home.
class _HomeGate extends ConsumerWidget {
  const _HomeGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeUser = ref.watch(activeUserProvider);

    return activeUser.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) =>
          user == null ? const RolePickerScreen() : const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FitCoach')),
      body: const Center(child: Text('FitCoach')),
    );
  }
}
