import 'package:fit_coach/core/settings/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Language switcher: shows each language in its own script, the way apps
/// usually do, so it is readable whichever language is active.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider).value ??
        Localizations.localeOf(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onSelected: (code) =>
          ref.read(appLocaleProvider.notifier).setLocale(Locale(code)),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'fa',
          checked: locale.languageCode == 'fa',
          child: const Text('فارسی'),
        ),
        CheckedPopupMenuItem(
          value: 'en',
          checked: locale.languageCode == 'en',
          child: const Text('English'),
        ),
      ],
    );
  }
}
