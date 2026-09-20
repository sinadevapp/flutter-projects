import 'package:fit_coach/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget of the FitCoach application.
class FitCoachApp extends ConsumerWidget {
  const FitCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'FitCoach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      routerConfig: buildAppRouter(),
    );
  }
}
