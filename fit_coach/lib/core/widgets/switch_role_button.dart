import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/session/active_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signs out: clears the session so the role picker shows again.
///
/// The coach's students and plans are untouched — only the session row goes.
class SwitchRoleButton extends ConsumerWidget {
  const SwitchRoleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: context.l10n.switchRole,
      onPressed: () => ref.read(activeSessionProvider.notifier).clear(),
    );
  }
}
