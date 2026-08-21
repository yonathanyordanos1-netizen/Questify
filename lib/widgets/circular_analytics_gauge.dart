import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Questify v5 readiness dial — Oura-style gradient arc sweep.
///
/// BUG FIX: Renders ONLY the arc sweep via CustomPainter. Score text is
/// rendered as a SEPARATE Text widget placed on top via Stack by callers,
/// OR passed via the optional [scoreText] parameter for a single unified
/// render (eliminates double-number / text ghosting artifacts).
///
/// Gradient sweep: `#FF6B35` (warm orange) → `#52B788` (sage green).
/// Score text uses Inter w800 at 44px for maximum high-contrast legibility.
class CircularAnalyticsGauge extends StatelessWidget {
  const CircularAnalyticsGauge({
    super.key,
    this.value = 40,
    this.size = 128,
    this.strokeWidth = 12,
    this.fillColor = AppColors.primary,
    this.gradientColors,
    this.scoreText,
    this.scoreColor,
    this.sublabel,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color fillColor;

  /// Optional stroke gradient (e.g. `[orange, primary, accent]`). When set it
  /// replaces the flat [fillColor].
  final List<Color>? gradientColors;

  /// Optional score text rendered ONCE in the center using Inter w800.
  /// When provided, this replaces any stacked text from callers to prevent
  /// double-number ghosting artifacts.
  final String? scoreText;

  /// Color for the score text. Defaults to the current theme ink color.
  final Color? scoreColor;

  /// Optional label rendered directly below the score (e.g. "complete").
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = scoreColor ??
        (isDark ? AppColors.inkLight : AppColors.ink);
    final textMuted = isDark ? AppColors.mutedLightDark : AppColors.muted;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF171D24) : const Color(0xFFF7F3EE),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: const Color(0xCC05070B),
                  blurRadius: 14,
                  offset: const Offset(5, 7),
                ),
                BoxShadow(
                  color: const Color(0x1F3B4354),
                  blurRadius: 14,
                  offset: const Offset(-4, -5),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0x206B5D55),
                  blurRadius: 14,
                  offset: const Offset(5, 7),
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 14,
                  offset: const Offset(-4, -5),
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arc sweep only — no text rendered here.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 100)),
            duration: 1600.ms,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CustomPaint(
              size: Size.square(size),
              painter: _GaugePainter(
                progress: v / 100,
                strokeWidth: strokeWidth,
                trackColors: isDark
                    ? const [Color(0xFF232932), Color(0xFF161B22)]
                    : const [Color(0xFFEAE4DD), Color(0xFFD8D1C9)],
                fillColor: fillColor,
                gradientColors: gradientColors,
              ),
            ),
          ),
          // Single score text — Inter w800, 38px, high-contrast.
          if (scoreText != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  scoreText!,
                  maxLines: 1,
                  softWrap: false,
                  style: GoogleFonts.inter(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1.5,
                    color: textPrimary,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sublabel!,
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: textMuted,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColors,
    required this.fillColor,
    this.gradientColors,
  });

  final double progress;
  final double strokeWidth;
  final List<Color> trackColors;
  final Color fillColor;
  final List<Color>? gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Groove: a subtly shaded track so it reads recessed rather than flat.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: trackColors,
      ).createShader(rect);
    canvas.drawCircle(center, radius, track);

    final start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;
    if (sweep <= 0) return;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final colors = gradientColors;
    if (colors != null && colors.length > 1) {
      final stops = List<double>.generate(
        colors.length,
        (i) => i / (colors.length - 1),
      );
      fill.shader = SweepGradient(
        startAngle: start,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: colors,
        stops: stops,
      ).createShader(rect);
    } else {
      fill.color = fillColor;
    }
    canvas.drawArc(rect, start, sweep, false, fill);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColors != trackColors ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.gradientColors != gradientColors;
}
