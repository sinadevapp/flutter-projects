import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/features/auth/application/active_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen shown when nobody is signed in yet.
class RolePickerScreen extends ConsumerWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> pick(UserRole role) async {
      await ref.read(activeSessionProvider.notifier).pickRole(role);
      if (context.mounted) context.go('/');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('FitCoach')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('نقش خود را انتخاب کنید'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => pick(UserRole.coach),
              child: const Text('مربی'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => pick(UserRole.student),
              child: const Text('شاگرد'),
            ),
          ],
        ),
      ),
    );
  }
}
