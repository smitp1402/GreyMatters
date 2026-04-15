// lib/core/services/realtime_broadcast.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attention_state.dart';

/// Supabase Realtime Broadcast for live teacher monitoring.
///
/// Uses Supabase Broadcast channels (pub/sub, no database writes)
/// to relay AttentionState from student → teacher across any network.
///
/// Student side: [publishAttentionState] sends every AttentionState to
/// the channel `session:{sessionId}`.
///
/// Teacher side: [subscribeToSession] listens on that channel and
/// emits AttentionState to a local stream.
class RealtimeBroadcast {
  RealtimeBroadcast._();
  static final instance = RealtimeBroadcast._();

  SupabaseClient get _client => Supabase.instance.client;

  RealtimeChannel? _publishChannel;
  RealtimeChannel? _subscribeChannel;

  final _controller = StreamController<AttentionState>.broadcast();

  /// Stream of AttentionState from a subscribed session (teacher side).
  Stream<AttentionState> get stream => _controller.stream;

  // ── Student Side ────────────────────────────────────────────

  /// Start publishing AttentionState to a session channel.
  /// Call once when session starts, then use [publishAttentionState].
  Future<void> startPublishing(String sessionId) async {
    await stopPublishing();
    _publishChannel = _client.channel(
      'session:$sessionId',
      opts: const RealtimeChannelConfig(self: true),
    );
    _publishChannel!.subscribe();
  }

  /// Publish a single AttentionState to the session channel.
  /// Called every 1s from the student's attention stream listener.
  Future<void> publishAttentionState(AttentionState state) async {
    if (_publishChannel == null) return;
    await _publishChannel!.sendBroadcastMessage(
      event: 'attention_state',
      payload: state.toJson(),
    );
  }

  /// Stop publishing (session ended or app closing).
  Future<void> stopPublishing() async {
    if (_publishChannel != null) {
      await _client.removeChannel(_publishChannel!);
      _publishChannel = null;
    }
  }

  // ── Teacher Side ────────────────────────────────────────────

  /// Subscribe to a student's session for live monitoring.
  /// AttentionState will be emitted on [stream].
  Future<void> subscribeToSession(String sessionId) async {
    await unsubscribe();
    _subscribeChannel = _client.channel('session:$sessionId');
    _subscribeChannel!.onBroadcast(
      event: 'attention_state',
      callback: (payload) {
        try {
          final state = AttentionState.fromJson(
            Map<String, dynamic>.from(payload),
          );
          _controller.add(state);
        } catch (_) {
          // Skip malformed payloads
        }
      },
    );
    _subscribeChannel!.subscribe();
  }

  /// Stop listening to a session.
  Future<void> unsubscribe() async {
    if (_subscribeChannel != null) {
      await _client.removeChannel(_subscribeChannel!);
      _subscribeChannel = null;
    }
  }

  /// Clean up all channels.
  Future<void> dispose() async {
    await stopPublishing();
    await unsubscribe();
    await _controller.close();
  }
}
