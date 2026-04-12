// lib/student/screens/session_code_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Screen 4 — Display the 6-character session code after calibration.
///
/// Student shares this code with their teacher for live monitoring.
/// TTS reads the code using NATO phonetic alphabet.
class SessionCodeScreen extends StatefulWidget {
  const SessionCodeScreen({super.key});

  @override
  State<SessionCodeScreen> createState() => _SessionCodeScreenState();
}

class _SessionCodeScreenState extends State<SessionCodeScreen>
    with SingleTickerProviderStateMixin {
  late final String _sessionCode;
  late final AnimationController _fadeIn;
  final FlutterTts _tts = FlutterTts();
  bool _copied = false;

  static const _nato = {
    'A': 'Alpha', 'B': 'Bravo', 'C': 'Charlie', 'D': 'Delta',
    'E': 'Echo', 'F': 'Foxtrot', 'G': 'Golf', 'H': 'Hotel',
    'I': 'India', 'J': 'Juliet', 'K': 'Kilo', 'L': 'Lima',
    'M': 'Mike', 'N': 'November', 'O': 'Oscar', 'P': 'Papa',
    'Q': 'Quebec', 'R': 'Romeo', 'S': 'Sierra', 'T': 'Tango',
    'U': 'Uniform', 'V': 'Victor', 'W': 'Whiskey', 'X': 'X-ray',
    'Y': 'Yankee', 'Z': 'Zulu',
    '0': 'Zero', '1': 'One', '2': 'Two', '3': 'Three', '4': 'Four',
    '5': 'Five', '6': 'Six', '7': 'Seven', '8': 'Eight', '9': 'Nine',
  };

  @override
  void initState() {
    super.initState();
    _sessionCode = _generateCode();

    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _initTts();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 confusion
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.35);
    await _tts.setPitch(0.8);

    // Read the code using NATO phonetic
    await Future.delayed(const Duration(milliseconds: 500));
    final phonetic = _sessionCode.split('').map((c) => _nato[c] ?? c).join(', ');
    await _tts.speak('Your session code is $phonetic. Share it with your teacher.');
  }

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _sessionCode));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  void _startLearning() {
    context.go('/student');
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _fadeIn,
          builder: (_, child) => Opacity(
            opacity: _fadeIn.value,
            child: child,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.focused.withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 36,
                      color: AppColors.focused,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'SESSION READY',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.0,
                      color: AppColors.focused,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Glass panel with code
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.glassBackground,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      border: Border.all(color: AppColors.glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Text(
                          'SESSION CODE',
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.0,
                            color: AppColors.outline,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Code characters in individual boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _sessionCode.split('').map((char) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Container(
                                width: 52,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  border: Border.all(
                                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  char,
                                  style: const TextStyle(
                                    fontFamily: 'Consolas',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // Copy button
                        TextButton.icon(
                          onPressed: _copyCode,
                          icon: Icon(
                            _copied ? Icons.check : Icons.copy,
                            size: 14,
                            color: _copied ? AppColors.focused : AppColors.primary,
                          ),
                          label: Text(
                            _copied ? 'COPIED!' : 'TAP TO COPY',
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: _copied ? AppColors.focused : AppColors.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Share this code with your teacher\nfor live focus monitoring',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Start Learning button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryContainer],
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _startLearning,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'START LEARNING',
                                style: TextStyle(
                                  fontFamily: 'Segoe UI',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 3.0,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
