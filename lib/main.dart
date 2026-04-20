// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_config.dart';
import 'core/services/profile_manager.dart';
import 'core/services/tts_service.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load assets/.env (OpenRouter key, TTS model/voice). Wrapped in
  // try/catch so a missing .env doesn't prevent app boot — TtsService
  // gracefully falls back to flutter_tts when the key isn't set.
  // Keep the path inside assets/ because Flutter web's asset bundler
  // drops dotfiles at the project root.
  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (e) {
    debugPrint('[main] .env not loaded: $e — TTS will use platform fallback');
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Try loading existing profile
  await ProfileManager.instance.loadProfile();

  // Kick off TTS prefetch in the background. Fire-and-forget — the
  // landing / connection screens don't need it to finish first, and
  // uncached phrases just fall back to flutter_tts during the race.
  unawaited(TtsService.instance.prefetchAll());

  runApp(const ProviderScope(child: GreyMattersApp()));
}

// Cheap fire-and-forget helper used above. Dart's `Future` has no
// built-in "ignore me" annotation and the analyzer complains about
// bare unawaited Futures — this gives it an explicit outlet.
void unawaited(Future<void> f) {
  // Intentionally empty.
}

class GreyMattersApp extends StatelessWidget {
  const GreyMattersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Grey Matters',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
