import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// A unified weekly bar chart widget.
///
/// Features:
/// - 180dp fixed height
/// - Pill-cap bars (top rounded corners only)
/// - Warm orange gradient fill (#FF6B35 → #E76F51) for active bars
/// - Subtle background tracks for empty/low bars
/// - Day labels below each bar
/// - Floating value badges on tap (haptic feedback)
/// - Smooth animated height transitions
class BarChartWidget extends StatefulWidget {
  const BarChartWidget({
    super.key,
    required this.values,
    required this.labels,
    this.activeIndex = -1,
    this.barColors,
    this.trackColor,
    this.height = 180,
    this.onBarTap,
  });

  /// The numeric value for each bar (7 for a week).
  final List<int> values;

  /// Label text below each bar (e.g. ['Mon','Tue',...]).
  final List<String> labels;

  /// Index of the highlighted/active bar (e.g. today).
  final int activeIndex;

  /// Optional gradient colors for the active bar. Defaults to
  /// [Color(0xFFFF6B35), Color(0xFFE76F51)].
  final List<Color>? barColors;

  /// Background track color. Defaults to light translucent slate.
  final Color? trackColor;

  /// Total chart height including labels.
  final double height;

  /// Called when a bar is tapped. Receives the bar index.
  final ValueChanged<int>? onBarTap;

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  int _tappedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxVal = widget.values.fold<int>(1, (m, v) => v > m ? v : m);
    final trackBg =
        widget.trackColor ?? (isDark ? const Color(0x0F0F172A) : const Color(0x0F0F172A));

    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < widget.values.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: widget.values[i] > 0
                    ? () {
                        HapticFeedback.lightImpact();
                        setState(() => _tappedIndex = _tappedIndex == i ? -1 : i);
                        widget.onBarTap?.call(i);
                      }
                    : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Floating value badge
                    AnimatedSize(
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                      child: _tappedIndex == i && widget.values[i] > 0
                          ? Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${widget.values[i]} XP',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    // Bar value label above bar
                    if (widget.values[i] > 0 && _tappedIndex != i)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${widget.values[i]}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: i == widget.activeIndex
                                ? AppColors.primary
                                : (isDark ? AppColors.mutedLightDark : AppColors.muted),
                          ),
                        ),
                      ),
                    // Bar + track
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final barHeight = widget.values[i] == 0
                            ? 20.0
                            : 12.0 + (widget.values[i] / maxVal) * (widget.height - 68);
                        return AnimatedContainer(
                          duration: 800.ms,
                          curve: Curves.easeOutCubic,
                          height: barHeight,
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            gradient: widget.values[i] > 0
                                ? LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: widget.barColors ??
                                        const [
                                          Color(0xFFFF6B35),
                                          Color(0xFFE76F51),
                                        ],
                                  )
                                : null,
                            color: widget.values[i] == 0 ? trackBg : null,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    // Day label
                    Text(
                      widget.labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            i == widget.activeIndex ? FontWeight.w800 : FontWeight.w600,
                        color: i == widget.activeIndex
                            ? AppColors.primary
                            : (isDark ? AppColors.mutedLightDark : AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
