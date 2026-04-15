// lib/student/screens/interventions/simulation_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/models/topic.dart' show SimElement, InterventionPack;

/// Simulation intervention — drag elements to correct positions.
///
/// For Periodic Table: drag element symbols to the correct group/period slot.
/// Visual snap-to-target feedback. Progress bar fills as elements are placed.
class SimulationScreen extends StatefulWidget {
  final String subject;
  final String topicId;
  final VoidCallback onComplete;

  const SimulationScreen({
    super.key,
    required this.subject,
    required this.topicId,
    required this.onComplete,
  });

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  List<SimElement> _elements = [];
  final Map<int, bool> _placed = {};
  int? _dragIndex;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadSimulation();
  }

  Future<void> _loadSimulation() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/curriculum/${widget.subject}/${widget.topicId}/interventions.json',
      );
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final pack = InterventionPack.fromJson(json);
      setState(() {
        _elements = pack.simulation?.elements ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _onElementPlaced(int index) {
    setState(() {
      _placed[index] = true;
      if (_placed.length == _elements.length) {
        _finished = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_elements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No simulation available', style: TextStyle(color: AppColors.onSurface)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: widget.onComplete, child: const Text('CONTINUE')),
          ],
        ),
      );
    }

    if (_finished) {
      return _buildCompleteScreen();
    }

    return _buildSimulation();
  }

  Widget _buildSimulation() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ELEMENT PLACEMENT',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.0,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${_placed.length} / ${_elements.length}',
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 14,
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _elements.isEmpty ? 0 : _placed.length / _elements.length,
              backgroundColor: AppColors.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.focused),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Drag each element to its correct position on the grid',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 15,
              color: AppColors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 32),

          // Draggable elements (source)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_elements.length, (i) {
              if (_placed.containsKey(i)) return const SizedBox.shrink();

              final el = _elements[i];
              return Draggable<int>(
                data: i,
                onDragStarted: () => setState(() => _dragIndex = i),
                onDragEnd: (_) => setState(() => _dragIndex = null),
                feedback: Material(
                  color: Colors.transparent,
                  child: _elementChip(el, dragging: true),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _elementChip(el),
                ),
                child: _elementChip(el),
              );
            }),
          ),

          const SizedBox(height: 32),

          // Drop targets (grid)
          Expanded(
            child: Center(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(_elements.length, (i) {
                  final el = _elements[i];
                  final isPlaced = _placed.containsKey(i);

                  return DragTarget<int>(
                    onWillAcceptWithDetails: (details) => details.data == i,
                    onAcceptWithDetails: (details) => _onElementPlaced(details.data),
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      final isRejected = rejectedData.isNotEmpty;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: isPlaced
                              ? AppColors.focused.withValues(alpha: 0.15)
                              : isHovering
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : isRejected
                                      ? AppColors.lost.withValues(alpha: 0.1)
                                      : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: isPlaced
                                ? AppColors.focused
                                : isHovering
                                    ? AppColors.primary
                                    : isRejected
                                        ? AppColors.lost
                                        : AppColors.outlineVariant.withValues(alpha: 0.3),
                            width: isPlaced || isHovering ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isPlaced) ...[
                              Text(
                                el.symbol,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.focused,
                                ),
                              ),
                              Text(
                                el.name,
                                style: const TextStyle(
                                  fontFamily: 'Segoe UI',
                                  fontSize: 10,
                                  color: AppColors.focused,
                                ),
                              ),
                              const Icon(Icons.check, size: 14, color: AppColors.focused),
                            ] else ...[
                              Text(
                                'G${el.group} P${el.period}',
                                style: TextStyle(
                                  fontFamily: 'Consolas',
                                  fontSize: 11,
                                  color: AppColors.outline.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '?',
                                style: TextStyle(
                                  fontFamily: 'Segoe UI',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.outline.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _elementChip(SimElement el, {bool dragging = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: dragging
            ? AppColors.primaryContainer
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: dragging ? AppColors.primary : AppColors.outlineVariant,
        ),
        boxShadow: dragging
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            el.symbol,
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: dragging ? AppColors.onPrimary : AppColors.primary,
            ),
          ),
          Text(
            el.name,
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontSize: 11,
              color: dragging ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 64, color: AppColors.focused),
          const SizedBox(height: 24),
          const Text(
            'ALL ELEMENTS PLACED!',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.0,
              color: AppColors.focused,
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
