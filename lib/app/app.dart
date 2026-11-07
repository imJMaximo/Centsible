import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/preferences_repository.dart';
import 'router.dart';
import 'theme.dart';

class CentsibleApp extends ConsumerWidget {
  const CentsibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(preferencesProvider.select((p) => p.themeMode));
    return MaterialApp.router(
      title: 'Centsible',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
