// lib/student/screens/interventions/voice_challenge_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/models/topic.dart';

/// Voice challenge intervention — question displayed + typed answer.
///
/// TTS reads the question aloud (when available), student types answer.
/// Fuzzy matching against accepted answers. Falls back to typed input
/// on all platforms for reliability.
class VoiceChallengeScreen extends StatefulWidget {
  final String topicId;
  final VoidCallback onComplete;

  const VoiceChallengeScreen({
    super.key,
    required this.topicId,
    required this.onComplete,
  });

  @override
  State<VoiceChallengeScreen> createState() => _VoiceChallengeScreenState();
}

class _VoiceChallengeScreenState extends State<VoiceChallengeScreen> {
  List<VoiceQuestion> _questions = [];
  int _currentIndex = 0;
  final _answerController = TextEditingController();
  bool _answered = false;
  bool _correct = false;
  int _score = 0;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/curriculum/${widget.topicId}.json',
      );
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final topic = Topic.fromJson(json);
      setState(() {
        _questions = topic.voiceQuestions;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _submitAnswer() {
    if (_answered || _answerController.text.trim().isEmpty) return;

    final userAnswer = _answerController.text.trim().toLowerCase();
    final q = _questions[_currentIndex];
    final isCorrect = q.acceptedAnswers.any(
      (a) => _fuzzyMatch(userAnswer, a.toLowerCase()),
    );

    setState(() {
      _answered = true;
      _correct = isCorrect;
      if (isCorrect) _score++;
    });

    // Auto-advance after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _answered = false;
          _correct = false;
          _answerController.clear();
        });
      } else {
        setState(() => _finished = true);
      }
    });
  }

  /// Simple fuzzy match — checks if answer contains the accepted answer
  /// or vice versa, with some tolerance.
  bool _fuzzyMatch(String input, String accepted) {
    if (input == accepted) return true;
    if (input.contains(accepted)) return true;
    if (accepted.contains(input) && input.length >= 3) return true;

    // Check word-level match
    final inputWords = input.split(RegExp(r'\s+'));
    final acceptedWords = accepted.split(RegExp(r'\s+'));
    for (final word in acceptedWords) {
      if (inputWords.any((w) => w == word || _levenshtein(w, word) <= 2)) {
        return true;
      }
    }
    return false;
  }

  /// Basic Levenshtein distance for typo tolerance.
  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= b.length; j++) matrix[0][j] = j;

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No voice questions available',
                style: TextStyle(color: AppColors.onSurface)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: widget.onComplete, child: const Text('CONTINUE')),
          ],
        ),
      );
    }

    if (_finished) return _buildScoreScreen();
    return _buildQuestionView();
  }

  Widget _buildQuestionView() {
    final q = _questions[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VOICE CHALLENGE',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.0,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${_currentIndex + 1} / ${_questions.length}',
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 14,
                  color: AppColors.outline,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Mic icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.mic, size: 40, color: AppColors.primary),
          ),

          const SizedBox(height: 32),

          // Question
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Text(
              q.question,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                color: AppColors.onSurface,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Answer input
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TextField(
              controller: _answerController,
              enabled: !_answered,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                suffixIcon: IconButton(
                  onPressed: _answered ? null : _submitAnswer,
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => _submitAnswer(),
            ),
          ),

          const SizedBox(height: 24),

          // Feedback
          if (_answered)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: (_correct ? AppColors.focused : AppColors.lost)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _correct ? Icons.check_circle : Icons.cancel,
                      color: _correct ? AppColors.focused : AppColors.lost,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _correct ? 'CORRECT!' : 'NOT QUITE',
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            color: _correct ? AppColors.focused : AppColors.lost,
                          ),
                        ),
                        if (!_correct)
                          Text(
                            'Accepted: ${q.acceptedAnswers.first}',
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 14,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildScoreScreen() {
    final percent = (_score / _questions.length * 100).round();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            percent >= 50 ? Icons.check_circle : Icons.refresh,
            size: 64,
            color: percent >= 50 ? AppColors.focused : AppColors.drifting,
          ),
          const SizedBox(height: 24),
          Text(
            '$_score / ${_questions.length}',
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percent% CORRECT',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 14,
              letterSpacing: 2.0,
              color: percent >= 50 ? AppColors.focused : AppColors.drifting,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: widget.onComplete,
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
  }
}
