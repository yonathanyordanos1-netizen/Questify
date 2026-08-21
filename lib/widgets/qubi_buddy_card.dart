import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../modals/photo_proof_sheet.dart';
import '../pages/qubi_page.dart';
import '../models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'pressable.dart';
import 'qubi_mascot.dart';

/// Qubi's Duolingo-style buddy banner — the mascot is the star of the
/// dashboard. It greets you, prods you toward the next quest that's due
/// ("Time for Gym Session! 🏋️"), and shows the streak/XP treats you bank for
/// verifying. Tapping the CTA jumps straight into photo-proof verification.
class QubiBuddyCard extends StatelessWidget {
  const QubiBuddyCard({super.key});

  /// "7:30 AM" / "21:00" → minutes since midnight (null when unparsable).
  static int? _timeMinutes(String time) {
    final m = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*(am|pm)?',
      caseSensitive: false,
    ).firstMatch(time.trim());
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = m.group(3)?.toLowerCase();
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    return h * 60 + min;
  }

  /// The quest Qubi should nudge about: the next pending quest whose time is
  /// still upcoming today, or the earliest pending one after the day's window
  /// has passed. Null when everything is verified.
  Habit? _nudgeHabit(AppState app) {
    final pending = app.pendingTodayHabits;
    if (pending.isEmpty) return null;
    final nowMinutes =
        DateTime.now().hour * 60 + DateTime.now().minute;
    Habit? fallback;
    for (final h in pending) {
      final t = _timeMinutes(h.time);
      if (t == null) continue;
      if (fallback == null ||
          t < (_timeMinutes(fallback.time) ?? 0)) {
        fallback = h;
      }
      if (t >= nowMinutes) return h;
    }
    return fallback ?? pending.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppState>();
    final nudge = _nudgeHabit(app);
    final pending = app.pendingTodayCount;
    final verifiedToday = app.habits.length - pending;
    final dueSoon = nudge != null &&
        (_timeMinutes(nudge.time) ?? 0).abs() <= 75;

    final String title;
    final String sub;
    final String cta;
    if (nudge == null) {
      title = 'Perfect day — every quest verified!';
      sub = 'Take the win, streak locked in. Treat earned!';
      cta = 'View Matrix';
    } else if (dueSoon) {
      title = 'Time for ${nudge.name}! ${nudge.emoji}';
      sub = 'Show me you did it and I’ll bank +50 XP.';
      cta = 'Verify now';
    } else {
      title = '$pending quest${pending == 1 ? '' : 's'} to go!';
      sub = 'Snap a photo proof to bank XP and keep the streak alive.';
      cta = 'Verify now';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF1C2334), Color(0xFF2A3040)]
                : const [Color(0xFFFFF3EB), Color(0xFFFFE3D4)],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.glassEdge),
          boxShadow: [AppSpacing.glassShadow],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.3),
                      AppColors.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      QubiMascot(size: 72),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                letterSpacing: -0.2,
                                color:
                                    isDark ? AppColors.inkLight : AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              sub,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                color: isDark
                                    ? AppColors.mutedLight
                                    : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Pressable(
                          onTap: () => _onCta(context, nudge),
                          scale: 0.97,
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcons.stroke(
                                  nudge == null ? 'calendar' : 'camera',
                                  size: 17,
                                  color: Colors.white,
                                  strokeWidth: 2.3,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cta,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Pressable(
                        onTap: () => openQubi(context),
                        scale: 0.97,
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.glassEdge),
                          ),
                          child: const Text(
                            'Chat',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _treat(
                        isDark: isDark,
                        icon: 'flame',
                        color: AppColors.primary,
                        value: '${app.streak}',
                        label: 'DAY STREAK',
                      ),
                      const SizedBox(width: 8),
                      _treat(
                        isDark: isDark,
                        icon: 'zap',
                        color: AppColors.primary,
                        value: _fmt(app.xp),
                        label: 'TOTAL XP',
                      ),
                      const SizedBox(width: 8),
                      _treat(
                        isDark: isDark,
                        icon: 'star',
                        color: AppColors.gold,
                        value: '$verifiedToday/${app.habits.length}',
                        label: 'DONE TODAY',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(
          delay: 140.ms,
        )
        .fadeIn(duration: 550.ms)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 600.ms,
          curve: Curves.easeOutBack,
        );
  }

  void _onCta(BuildContext context, Habit? nudge) {
    if (nudge == null) {
      context.read<AppState>().setActiveTab(1);
      return;
    }
    showPhotoProofSheet(context, nudge);
  }

  Widget _treat({
    required bool isDark,
    required String icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.glassEdgeDark : AppColors.glassEdge,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcons.stroke(icon, size: 13, color: color, strokeWidth: 2.4),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? AppColors.inkLight : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? AppColors.mutedLight : AppColors.mutedLightDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    }
    return '$n';
  }
}
