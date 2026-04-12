// lib/core/models/topic.dart

/// Curriculum data model — represents a single topic with all its content
/// and intervention materials. Loaded from JSON files in assets/curriculum/.

class Topic {
  final String id;
  final String name;
  final String subject;
  final int estimatedMinutes;
  final List<Section> sections;
  final List<Flashcard> flashcards;
  final SimulationConfig? simulation;
  final List<GestureQuestion> gestureQuestions;
  final List<VoiceQuestion> voiceQuestions;
  final String? curiosityBomb;

  const Topic({
    required this.id,
    required this.name,
    required this.subject,
    required this.estimatedMinutes,
    required this.sections,
    this.flashcards = const [],
    this.simulation,
    this.gestureQuestions = const [],
    this.voiceQuestions = const [],
    this.curiosityBomb,
  });

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        id: j['id'] as String,
        name: j['name'] as String,
        subject: j['subject'] as String,
        estimatedMinutes: j['estimatedMinutes'] as int,
        sections: (j['sections'] as List)
            .map((s) => Section.fromJson(s as Map<String, dynamic>))
            .toList(),
        flashcards: (j['flashcards'] as List?)
                ?.map((f) => Flashcard.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [],
        simulation: j['simulation'] != null
            ? SimulationConfig.fromJson(j['simulation'] as Map<String, dynamic>)
            : null,
        gestureQuestions: (j['gestureQuestions'] as List?)
                ?.map((g) => GestureQuestion.fromJson(g as Map<String, dynamic>))
                .toList() ??
            [],
        voiceQuestions: (j['voiceQuestions'] as List?)
                ?.map((v) => VoiceQuestion.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [],
        curiosityBomb: j['curiosityBomb'] as String?,
      );
}

class Section {
  final String id;
  final String title;
  final String content;
  final List<String> keyTerms;

  const Section({
    required this.id,
    required this.title,
    required this.content,
    this.keyTerms = const [],
  });

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        id: j['id'] as String,
        title: j['title'] as String,
        content: j['content'] as String,
        keyTerms: (j['keyTerms'] as List?)?.cast<String>() ?? [],
      );
}

class Flashcard {
  final String question;
  final String answer;
  final String? explanation;

  const Flashcard({
    required this.question,
    required this.answer,
    this.explanation,
  });

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
        question: j['question'] as String,
        answer: j['answer'] as String,
        explanation: j['explanation'] as String?,
      );
}

class SimulationConfig {
  final String type;
  final String instructions;
  final List<SimElement> elements;

  const SimulationConfig({
    required this.type,
    required this.instructions,
    required this.elements,
  });

  factory SimulationConfig.fromJson(Map<String, dynamic> j) => SimulationConfig(
        type: j['type'] as String,
        instructions: j['instructions'] as String,
        elements: (j['elements'] as List)
            .map((e) => SimElement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SimElement {
  final String symbol;
  final String name;
  final int group;
  final int period;

  const SimElement({
    required this.symbol,
    required this.name,
    required this.group,
    required this.period,
  });

  factory SimElement.fromJson(Map<String, dynamic> j) => SimElement(
        symbol: j['symbol'] as String,
        name: j['name'] as String,
        group: j['group'] as int,
        period: j['period'] as int,
      );
}

class GestureQuestion {
  final String question;
  final int answer;
  final String? hint;

  const GestureQuestion({
    required this.question,
    required this.answer,
    this.hint,
  });

  factory GestureQuestion.fromJson(Map<String, dynamic> j) => GestureQuestion(
        question: j['question'] as String,
        answer: j['answer'] as int,
        hint: j['hint'] as String?,
      );
}

class VoiceQuestion {
  final String question;
  final List<String> acceptedAnswers;

  const VoiceQuestion({
    required this.question,
    required this.acceptedAnswers,
  });

  factory VoiceQuestion.fromJson(Map<String, dynamic> j) => VoiceQuestion(
        question: j['question'] as String,
        acceptedAnswers: (j['acceptedAnswers'] as List).cast<String>(),
      );
}
