// lib/student/screens/interventions/flashcard_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/models/topic.dart';

/// Flashcard intervention — swipeable 5-card deck with Q&A.
///
/// Student taps card to flip, then swipes or taps next.
/// Shows score at end. Calls onComplete when done.
class FlashcardScreen extends StatefulWidget {
  final String topicId;
  final VoidCallback onComplete;

  const FlashcardScreen({
    super.key,
    required this.topicId,
    required this.onComplete,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  List<Flashcard> _cards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  int _correct = 0;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/curriculum/${widget.topicId}.json',
      );
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final topic = Topic.fromJson(json);
      setState(() {
        _cards = topic.flashcards.take(5).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _flipCard() {
    setState(() => _showAnswer = true);
  }

  void _markCorrect() {
    _correct++;
    _nextCard();
  }

  void _markIncorrect() {
    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No flashcards available', style: TextStyle(color: AppColors.onSurface)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: widget.onComplete, child: const Text('CONTINUE')),
          ],
        ),
      );
    }

    if (_finished) {
      return _buildScoreScreen();
    }

    return _buildCardView();
  }

  Widget _buildCardView() {
    final card = _cards[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FLASHCARD CHALLENGE',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.0,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${_currentIndex + 1} / ${_cards.length}',
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 14,
                  color: AppColors.outline,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Card
          GestureDetector(
            onTap: _showAnswer ? null : _flipCard,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey('$_currentIndex-$_showAnswer'),
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 500, minHeight: 280),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: _showAnswer
                      ? AppColors.surfaceContainerHigh
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(
                    color: _showAnswer
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_showAnswer) ...[
                      const Icon(Icons.help_outline, size: 32, color: AppColors.primary),
                      const SizedBox(height: 20),
                      Text(
                        card.question,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 22,
                          color: AppColors.onSurface,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'TAP TO REVEAL',
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 10,
                          letterSpacing: 3.0,
                          color: AppColors.outline.withValues(alpha: 0.5),
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.lightbulb_outline, size: 32, color: AppColors.tertiary),
                      const SizedBox(height: 20),
                      Text(
                        card.answer,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          height: 1.4,
                        ),
                      ),
                      if (card.explanation != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          card.explanation!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Correct / Incorrect buttons
          if (_showAnswer)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                  icon: Icons.close,
                  label: 'INCORRECT',
                  color: AppColors.lost,
                  onTap: _markIncorrect,
                ),
                const SizedBox(width: 24),
                _actionButton(
                  icon: Icons.check,
                  label: 'CORRECT',
                  color: AppColors.focused,
                  onTap: _markCorrect,
                ),
              ],
            ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Segoe UI',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.5,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreScreen() {
    final percent = (_correct / _cards.length * 100).round();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            percent >= 60 ? Icons.check_circle : Icons.refresh,
            size: 64,
            color: percent >= 60 ? AppColors.focused : AppColors.drifting,
          ),
          const SizedBox(height: 24),
          Text(
            '$_correct / ${_cards.length}',
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
              color: percent >= 60 ? AppColors.focused : AppColors.drifting,
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
