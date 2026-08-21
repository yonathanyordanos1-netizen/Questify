import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_provider.dart';
import '../providers/stats_provider.dart';
import '../services/rank_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/live_activity_toast.dart';

class RanksPage extends StatelessWidget {
  const RanksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Consumer2<AppState, StatsProvider>(
          builder: (context, app, stats, _) {
            final userXp = app.xp;
            final userTier = RankService.tierForXp(
              userXp,
              totalCompletions: userXp > 0 ? 1 : 0,
            );
            final userTierData = RankService.tierDataForXp(
              userXp,
              totalCompletions: userXp > 0 ? 1 : 0,
            );
            final mergedLeague = stats.mergedLeaderboard(
              displayName: app.displayName,
              initials: app.initials,
              realXp: userXp,
              realStreak: app.streak,
            );
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(
                    bottom: 130.0,
                    left: 16.0,
                    right: 16.0,
                    top: 16.0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _yourRankCard(
                        context,
                        tier: userTier,
                        tierData: userTierData,
                        xp: userXp,
                      ),
                      _liveToast(stats),
                      _allRanksSection(context, userTier: userTier, xp: userXp),
                      _leaderboardHeader(context, mergedLeague),
                      ...List.generate(
                        mergedLeague.length,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _leaderRow(context, mergedLeague[i]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Your Rank Card ────────────────────────────────────────────────────

  Widget _yourRankCard(
    BuildContext context, {
    required RankTier tier,
    required RankTierData tierData,
    required int xp,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final next = RankService.nextTier(tier);
    final progress = RankService.tierProgress(
      xp,
      totalCompletions: xp > 0 ? 1 : 0,
    );
    final toNext = RankService.xpToNextTier(
      xp,
      totalCompletions: xp > 0 ? 1 : 0,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDark ? AppColors.glassDark : AppColors.glassLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tier.color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: tier.color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: tier.gradient,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: tier.color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      tier.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.label,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: tier.color,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$xp XP',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.mutedLightDark : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: isDark ? AppColors.gaugeTrackDark : AppColors.gaugeTrack,
                valueColor: AlwaysStoppedAnimation(tier.color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              next != null
                  ? '$toNext XP to ${next.emoji} ${next.label}'
                  : 'Max Rank!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── All Ranks Section ─────────────────────────────────────────────────

  Widget _allRanksSection(
    BuildContext context, {
    required RankTier userTier,
    required int xp,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final tiers = RankService.tiers;
    final userTierIdx = tiers.indexWhere((t) => t.tier == userTier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'All Ranks',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
        ...List.generate(tiers.length, (i) {
          final data = tiers[i];
          final isCurrentTier = data.tier == userTier;
          final passed = userTierIdx > i || isCurrentTier;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrentTier
                  ? data.tier.color.withValues(alpha: 0.06)
                  : (isDark ? AppColors.glassDark : AppColors.glassLight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentTier
                    ? data.tier.color.withValues(alpha: 0.4)
                    : (isDark ? AppColors.borderDark : AppColors.border),
                width: isCurrentTier ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  data.tier.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.tier.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isCurrentTier ? data.tier.color : ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        RankService.rangeLabel(data),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (passed)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: isCurrentTier ? data.tier.color : AppColors.success,
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Leaderboard ───────────────────────────────────────────────────────

  Widget _leaderboardHeader(BuildContext context, List<LeagueEntry> mergedLeague) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Leaderboard',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
          Text(
            '${mergedLeague.length} players',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveToast(StatsProvider stats) {
    if (stats.recentActivity.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiveActivityToast(events: stats.recentActivity)
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _leaderRow(BuildContext context, LeagueEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final rankTier = entry.tierEnum;
    final tierColor = rankTier.color;
    final isMe = entry.isMe;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(
          sizeFactor: anim,
          child: child,
        ),
      ),
      child: ClipRRect(
        key: ValueKey('${entry.name}_${entry.rank}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primary.withValues(alpha: 0.06)
                : (isDark ? AppColors.glassDark : AppColors.glassLight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : (isDark ? AppColors.borderDark : AppColors.border),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${entry.rank}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: entry.rank <= 3
                        ? [AppColors.gold, AppColors.silver, AppColors.bronze][
                            entry.rank - 1]
                        : muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(rankTier.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tierColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tierColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.primaryDeep],
                        )
                      : null,
                  color: isMe ? null : tierColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  boxShadow: isMe
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    entry.initials,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isMe ? Colors.white : tierColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isMe ? AppColors.primary : ink,
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'You',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        AppIcons.stroke('flame', size: 11, color: tierColor),
                        const SizedBox(width: 3),
                        Text(
                          '${entry.streak}-day streak',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : (isDark ? AppColors.surfaceContainer : AppColors.surfaceContainerLow),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_fmt(entry.xp)} XP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isMe ? AppColors.primary : ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
