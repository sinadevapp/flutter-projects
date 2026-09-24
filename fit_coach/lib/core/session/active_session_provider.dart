import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who this device is currently acting as. Null = nobody signed in.
class ActiveSession {
  const ActiveSession({required this.role, this.studentId});

  final UserRole role;

  /// Set when [role] is [UserRole.student]: the student record being acted as.
  final int? studentId;
}

/// The current session, persisted in the `sessions` table so a restart keeps
/// you where you were. Deliberately separate from the coach's data: signing
/// out never deletes students or their plans.
final activeSessionProvider =
    AsyncNotifierProvider<ActiveSessionNotifier, ActiveSession?>(
  ActiveSessionNotifier.new,
);

class ActiveSessionNotifier extends AsyncNotifier<ActiveSession?> {
  @override
  Future<ActiveSession?> build() async {
    final db = ref.read(appDatabaseProvider);
    final role = await db.getActiveRole();
    if (role == null) return null;
    return ActiveSession(role: role, studentId: await db.getActiveStudentId());
  }

  Future<void> pickRole(UserRole role) async {
    await ref.read(appDatabaseProvider).setActiveRole(role);
    state = AsyncData(ActiveSession(role: role));
  }

  /// Phase 1 has no real login: the student says which record they are.
  Future<void> pickStudent(int studentId) async {
    await ref
        .read(appDatabaseProvider)
        .setActiveRole(UserRole.student, studentId: studentId);
    state = AsyncData(
      ActiveSession(role: UserRole.student, studentId: studentId),
    );
  }

  /// Signs out — students and plans stay in the database.
  Future<void> clear() async {
    await ref.read(appDatabaseProvider).clearActiveRole();
    state = const AsyncData(null);
  }
}
