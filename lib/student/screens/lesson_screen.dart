// lib/student/screens/lesson_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/models/attention_state.dart';
import '../../core/models/topic.dart';
import '../../core/services/attention_stream.dart';
import '../widgets/focus_hud.dart';
import 'interventions/intervention_engine.dart';

/// Lesson screen — full lesson renderer following the doc structure:
/// text → diagram → video → callout → checkpoint per section.
/// Sidebar with section locking (unlock via checkpoint).
/// Focus HUD at bottom, pacing engine pauses on drift.
class LessonScreen extends StatefulWidget {
  final String topicId;
  const LessonScreen({super.key, required this.topicId});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen>
    with SingleTickerProviderStateMixin {
  Topic? _topic;
  bool _loading = true;
  int _currentSectionIndex = 0;

  // Section locking: index of highest unlocked section
  int _unlockedUpTo = 0;
  // Checkpoint state per section
  final Map<int, bool> _checkpointCompleted = {};
  int? _selectedOption;
  bool? _checkpointCorrect;

  // Pacing
  bool _paused = false;
  AttentionLevel _currentLevel = AttentionLevel.focused;
  StreamSubscription<AttentionState>? _attentionSub;
  int _driftSeconds = 0;
  Timer? _driftTimer;

  // Interventions
  final _interventionEngine = InterventionEngine();
  bool _showingIntervention = false;
  String? _currentFormat;

  // Session
  final _sessionStart = DateTime.now();
  int _driftCount = 0;
  final _scrollController = ScrollController();
  late final AnimationController _pauseAnim;

  @override
  void initState() {
    super.initState();
    _pauseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadTopic();
    _startPacingEngine();
  }

  String? _loadError;

  Future<void> _loadTopic() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/curriculum/${widget.topicId}.json',
      );
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _topic = Topic.fromJson(json);
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('Failed to load topic: $e');
      debugPrint('$stack');
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  void _startPacingEngine() {
    _attentionSub = AttentionStream.instance.stream.listen((state) {
      if (!mounted) return;
      _currentLevel = state.level;
      if (!_paused &&
          (state.level == AttentionLevel.drifting ||
              state.level == AttentionLevel.lost)) {
        _onDriftDetected();
      }
      if (_paused &&
          !_showingIntervention &&
          state.level == AttentionLevel.focused) {
        _onFocusRecovered();
      }
    });
  }

