// lib/screens/landing_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Full landing page — "The Cognitive Sanctuary"
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Fixed nav bar
          _NavBar(),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _HeroSection(),
                  _TechnologySection(),
                  _InterventionsSection(),
                  _AudienceSection(),
                  _Footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Nav Bar
// ============================================================

class _NavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      color: AppColors.surface,
      child: Row(
        children: [
          const Text(
            'NeuroLearn',
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _navLink('Science', true),
          _navLink('Technology', false),
          _navLink('Methodology', false),
          const SizedBox(width: 24),
          TextButton(
            onPressed: () => context.go('/login'),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            child: const Text(
              'Get Started',
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navLink(String label, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: active ? AppColors.primary : AppColors.outline,
        ),
      ),
    );
  }
}

// ============================================================
// Hero Section
// ============================================================

class _HeroSection extends StatefulWidget {
  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.8;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0E0E0E), AppColors.surface],
              ),
            ),
          ),

          // Animated waves
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => CustomPaint(
                painter:
                    _WavePainter(phase: _waveController.value * 2 * pi),
              ),
            ),
          ),

          // Radial glow
          Center(
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Hero text
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'The Cognitive Sanctuary',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      fontSize: _fontSize(context, 40, 72),
                      color: AppColors.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Text(
                      'Unlock surgical precision in your learning journey with '
                      'EEG-adaptive feedback loops that stabilize focus and '
                      'dissolve distraction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: _fontSize(context, 15, 20),
                        color: AppColors.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Begin Journey
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryContainer],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 24,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/login'),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                child: Text(
                  'Begin Journey',
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // View Science
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                child: Text(
                  'View Science',
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _fontSize(BuildContext context, double min, double max) {
    final w = MediaQuery.of(context).size.width;
    return min + (max - min) * ((w - 400) / 800).clamp(0.0, 1.0);
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.phase});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 5; i++) {
      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.03 - (i * 0.005))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final path = Path();
      final cy = size.height * (0.4 + i * 0.05);

      path.moveTo(0, cy);
      for (double x = 0; x <= size.width; x += 3) {
        path.lineTo(
          x,
          cy + sin((x / size.width) * 3 * pi + phase + i * 0.7) * (30.0 + i * 20),
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.phase != phase;
}

// ============================================================
// Technology of Focus
// ============================================================

class _TechnologySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;

    return Container(
      color: AppColors.surfaceContainerLow,
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: wide ? 80 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: wide
              ? Row(
                  children: [
                    Expanded(child: _textColumn(context)),
                    const SizedBox(width: 80),
                    Expanded(child: _crownVisual()),
                  ],
                )
              : Column(
                  children: [
                    _crownVisual(),
                    const SizedBox(height: 48),
                    _textColumn(context),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _textColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'HARD SCIENCE',
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 2.0,
              color: AppColors.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'The Technology\nof Focus',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w600,
            fontSize: 40,
            color: AppColors.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 32),
        _featureRow(
          Icons.analytics,
          'Neural Band Calibration',
          'Continuous monitoring of Theta, Alpha, and Beta bands to detect '
              'cognitive overload before it occurs.',
        ),
        const SizedBox(height: 24),
        _featureRow(
          Icons.psychology,
          'Neurosity Crown Integration',
          'Seamless hardware-software synergy that translates raw brainwaves '
              'into real-time learning adjustments.',
        ),
      ],
    );
  }

  Widget _featureRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.onSurface,
                  )),
              const SizedBox(height: 8),
              Text(desc,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _crownVisual() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.headset, size: 100,
                color: AppColors.primary.withValues(alpha: 0.5)),
            // Focus Index HUD
            Positioned(
              top: 40,
              left: 0,
              child: _hudChip('FOCUS INDEX', '84%', AppColors.primary),
            ),
            // Gamma HUD
            Positioned(
              bottom: 60,
              right: 0,
              child: _hudChip('GAMMA PULSE', 'Active', AppColors.tertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.onSurfaceVariant,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              )),
        ],
      ),
    );
  }
}

// ============================================================
// Adaptive Interventions
// ============================================================

