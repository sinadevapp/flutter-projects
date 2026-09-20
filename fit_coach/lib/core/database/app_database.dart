import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
  AppDatabase() : super(_openConnection());

  /// In-memory constructor for tests.
  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  Future<int> insertUser(UsersCompanion entry) => into(users).insert(entry);

  Future<List<User>> getAllUsers() => select(users).get();
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'fit_coach');
}
