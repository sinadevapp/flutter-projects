import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('inserting and reading a user round-trips name and role', () async {
    await db.insertUser(
      UsersCompanion.insert(name: 'Sina', role: UserRole.coach),
    );

    final users = await db.getAllUsers();

    expect(users.length, 1);
    expect(users.first.name, 'Sina');
    expect(users.first.role, UserRole.coach);
  });

  test('user ids auto-increment', () async {
    await db.insertUser(
      UsersCompanion.insert(name: 'A', role: UserRole.coach),
    );
    await db.insertUser(
      UsersCompanion.insert(name: 'B', role: UserRole.student),
    );

    final users = await db.getAllUsers();

    expect(users.length, 2);
    expect(users[0].id, 1);
    expect(users[1].id, 2);
    expect(users[1].role, UserRole.student);
  });
}
