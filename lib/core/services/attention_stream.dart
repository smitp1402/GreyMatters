// lib/core/services/attention_stream.dart
// FROZEN — do not change without agreement from BOTH Smit and Felipe

import 'dart:async';
import '../models/attention_state.dart';

/// Singleton broadcast stream that delivers [AttentionState] to all subscribers.
///
/// The [WebSocketClient] calls [emit] whenever a new message arrives from the
/// Python daemon. Any widget or service can subscribe via [stream].
///
/// Felipe's teacher monitor uses [forSession] to filter to a single student.
class AttentionStream {
  AttentionStream._();
  static final instance = AttentionStream._();

  final _controller = StreamController<AttentionState>.broadcast();

  /// The raw broadcast stream — every AttentionState from every session.
  Stream<AttentionState> get stream => _controller.stream;

  /// Called by [WebSocketClient] when a new message arrives.
  void emit(AttentionState state) => _controller.add(state);

  /// Filter the stream to a single session by [sessionId].
  /// Used by Felipe's teacher monitor to subscribe to one student.
  Stream<AttentionState> forSession(String sessionId) =>
      stream.where((s) => s.sessionId == sessionId);

  /// Shut down the stream (app lifecycle).
  void dispose() => _controller.close();
}
