import 'package:fit_coach/features/auth/application/active_session_provider.dart';
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
      tooltip: 'تغییر نقش',
      onPressed: () => ref.read(activeSessionProvider.notifier).clear(),
    );
  }
}
