// lib/core/services/attention_stream_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attention_state.dart';
import 'attention_stream.dart';

/// Riverpod StreamProvider that exposes [AttentionStream] to widgets.
///
/// Usage in any widget:
/// ```dart
/// final attentionAsync = ref.watch(attentionStreamProvider);
/// attentionAsync.when(
///   data: (state) => Text('Focus: ${state.focusScore}'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```
final attentionStreamProvider = StreamProvider<AttentionState>((ref) {
  return AttentionStream.instance.stream;
});

/// Filtered provider for a specific session (used by teacher monitor).
///
/// Usage:
/// ```dart
/// final provider = sessionAttentionProvider('abc123');
/// final attentionAsync = ref.watch(provider);
/// ```
final sessionAttentionProvider =
    StreamProvider.family<AttentionState, String>((ref, sessionId) {
  return AttentionStream.instance.forSession(sessionId);
});
