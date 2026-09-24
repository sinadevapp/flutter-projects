import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/schedule/exercise_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise ex({
  required int id,
  required int week,
  required int day,
  int sets = 3,
  int reps = 10,
  ExerciseCategory category = ExerciseCategory.compound,
  int position = 0,
  String name = 'حرکت',
}) => Exercise(
  id: id,
  planId: 1,
  weekNumber: week,
  dayNumber: day,
  name: name,
  sets: sets,
  reps: reps,
  category: category,
  position: position,
);

/// A two-week sample shaped like a real PPL block: week 1 legs+chest on two
/// days, week 2 the same movements with different sets.
final sample = [
  ex(
    id: 1,
    week: 1,
    day: 1,
    name: 'اسکوات',
    category: ExerciseCategory.legs,
    position: 0,
  ),
  ex(
    id: 2,
    week: 1,
    day: 1,
    name: 'پرس سینه',
    sets: 4,
    category: ExerciseCategory.chest,
    position: 1,
  ),
  ex(
    id: 3,
    week: 1,
    day: 2,
    name: 'لانج',
    sets: 3,
    reps: 12,
    category: ExerciseCategory.legs,
    position: 0,
  ),
  ex(
    id: 4,
    week: 2,
    day: 1,
    name: 'اسکوات',
    sets: 5,
    category: ExerciseCategory.legs,
    position: 0,
  ),
];

void main() {
  group('finding the days of a plan', () {
    test('an empty plan has no days', () {
      expect(daysOf(const []), isEmpty);
      expect(nextWeekToAuthor(const []), 1);
    });

    test('days are listed in authoring order: week, then day', () {
      // Inserted out of order on purpose — the schedule must not depend on
      // how the rows happened to arrive.
      final scrambled = [
        ex(id: 4, week: 2, day: 1),
        ex(id: 3, week: 1, day: 2),
        ex(id: 1, week: 1, day: 1),
        ex(id: 2, week: 1, day: 1),
      ];

      expect(daysOf(scrambled), [(1, 1), (1, 2), (2, 1)]);
    });

    test('a day is reported once no matter how many movements it has', () {
      expect(daysOf(sample), [(1, 1), (1, 2), (2, 1)]);
    });
  });

  group('reading one day', () {
    test('returns only that day, in display order', () {
      final day = exercisesForDay(sample, 1, 1);

      expect(day.map((e) => e.name).toList(), ['اسکوات', 'پرس سینه']);
      expect(day.map((e) => e.id).toList(), [1, 2]);
    });

    test('position orders inside the day, not across the plan', () {
      // Both days start at position 0. Reading by position alone would
      // interleave them; the day has to be selected first.
      final day2 = exercisesForDay(sample, 1, 2);

      expect(day2.map((e) => e.id), [3]);
      expect(exercisesForDay(sample, 1, 1).map((e) => e.id), [1, 2]);
    });

    test('a week or day with nothing in it is empty, not an error', () {
      expect(exercisesForDay(sample, 3, 9), isEmpty);
      expect(exercisesForWeek(sample, 3), isEmpty);
      expect(exercisesForWeek(sample, 1), hasLength(3));
    });
  });

  group('categories', () {
    test('each movement carries the coach\'s tag', () {
      final legs = exercisesForDay(
        sample,
        1,
        1,
      ).where((e) => e.category == ExerciseCategory.legs);

      expect(legs.map((e) => e.name), ['اسکوات']);
    });

    test('the tag is preserved by movement id, not by name', () {
      // Two different weeks both have an اسکوات; the tag belongs to the row.
      expect(
        exercisesForWeek(sample, 2).single.category,
        ExerciseCategory.legs,
      );
    });
  });

  group('which week to author next', () {
    test('starts at 1 when there is nothing yet', () {
      expect(nextWeekToAuthor(const []), 1);
    });

    test('is the first week with no movements in it', () {
      expect(nextWeekToAuthor(sample), 3);
    });

    test('a hole in the middle counts as the next week', () {
      final gap = [ex(id: 1, week: 1, day: 1), ex(id: 3, week: 3, day: 1)];

      // Week 2 is empty, so it is what the coach should author next.
      expect(nextWeekToAuthor(gap), 2);
    });
  });

  group('copying a week', () {
    test('every movement is relabelled for the new week', () {
      final copies = copyWeekForward(
        planId: 7,
        source: sample,
        fromWeek: 1,
        toWeek: 3,
      );

      expect(copies, hasLength(3));
      for (final copy in copies) {
        expect(copy.weekNumber, isNotNull);
        expect(copy.weekNumber.value, 3);
        // The plan, day, order and category all carry over unchanged.
        expect(copy.planId.value, 7);
      }
    });

    test('the shape of the week survives: days, order, sets, category', () {
      final copies = copyWeekForward(
        planId: 1,
        source: sample,
        fromWeek: 1,
        toWeek: 2,
      );

      expect(
        copies.map((c) => c.dayNumber.value).toList(),
        [1, 1, 2],
        reason: 'day grouping is what makes the copy usable',
      );
      expect(
        copies.map((c) => c.position.value).toList(),
        [0, 1, 0],
        reason: 'order within a day must hold',
      );
      expect(copies.map((c) => c.name.value).toList(), [
        'اسکوات',
        'پرس سینه',
        'لانج',
      ]);
      expect(copies.map((c) => c.sets.value).toList(), [3, 4, 3]);
      expect(copies.map((c) => c.category.value).toList(), [
        ExerciseCategory.legs,
        ExerciseCategory.chest,
        ExerciseCategory.legs,
      ]);
    });

    test('the source is untouched — a copy is not a move', () {
      copyWeekForward(planId: 1, source: sample, fromWeek: 1, toWeek: 3);

      // `sample` is not mutated; week 1 still has exactly three movements.
      expect(exercisesForWeek(sample, 1), hasLength(3));
      expect(sample.where((e) => e.weekNumber == 3), isEmpty);
    });

    test('copying a week onto itself copies nothing', () {
      // There is no destination distinct from the source, so merging would be
      // the only alternative — and doubling a week by accident is worse than
      // doing nothing.
      expect(
        copyWeekForward(planId: 1, source: sample, fromWeek: 1, toWeek: 1),
        isEmpty,
      );
    });

    test('an empty source copies nothing', () {
      expect(
        copyWeekForward(planId: 1, source: sample, fromWeek: 9, toWeek: 10),
        isEmpty,
      );
    });

    test('a filled destination is refused rather than merged into', () {
      // Week 2 already has movements. Overwriting or appending to it would
      // destroy what the coach wrote there.
      expect(canCopyWeek(sample, fromWeek: 1, toWeek: 2), isFalse);
      expect(canCopyWeek(sample, fromWeek: 1, toWeek: 3), isTrue);
    });

    test('the next empty week is always copyable from a filled one', () {
      final next = nextWeekToAuthor(sample);

      expect(canCopyWeek(sample, fromWeek: 1, toWeek: next), isTrue);
    });
  });
}
