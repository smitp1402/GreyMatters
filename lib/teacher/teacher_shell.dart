// lib/teacher/teacher_shell.dart

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Root widget for the teacher module.
///
/// Entry point for teacher-side navigation: session code join,
/// live focus monitor, session history, and export.
class TeacherShell extends StatelessWidget {
  const TeacherShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEUROLEARN'),
        backgroundColor: AppColors.surfaceContainer,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text(
                'EDUCATOR',
                style: TextStyle(
                  fontFamily: 'Segoe UI',
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 2.0,
                  color: AppColors.onTertiary,
                ),
              ),
              backgroundColor: AppColors.tertiary,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Live Monitor',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Enter a student\'s session code to begin\nmonitoring their focus in real time.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 280,
                child: TextField(
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 24,
                    letterSpacing: 8.0,
                    color: AppColors.onSurface,
                  ),
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'ABC123',
                    hintStyle: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 24,
                      letterSpacing: 8.0,
                      color: AppColors.surfaceContainerHighest,
                    ),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 280,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: wire up session join
                  },
                  child: const Text('JOIN SESSION'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
