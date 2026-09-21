import 'package:fit_coach/features/auth/presentation/switch_role_button.dart';
import 'package:flutter/material.dart';

/// Student home — placeholder until the student features land
/// (workout execution, nutrition budget, progress tracking).
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاگرد'),
        actions: const [SwitchRoleButton()],
      ),
      body: const Center(
        child: Text('به‌زودی: برنامه تمرینی شما اینجا نمایش داده می‌شود'),
      ),
    );
  }
}
