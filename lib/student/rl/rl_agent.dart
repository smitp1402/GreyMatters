// lib/student/rl/rl_agent.dart

import '../../core/models/attention_state.dart';

/// Abstract RL agent interface.
///
/// Rule-based and bandit implementations share this interface
/// so the intervention engine can swap them without code changes.
abstract class RLAgent {
  /// Select the best intervention format given current state.
  String selectFormat(InterventionState state);

  /// Update the agent with reward signal after intervention.
  void updateReward(String format, double reward);
}

/// State observed by the RL agent when selecting an intervention.
class InterventionState {
  final AttentionLevel attentionLevel;
  final int driftDurationSec;
  final String topicId;
  final String subject;
  final List<String> formatsTried;
  final int sessionNumber;
  final int timeInSessionSec;

  const InterventionState({
    required this.attentionLevel,
    required this.driftDurationSec,
    required this.topicId,
    required this.subject,
    required this.formatsTried,
    required this.sessionNumber,
    required this.timeInSessionSec,
  });
}
