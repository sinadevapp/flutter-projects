import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The role this device is currently acting as (null = nobody signed in).
///
/// Persisted in the `sessions` table so a restart keeps you where you were.
/// Session state is deliberately separate from the coach's data: signing out
/// and back in must never delete students or their plans.
final activeRoleProvider =
    AsyncNotifierProvider<ActiveRoleNotifier, UserRole?>(ActiveRoleNotifier.new);

class ActiveRoleNotifier extends AsyncNotifier<UserRole?> {
  @override
  Future<UserRole?> build() => ref.read(appDatabaseProvider).getActiveRole();

  Future<void> pickRole(UserRole role) async {
    await ref.read(appDatabaseProvider).setActiveRole(role);
    state = AsyncData(role);
  }

  /// Signs out — students and plans stay in the database.
  Future<void> clear() async {
    await ref.read(appDatabaseProvider).clearActiveRole();
    state = const AsyncData(null);
  }
}
