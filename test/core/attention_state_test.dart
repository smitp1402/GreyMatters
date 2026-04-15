// test/core/attention_state_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:neurolearn/core/models/attention_state.dart';

void main() {
  group('AttentionState', () {
    final sampleJson = <String, dynamic>{
      'session_id': 'abc123',
      'focus_score': 0.72,
      'delta': 0.12,
      'theta': 0.41,
      'alpha': 0.28,
      'beta': 0.81,
      'gamma': 0.45,
      'level': 'focused',
      'timestamp': 1712345678.123,
      'theta_alpha': 1.4643,
      'beta_theta': 1.9756,
      'beta_alpha_theta': 1.1739,
      'signal_quality': {
        'CP3': 92.0,
        'C3': 85.0,
        'F5': 78.0,
        'PO3': 88.0,
        'PO4': 91.0,
        'F6': 45.0,
        'C4': 87.0,
        'CP4': 90.0,
      },
    };

    test('fromJson parses all fields correctly', () {
      final state = AttentionState.fromJson(sampleJson);

      expect(state.sessionId, 'abc123');
      expect(state.focusScore, 0.72);
      expect(state.delta, 0.12);
      expect(state.theta, 0.41);
      expect(state.alpha, 0.28);
      expect(state.beta, 0.81);
      expect(state.gamma, 0.45);
      expect(state.level, AttentionLevel.focused);
      expect(state.timestamp.millisecondsSinceEpoch, 1712345678123);
      expect(state.thetaAlpha, 1.4643);
      expect(state.betaTheta, 1.9756);
      expect(state.betaAlphaTheta, 1.1739);
      expect(state.signalQuality['CP3'], 92.0);
      expect(state.signalQuality['F6'], 45.0);
      expect(state.signalQuality.length, 8);
    });

    test('toJson round-trips correctly', () {
      final state = AttentionState.fromJson(sampleJson);
      final json = state.toJson();

      expect(json['session_id'], 'abc123');
      expect(json['focus_score'], 0.72);
      expect(json['delta'], 0.12);
      expect(json['theta'], 0.41);
      expect(json['alpha'], 0.28);
      expect(json['beta'], 0.81);
      expect(json['gamma'], 0.45);
      expect(json['level'], 'focused');
      expect(json['theta_alpha'], 1.4643);
      expect(json['beta_theta'], 1.9756);
      expect(json['beta_alpha_theta'], 1.1739);
      expect((json['signal_quality'] as Map).length, 8);
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
      expect(roundTripped.delta, original.delta);
      expect(roundTripped.theta, original.theta);
      expect(roundTripped.alpha, original.alpha);
      expect(roundTripped.beta, original.beta);
      expect(roundTripped.gamma, original.gamma);
      expect(roundTripped.level, original.level);
      expect(roundTripped.thetaAlpha, original.thetaAlpha);
      expect(roundTripped.betaTheta, original.betaTheta);
      expect(roundTripped.betaAlphaTheta, original.betaAlphaTheta);
      expect(roundTripped.signalQuality, original.signalQuality);
    });

    test('fromJson defaults new fields when missing (backward compat)', () {
      final legacyJson = <String, dynamic>{
        'session_id': 'legacy',
        'focus_score': 0.5,
        'theta': 0.3,
        'alpha': 0.25,
        'beta': 0.3,
        'gamma': 0.15,
        'level': 'drifting',
        'timestamp': 1712345678.0,
      };
      final state = AttentionState.fromJson(legacyJson);

      expect(state.delta, 0.0);
      expect(state.thetaAlpha, 0.0);
      expect(state.betaTheta, 0.0);
      expect(state.betaAlphaTheta, 0.0);
      expect(state.signalQuality, isEmpty);
    });
  });
}
