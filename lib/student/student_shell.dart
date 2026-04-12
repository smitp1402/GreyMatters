// lib/student/student_shell.dart
// Smit owns this file and everything under lib/student/

import 'package:flutter/material.dart';

/// Root widget for the student module.
///
/// This is the entry point for all student-side navigation: dashboard
/// (home + library tabs), lesson screen, focus HUD, intervention engine,
/// and session start/end flows.
class StudentShell extends StatelessWidget {
  const StudentShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NeuroLearn — Student')),
      body: const Center(
        child: Text(
          'Student view — coming soon\n\nSmit: start building here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
