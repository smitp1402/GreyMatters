// lib/teacher/teacher_shell.dart

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'screens/join_session_screen.dart';

/// Root widget for the teacher module.
///
/// Shows the session code join screen. After joining, navigates
/// to the live monitor via go_router.
class TeacherShell extends StatelessWidget {
  const TeacherShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'The Cognitive Sanctuary',
          style: TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.primary,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: AppColors.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: const Text(
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
      body: const JoinSessionScreen(),
    );
  }
}
