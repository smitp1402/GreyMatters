// lib/core/models/user.dart

/// The two roles in the app — student and teacher.
/// Selected at the role picker screen and used to route navigation.
enum UserRole { student, teacher }

/// Minimal user identity for the current session.
///
/// No auth in v1 — this is just the role selection from the role picker.
/// Supabase auth can be added in Week 5 without changing this interface.
class User {
  final String displayName;
  final UserRole role;

  const User({
    required this.displayName,
    required this.role,
  });

  @override
  String toString() => 'User(name=$displayName, role=${role.name})';
}
