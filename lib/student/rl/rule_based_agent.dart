// lib/student/rl/rule_based_agent.dart

import '../../core/models/attention_state.dart';
import 'rl_agent.dart';

/// Rule-based RL agent for sessions 1-5.
///
/// Fixed cascade by drift duration:
///   mild (4-8s)   → flashcard
///   moderate (8-20s) → simulation
///   severe (20+s) → voice
///   lost level    → gesture
///
/// Avoids repeating formats already tried in the current cascade.
class RuleBasedAgent implements RLAgent {
  static const _allFormats = ['flashcard', 'simulation', 'voice', 'gesture', 'activity'];

  @override
  String selectFormat(InterventionState state) {
    // Periodic table uses a single themed intervention activity (Synthetic Alchemist)
    // that matches the system aesthetic. Bypasses the RL cascade entirely.
    if (state.topicId == 'periodic_table') {
      return 'activity';
    }

    // Determine preferred format based on drift severity
    final String preferred;

    if (state.attentionLevel == AttentionLevel.lost) {
      preferred = 'gesture';
    } else if (state.driftDurationSec >= 20) {
      preferred = 'voice';
    } else if (state.driftDurationSec >= 8) {
      preferred = 'simulation';
    } else {
      preferred = 'flashcard';
    }

    // If preferred format hasn't been tried, use it
    if (!state.formatsTried.contains(preferred)) {
      return preferred;
    }

    // Otherwise, pick the first untried format
    for (final format in _allFormats) {
      if (!state.formatsTried.contains(format)) {
        return format;
      }
    }

    // All formats tried — restart from flashcard
    return 'flashcard';
  }

  @override
  void updateReward(String format, double reward) {
    // Rule-based agent doesn't learn — rewards are logged but ignored.
    // The bandit agent (sessions 6+) will use these rewards for learning.
  }
}
