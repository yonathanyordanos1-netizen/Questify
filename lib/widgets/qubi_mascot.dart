import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// Qubi — the Questify mascot. A cheerful circle avatar framed by the brand
/// gradient, with an optional gentle bob (opt-in so always-on pages don't run
/// a perpetual animation) and a halo that lights up when celebrating.
class QubiMascot extends StatelessWidget {
  const QubiMascot({
    super.key,
    this.size = 120,
    this.celebrating = false,
    this.bob = false,
  });

  final double size;
  final bool celebrating;
  final bool bob;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final widget = Stack(
      alignment: Alignment.center,
      children: [
        if (celebrating)
          Container(
            width: size * 1.2,
            height: size * 1.2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: isDark ? 0.24 : 0.3),
                  AppColors.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.04),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.32),
                blurRadius: size * 0.28,
                offset: Offset(0, size * 0.1),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/lumo.jpg',
              fit: BoxFit.cover,
              semanticLabel: 'Qubi',
              errorBuilder: (_, _, _) => ColoredBox(
                color: AppColors.primarySoft,
                child: Center(
                  child: Icon(
                    Icons.bolt,
                    size: size * 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (!bob) return widget;

    return widget
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: 0, end: -6, duration: 2400.ms, curve: Curves.easeInOut);
  }
}
