// lib/student/screens/interventions/gesture_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/models/topic.dart';

/// Gesture intervention — hold up fingers to answer questions.
///
/// On desktop/web: shows number buttons as fallback since camera
/// access requires the MediaPipe Python server.
/// Student answers by clicking the number or holding up fingers.
class GestureScreen extends StatefulWidget {
  final String topicId;
  final VoidCallback onComplete;

  const GestureScreen({
    super.key,
    required this.topicId,
    required this.onComplete,
  });

  @override
  State<GestureScreen> createState() => _GestureScreenState();
}

class _GestureScreenState extends State<GestureScreen>
    with SingleTickerProviderStateMixin {
  List<GestureQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _correct = false;
  int _score = 0;
  bool _loading = true;
  bool _finished = false;
  late final AnimationController _feedbackAnim;

  @override
  void initState() {
    super.initState();
    _feedbackAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
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
        _questions = topic.gestureQuestions;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _submitAnswer(int answer) {
    if (_answered) return;

    final isCorrect = answer == _questions[_currentIndex].answer;
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      _correct = isCorrect;
      if (isCorrect) _score++;
    });
    _feedbackAnim.forward(from: 0);

    // Auto-advance after 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedAnswer = null;
          _answered = false;
        });
      } else {
        setState(() => _finished = true);
      }
    });
  }

  @override
  void dispose() {
    _feedbackAnim.dispose();
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
            const Text('No gesture questions available',
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
                'GESTURE CHALLENGE',
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

          // Hand icon
          Icon(
            Icons.pan_tool,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),

          // Question
          Text(
            q.question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 24,
              color: AppColors.onSurface,
              height: 1.4,
            ),
          ),

          if (q.hint != null) ...[
            const SizedBox(height: 8),
            Text(
              q.hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],

          const SizedBox(height: 16),

          Text(
            'HOLD UP FINGERS OR TAP A NUMBER',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 10,
              letterSpacing: 3.0,
              color: AppColors.outline.withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: 32),

          // Number buttons (0-10)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: List.generate(11, (i) {
              final isSelected = _selectedAnswer == i;
              final isCorrectAnswer = _answered && i == q.answer;

              Color bgColor;
              Color textColor;
              if (_answered && isCorrectAnswer) {
                bgColor = AppColors.focused.withValues(alpha: 0.2);
                textColor = AppColors.focused;
              } else if (_answered && isSelected && !_correct) {
                bgColor = AppColors.lost.withValues(alpha: 0.2);
                textColor = AppColors.lost;
              } else {
                bgColor = AppColors.surfaceContainerHigh;
                textColor = AppColors.onSurface;
              }

              return GestureDetector(
                onTap: _answered ? null : () => _submitAnswer(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: isSelected
                          ? (_correct ? AppColors.focused : AppColors.lost)
                          : AppColors.outlineVariant.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$i',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              );
            }),
          ),

          // Feedback
          if (_answered) ...[
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _feedbackAnim,
              builder: (_, __) => Opacity(
                opacity: _feedbackAnim.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _correct ? Icons.check_circle : Icons.cancel,
                      color: _correct ? AppColors.focused : AppColors.lost,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _correct ? 'CORRECT!' : 'Answer: ${q.answer}',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _correct ? AppColors.focused : AppColors.lost,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

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
