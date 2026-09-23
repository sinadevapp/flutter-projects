import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Form screen for the coach to add a new student.
class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _nameController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.nameRequired);
      return;
    }

    await ref.read(appDatabaseProvider).insertUser(
          UsersCompanion.insert(name: name, role: UserRole.student),
        );
    setState(() => _error = null);

    // Return to the list: the coach added the student in order to *see* them
    // there, and leaving them on a cleared form makes them navigate back for
    // something they already asked for.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addStudent)),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.studentNameLabel,
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
