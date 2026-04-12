// lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/eeg_service.dart';
import 'core/services/websocket_client.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the Python EEG daemon on desktop platforms.
  if (EEGService.instance.isDesktop) {
    await EEGService.instance.startDaemon();
  }

  // Connect to the daemon's WebSocket server.
  await WebSocketClient.instance.connect();

  runApp(const ProviderScope(child: NeuroLearnApp()));
}

class NeuroLearnApp extends StatelessWidget {
  const NeuroLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NeuroLearn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
