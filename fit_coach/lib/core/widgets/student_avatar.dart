import 'package:fit_coach/core/database/app_database.dart';
import 'package:flutter/material.dart';

/// The coach's photo for a student, or a stand-in when there is none.
///
/// One widget so the coach's list and the student's own picker cannot drift
/// apart — a student must look the same to themselves as they do to their
/// coach.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({super.key, required this.student, this.radius = 20});

  final User student;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = student.photo;

    if (photo == null || photo.isEmpty) {
      // No photo is the normal case, not an error: a default icon instead of
      // the student's initial keeps a half-filled roster from looking broken.
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(Icons.person, size: radius * 1.2, color: scheme.outline),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surfaceContainerHighest,
      backgroundImage: MemoryImage(photo),
    );
  }
}
