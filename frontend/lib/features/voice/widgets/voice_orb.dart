import 'package:flutter/material.dart';

import '../../../core/theme/jarvis_theme.dart';
import '../screens/voice_chat_screen.dart';

class VoiceOrb extends StatelessWidget {
  final VoiceState state;
  final double soundLevel;
  final AnimationController pulseController;
  final AnimationController waveController;

  const VoiceOrb({
    super.key,
    required this.state,
    required this.soundLevel,
    required this.pulseController,
    required this.waveController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow rings
          ...List.generate(3, (index) => _buildGlowRing(index)),

          // Sound wave rings (when listening)
          if (state == VoiceState.listening) ..._buildSoundWaves(),

          // Main orb
          _buildMainOrb(),

          // Inner core
          _buildInnerCore(),

          // Icon overlay
          _buildIconOverlay(),
        ],
      ),
    );
  }

  Widget _buildGlowRing(int index) {
    final delay = index * 0.3;
    final baseSize = 200.0 + (index * 30);

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final progress = (pulseController.value + delay) % 1.0;
        final scale = 1.0 + (progress * 0.1);
        final opacity = (1.0 - progress) * 0.3;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: baseSize,
            height: baseSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _getStateColor().withOpacity(opacity),
                width: 1,
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSoundWaves() {
    return List.generate(4, (index) {
      return AnimatedBuilder(
        animation: waveController,
        builder: (context, child) {
          final progress = (waveController.value + (index * 0.25)) % 1.0;
          final scale = 1.0 + (progress * 0.5) + (soundLevel / 20);
          final opacity = (1.0 - progress) * 0.5;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: JarvisColors.primary.withOpacity(opacity),
                  width: 2,
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildMainOrb() {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final pulse = 1.0 + (pulseController.value * 0.05);
        final extraScale = state == VoiceState.listening
            ? (soundLevel / 30).clamp(0.0, 0.15)
            : 0.0;

        return Transform.scale(
          scale: pulse + extraScale,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _getStateColor().withOpacity(0.4),
                  _getStateColor().withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getStateColor().withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: _getStateColor().withOpacity(0.3),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInnerCore() {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final pulse = 1.0 + (pulseController.value * 0.1);

        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _getStateColor(),
                  _getStateColor().withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getStateColor().withOpacity(0.8),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconOverlay() {
    IconData icon;

    switch (state) {
      case VoiceState.idle:
        icon = Icons.mic_none;
        break;
      case VoiceState.listening:
        icon = Icons.mic;
        break;
      case VoiceState.processing:
        icon = Icons.hourglass_empty;
        break;
      case VoiceState.speaking:
        icon = Icons.volume_up;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        icon,
        key: ValueKey(state),
        size: 32,
        color: JarvisColors.background,
      ),
    );
  }

  Color _getStateColor() {
    switch (state) {
      case VoiceState.idle:
        return JarvisColors.textMuted;
      case VoiceState.listening:
        return JarvisColors.primary;
      case VoiceState.processing:
        return JarvisColors.warning;
      case VoiceState.speaking:
        return JarvisColors.accent;
    }
  }
}
