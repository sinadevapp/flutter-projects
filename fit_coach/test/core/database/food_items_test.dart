import 'dart:io';

import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser, Value;
import 'package:drift/native.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/nutrition_budget/domain/food_cost.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stored row as the domain sees it — the two types stay separate on
/// purpose: [FoodRow] is a database row, [FoodItem] is pricing logic.
FoodItem _toDomain(FoodRow row) => FoodItem(
      id: row.id,
      name: row.name,
      proteinPer100g: row.proteinPer100g,
      kcalPer100g: row.kcalPer100g,
      pricePerKg: row.pricePerKg,
    );

void main() {
  test('a fresh database is seeded with foods but no prices', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final foods = await db.getAllFoods();

    expect(foods, isNotEmpty);
    for (final food in foods) {
      // Macros are facts about the food, so they are seeded...
      expect(food.proteinPer100g, greaterThan(0), reason: food.name);
      expect(food.kcalPer100g, greaterThan(0), reason: food.name);
      // ...but prices belong to the coach's market, so they stay blank.
      // An invented price would look like a fact worth trusting.
      expect(food.pricePerKg, isNull, reason: food.name);
    }
    expect(foods.map((f) => f.name), contains('پروتئین وی'));
    expect(foods.map((f) => f.name), contains('عدس'));
  });

  test('unpriced foods are not comparable, so cannot be ranked', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final ranked =
        rankByProteinCost((await db.getAllFoods()).map(_toDomain).toList());

    // Every food sinks to the unranked tail rather than reading as free.
    expect(ranked, hasLength((await db.getAllFoods()).length));
    expect(ranked.every((f) => f.costPerGramProtein == null), isTrue);
    // Grams-needed still works: it never depended on price.
    expect(ranked.first.gramsForProtein(160), isNotNull);
  });

  test('a food round-trips with its macros and price', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final id = await db.insertFood(
      FoodItemsCompanion.insert(
        name: 'سینه بوقلمون',
        proteinPer100g: 29,
        kcalPer100g: 135,
        pricePerKg: const Value(480000),
      ),
    );

    final food = await db.getFood(id);
    expect(food!.name, 'سینه بوقلمون');
    expect(food.proteinPer100g, 29);
    expect(food.kcalPer100g, 135);
    expect(food.pricePerKg, 480000);
  });

  test('entering a price stores it and stamps the time', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final id = await db.insertFood(
      FoodItemsCompanion.insert(
        name: 'تخم مرغ',
        proteinPer100g: 13,
        kcalPer100g: 155,
      ),
    );
    expect((await db.getFood(id))!.pricePerKg, isNull);
    final before = (await db.getFood(id))!.updatedAt;

    await db.updateFoodPrice(id, 180000);

    final after = await db.getFood(id);
    expect(after!.pricePerKg, 180000);
    expect(after.updatedAt.isBefore(before), isFalse);
  });

  test('clearing a price blanks it rather than zeroing it', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final id = await db.insertFood(
      FoodItemsCompanion.insert(
        name: 'نخود',
        proteinPer100g: 19,
        kcalPer100g: 364,
        pricePerKg: const Value(100000),
      ),
    );

    await db.updateFoodPrice(id, null);

    // 0 would read as "free"; null reads as "not known yet".
    expect((await db.getFood(id))!.pricePerKg, isNull);
  });

  test('priced foods rank against each other through the domain', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final all = await db.getAllFoods();
    await db.updateFoodPrice(
        all.firstWhere((f) => f.name == 'پروتئین وی').id, 2500000);
    await db.updateFoodPrice(
        all.firstWhere((f) => f.name == 'عدس').id, 100000);

    final ranked =
        rankByProteinCost((await db.getAllFoods()).map(_toDomain).toList());

    // 100000/250 = 400 toman per gram of protein vs 2500000/800 = 3125.
    expect(ranked.first.name, 'عدس');
    expect(ranked.first.costPerGramProtein, closeTo(400, 0.01));
  });

  test('deleting every food does not bring the seed data back', () async {
    final dir = Directory.systemTemp.createTempSync('fit_coach_foods');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/foods.sqlite');

    final first = AppDatabase(executor: NativeDatabase(file));
    await first.deleteAllFoods();
    await first.close();

    // Reopening must not re-seed: an empty list is a choice the coach made.
    final second = AppDatabase(executor: NativeDatabase(file));
    addTearDown(second.close);

    expect(await second.getAllFoods(), isEmpty);
  });

  test('a database created at schema 6 upgrades and gains food items',
      () async {
    final dir = Directory.systemTemp.createTempSync('fit_coach_upgrade6');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/legacy6.sqlite');

    // The schema an install of the previous version left on disk.
    final legacy = NativeDatabase(file);
    await legacy.ensureOpen(_LegacyUser(6));
    for (final sql in _schema6) {
      await legacy.runCustom(sql, const []);
    }
    await legacy.runCustom('INSERT INTO users (name, role) VALUES (?, ?)',
        ['علی', UserRole.student.index]);
    await legacy.runCustom('PRAGMA user_version = 6', const []);
    await legacy.close();

    // Opening with the current code must migrate, not crash — and must keep
    // the coach's existing data.
    final upgraded = AppDatabase(executor: NativeDatabase(file));
    addTearDown(upgraded.close);

    expect((await upgraded.getAllUsers()).map((u) => u.name), ['علی']);
    expect(await upgraded.getAllFoods(), isNotEmpty);

    // The new column is usable, and starts blank.
    final id = await upgraded.insertFood(
      FoodItemsCompanion.insert(
        name: 'ماست یونانی',
        proteinPer100g: 10,
        kcalPer100g: 59,
      ),
    );
    expect((await upgraded.getFood(id))!.pricePerKg, isNull);
  });
}

/// The tables a schema-6 install already had, in the exact shape Drift emits.
const _schema6 = [
  'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, role INTEGER NOT NULL)',
  'CREATE TABLE workout_plans (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'title TEXT NOT NULL, created_at INTEGER NOT NULL)',
  'CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'name TEXT NOT NULL, sets INTEGER NOT NULL, reps INTEGER NOT NULL, '
      'position INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'role INTEGER NOT NULL, student_id INTEGER NULL REFERENCES users(id))',
  'CREATE TABLE workout_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'started_at INTEGER NOT NULL, finished_at INTEGER NULL)',
  'CREATE TABLE set_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'session_id INTEGER NOT NULL REFERENCES workout_sessions(id), '
      'exercise_id INTEGER NOT NULL REFERENCES exercises(id), '
      'set_number INTEGER NOT NULL, completed_at INTEGER NOT NULL)',
  'CREATE TABLE app_settings (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'locale TEXT NULL)',
];

class _LegacyUser implements QueryExecutorUser {
  _LegacyUser(this.version);

  final int version;

  @override
  Future<void> beforeOpen(
          QueryExecutor executor, OpeningDetails details) async {}

  @override
  int get schemaVersion => version;
}
