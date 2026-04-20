// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/feature_flags.dart';
import 'core/services/demo_attention_controller.dart';
import 'core/services/profile_manager.dart';
import 'core/services/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Try loading existing profile
  await ProfileManager.instance.loadProfile();

  runApp(const ProviderScope(child: GreyMattersApp()));
}

/// Intent fired when the spacebar is pressed while EEG trigger is off.
/// The [Actions] map at the app root binds this to the
/// [DemoAttentionController.cycleState] callback.
class _CycleDemoAttentionIntent extends Intent {
  const _CycleDemoAttentionIntent();
}

class GreyMattersApp extends StatelessWidget {
  const GreyMattersApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp.router(
      title: 'Grey Matters',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );

    // When the EEG trigger is off, spacebar becomes the demo-cheat that
    // cycles focused → drifting → lost. We claim the key at the app root
    // via Shortcuts/Actions so it overrides Flutter's default button
    // activation (which also maps space). Text fields still receive
    // spaces for typing because TextField reads raw text input via the
    // platform IME, not through the Shortcuts system.
    if (!FeatureFlags.useEegTrigger) {
      return Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): _CycleDemoAttentionIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _CycleDemoAttentionIntent: CallbackAction<_CycleDemoAttentionIntent>(
              onInvoke: (_) {
                DemoAttentionController.instance.cycleState();
                return null;
              },
            ),
          },
          // Focus here so the Shortcuts tree sits above every route and
          // receives key events even when no specific widget has focus.
          child: Focus(
            autofocus: true,
            child: app,
          ),
        ),
      );
    }

    return app;
  }
}
