// lib/screens/role_picker_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Auth-style role picker — "Cognitive Sanctuary" login screen.
///
/// Matches the Stitch UI design: dark glass-panel card with role toggle,
/// identity input, gradient CTA button, and brainwave background.
/// No real auth in v1 — stores name locally for display in session.
class RolePickerScreen extends StatefulWidget {
  const RolePickerScreen({super.key});

  @override
  State<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends State<RolePickerScreen>
    with SingleTickerProviderStateMixin {
  _Role _selectedRole = _Role.student;
  final _nameController = TextEditingController();
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleInitialize() {
    final route = _selectedRole == _Role.student ? '/student' : '/teacher';
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Brainwave background decoration
          const _BrainwaveBackground(),

          // Bottom gradient glow
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.33,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0x33ACC7FF), // primary at 20%
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // System status indicator (top-right, desktop only)
          if (MediaQuery.of(context).size.width > 800)
            Positioned(
              top: 48,
              right: 48,
              child: _SystemStatusIndicator(pulseController: _pulseController),
            ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand header
                    _buildBrandHeader(context),
                    const SizedBox(height: 40),

                    // Glass login card
                    _buildLoginCard(context),
                    const SizedBox(height: 48),

                    // Compliance branding
                    _buildComplianceBranding(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Column(
      children: [
        Text(
          'NEUROLEARN',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 28,
                letterSpacing: 8.0,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the Cognitive Sanctuary',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 18,
              ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Role selector
              _buildRoleSelector(context),
              const SizedBox(height: 32),

              // Name input
              _buildNameInput(context),
              const SizedBox(height: 32),

              // Initialize button
              _buildInitializeButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT PROTOCOL',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              Expanded(
                child: _RoleToggle(
                  icon: Icons.school,
                  label: 'Student',
                  isSelected: _selectedRole == _Role.student,
                  onTap: () => setState(() => _selectedRole = _Role.student),
                ),
              ),
              Expanded(
                child: _RoleToggle(
                  icon: Icons.monitor_heart_outlined,
                  label: 'Teacher',
                  isSelected: _selectedRole == _Role.teacher,
                  onTap: () => setState(() => _selectedRole = _Role.teacher),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNameInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IDENTITY TAG',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 3.0,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: _selectedRole == _Role.student
                ? 'Your name, student...'
                : 'Your name, educator...',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                Icons.fingerprint,
                color: AppColors.outline,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitializeButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleInitialize,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'INITIALIZE SESSION',
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 3.0,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComplianceBranding(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security, size: 24, color: AppColors.onSurface),
              SizedBox(width: 24),
              Icon(Icons.psychology, size: 24, color: AppColors.onSurface),
              SizedBox(width: 24),
              Icon(Icons.monitor_heart, size: 24, color: AppColors.onSurface),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 48,
            height: 1,
            color: AppColors.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'NEURAL INTERFACE PROTOCOL v1.0',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 4.0,
                  color: AppColors.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Private widgets
// ============================================================

enum _Role { student, teacher }

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemStatusIndicator extends StatelessWidget {
  const _SystemStatusIndicator({required this.pulseController});

  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'SYSTEM STATUS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.0,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, __) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer.withOpacity(
                    0.4 + (pulseController.value * 0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'NEURAL LINK ACTIVE',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                letterSpacing: 2.0,
                color: AppColors.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Mini progress bars
        _MiniProgressBar(width: 128, fill: 0.66, color: AppColors.primary),
        const SizedBox(height: 4),
        _MiniProgressBar(width: 96, fill: 0.5, color: AppColors.secondaryContainer),
      ],
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({
    required this.width,
    required this.fill,
    required this.color,
  });

  final double width;
  final double fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: fill,
          backgroundColor: AppColors.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

/// Animated brainwave SVG-like background using CustomPainter.
class _BrainwaveBackground extends StatefulWidget {
  const _BrainwaveBackground();

  @override
  State<_BrainwaveBackground> createState() => _BrainwaveBackgroundState();
}

class _BrainwaveBackgroundState extends State<_BrainwaveBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _BrainwavePainter(phase: _controller.value * 2 * pi),
        size: Size.infinite,
      ),
    );
  }
}

class _BrainwavePainter extends CustomPainter {
  _BrainwavePainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.5;

    for (int i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = AppColors.primary.withOpacity(0.04 - (i * 0.012))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 - (i * 0.2);

      final path = Path();
      final offset = i * 20.0;
      final amplitude = 40.0 + (i * 15.0);

      path.moveTo(0, centerY + offset);
      for (double x = 0; x <= size.width; x += 2) {
        final y = centerY +
            offset +
            sin((x / size.width) * 4 * pi + phase + (i * 0.5)) * amplitude;
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BrainwavePainter old) => old.phase != phase;
}
