// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Daemon and WebSocket connections are deferred until a session starts.
  // This ensures the app launches immediately without blocking on missing
  // Python daemon or Crown hardware.

  runApp(const ProviderScope(child: NeuroLearnApp()));
}

class NeuroLearnApp extends StatelessWidget {
  const NeuroLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NeuroLearn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
