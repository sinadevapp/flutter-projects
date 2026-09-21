import 'package:drift/drift.dart';
// NOTE: do NOT import drift/native.dart or drift/wasm.dart here —
// this file is shared across native and web; dart:ffi breaks dart2js.
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Role of a user inside the coaching platform.
enum UserRole { coach, student }

/// Users table: coaches and students of the platform.
///
/// Phase 1 is local-only; a sync layer can map this to a backend later.
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get role => intEnum<UserRole>()();
}

@DriftDatabase(tables: [Users])
class AppDatabase extends _$AppDatabase {
  /// Platform-appropriate connection:
  /// native (Android/Windows) uses the bundled sqlite3,
  /// web uses the WASM build via web/sqlite3.wasm + web/drift_worker.js.
  AppDatabase({QueryExecutor? executor})
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> insertUser(UsersCompanion entry) => into(users).insert(entry);

  Future<List<User>> getAllUsers() => select(users).get();

  Future<int> deleteAllUsers() => delete(users).go();
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'fit_coach',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
