import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Renders the official Questify app logo (`assets/images/questify_logo.png`).
///
/// The logo art fills its whole 1600×1600 canvas, so it is drawn edge-to-edge
/// with `BoxFit.cover` inside a rounded-square frame — no letterboxing, no
/// "zoomed out" empty padding. Use [QuestifyLogoShape.circle] where a round
/// avatar-style treatment fits the surrounding layout.
class QuestifyLogo extends StatelessWidget {
  const QuestifyLogo({
    super.key,
    this.size = 96,
    this.shape = QuestifyLogoShape.rounded,
    this.glow = false,
    this.semanticLabel = 'Questify',
  });

  /// Bounding box edge length.
  final double size;

  /// Circle (avatar) vs. rounded-square (app icon) frame.
  final QuestifyLogoShape shape;

  /// Soft brand-glow shadow underneath the logo (used on the splash screen).
  final bool glow;

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = shape == QuestifyLogoShape.circle
        ? size / 2
        : size * 0.235;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: size * 0.32,
                    offset: Offset(0, size * 0.07),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.asset(
            'assets/images/questify_logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

enum QuestifyLogoShape { circle, rounded }
