import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// The library the coach picks from instead of retyping names.
///
/// A coach writing three programs types "اسکوات" fifteen times. Worse, they
/// type three spellings of it, and history later reads as four different
/// movements — which is how a volume chart starts lying without anyone
/// deciding it should.
void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  group('the seed', () {
    test('exists and is usable on a fresh install', () async {
      final items = await db.libraryFor(null);

      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.name, isNotEmpty);
        expect(item.category, isNotNull);
      }
    });

    test('covers every category the coach can pick', () async {
      for (final category in ExerciseCategory.values) {
        final items = await db.libraryFor(category);

        expect(items, isNotEmpty, reason: 'no library entries for $category');
        expect(
          items.every((i) => i.category == category),
          isTrue,
          reason: 'wrong category leaked into $category',
        );
      }
    });

    test('is ordered so the common movement comes first', () async {
      final items = await db.libraryFor(ExerciseCategory.legs);

      // Squat first: the coach reaching for the legs category almost always
      // wants it, and putting it behind three obscure machines defeats the
      // point of having a list at all.
      expect(items.first.name, 'اسکوات');
    });
  });

  group('browsing', () {
    test('a null category means the whole library', () async {
      final everything = await db.libraryFor(null);
      final legs = await db.libraryFor(ExerciseCategory.legs);

      expect(everything.length, greaterThan(legs.length));
      expect(
        everything.where((i) => i.category == ExerciseCategory.legs),
        hasLength(legs.length),
      );
    });

    test('search is by prefix and is case-insensitive on latin names', () async {
      expect(await db.searchLibrary('اسک'), isNotEmpty);
      expect(await db.searchLibrary('Barbell'), hasLength(1));
      expect(await db.searchLibrary('ژراث'), isEmpty);
    });

    test('search spans categories, because a name search is not a filter',
        () async {
      final found = await db.searchLibrary('اسکوات');

      expect(found.map((e) => e.category), contains(ExerciseCategory.legs));
    });

    test('a prefix nobody typed returns nothing rather than everything', () async {
      // Every category has entries — the seed covers them all — so a query
      // that returns nothing has to be *not matching*, not "unknown".
      final everything = await db.libraryFor(null);

      expect(await db.libraryFor(ExerciseCategory.arms), isNotEmpty);
      expect(await db.searchLibrary('اسکواتناموجود'), isEmpty);
      // Blank means "not typed yet", so it returns everything rather than
      // nothing — the same choice the row makes before a search begins.
      expect(await db.searchLibrary('   '), hasLength(everything.length));
    });
  });

  group('adding', () {
    test('a coach\'s own movement joins the library', () async {
      final before = (await db.libraryFor(ExerciseCategory.chest)).length;

      await db.addToLibrary(
        name: 'پرس سینه دستگیره‌دار',
        category: ExerciseCategory.chest,
      );

      final after = await db.libraryFor(ExerciseCategory.chest);
      expect(after, hasLength(before + 1));
      expect(after.map((e) => e.name), contains('پرس سینه دستگیره‌دار'));
    });

    test('adding the same name twice does not duplicate it', () async {
      await db.addToLibrary(name: 'اسکوات', category: ExerciseCategory.legs);
      final after = (await db.libraryFor(ExerciseCategory.legs)).length;

      await db.addToLibrary(name: 'اسکوات', category: ExerciseCategory.legs);

      expect((await db.libraryFor(ExerciseCategory.legs)).length, after);
    });

    test('the same name under another category is a different entry', () async {
      // A name can belong to two ways of categorising — "ددلیفت" is both a
      // back movement and the classic compound. Deduplicating across
      // categories would throw one of them away.
      await db.addToLibrary(name: 'ددلیفت', category: ExerciseCategory.back);
      await db.addToLibrary(name: 'ددلیفت', category: ExerciseCategory.compound);

      expect(
        (await db.searchLibrary('ددلیفت')).map((e) => e.category).toSet(),
        {ExerciseCategory.back, ExerciseCategory.compound},
      );
    });

    test('a blank name is refused rather than stored empty', () async {
      final before = (await db.libraryFor(null)).length;

      await db.addToLibrary(name: '   ', category: ExerciseCategory.legs);

      expect((await db.libraryFor(null)).length, before);
    });
  });
}
