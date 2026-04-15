// lib/core/models/topic.dart

// Curriculum data models — split into Lesson (content) and InterventionPack
// (interactive challenges). Loaded from JSON files in assets/curriculum/.
//
// Structure: assets/curriculum/{subject}/{topicId}/lesson.json
//            assets/curriculum/{subject}/{topicId}/interventions.json

// ── Lesson (content only) ───────────────────────────────────────────────

class Topic {
  final String id;
  final String name;
  final String subject;
  final int estimatedMinutes;
  final String? grade;
  final List<Section> sections;
  final String? curiosityBomb;

  const Topic({
    required this.id,
    required this.name,
    required this.subject,
    required this.estimatedMinutes,
    this.grade,
    required this.sections,
    this.curiosityBomb,
  });

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        id: j['id'] as String,
        name: j['name'] as String,
        subject: j['subject'] as String,
        estimatedMinutes: j['estimatedMinutes'] as int,
        grade: j['grade'] as String?,
        sections: (j['sections'] as List)
            .map((s) => Section.fromJson(s as Map<String, dynamic>))
            .toList(),
        curiosityBomb: j['curiosityBomb'] as String?,
      );
}

// ── InterventionPack (challenges loaded separately) ─────────────────────

class InterventionPack {
  final String topicId;
  final List<Flashcard> flashcards;
  final SimulationConfig? simulation;
  final List<GestureQuestion> gestureQuestions;
  final List<VoiceQuestion> voiceQuestions;

  const InterventionPack({
    required this.topicId,
    this.flashcards = const [],
    this.simulation,
    this.gestureQuestions = const [],
    this.voiceQuestions = const [],
  });

