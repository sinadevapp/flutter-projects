import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/features/coach_hub/domain/student_filter.dart';
import 'package:flutter_test/flutter_test.dart';

User student(int id, String name, StudentVisibility visibility) => User(
      id: id,
      name: name,
      role: UserRole.student,
      photo: null,
      visibility: visibility,
    );

void main() {
  const priv = StudentVisibility.private;
  const pub = StudentVisibility.public;

  final roster = [
    student(1, 'علی', priv),
    student(2, 'رضا', pub),
    student(3, 'سینا', priv),
    student(4, 'مریم', pub),
  ];

  test('the default tab shows everyone, as the screen did before tabs',
      () {
    expect(filterStudents(roster, StudentFilter.all).map((s) => s.name),
        ['علی', 'رضا', 'سینا', 'مریم']);
  });

  test('the private tab keeps only private students', () {
    final privates =
        filterStudents(roster, StudentFilter.private).map((s) => s.name);

    expect(privates, ['علی', 'سینا']);
    expect(privates, isNot(contains('رضا')));
  });

  test('the public tab keeps only public students', () {
    expect(
      filterStudents(roster, StudentFilter.public).map((s) => s.name),
      ['رضا', 'مریم'],
    );
  });

  test('a filter never invents or reorders students', () {
    for (final filter in StudentFilter.values) {
      final result = filterStudents(roster, filter);

      // Filtering is a subset of the input, in the input's order — the tabs
      // must not shuffle the coach's own ordering.
      expect(result.length, lessThanOrEqualTo(roster.length));
      final indexes = [
        for (final s in result) roster.indexWhere((r) => r.id == s.id),
      ];
      expect(indexes, List.of(indexes)..sort(), reason: filter.name);
    }
  });

  test('an empty roster stays empty in every tab', () {
    for (final filter in StudentFilter.values) {
      expect(filterStudents(const [], filter), isEmpty, reason: filter.name);
    }
  });

  test('every student lands in exactly one of the two specific tabs', () {
    final privates = filterStudents(roster, StudentFilter.private);
    final publics = filterStudents(roster, StudentFilter.public);

    // Disjoint, and together they are the whole roster — so no student can be
    // invisible on both tabs.
    expect(privates.map((s) => s.id).toSet()
        .intersection(publics.map((s) => s.id).toSet()),
        isEmpty);
    expect(privates.length + publics.length, roster.length);
  });
}
