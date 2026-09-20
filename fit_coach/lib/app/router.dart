import 'package:flutter/material.dart';
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
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
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