class _InterventionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const Text(
                'Adaptive Interventions',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  fontSize: 40,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: const Text(
                  'When focus wavers, our system deploys subtle cognitive '
                  'rescues to pull you back into the flow.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 17,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              _buildCards(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCards(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;
    final cards = [
      _IntCard(
          icon: Icons.science,
          title: 'Interactive Simulations',
          desc: 'Manipulate visual data structures in 3D space to '
              're-engage tactile cognitive processing.',
          color: AppColors.primary),
      _IntCard(
          icon: Icons.mic,
          title: 'Voice Challenges',
          desc: 'Auditory logic puzzles designed to sharpen acoustic '
              'attention and verbal retention peaks.',
          color: AppColors.tertiary),
      _IntCard(
          icon: Icons.gesture,
          title: 'Gesture Recognition',
          desc: 'Hand gesture interactions that break passive reading '
              'patterns and re-engage motor cortex.',
          color: AppColors.secondary),
    ];

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards
            .map((c) => Expanded(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: c)))
            .toList(),
      );
    }
    return Column(
        children: cards
            .map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c))
            .toList());
  }
}

class _IntCard extends StatefulWidget {
  const _IntCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });
  final IconData icon;
  final String title, desc;
  final Color color;

  @override
  State<_IntCard> createState() => _IntCardState();
}

class _IntCardState extends State<_IntCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(widget.icon, color: widget.color, size: 26),
            ),
            const SizedBox(height: 20),
            Text(widget.title,
                style: const TextStyle(
                  fontFamily: 'Segoe UI',
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                  color: AppColors.onSurface,
                )),
            const SizedBox(height: 10),
            Text(widget.desc,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                  height: 1.6,
                )),
            const SizedBox(height: 16),
            Row(children: [
              Text('EXPLORE',
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.0,
                    color: widget.color,
                  )),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 14, color: widget.color),
            ]),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Audience Section
// ============================================================

class _AudienceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 800;

    return Container(
      color: AppColors.surfaceContainerLow,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _panel(
                        Icons.monitor_heart, AppColors.tertiary,
                        'For Educators',
                        'Gain unprecedented insight into student engagement. '
                            'Identify "Dead Zones" in your curriculum using '
                            'aggregated neural metrics and real-time focus heatmaps.',
                        ['Live Student Attention HUD',
                         'Curriculum Retention Analytics',
                         'Automated Intervention Reports'],
                        AppColors.surfaceContainerLowest,
                        AppColors.primary,
                      )),
                      Expanded(child: _panel(
                        Icons.spa, AppColors.primary,
                        'For Students',
                        'Enter a personal sanctuary where the interface adapts '
                            'to your state of mind. No more fighting burnout; '
                            'the system breathes with you.',
                        ['Adaptive UI Complexity',
                         'Gamified Flow State Rewards',
                         'Personal Cognitive Records'],
                        AppColors.surfaceContainerHigh,
                        AppColors.secondary,
                      )),
                    ],
                  ),
                )
              : Column(children: [
                  _panel(Icons.monitor_heart, AppColors.tertiary, 'For Educators',
                    'Gain unprecedented insight into student engagement.',
                    ['Live Student Attention HUD', 'Curriculum Retention Analytics',
                     'Automated Intervention Reports'],
                    AppColors.surfaceContainerLowest, AppColors.primary),
                  _panel(Icons.spa, AppColors.primary, 'For Students',
                    'Enter a personal sanctuary where the interface adapts to your state of mind.',
                    ['Adaptive UI Complexity', 'Gamified Flow State Rewards',
                     'Personal Cognitive Records'],
                    AppColors.surfaceContainerHigh, AppColors.secondary),
                ]),
        ),
      ),
    );
  }

  Widget _panel(IconData icon, Color iconColor, String title, String desc,
      List<String> features, Color bg, Color checkColor) {
    return Container(
      color: bg,
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: iconColor),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                fontSize: 30,
                color: AppColors.onSurface,
              )),
          const SizedBox(height: 14),
          Text(desc,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 15,
                color: AppColors.onSurfaceVariant,
                height: 1.6,
              )),
          const SizedBox(height: 20),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Icon(Icons.check_circle, size: 16, color: checkColor),
                  const SizedBox(width: 10),
                  Text(f,
                      style: const TextStyle(
                        fontFamily: 'Segoe UI',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      )),
                ]),
              )),
        ],
      ),
    );
  }
}

// ============================================================
// Footer
// ============================================================

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NeuroLearn',
                      style: TextStyle(
                        fontFamily: 'Segoe UI',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.primary,
                      )),
                  const SizedBox(height: 6),
                  Text('© 2026 The Cognitive Sanctuary. All rights reserved.',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color: AppColors.outline.withValues(alpha: 0.6),
                      )),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 28,
                children: ['White Papers', 'Research', 'Privacy', 'Terms']
                    .map((t) => Text(t,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          color: AppColors.outline.withValues(alpha: 0.6),
                        )))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
