// lib/router.dart

import 'package:go_router/go_router.dart';
import 'core/services/profile_manager.dart';
import 'screens/landing_screen.dart';
import 'screens/role_picker_screen.dart';
import 'student/student_shell.dart';
import 'student/screens/crown_connection_screen.dart';
import 'student/screens/debug_stream_screen.dart';
import 'student/screens/calibration_screen.dart';
import 'student/screens/session_code_screen.dart';
import 'student/screens/lesson_screen.dart';
import 'student/screens/session_end_screen.dart';
import 'teacher/teacher_shell.dart';
import 'teacher/screens/live_monitor_screen.dart';
import 'teacher/screens/student_detail_screen.dart';

/// Top-level router for the entire app.
///
/// Redirect logic:
///   - If profile exists → skip landing/login, go straight to role-specific shell
///   - If no profile → show landing → login
final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final profile = ProfileManager.instance;
    final path = state.uri.path;

    // If user has a profile and is visiting landing or login, redirect to their shell
    if (profile.hasProfile && (path == '/' || path == '/login')) {
      return profile.isStudent ? '/student' : '/teacher';
    }

    // No redirect needed
    return null;
  },
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
    // Lesson screen with subject and topic ID
    GoRoute(
      path: '/student/lesson/:subject/:topicId',
      builder: (_, state) => LessonScreen(
        subject: state.pathParameters['subject']!,
        topicId: state.pathParameters['topicId']!,
      ),
    ),
    // Session end summary (demo data for now)
    GoRoute(
      path: '/student/session-end',
      builder: (_, __) => SessionEndScreen.demo(),
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
    GoRoute(
      path: '/teacher/student/:studentId',
      builder: (_, state) => StudentDetailScreen(
        studentId: state.pathParameters['studentId']!,
      ),
    ),
    GoRoute(
      path: '/teacher/monitor/:sessionCode',
      builder: (_, state) => LiveMonitorScreen(
        sessionCode: state.pathParameters['sessionCode']!,
      ),
    ),
  ],
);
