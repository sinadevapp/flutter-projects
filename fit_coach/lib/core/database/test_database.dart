import 'package:drift/native.dart';

import 'app_database.dart';

/// In-memory database for tests (VM only — web tests use sqlite3 WASM).
AppDatabase createTestDatabase() {
  return AppDatabase(executor: NativeDatabase.memory());
}
