import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/stats_provider.dart';
import '../theme/app_theme.dart';

/// A floating glass toast that shows the latest simulated user activity.
/// Auto-advances through events and dismisses after a few seconds.
class LiveActivityToast extends StatefulWidget {
  const LiveActivityToast({super.key, required this.events});

  /// Stream of new activity events from [StatsProvider].
  final List<ActivityEvent> events;

  @override
  State<LiveActivityToast> createState() => _LiveActivityToastState();
}

class _LiveActivityToastState extends State<LiveActivityToast> {
  int _currentIndex = 0;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _advanceTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) %
            widget.events.length.clamp(1, widget.events.length);
      });
    });
  }

  @override
  void didUpdateWidget(LiveActivityToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.events.isNotEmpty &&
        widget.events.first != (oldWidget.events.isNotEmpty ? oldWidget.events.first : null)) {
      _currentIndex = 0;
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();

    final event = widget.events[_currentIndex % widget.events.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.glassEdge,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Fire emoji
            const Text('\ud83d\udd25', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            // Activity text
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  text: event.user.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.ink,
                  ),
                  children: [
                    TextSpan(
                      text: ' just verified ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.muted,
                      ),
                    ),
                    TextSpan(
                      text: "'${event.habitName}'",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    TextSpan(
                      text: ' (+${event.xpGain} XP)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Live indicator
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
