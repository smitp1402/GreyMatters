// lib/student/student_shell.dart
// Smit owns this file and everything under lib/student/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import 'screens/dashboard_screen.dart';
import 'screens/library_screen.dart';

/// Root widget for the student module.
///
/// Two-tab layout: Home (attention-prioritized dashboard) and Library
/// (full topic browser). Navigation between lesson, intervention, and
/// session end flows happens via GoRouter.
class StudentShell extends ConsumerStatefulWidget {
  const StudentShell({super.key});

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  int _selectedIndex = 0;

  final _screens = [
    const DashboardScreen(),
    const LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEUROLEARN'),
        backgroundColor: AppColors.surfaceContainer,
        actions: [
          // Connection status dot
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.focused,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ONLINE',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 10,
                    letterSpacing: 2.0,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: AppColors.surfaceContainer,
        indicatorColor: AppColors.secondaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}
