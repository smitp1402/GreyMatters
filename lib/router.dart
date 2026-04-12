// lib/router.dart

import 'package:go_router/go_router.dart';
import 'screens/landing_screen.dart';
import 'screens/role_picker_screen.dart';
import 'student/student_shell.dart';
import 'teacher/teacher_shell.dart';

/// Top-level router for the entire app.
///
/// Flow: Landing → Login (role picker) → Student/Teacher shell.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const LandingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, __) => const RolePickerScreen(),
    ),
    GoRoute(
      path: '/student',
      builder: (_, __) => const StudentShell(),
    ),
    GoRoute(
      path: '/teacher',
      builder: (_, __) => const TeacherShell(),
    ),
  ],
);
