import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';

/// Badge variants — shadcn-style: `default`/`secondary`/`outline`/`success`/
/// `gold`/`error`. Use variants instead of hand-rolled colored containers so
/// status styling stays consistent app-wide.
enum AppBadgeVariant { primary, secondary, success, gold, outline, error }

class AppBadge extends StatelessWidget {
  const AppBadge(
    this.label, {
    super.key,
    this.icon,
    this.variant = AppBadgeVariant.secondary,
    this.dense = false,
  });

  final String label;
  final Widget? icon;
  final AppBadgeVariant variant;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, border) = switch (variant) {
      AppBadgeVariant.primary => (
          AppColors.primary.withValues(alpha: 0.12),
          isDark ? AppColors.primaryFixedDim : AppColors.primaryDeep,
          AppColors.primary.withValues(alpha: 0.4),
        ),
      AppBadgeVariant.secondary => (
          AppColors.surfaceContainer,
          AppColors.muted,
          AppColors.glassEdge,
        ),
      AppBadgeVariant.success => (
          AppColors.success.withValues(alpha: 0.14),
          AppColors.success,
          AppColors.success.withValues(alpha: 0.45),
        ),
      AppBadgeVariant.gold => (
          AppColors.gold.withValues(alpha: 0.14),
          AppColors.gold,
          AppColors.gold.withValues(alpha: 0.5),
        ),
      AppBadgeVariant.outline => (
          Colors.transparent,
          isDark ? AppColors.mutedLightDark : AppColors.muted,
          AppColors.glassEdge,
        ),
      AppBadgeVariant.error => (
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
          AppColors.error.withValues(alpha: 0.45),
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10 : 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state placeholder — icon + title + optional message/action. Use this
/// instead of ad-hoc empty containers so every empty screen reads the same.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = 'sparkle',
    required this.title,
    this.message,
    this.action,
  });

  final String icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcons.stroke(
                  icon,
                  size: 28,
                  color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                  strokeWidth: 1.8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.inkLight : AppColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared minimal surface: flat fill, hairline outline and a soft blurred
/// elevation — the same language as the nav bar.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color,
    this.radius = AppSpacing.radiusCard,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surface = Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppColors.glassDark : AppColors.glassLight),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassEdge, width: 1),
        boxShadow: [AppSpacing.glassShadow],
      ),
      child: child,
    );

    if (onTap == null) return surface;
    return GestureDetector(onTap: onTap, child: surface);
  }
}

/// Minimal pressable button: flat fill, rounded corners and a soft shadow.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 56,
    this.fill,
    this.foreground,
    this.radius = AppSpacing.radiusSoft,
    this.icon,
    this.trailingIcon,
    this.bold = true,
  });

  final String label;
  final VoidCallback onTap;
  final double height;
  final Color? fill;
  final Color? foreground;
  final double radius;
  final Widget? icon;
  final Widget? trailingIcon;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final fg = foreground ?? ink;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: 1,
        duration: 160.ms,
        curve: Curves.easeOut,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill ?? AppColors.primary,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: (fill ?? AppColors.primary).withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                    letterSpacing: 0.2,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  trailingIcon!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
