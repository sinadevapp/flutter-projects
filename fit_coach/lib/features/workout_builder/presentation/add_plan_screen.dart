import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One editable exercise row in the add-plan form.
class _ExerciseDraft {
  final name = TextEditingController();
  final sets = TextEditingController();
  final reps = TextEditingController();

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
  }
}

/// Coach form: build a training plan (title + movements) for one student.
class AddPlanScreen extends ConsumerStatefulWidget {
  const AddPlanScreen({super.key, required this.student});

  final User student;

  @override
  ConsumerState<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends ConsumerState<AddPlanScreen> {
  final _title = TextEditingController();
  final List<_ExerciseDraft> _drafts = [_ExerciseDraft()];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'عنوان برنامه را وارد کنید');
      return;
    }

    // Only rows the coach actually named become exercises.
    final rows = _drafts.where((d) => d.name.text.trim().isNotEmpty).toList();

    setState(() {
      _error = null;
      _saving = true;
    });

    final db = ref.read(appDatabaseProvider);
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: widget.student.id, title: title),
    );

    for (var i = 0; i < rows.length; i++) {
      await db.insertExercise(ExercisesCompanion.insert(
        planId: planId,
        name: rows[i].name.text.trim(),
        sets: int.tryParse(rows[i].sets.text.trim()) ?? 0,
        reps: int.tryParse(rows[i].reps.text.trim()) ?? 0,
        position: Value(i),
      ));
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('برنامه برای ${widget.student.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'عنوان برنامه',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          Text('حرکات', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < _drafts.length; i++) _exerciseRow(i),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _drafts.add(_ExerciseDraft())),
            icon: const Icon(Icons.add),
            label: const Text('افزودن حرکت'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  Widget _exerciseRow(int index) {
    final draft = _drafts[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          TextField(
            controller: draft.name,
            decoration: const InputDecoration(
              labelText: 'نام حرکت',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.sets,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ست',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'تکرار',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
