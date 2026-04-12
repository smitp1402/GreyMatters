// lib/router.dart

import 'package:go_router/go_router.dart';
import 'screens/landing_screen.dart';
import 'screens/role_picker_screen.dart';
import 'student/student_shell.dart';
import 'student/screens/crown_connection_screen.dart';
import 'student/screens/debug_stream_screen.dart';
import 'student/screens/calibration_screen.dart';
import 'student/screens/session_code_screen.dart';
import 'student/screens/lesson_screen.dart';
import 'teacher/teacher_shell.dart';

/// Top-level router for the entire app.
///
/// Flow:
///   Landing → Login → Student path / Teacher path
///
/// Student path:
///   Login → Crown Connection → Debug Stream → Calibration → Session Code → Dashboard
///
/// Teacher path:
///   Login → Teacher Shell (join session)
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
    // Student session flow
    GoRoute(
      path: '/student/connect',
      builder: (_, __) => const CrownConnectionScreen(),
    ),
    GoRoute(
      path: '/student/debug-stream',
      builder: (_, __) => const DebugStreamScreen(),
    ),
    GoRoute(
      path: '/student/calibrate',
      builder: (_, __) => const CalibrationScreen(),
    ),
    GoRoute(
      path: '/student/session-ready',
      builder: (_, __) => const SessionCodeScreen(),
    ),
    // Lesson screen with topic ID
    GoRoute(
      path: '/student/lesson/:topicId',
      builder: (_, state) => LessonScreen(
        topicId: state.pathParameters['topicId']!,
      ),
    ),
    // Student dashboard (post-session-setup)
    GoRoute(
      path: '/student',
      builder: (_, __) => const StudentShell(),
    ),
    // Teacher
    GoRoute(
      path: '/teacher',
      builder: (_, __) => const TeacherShell(),
    ),
  ],
);
