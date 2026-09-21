import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Currently active user (null = no user picked yet).
///
/// Phase 1: single local user per device. Loading happens on app start;
/// picking a role inserts a user row and sets this provider.
final activeUserProvider =
    AsyncNotifierProvider<ActiveUserNotifier, User?>(
  ActiveUserNotifier.new,
);

class ActiveUserNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final db = ref.read(appDatabaseProvider);
    final users = await db.getAllUsers();
    return users.isEmpty ? null : users.first;
  }

  Future<void> pickRole(UserRole role) async {
    final db = ref.read(appDatabaseProvider);
    final id = await db
        .insertUser(UsersCompanion.insert(name: role.name, role: role));
    state = AsyncData(User(
      id: id,
      name: role.name,
      role: role,
    ));
  }

  /// Drops the local user and returns to the role picker.
  Future<void> clear() async {
    final db = ref.read(appDatabaseProvider);
    await db.deleteAllUsers();
    state = const AsyncData(null);
  }
}

/// Screen shown when there is no active user yet.
class RolePickerScreen extends ConsumerWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('FitCoach')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('نقش خود را انتخاب کنید'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await ref.read(activeUserProvider.notifier).pickRole(
                      UserRole.coach,
                    );
                if (context.mounted) context.go('/');
              },
              child: const Text('مربی'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await ref.read(activeUserProvider.notifier).pickRole(
                      UserRole.student,
                    );
                if (context.mounted) context.go('/');
              },
              child: const Text('شاگرد'),
            ),
          ],
        ),
      ),
    );
  }
}