  factory InterventionPack.fromJson(Map<String, dynamic> j) =>
      InterventionPack(
        topicId: j['topicId'] as String,
        flashcards: (j['flashcards'] as List?)
                ?.map((f) => Flashcard.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [],
        simulation: j['simulation'] != null
            ? SimulationConfig.fromJson(
                j['simulation'] as Map<String, dynamic>)
            : null,
        gestureQuestions: (j['gestureQuestions'] as List?)
                ?.map(
                    (g) => GestureQuestion.fromJson(g as Map<String, dynamic>))
                .toList() ??
            [],
        voiceQuestions: (j['voiceQuestions'] as List?)
                ?.map((v) => VoiceQuestion.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ── CurriculumIndex (master catalog) ────────────────────────────────────

class CurriculumIndex {
  final List<SubjectEntry> subjects;

  const CurriculumIndex({required this.subjects});

  factory CurriculumIndex.fromJson(Map<String, dynamic> j) => CurriculumIndex(
        subjects: (j['subjects'] as List)
            .map((s) => SubjectEntry.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class SubjectEntry {
  final String id;
  final String name;
  final String icon;
  final String? color;
  final List<TopicEntry> topics;

  const SubjectEntry({
    required this.id,
    required this.name,
    required this.icon,
    this.color,
    required this.topics,
  });

  factory SubjectEntry.fromJson(Map<String, dynamic> j) => SubjectEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String,
        color: j['color'] as String?,
        topics: (j['topics'] as List)
            .map((t) => TopicEntry.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

class TopicEntry {
  final String id;
  final String name;
  final String? grade;
  final int estimatedMinutes;
  final List<String> prereqs;

  const TopicEntry({
    required this.id,
    required this.name,
    this.grade,
    required this.estimatedMinutes,
    this.prereqs = const [],
  });

  factory TopicEntry.fromJson(Map<String, dynamic> j) => TopicEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        grade: j['grade'] as String?,
        estimatedMinutes: j['estimatedMinutes'] as int,
        prereqs: (j['prereqs'] as List?)?.cast<String>() ?? [],
      );
}

// ── Section ─────────────────────────────────────────────────────────────

class Section {
  final String id;
  final String title;
  final String? subtitle;
  final List<String> paragraphs;
  final List<String> keyTerms;
  final DiagramSpec? diagram;
  final VideoEmbed? video;
  final VideoEmbed? driftVideo;
  final CalloutBox? callout;
  final Checkpoint? checkpoint;
  final InterventionMap? interventionMap;
  final String? recapOnReturn;

  const Section({
    required this.id,
    required this.title,
    this.subtitle,
    required this.paragraphs,
    this.keyTerms = const [],
    this.diagram,
    this.video,
    this.driftVideo,
    this.callout,
    this.checkpoint,
    this.interventionMap,
    this.recapOnReturn,
  });

  factory Section.fromJson(Map<String, dynamic> j) {
    // Support both "content" (old format) and "paragraphs" (new format)
    List<String> paragraphs;
    if (j.containsKey('paragraphs')) {
      paragraphs = (j['paragraphs'] as List).cast<String>();
    } else if (j.containsKey('content')) {
      paragraphs = (j['content'] as String).split('\n\n');
    } else {
      paragraphs = [];
    }

    return Section(
      id: j['id'] as String,
      title: j['title'] as String,
      subtitle: j['subtitle'] as String?,
      paragraphs: paragraphs,
      keyTerms: (j['keyTerms'] as List?)?.cast<String>() ?? [],
      diagram: j['diagram'] != null
          ? DiagramSpec.fromJson(j['diagram'] as Map<String, dynamic>)
          : null,
      video: j['video'] != null
          ? VideoEmbed.fromJson(j['video'] as Map<String, dynamic>)
          : null,
      driftVideo: j['driftVideo'] != null
          ? VideoEmbed.fromJson(j['driftVideo'] as Map<String, dynamic>)
          : null,
      callout: j['callout'] != null
          ? CalloutBox.fromJson(j['callout'] as Map<String, dynamic>)
          : null,
      checkpoint: j['checkpoint'] != null
          ? Checkpoint.fromJson(j['checkpoint'] as Map<String, dynamic>)
          : null,
      interventionMap: j['interventionMap'] != null
          ? InterventionMap.fromJson(
              j['interventionMap'] as Map<String, dynamic>)
          : null,
      recapOnReturn: j['recapOnReturn'] as String?,
    );
  }
}

// ── Content block types ─────────────────────────────────────────────────

class DiagramSpec {
  final String type;
  final String title;
  final String description;
  final String? interactiveHint;

  const DiagramSpec({
    this.type = 'generic',
    required this.title,
    required this.description,
    this.interactiveHint,
  });

  factory DiagramSpec.fromJson(Map<String, dynamic> j) => DiagramSpec(
        type: j['type'] as String? ?? 'generic',
        title: j['title'] as String,
        description: j['description'] as String,
        interactiveHint: j['interactiveHint'] as String?,
      );
}

class VideoEmbed {
  final String title;
  final String youtubeId;
  final String startTime;
  final String endTime;
  final String duration;
  final String? description;

  const VideoEmbed({
    required this.title,
    required this.youtubeId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.description,
  });

  factory VideoEmbed.fromJson(Map<String, dynamic> j) => VideoEmbed(
        title: j['title'] as String,
        youtubeId: j['youtubeId'] as String,
        startTime: j['startTime'] as String? ?? '0:00',
        endTime: j['endTime'] as String? ?? '0:00',
        duration: j['duration'] as String? ?? '',
        description: j['description'] as String?,
      );
}

class CalloutBox {
  final String type;
  final String content;

  const CalloutBox({required this.type, required this.content});

  factory CalloutBox.fromJson(Map<String, dynamic> j) => CalloutBox(
        type: j['type'] as String,
        content: j['content'] as String,
      );
}

class Checkpoint {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String onCorrect;
  final String onWrong;

  const Checkpoint({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.onCorrect,
    required this.onWrong,
  });

  factory Checkpoint.fromJson(Map<String, dynamic> j) => Checkpoint(
        question: j['question'] as String,
        options: (j['options'] as List).cast<String>(),
        correctIndex: j['correctIndex'] as int,
        onCorrect: j['onCorrect'] as String,
        onWrong: j['onWrong'] as String,
      );
}

class InterventionMap {
  final InterventionLevel mild;
  final InterventionLevel moderate;
  final InterventionLevel severe;

  const InterventionMap({
    required this.mild,
    required this.moderate,
    required this.severe,
  });

  factory InterventionMap.fromJson(Map<String, dynamic> j) => InterventionMap(
        mild: InterventionLevel.fromJson(j['mild'] as Map<String, dynamic>),
        moderate:
            InterventionLevel.fromJson(j['moderate'] as Map<String, dynamic>),
        severe:
            InterventionLevel.fromJson(j['severe'] as Map<String, dynamic>),
      );
}

class InterventionLevel {
  final String format;
  final String description;

  const InterventionLevel({required this.format, required this.description});

  factory InterventionLevel.fromJson(Map<String, dynamic> j) =>
      InterventionLevel(
        format: j['format'] as String,
        description: j['description'] as String,
      );
}

// ── Intervention data models ────────────────────────────────────────────

class Flashcard {
  final String question;
  final String answer;
  final String? explanation;

  const Flashcard(
      {required this.question, required this.answer, this.explanation});

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

  const SimulationConfig(
      {required this.type,
      required this.instructions,
      required this.elements});

  factory SimulationConfig.fromJson(Map<String, dynamic> j) =>
      SimulationConfig(
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

  const SimElement(
      {required this.symbol,
      required this.name,
      required this.group,
      required this.period});

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

  const GestureQuestion(
      {required this.question, required this.answer, this.hint});

  factory GestureQuestion.fromJson(Map<String, dynamic> j) => GestureQuestion(
        question: j['question'] as String,
        answer: j['answer'] as int,
        hint: j['hint'] as String?,
      );
}

class VoiceQuestion {
  final String question;
  final List<String> acceptedAnswers;

  const VoiceQuestion(
      {required this.question, required this.acceptedAnswers});

  factory VoiceQuestion.fromJson(Map<String, dynamic> j) => VoiceQuestion(
        question: j['question'] as String,
        acceptedAnswers: (j['acceptedAnswers'] as List).cast<String>(),
      );
}
