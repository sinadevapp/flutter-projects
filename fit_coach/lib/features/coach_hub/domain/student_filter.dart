import 'package:fit_coach/core/database/app_database.dart';

/// Which of the three tabs of the coach's student list.
///
/// Pure on purpose: which students belong where is a rule about the data, not
/// about the widget showing it, so it is unit-tested without a screen.
enum StudentFilter { all, private, public }

/// Keeps only the students that belong under [filter].
///
/// Order is preserved — the coach's list order is the coach's, and a filter
/// that shuffled it would make students appear to move between tabs.
List<User> filterStudents(List<User> students, StudentFilter filter) {
  return switch (filter) {
    StudentFilter.all => students,
    StudentFilter.private => students
        .where((s) => s.visibility == StudentVisibility.private)
        .toList(),
    StudentFilter.public => students
        .where((s) => s.visibility == StudentVisibility.public)
        .toList(),
  };
}
