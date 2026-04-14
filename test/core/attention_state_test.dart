// test/core/attention_state_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:neurolearn/core/models/attention_state.dart';

void main() {
  group('AttentionState', () {
    final sampleJson = <String, dynamic>{
      'session_id': 'abc123',
      'focus_score': 0.72,
      'theta': 0.41,
      'alpha': 0.28,
      'beta': 0.81,
      'gamma': 0.45,
      'level': 'focused',
      'timestamp': 1712345678.123,
    };

    test('fromJson parses all fields correctly', () {
      final state = AttentionState.fromJson(sampleJson);

      expect(state.sessionId, 'abc123');
      expect(state.focusScore, 0.72);
      expect(state.theta, 0.41);
      expect(state.alpha, 0.28);
      expect(state.beta, 0.81);
      expect(state.gamma, 0.45);
      expect(state.level, AttentionLevel.focused);
      expect(state.timestamp.millisecondsSinceEpoch, 1712345678123);
    });

    test('toJson round-trips correctly', () {
      final state = AttentionState.fromJson(sampleJson);
      final json = state.toJson();

      expect(json['session_id'], 'abc123');
      expect(json['focus_score'], 0.72);
      expect(json['theta'], 0.41);
      expect(json['alpha'], 0.28);
      expect(json['beta'], 0.81);
      expect(json['gamma'], 0.45);
      expect(json['level'], 'focused');
    });

    test('fromJson handles all attention levels', () {
      for (final level in AttentionLevel.values) {
        final json = {...sampleJson, 'level': level.name};
        final state = AttentionState.fromJson(json);
        expect(state.level, level);
      }
    });

    test('toJson → fromJson is idempotent', () {
      final original = AttentionState.fromJson(sampleJson);
      final roundTripped = AttentionState.fromJson(original.toJson());

      expect(roundTripped.sessionId, original.sessionId);
      expect(roundTripped.focusScore, original.focusScore);
      expect(roundTripped.theta, original.theta);
      expect(roundTripped.alpha, original.alpha);
      expect(roundTripped.beta, original.beta);
      expect(roundTripped.gamma, original.gamma);
      expect(roundTripped.level, original.level);
    });
  });
}