  void _onDriftDetected() {
    setState(() { _paused = true; _driftCount++; _driftSeconds = 0; });
    _pauseAnim.forward();
    _driftTimer?.cancel();
    _driftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _driftSeconds++);
      if (_driftSeconds >= 4 && !_showingIntervention && !_interventionEngine.isActive) {
        _launchIntervention();
      }
    });
  }

  void _launchIntervention() {
    _interventionEngine.start(
      driftDurationSec: _driftSeconds,
      topicId: widget.topicId,
      subject: _topic?.subject ?? '',
    );
    final format = _interventionEngine.selectNextFormat();
    setState(() { _showingIntervention = true; _currentFormat = format; });
  }

  void _onInterventionComplete() {
    final recovered = _currentLevel == AttentionLevel.focused;
    _interventionEngine.reportResult(_currentFormat!, recovered);
    if (!recovered && _interventionEngine.hasMoreFormats) {
      final next = _interventionEngine.selectNextFormat();
      setState(() => _currentFormat = next);
    } else {
      _onFocusRecovered();
    }
  }

  void _onFocusRecovered() {
    _driftTimer?.cancel();
    _pauseAnim.reverse();
    _interventionEngine.reset();
    setState(() { _paused = false; _showingIntervention = false; _currentFormat = null; });
  }

  void _goToSection(int index) {
    if (index > _unlockedUpTo) return;
    setState(() {
      _currentSectionIndex = index;
      _selectedOption = null;
      _checkpointCorrect = null;
    });
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _onCheckpointAnswer(int optionIndex) {
    final cp = _topic!.sections[_currentSectionIndex].checkpoint;
    if (cp == null) return;
    final correct = optionIndex == cp.correctIndex;
    setState(() {
      _selectedOption = optionIndex;
      _checkpointCorrect = correct;
    });
    if (correct) {
      setState(() {
        _checkpointCompleted[_currentSectionIndex] = true;
        if (_currentSectionIndex + 1 > _unlockedUpTo &&
            _currentSectionIndex + 1 < _topic!.sections.length) {
          _unlockedUpTo = _currentSectionIndex + 1;
        }
      });
    }
  }

  void _nextSection() {
    if (_topic != null && _currentSectionIndex < _topic!.sections.length - 1) {
      _goToSection(_currentSectionIndex + 1);
    } else {
      context.go('/student/session-end');
    }
  }

  @override
  void dispose() {
    _attentionSub?.cancel();
    _driftTimer?.cancel();
    _scrollController.dispose();
    _pauseAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_topic == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load topic: ${widget.topicId}',
                style: const TextStyle(color: AppColors.onSurface)),
            if (_loadError != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Text(_loadError!,
                    style: TextStyle(color: AppColors.outline, fontSize: 12, fontFamily: 'Consolas'),
                    textAlign: TextAlign.center),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/student'),
              child: const Text('BACK TO DASHBOARD'),
            ),
          ]),
        ),
      );
    }

    final topic = _topic!;
    final section = topic.sections[_currentSectionIndex];
    final progress = (_currentSectionIndex + (_checkpointCompleted.containsKey(_currentSectionIndex) ? 1 : 0)) / topic.sections.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(topic, progress),
              Expanded(
                child: Row(
                  children: [
                    _buildSidebar(topic),
                    Expanded(child: _buildContent(section)),
                  ],
                ),
              ),
              const FocusHud(),
            ],
          ),
          if (_showingIntervention && _currentFormat != null)
            Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  // Keep HUD visible during intervention
                  Expanded(
                    child: InterventionEngine.buildFormatScreen(
                      format: _currentFormat!,
                      topicId: widget.topicId,
                      onComplete: _onInterventionComplete,
                    ),
                  ),
                  const FocusHud(),
                ],
              ),
            )
          else if (_paused)
            _buildPauseOverlay(section),
        ],
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────

  Widget _buildTopBar(Topic topic, double progress) {
    final elapsed = DateTime.now().difference(_sessionStart);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.surfaceContainer,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.outline),
            onPressed: () => context.go('/student'),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(topic.subject.toUpperCase(),
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 2.0, color: AppColors.primary)),
              Text(topic.name,
                  style: const TextStyle(fontFamily: 'Segoe UI', fontSize: 14,
                      fontWeight: FontWeight.w600, color: AppColors.onSurface)),
            ],
          ),
          const SizedBox(width: 20),
          // Progress bar
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text('Progress', style: TextStyle(fontFamily: 'Consolas',
                        fontSize: 9, color: AppColors.outline.withValues(alpha: 0.6))),
                    const Spacer(),
                    Text('${(progress * 100).round()}%', style: TextStyle(fontFamily: 'Consolas',
                        fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.focused)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(AppColors.focused),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Text(
            '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ──────────────────────────────────────────────

  Widget _buildSidebar(Topic topic) {
    return Container(
      width: 220,
      color: AppColors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.subject.toUpperCase(),
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 9,
                        fontWeight: FontWeight.w700, letterSpacing: 2.0,
                        color: AppColors.outline.withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                Text(topic.name,
                    style: const TextStyle(fontFamily: 'Segoe UI', fontSize: 14,
                        fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (_unlockedUpTo + (_checkpointCompleted.containsKey(_unlockedUpTo) ? 1 : 0)) / topic.sections.length,
                backgroundColor: AppColors.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(AppColors.focused),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Section list
          Expanded(
            child: ListView.builder(
              itemCount: topic.sections.length,
              padding: EdgeInsets.zero,
              itemBuilder: (_, i) {
                final s = topic.sections[i];
                final isActive = i == _currentSectionIndex;
                final isLocked = i > _unlockedUpTo;
                final isCompleted = _checkpointCompleted.containsKey(i);

                return InkWell(
                  onTap: isLocked ? null : () => _goToSection(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.secondaryContainer.withValues(alpha: 0.2)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isActive ? AppColors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Opacity(
                      opacity: isLocked ? 0.4 : 1.0,
                      child: Row(
                        children: [
                          // Status icon
                          if (isCompleted)
                            const Icon(Icons.check_circle, size: 14, color: AppColors.focused)
                          else if (isLocked)
                            const Icon(Icons.lock, size: 14, color: AppColors.outline)
                          else
                            Icon(Icons.circle_outlined, size: 14,
                                color: isActive ? AppColors.primary : AppColors.outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title,
                                    style: TextStyle(
                                      fontFamily: 'Georgia', fontSize: 13,
                                      color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                    )),
                                if (s.subtitle != null)
                                  Text(s.subtitle!,
                                      style: TextStyle(fontFamily: 'Consolas', fontSize: 9,
                                          color: AppColors.outline.withValues(alpha: 0.5))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Content ──────────────────────────────────────────────

  Widget _buildContent(Section section) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Text(section.title,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 28,
                    fontWeight: FontWeight.w600, color: AppColors.onSurface, height: 1.3)),
            if (section.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(section.subtitle!,
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 11,
                      color: AppColors.outline.withValues(alpha: 0.6))),
            ],
            const SizedBox(height: 28),

            // Paragraphs
            ...section.paragraphs.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(p,
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 16,
                          color: AppColors.onSurfaceVariant, height: 1.8, letterSpacing: 0.2)),
                )),

            // Key terms
            if (section.keyTerms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: section.keyTerms.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t, style: const TextStyle(fontFamily: 'Segoe UI',
                          fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                    )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Diagram
            if (section.diagram != null) _buildDiagram(section.diagram!),

            // Video
            if (section.video != null) _buildVideo(section.video!),

            // Callout
            if (section.callout != null) _buildCallout(section.callout!),

            // Checkpoint
            if (section.checkpoint != null) _buildCheckpoint(section.checkpoint!),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagram(DiagramSpec diagram) {
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schema, size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text('DIAGRAM', style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 3.0, color: AppColors.outline)),
            ],
          ),
          const SizedBox(height: 12),
          Text(diagram.title, style: const TextStyle(fontFamily: 'Segoe UI',
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 16),

          // Render a mini periodic table grid
          _buildMiniPeriodicTable(),

          const SizedBox(height: 12),
          Text(diagram.description, style: TextStyle(fontFamily: 'Georgia',
              fontSize: 13, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7), height: 1.5)),
          if (diagram.interactiveHint != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.touch_app, size: 14, color: AppColors.primary.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(diagram.interactiveHint!, style: TextStyle(fontFamily: 'Consolas',
                    fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.primary.withValues(alpha: 0.5))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Renders a simplified periodic table grid with key elements highlighted.
  Widget _buildMiniPeriodicTable() {
    // Simplified periodic table — 7 periods x 18 groups
    // Only showing key representative elements
    final Map<String, _PTElement> elements = {
      '1,1': _PTElement('H', 1, AppColors.onSurface),
      '1,18': _PTElement('He', 2, const Color(0xFF80CBC4)),
      '2,1': _PTElement('Li', 3, const Color(0xFFEF5350)),
      '2,2': _PTElement('Be', 4, const Color(0xFFFF9800)),
      '2,13': _PTElement('B', 5, AppColors.onSurfaceVariant),
      '2,14': _PTElement('C', 6, AppColors.onSurfaceVariant),
      '2,15': _PTElement('N', 7, AppColors.onSurfaceVariant),
      '2,16': _PTElement('O', 8, AppColors.onSurfaceVariant),
      '2,17': _PTElement('F', 9, const Color(0xFFEC407A)),
      '2,18': _PTElement('Ne', 10, const Color(0xFF80CBC4)),
      '3,1': _PTElement('Na', 11, const Color(0xFFEF5350)),
      '3,2': _PTElement('Mg', 12, const Color(0xFFFF9800)),
      '3,13': _PTElement('Al', 13, AppColors.onSurfaceVariant),
      '3,14': _PTElement('Si', 14, AppColors.onSurfaceVariant),
      '3,15': _PTElement('P', 15, AppColors.onSurfaceVariant),
      '3,16': _PTElement('S', 16, AppColors.onSurfaceVariant),
      '3,17': _PTElement('Cl', 17, const Color(0xFFEC407A)),
      '3,18': _PTElement('Ar', 18, const Color(0xFF80CBC4)),
      '4,1': _PTElement('K', 19, const Color(0xFFEF5350)),
      '4,2': _PTElement('Ca', 20, const Color(0xFFFF9800)),
      '4,3': _PTElement('Sc', 21, const Color(0xFF42A5F5)),
      '4,6': _PTElement('Cr', 24, const Color(0xFF42A5F5)),
      '4,8': _PTElement('Fe', 26, const Color(0xFF42A5F5)),
      '4,11': _PTElement('Cu', 29, const Color(0xFF42A5F5)),
      '4,12': _PTElement('Zn', 30, const Color(0xFF42A5F5)),
      '4,17': _PTElement('Br', 35, const Color(0xFFEC407A)),
      '4,18': _PTElement('Kr', 36, const Color(0xFF80CBC4)),
      '5,1': _PTElement('Rb', 37, const Color(0xFFEF5350)),
      '5,18': _PTElement('Xe', 54, const Color(0xFF80CBC4)),
      '6,1': _PTElement('Cs', 55, const Color(0xFFEF5350)),
      '6,11': _PTElement('Au', 79, const Color(0xFF42A5F5)),
      '6,18': _PTElement('Rn', 86, const Color(0xFF80CBC4)),
    };

    return Column(
      children: [
        // Group labels
        Row(
          children: [
            const SizedBox(width: 24),
            ...List.generate(18, (g) {
              return Expanded(
                child: Center(
                  child: Text(
                    '${g + 1}',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 7,
                        color: AppColors.outline.withValues(alpha: 0.4)),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 2),
        // Grid rows
        ...List.generate(7, (period) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                // Period label
                SizedBox(
                  width: 24,
                  child: Text(
                    '${period + 1}',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 8,
                        color: AppColors.outline.withValues(alpha: 0.4)),
                    textAlign: TextAlign.center,
                  ),
                ),
                ...List.generate(18, (group) {
                  final key = '${period + 1},${group + 1}';
                  final el = elements[key];

                  if (el == null) {
                    return Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          margin: const EdgeInsets.all(0.5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    );
                  }

                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Tooltip(
                        message: '${el.symbol} (${el.atomicNum})',
                        child: Container(
                          margin: const EdgeInsets.all(0.5),
                          decoration: BoxDecoration(
                            color: el.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: el.color.withValues(alpha: 0.3), width: 0.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            el.symbol,
                            style: TextStyle(fontFamily: 'Consolas', fontSize: 8,
                                fontWeight: FontWeight.w700, color: el.color),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _legendItem(const Color(0xFFEF5350), 'Alkali Metals'),
            _legendItem(const Color(0xFFFF9800), 'Alkaline Earth'),
            _legendItem(const Color(0xFF42A5F5), 'Transition Metals'),
            _legendItem(const Color(0xFFEC407A), 'Halogens'),
            _legendItem(const Color(0xFF80CBC4), 'Noble Gases'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontFamily: 'Consolas', fontSize: 9,
            color: AppColors.outline.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _buildVideo(VideoEmbed video) {
    // Parse start time to seconds for YouTube URL
    final startParts = video.startTime.split(':');
    final startSec = startParts.length == 2
        ? int.tryParse(startParts[0])! * 60 + int.tryParse(startParts[1])!
        : 0;
    final youtubeUrl = 'https://www.youtube.com/watch?v=${video.youtubeId}&t=${startSec}s';
    final thumbUrl = 'https://img.youtube.com/vi/${video.youtubeId}/hqdefault.jpg';

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // YouTube thumbnail with play button
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(youtubeUrl), mode: LaunchMode.externalApplication),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surfaceContainerLowest,
                      child: const Center(
                        child: Icon(Icons.play_circle_outline, size: 64, color: AppColors.outline),
                      ),
                    ),
                  ),
                ),
                // Play button overlay
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.lost.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow, size: 36, color: Colors.white),
                ),
                // Duration badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(video.duration,
                        style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          // Video info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_circle, size: 14, color: AppColors.lost.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text('VIDEO', style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 3.0, color: AppColors.outline)),
                    const Spacer(),
                    Text('${video.startTime} → ${video.endTime}',
                        style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                            color: AppColors.outline.withValues(alpha: 0.5))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(video.title, style: const TextStyle(fontFamily: 'Segoe UI',
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                if (video.description != null) ...[
                  const SizedBox(height: 4),
                  Text(video.description!, style: TextStyle(fontFamily: 'Georgia',
                      fontSize: 13, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallout(CalloutBox callout) {
    final Color accentColor;
    final IconData icon;
    final String label;
    switch (callout.type) {
      case 'did_you_know':
        accentColor = AppColors.tertiary; icon = Icons.lightbulb; label = 'DID YOU KNOW?';
      case 'real_world':
        accentColor = AppColors.focused; icon = Icons.public; label = 'REAL WORLD';
      case 'remember':
        accentColor = AppColors.primary; icon = Icons.bookmark; label = 'REMEMBER THIS';
      case 'common_mistake':
        accentColor = AppColors.lost; icon = Icons.warning_amber; label = 'COMMON MISTAKE';
      default:
        accentColor = AppColors.primary; icon = Icons.info; label = 'NOTE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 3.0, color: accentColor)),
            ],
          ),
          const SizedBox(height: 12),
          Text(callout.content, style: TextStyle(fontFamily: 'Georgia',
              fontSize: 15, color: AppColors.onSurface.withValues(alpha: 0.9), height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildCheckpoint(Checkpoint cp) {
    final answered = _selectedOption != null;
    final completed = _checkpointCompleted.containsKey(_currentSectionIndex);

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: completed ? AppColors.focused.withValues(alpha: 0.3) : AppColors.outlineVariant.withValues(alpha: 0.2),
          width: completed ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(completed ? Icons.check_circle : Icons.quiz, size: 16,
                  color: completed ? AppColors.focused : AppColors.primary),
              const SizedBox(width: 8),
              Text(completed ? 'CHECKPOINT COMPLETE' : 'QUICK CHECK',
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 3.0,
                      color: completed ? AppColors.focused : AppColors.outline)),
            ],
          ),
          const SizedBox(height: 16),
          Text(cp.question, style: const TextStyle(fontFamily: 'Georgia',
              fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.onSurface, height: 1.4)),
          const SizedBox(height: 16),
          // Options
          ...List.generate(cp.options.length, (i) {
            final isSelected = _selectedOption == i;
            final isCorrect = i == cp.correctIndex;
            Color optionColor = AppColors.surfaceContainerLow;
            Color textColor = AppColors.onSurfaceVariant;

            if (answered) {
              if (isCorrect) {
                optionColor = AppColors.focused.withValues(alpha: 0.15);
                textColor = AppColors.focused;
              } else if (isSelected && !_checkpointCorrect!) {
                optionColor = AppColors.lost.withValues(alpha: 0.15);
                textColor = AppColors.lost;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: optionColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: InkWell(
                  onTap: answered && _checkpointCorrect! ? null : () => _onCheckpointAnswer(i),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        if (answered && isCorrect)
                          const Icon(Icons.check_circle, size: 18, color: AppColors.focused)
                        else if (answered && isSelected)
                          const Icon(Icons.cancel, size: 18, color: AppColors.lost)
                        else
                          Icon(Icons.radio_button_unchecked, size: 18,
                              color: AppColors.outline.withValues(alpha: 0.4)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(cp.options[i], style: TextStyle(
                              fontFamily: 'Georgia', fontSize: 14, color: textColor)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          // Feedback
          if (answered) ...[
            const SizedBox(height: 12),
            Text(
              _checkpointCorrect! ? cp.onCorrect : cp.onWrong,
              style: TextStyle(
                fontFamily: 'Georgia', fontSize: 14, fontStyle: FontStyle.italic,
                color: _checkpointCorrect! ? AppColors.focused : AppColors.drifting,
                height: 1.5,
              ),
            ),
          ],
          // Next section button (after correct answer)
          if (completed) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _nextSection,
              child: Text(
                _currentSectionIndex < (_topic?.sections.length ?? 1) - 1
                    ? 'CONTINUE TO NEXT SECTION'
                    : 'COMPLETE LESSON',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Pause Overlay ────────────────────────────────────────

  Widget _buildPauseOverlay(Section section) {
    return AnimatedBuilder(
      animation: _pauseAnim,
      builder: (_, __) => Opacity(
        opacity: _pauseAnim.value,
        child: Container(
          color: AppColors.surface.withValues(alpha: 0.9),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentLevel == AttentionLevel.lost ? Icons.warning_amber : Icons.pause_circle_outline,
                  size: 64,
                  color: _currentLevel == AttentionLevel.lost ? AppColors.lost : AppColors.drifting,
                ),
                const SizedBox(height: 20),
                Text(
                  _currentLevel == AttentionLevel.lost ? 'FOCUS LOST' : 'ATTENTION DRIFTING',
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 18, fontWeight: FontWeight.w700,
                      letterSpacing: 3.0,
                      color: _currentLevel == AttentionLevel.lost ? AppColors.lost : AppColors.drifting),
                ),
                const SizedBox(height: 10),
                const Text('Content paused. Refocus to continue.',
                    style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic,
                        fontSize: 16, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text('Drifting for $_driftSeconds seconds',
                    style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: AppColors.outline)),
                if (section.recapOnReturn != null) ...[
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Text(section.recapOnReturn!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 14,
                            fontStyle: FontStyle.italic, color: AppColors.primary.withValues(alpha: 0.7))),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _onFocusRecovered,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.outlineVariant)),
                  child: const Text('RESUME MANUALLY',
                      style: TextStyle(fontFamily: 'Segoe UI', fontSize: 12,
                          fontWeight: FontWeight.w600, letterSpacing: 2.0, color: AppColors.outline)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PTElement {
  final String symbol;
  final int atomicNum;
  final Color color;
  const _PTElement(this.symbol, this.atomicNum, this.color);
}
