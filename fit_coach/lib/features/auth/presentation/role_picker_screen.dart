import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/settings/language_button.dart';
import 'package:fit_coach/core/session/active_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen shown when nobody is signed in yet.
class RolePickerScreen extends ConsumerWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    Future<void> pick(UserRole role) async {
      await ref.read(activeSessionProvider.notifier).pickRole(role);
      if (context.mounted) context.go('/');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitCoach'),
        actions: const [LanguageButton()],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.rolePickerTitle),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => pick(UserRole.coach),
              child: Text(l10n.coach),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => pick(UserRole.student),
              child: Text(l10n.student),
            ),
          ],
        ),
      ),
    );
  }
}
