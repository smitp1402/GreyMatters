// lib/student/screens/crown_connection_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/config/tts_phrase_bank.dart';
import '../../core/services/tts_service.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/websocket_client.dart';
import '../../core/services/attention_stream.dart';
import '../../core/models/attention_state.dart';

/// Screen 1 of the session flow — connect to the Neurosity Crown.
///
/// Shows a headset icon that transitions through states:
/// dim (idle) → pulsing (searching) → glowing (connected) → error (failed).
/// TTS voice prompt on load and on connection success.
class CrownConnectionScreen extends StatefulWidget {
  const CrownConnectionScreen({super.key});

  @override
  State<CrownConnectionScreen> createState() => _CrownConnectionScreenState();
}

enum _ConnectionState { idle, searching, connected, failed }

class _CrownConnectionScreenState extends State<CrownConnectionScreen>
    with TickerProviderStateMixin {
  _ConnectionState _state = _ConnectionState.idle;
  late final AnimationController _pulseController;
  late final AnimationController _glowController;
  final TtsService _tts = TtsService.instance;
  StreamSubscription<AttentionState>? _streamSub;
  bool _firstMessageReceived = false;

  // Signal quality for 8 channels (simulated from first message)
  final List<int> _channelQuality = List.filled(8, 0); // 0=off, 1=poor, 2=ok, 3=good

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // TtsService is configured once at app startup; no per-screen setup.
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _streamSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _startConnection() async {
    setState(() => _state = _ConnectionState.searching);
    await _tts.speak(TtsPhraseBank.crownSearch);

    try {
      // Connect to daemon WebSocket
      await WebSocketClient.instance.connect();

      // Listen for the first AttentionState message as proof of connection
      _streamSub = AttentionStream.instance.stream.listen((state) {
        if (!_firstMessageReceived) {
          _firstMessageReceived = true;
          _onConnected();
        }

        // Update channel quality from incoming data (simulate based on focus)
        if (mounted) {
          setState(() {
            final rng = Random();
            for (int i = 0; i < 8; i++) {
              _channelQuality[i] = state.focusScore > 0.3 ? 3 : (rng.nextBool() ? 2 : 1);
            }
          });
        }
      });

      // Timeout after 10 seconds if no message received
      Future.delayed(const Duration(seconds: 10), () {
        if (!_firstMessageReceived && mounted) {
          setState(() => _state = _ConnectionState.failed);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _state = _ConnectionState.failed);
      }
    }
  }

  Future<void> _onConnected() async {
    if (!mounted) return;
    setState(() {
      _state = _ConnectionState.connected;
      // All channels good on connection
      for (int i = 0; i < 8; i++) {
        _channelQuality[i] = 3;
      }
    });

    _glowController.forward();
    await _tts.speak(TtsPhraseBank.crownConnected);

    // Auto-advance to debug stream after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      context.go('/student/debug-stream');
    }
  }

  void _skipToMock() {
    // Connect to mock daemon (assumes --mock daemon is running)
    _startConnection();
  }

  void _retry() {
    setState(() {
      _state = _ConnectionState.idle;
      _firstMessageReceived = false;
    });
    _streamSub?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Background radial glow when connected
          if (_state == _ConnectionState.connected)
            Center(
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (_, __) => Container(
                  width: 400 + _glowController.value * 200,
                  height: 400 + _glowController.value * 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.08 * _glowController.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Main content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Headset icon with pulse ring
                _buildHeadsetVisual(),
                const SizedBox(height: 40),

                // Status text
                _buildStatusText(),
                const SizedBox(height: 32),

                // Channel quality indicators
                _buildChannelDots(),
                const SizedBox(height: 48),

                // Action buttons
                _buildActions(),
              ],
            ),
          ),

          // Skip button (bottom)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: _state == _ConnectionState.idle || _state == _ConnectionState.failed
                  ? TextButton(
                      onPressed: _skipToMock,
                      child: Text(
                        _state == _ConnectionState.failed
                            ? 'CONTINUE WITH MOCK DATA'
                            : 'SKIP — USE MOCK DATA',
                        style: const TextStyle(
                          fontFamily: 'Segoe UI',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                          color: AppColors.outline,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadsetVisual() {
    final Color iconColor;
    final double iconOpacity;

    switch (_state) {
      case _ConnectionState.idle:
        iconColor = AppColors.outline;
        iconOpacity = 0.3;
      case _ConnectionState.searching:
        iconColor = AppColors.outline;
        iconOpacity = 0.5;
      case _ConnectionState.connected:
        iconColor = AppColors.primary;
        iconOpacity = 1.0;
      case _ConnectionState.failed:
        iconColor = AppColors.error;
        iconOpacity = 0.5;
    }

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring (during searching)
          if (_state == _ConnectionState.searching)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 180 + _pulseController.value * 20,
                height: 180 + _pulseController.value * 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(
                      alpha: 0.3 - _pulseController.value * 0.2,
                    ),
                    width: 2,
                  ),
                ),
              ),
            ),

          // Connected glow ring
          if (_state == _ConnectionState.connected)
            AnimatedBuilder(
              animation: _glowController,
              builder: (_, __) => Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.6 * _glowController.value),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2 * _glowController.value),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

          // Headset icon
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: iconOpacity,
            child: Icon(
              Icons.headset,
              size: 100,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    final String text;
    final Color color;

    switch (_state) {
      case _ConnectionState.idle:
        text = 'NEUROSITY CROWN';
        color = AppColors.onSurfaceVariant;
      case _ConnectionState.searching:
        text = 'SEARCHING FOR CROWN...';
        color = AppColors.primary;
      case _ConnectionState.connected:
        text = 'NEURAL LINK ESTABLISHED';
        color = AppColors.focused;
      case _ConnectionState.failed:
        text = 'CROWN NOT FOUND';
        color = AppColors.error;
    }

    return Column(
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.0,
            color: color,
          ),
          child: Text(text),
        ),
        if (_state == _ConnectionState.searching) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
        ],
        if (_state == _ConnectionState.idle) ...[
          const SizedBox(height: 8),
          Text(
            'Tap below to establish neural link',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChannelDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (i) {
        final q = _channelQuality[i];
        final Color color;
        if (q == 0) {
          color = AppColors.surfaceContainerHighest;
        } else if (q == 1) {
          color = AppColors.lost;
        } else if (q == 2) {
          color = AppColors.drifting;
        } else {
          color = AppColors.focused;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: q == 3
                      ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CH${i + 1}',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 8,
                  color: AppColors.outline.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActions() {
    switch (_state) {
      case _ConnectionState.idle:
        return _connectButton();
      case _ConnectionState.searching:
        return const SizedBox.shrink();
      case _ConnectionState.connected:
        return Text(
          'ENTERING NEURAL STREAM...',
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: 11,
            letterSpacing: 2.0,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        );
      case _ConnectionState.failed:
        return Column(
          children: [
            _connectButton(label: 'RETRY CONNECTION'),
            const SizedBox(height: 12),
          ],
        );
    }
  }

  Widget _connectButton({String label = 'CONNECT CROWN'}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _startConnection,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Segoe UI',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 3.0,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
