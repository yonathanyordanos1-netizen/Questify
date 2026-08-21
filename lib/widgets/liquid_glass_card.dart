import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Questify design v2 card: flat material surface (no frosted blur), 24px
/// radius, hairline border and a soft ambient shadow.
///
/// MANDATORY: Every LiquidGlassCard wraps its children in an internal
/// [EdgeInsets.all(16)] padding inside the ClipRRect so card headers,
/// top badges, and chart labels maintain a 16dp safety buffer from
/// curved corners. Override with `padding: EdgeInsets.zero` only when
/// the caller explicitly manages its own internal padding.
///
/// ```dart
/// LiquidGlassCard(
///   radius: 24,
///   child: ...,           // card content
///   overlay: ...,        // optional accent painted on top
/// )
/// ```
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.radius = AppSpacing.radiusCard,
    this.blur,
    this.tint,
    this.borderColor,
    this.shadow,
    this.padding = const EdgeInsets.all(16.0),
    this.overlay,
    this.onTap,
    this.semanticLabel,
  });

  /// Content of the card.
  final Widget child;

  final double radius;

  /// Kept for API compatibility (v1 frosted glass). Ignored in v2.
  final double? blur;

  /// Surface tint — overrides the automatic light/dark card fill.
  final Color? tint;

  /// Border color — defaults to the v2 hairline edge.
  final Color? borderColor;

  /// Ambient card shadow. Defaults to the v2 level-1 shadow.
  final BoxShadow? shadow;

  final EdgeInsetsGeometry padding;

  /// Optional accent painted OVER the card (e.g. specular band, orb).
  final Widget? overlay;

  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = tint ?? (isDark ? AppColors.glassDark : AppColors.glassLight);
    final edge = borderColor ?? (isDark ? AppColors.glassEdgeDark : AppColors.glassEdge);

    final surface = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: edge, width: 1),
        boxShadow: [?shadow, AppSpacing.glassShadow],
      ),
      child: Padding(
        padding: padding,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            if (overlay != null) Positioned.fill(child: overlay!),
          ],
        ),
      ),
    );

    if (onTap == null) return surface;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: surface,
        ),
      ),
    );
  }
}

/// Top-down gloss band that sits over the card to sell the "liquid" look.
/// v2 uses a whisper-light sheen (kept at very low opacity).
class GlassSheen extends StatelessWidget {
  const GlassSheen({super.key, this.opacity = 0.04});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.45],
          ),
        ),
      ),
    );
  }
}

/// Flat inline card that tracks the active theme automatically.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppSpacing.radiusCard,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: color ?? (isDark ? AppColors.glassDark : AppColors.glassLight),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: borderColor ?? (isDark ? AppColors.glassEdgeDark : AppColors.glassEdge),
            width: 1,
          ),
          boxShadow: [AppSpacing.glassShadow],
        ),
        child: onTap != null
            ? InkWell(onTap: onTap, child: Padding(padding: padding, child: child))
            : Padding(padding: padding, child: child),
      ),
    );
  }
}
