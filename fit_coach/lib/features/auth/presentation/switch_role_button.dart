import 'package:fit_coach/features/auth/presentation/role_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clears the active user so the role picker shows again.
///
/// Phase 1 keeps a single local user per device; this is the only way back
/// to the picker without wiping the app data.
class SwitchRoleButton extends ConsumerWidget {
  const SwitchRoleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'تغییر نقش',
      onPressed: () => ref.read(activeUserProvider.notifier).clear(),
    );
  }
}
