// lib/student/screens/activities/activity_registry.dart

import 'package:flutter/material.dart';
import 'synthetic_alchemist_screen.dart';
import 'stellar_lifecycle_screen.dart';

/// Registry mapping topic-specific activities to widgets.
///
/// Activities are custom interactive experiences tied to specific topics,
/// unlike generic intervention formats (flashcard, gesture, voice, simulation).
class ActivityRegistry {
  /// Returns a widget for the given activity, or null if unknown.
  static Widget? build({
    required String activityId,
    required String subject,
    required String topicId,
    required int sectionIndex,
    required VoidCallback onComplete,
  }) {
    switch (activityId) {
      case 'synthetic_alchemist':
        return SyntheticAlchemistScreen(
          subject: subject,
          topicId: topicId,
          sectionIndex: sectionIndex,
          onComplete: onComplete,
        );
      case 'stellar_lifecycle_interactive':
        return StellarLifecycleScreen(
          subject: subject,
          topicId: topicId,
          sectionIndex: sectionIndex,
          onComplete: onComplete,
        );
      default:
        return null;
    }
  }

  /// Check if a topic has a registered activity.
  /// Returns the activityId or null.
  static String? activityForTopic(String subject, String topicId) {
    if (subject == 'chemistry' && topicId == 'periodic_table') {
      return 'synthetic_alchemist';
    }
    if (subject == 'astronomy' && topicId == 'stellar_lifecycle') {
      return 'stellar_lifecycle_interactive';
    }
    return null;
  }
}
