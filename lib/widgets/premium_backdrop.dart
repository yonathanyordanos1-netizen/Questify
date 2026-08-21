import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Questify v2 backdrop: a calm light surface with static questOrange glow
/// orbs and sparkles. Shared by the splash and the onboarding wizard so the
/// whole first-run flow feels like one continuous scene.
///
/// The orbs and sparkles are intentionally static: continuous `repeat`
/// animations across a full-screen backdrop force the GPU to repaint every
/// frame, which taxes low-end devices and the emulator. The splash keeps its
/// bounded logo/progress animations instead.
class PremiumBackdrop extends StatelessWidget {
  const PremiumBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF1E2124),
                  Color(0xFF121417),
                ]
              : const [
                  Color(0xFFFDF5F1),
                  AppColors.canvas,
                ],
          stops: const [0, 1],
        ),
      ),
      child: Stack(
        children: [
          _GlowOrb(
            size: 380,
            left: -150,
            top: -130,
            opacity: 0.35,
            tint: AppColors.primary,
          ),
          _GlowOrb(
            size: 460,
            right: -170,
            bottom: -170,
            opacity: 0.28,
            tint: AppColors.secondaryContainer,
          ),
          _GlowOrb(
            size: 220,
            left: -60,
            bottom: 90,
            opacity: 0.22,
            tint: AppColors.primary,
          ),
          for (var i = 0; i < 5; i++)
            _Sparkle(
              left: 40.0 + (i * 82) % 300,
              top: 140.0 + (i * 131) % 460,
              size: i.isEven ? 7.0 : 5.0,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.opacity,
    required this.tint,
  });

  final double size;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double opacity;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              tint.withValues(alpha: opacity),
              tint.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny sparkle dot on the backdrop.
class _Sparkle extends StatelessWidget {
  const _Sparkle({
    required this.left,
    required this.top,
    required this.size,
    required this.isDark,
  });

  final double left;
  final double top;
  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (isDark ? AppColors.primaryFixedDim : AppColors.primary)
              .withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
