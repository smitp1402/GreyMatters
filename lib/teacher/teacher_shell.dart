// lib/teacher/teacher_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/services/profile_manager.dart';
import '../core/theme/app_colors.dart';
import 'screens/teacher_dashboard_screen.dart';

/// Root widget for the teacher module.
///
/// Shows the student list dashboard. Teacher can tap students to see
/// performance, or join a live session by code.
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
            padding: const EdgeInsets.only(right: 8),
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
          IconButton(
            onPressed: () {
              ProfileManager.instance.clear();
              context.go('/login');
            },
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: AppColors.outline, size: 22),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const TeacherDashboardScreen(),
    );
  }
}
