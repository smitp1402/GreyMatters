// lib/student/screens/interventions/intervention_engine.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/attention_state.dart';
import '../../../core/services/attention_stream.dart';
import '../../../core/theme/app_colors.dart';
import '../../rl/rl_agent.dart';
import '../../rl/rule_based_agent.dart';
import 'flashcard_screen.dart';
import 'simulation_screen.dart';
import 'gesture_screen.dart';
import 'voice_challenge_screen.dart';

/// Callback when intervention completes (recovered or not).
typedef InterventionCallback = void Function(bool recovered, String format);

/// Intervention Engine — orchestrates the drift → format → recovery → resume flow.
///
/// When activated by the pacing engine:
/// 1. Queries RL agent for best format
/// 2. Launches the format screen
/// 3. After completion, measures EEG for 60s
/// 4. Computes reward and updates RL agent
/// 5. If not recovered, cascades to next format
class InterventionEngine {
  final RLAgent _agent = RuleBasedAgent();
  final List<String> _formatsTried = [];
  int _driftDurationSec = 0;
  String _topicId = '';
  String _subject = '';
  bool _active = false;

  bool get isActive => _active;

  /// Start an intervention cascade.
  void start({
    required int driftDurationSec,
    required String topicId,
    required String subject,
  }) {
    _driftDurationSec = driftDurationSec;
    _topicId = topicId;
    _subject = subject;
    _formatsTried.clear();
    _active = true;
  }

  /// Get the next intervention format to show.
  String selectNextFormat() {
    final state = InterventionState(
      attentionLevel: AttentionLevel.drifting,
      driftDurationSec: _driftDurationSec,
      topicId: _topicId,
      subject: _subject,
      formatsTried: List.unmodifiable(_formatsTried),
      sessionNumber: 1,
      timeInSessionSec: 0,
    );

    final format = _agent.selectFormat(state);
    _formatsTried.add(format);
    return format;
  }

  /// Report the result of an intervention.
  void reportResult(String format, bool recovered) {
    final reward = recovered ? 1.0 : -1.0;
    _agent.updateReward(format, reward);

    if (recovered || _formatsTried.length >= 4) {
      _active = false;
    }
  }

  /// Check if more formats are available in the cascade.
  bool get hasMoreFormats => _formatsTried.length < 4;

  /// Reset the engine.
  void reset() {
    _formatsTried.clear();
    _active = false;
    _driftDurationSec = 0;
  }

  /// Build the widget for a given format.
  static Widget buildFormatScreen({
    required String format,
    required String topicId,
    required VoidCallback onComplete,
  }) {
    switch (format) {
      case 'flashcard':
        return FlashcardScreen(topicId: topicId, onComplete: onComplete);
      case 'simulation':
        return SimulationScreen(topicId: topicId, onComplete: onComplete);
      case 'gesture':
        return GestureScreen(topicId: topicId, onComplete: onComplete);
      case 'voice':
        return VoiceChallengeScreen(topicId: topicId, onComplete: onComplete);
      default:
        return FlashcardScreen(topicId: topicId, onComplete: onComplete);
    }
  }
}
