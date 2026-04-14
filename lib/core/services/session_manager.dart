// lib/core/services/session_manager.dart

import 'dart:math';

/// Manages session lifecycle — ID generation and active session tracking.
///
/// Session IDs are 6-character alphanumeric codes (e.g. 'abc123').
/// The student's app generates the code; the teacher enters it to subscribe.
class SessionManager {
  SessionManager._();
  static final instance = SessionManager._();

  static const _codeLength = 6;
  static const _codeChars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  static final _random = Random.secure();

  String? _activeSessionId;

  /// The currently active session ID, or null if no session is running.
  String? get activeSessionId => _activeSessionId;

  /// Generate a new 6-character session ID and mark it as active.
  String startSession() {
    _activeSessionId = _generateCode();
    return _activeSessionId!;
  }

  /// End the current session.
  void endSession() {
    _activeSessionId = null;
  }

  /// Generate a random 6-char alphanumeric code.
  String _generateCode() => String.fromCharCodes(
        Iterable.generate(
          _codeLength,
          (_) => _codeChars.codeUnitAt(_random.nextInt(_codeChars.length)),
        ),
      );
}
