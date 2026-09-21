import 'package:drift/drift.dart' show OrderingTerm;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live list of every student on the device.
///
/// Shared read model: the coach dashboard lists students to manage, and the
/// student side lists them to pick "who am I". It lives in core/ so neither
/// feature has to import the other.
final studentsProvider = StreamProvider.autoDispose<List<User>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.users)
        ..where((u) => u.role.equalsValue(UserRole.student))
        ..orderBy([(u) => OrderingTerm.asc(u.id)]))
      .watch();
});
