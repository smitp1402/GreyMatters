// lib/router.dart

import 'package:go_router/go_router.dart';
import 'screens/role_picker_screen.dart';
import 'student/student_shell.dart';
import 'teacher/teacher_shell.dart';

/// Top-level router for the entire app.
///
/// The app starts at the role picker. After the user selects "Student" or
/// "Teacher," they are routed to their module's shell. The two shells are
/// completely independent navigation trees — neither imports the other.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
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
