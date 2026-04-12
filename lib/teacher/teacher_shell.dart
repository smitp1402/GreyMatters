// lib/teacher/teacher_shell.dart
// Felipe owns this file and everything under lib/teacher/

import 'package:flutter/material.dart';

/// Root widget for the teacher module.
///
/// This is the entry point for all teacher-side navigation: live focus
/// monitor, session code join flow, multi-session switcher, session
/// history, and export/report generation.
class TeacherShell extends StatelessWidget {
  const TeacherShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NeuroLearn — Teacher')),
      body: const Center(
        child: Text(
          'Teacher view — coming soon\n\nFelipe: start building here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
