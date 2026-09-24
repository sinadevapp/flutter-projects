import 'dart:typed_data';

import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:fit_coach/core/utils/pick_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Corrects a student's name, photo and kind after registration.
///
/// Without this, picking the wrong kind at registration is permanent — and a
/// feature the coach can only ever set once is a feature they will avoid.
class EditStudentScreen extends ConsumerStatefulWidget {
  const EditStudentScreen({super.key, required this.student});

  final User student;

  @override
  ConsumerState<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends ConsumerState<EditStudentScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.student.name);
  late Uint8List? _photo = widget.student.photo;
  late StudentVisibility _visibility = widget.student.visibility;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    // Cancelling leaves the current photo alone rather than clearing it.
    final picked = await pickStudentPhoto();
    if (picked == null) return;
    if (mounted) setState(() => _photo = picked);
  }

  Future<void> _removePhoto() async {
    if (mounted) setState(() => _photo = null);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.nameRequired);
      return;
    }

    final db = ref.read(appDatabaseProvider);
    await db.updateStudentName(widget.student.id, name);
    await db.updateStudentPhoto(widget.student.id, _photo);
    await db.updateStudentVisibility(widget.student.id, _visibility);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.studentUpdated)));
    Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteStudent),
        // Names them: the coach came here from a list that may hold several
        // people, and an unlabelled confirmation is a wrong press waiting to
        // happen.
        content: Text(
          context.l10n.deleteStudentConfirm(widget.student.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Take them off the roster entirely: plans, movements, sessions, logs,
    // nutrition profile, sign-in row and photo all go with them.
    await ref.read(appDatabaseProvider).deleteStudent(widget.student.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.studentDeleted)));

    // This screen and the student's detail page both describe someone who no
    // longer exists, so leave both — popping once would land on a dead record.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = _photo != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editStudent)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: hasPhoto ? MemoryImage(_photo!) : null,
                    child: hasPhoto
                        ? null
                        : Icon(Icons.person, size: 48, color: scheme.outline),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(
                            hasPhoto ? l10n.changePhoto : l10n.addPhoto),
                      ),
                      if (hasPhoto)
                        TextButton.icon(
                          onPressed: _removePhoto,
                          icon: const Icon(Icons.close),
                          label: Text(l10n.removePhoto),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.studentNameLabel,
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.visibilityLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<StudentVisibility>(
              segments: [
                ButtonSegment(
                  value: StudentVisibility.private,
                  label: Text(l10n.privateStudent),
                  icon: const Icon(Icons.person_outline),
                ),
                ButtonSegment(
                  value: StudentVisibility.public,
                  label: Text(l10n.publicStudent),
                  icon: const Icon(Icons.groups_outlined),
                ),
              ],
              selected: {_visibility},
              onSelectionChanged: (selection) =>
                  setState(() => _visibility = selection.first),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: _save, child: Text(l10n.save)),
            const SizedBox(height: 16),
            // Destructive and separate from Save: pressing the wrong one here
            // either loses the edits or loses the student.
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onPressed: _remove,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.deleteStudent),
            ),
          ],
        ),
      ),
    );
  }
}
