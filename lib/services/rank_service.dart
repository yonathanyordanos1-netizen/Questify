import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The 7 explicit rank tiers in Questify, from lowest to highest.
enum RankTier {
  unranked,
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  ultimate,
  quester;

  String get label {
    switch (this) {
      case RankTier.unranked:
        return 'Unranked';
      case RankTier.bronze:
        return 'Bronze';
      case RankTier.silver:
        return 'Silver';
      case RankTier.gold:
        return 'Gold';
      case RankTier.platinum:
        return 'Platinum';
      case RankTier.diamond:
        return 'Diamond';
      case RankTier.ultimate:
        return 'Ultimate';
      case RankTier.quester:
        return 'Quester';
    }
  }

  String get emoji {
    switch (this) {
      case RankTier.unranked:
        return '🔒';
      case RankTier.bronze:
        return '🥉';
      case RankTier.silver:
        return '🥈';
      case RankTier.gold:
        return '🥇';
      case RankTier.platinum:
        return '💎';
      case RankTier.diamond:
        return '💠';
      case RankTier.ultimate:
        return '⚡';
      case RankTier.quester:
        return '👑';
    }
  }

  Color get color {
    switch (this) {
      case RankTier.unranked:
        return AppColors.muted;
      case RankTier.bronze:
        return const Color(0xFFCD7F32);
      case RankTier.silver:
        return const Color(0xFFC0C0C0);
      case RankTier.gold:
        return const Color(0xFFFFCC00);
      case RankTier.platinum:
        return const Color(0xFFD9E2EC);
      case RankTier.diamond:
        return const Color(0xFF7ECFE6);
      case RankTier.ultimate:
        return const Color(0xFF9B59B6);
      case RankTier.quester:
        return const Color(0xFFFF6B35);
    }
  }

  /// Gradient colors for badge backgrounds.
  List<Color> get gradient {
    switch (this) {
      case RankTier.unranked:
        return [const Color(0xFF94A3B8), const Color(0xFF64748B)];
      case RankTier.bronze:
        return [const Color(0xFFCD7F32), const Color(0xFF8B5E3C)];
      case RankTier.silver:
        return [const Color(0xFFC0C0C0), const Color(0xFF8E8E8E)];
      case RankTier.gold:
        return [const Color(0xFFFFCC00), const Color(0xFFE6A800)];
      case RankTier.platinum:
        return [const Color(0xFFD9E2EC), const Color(0xFFA3B8D0)];
      case RankTier.diamond:
        return [const Color(0xFF7ECFE6), const Color(0xFF4DA8CC)];
      case RankTier.ultimate:
        return [const Color(0xFF9B59B6), const Color(0xFF6C3483)];
      case RankTier.quester:
        return [const Color(0xFFFF6B35), const Color(0xFFE76F51)];
    }
  }

  String get description {
    switch (this) {
      case RankTier.unranked:
        return 'Complete your first task to unlock your rank badge.';
      case RankTier.bronze:
        return 'The journey begins. Keep completing tasks to climb higher.';
      case RankTier.silver:
        return 'You\'re building momentum. Stay consistent.';
      case RankTier.gold:
        return 'A true achiever. Your dedication shows.';
      case RankTier.platinum:
        return 'Exceptional discipline. You\'re in the top tier.';
      case RankTier.diamond:
        return 'Rare and brilliant. Almost at the peak.';
      case RankTier.ultimate:
        return 'Transcendent. You\'ve mastered the grind.';
      case RankTier.quester:
        return 'The apex predator. You ARE Questify.';
    }
  }
}

/// Data for a single rank tier display.
class RankTierData {
  const RankTierData({
    required this.tier,
    required this.minXp,
    required this.maxXp,
  });

  final RankTier tier;
  final int minXp;
  final int maxXp;

  int get range => maxXp - minXp;

  bool contains(int xp) => xp >= minXp && xp < maxXp;
}

/// Central rank engine — computes tier, progression, and next-tier thresholds.
class RankService {
  const RankService._();

  /// All 7 rank tiers in ascending order, with their XP boundaries.
  static const List<RankTierData> tiers = [
    RankTierData(tier: RankTier.bronze, minXp: 0, maxXp: 500),
    RankTierData(tier: RankTier.silver, minXp: 500, maxXp: 1500),
    RankTierData(tier: RankTier.gold, minXp: 1500, maxXp: 3500),
    RankTierData(tier: RankTier.platinum, minXp: 3500, maxXp: 7000),
    RankTierData(tier: RankTier.diamond, minXp: 7000, maxXp: 12000),
    RankTierData(tier: RankTier.ultimate, minXp: 12000, maxXp: 20000),
    RankTierData(tier: RankTier.quester, minXp: 20000, maxXp: 999999),
  ];

  /// Determines the user's rank tier based on their XP.
  /// Returns [RankTier.unranked] if [totalCompletions] is 0.
  static RankTier tierForXp(int xp, {int totalCompletions = 0}) {
    if (totalCompletions <= 0) return RankTier.unranked;
    for (final t in tiers) {
      if (t.contains(xp)) return t.tier;
    }
    return RankTier.quester; // 20000+ XP
  }

  /// Returns the current [RankTierData] for the given XP.
  static RankTierData tierDataForXp(int xp, {int totalCompletions = 0}) {
    if (totalCompletions <= 0) {
      return const RankTierData(tier: RankTier.unranked, minXp: 0, maxXp: 0);
    }
    for (final t in tiers) {
      if (t.contains(xp)) return t;
    }
    return tiers.last; // quester
  }

  /// Progress within the current tier (0.0 to 1.0).
  static double tierProgress(int xp, {int totalCompletions = 0}) {
    if (totalCompletions <= 0) return 0.0;
    final data = tierDataForXp(xp, totalCompletions: totalCompletions);
    if (data.range <= 0) return 1.0;
    final clamped = xp.clamp(data.minXp, data.maxXp);
    return (clamped - data.minXp) / data.range;
  }

  /// XP remaining to reach the next tier.
  static int xpToNextTier(int xp, {int totalCompletions = 0}) {
    if (totalCompletions <= 0) return 0;
    final data = tierDataForXp(xp, totalCompletions: totalCompletions);
    if (data.tier == RankTier.quester) return 0;
    return data.maxXp - xp;
  }

  /// The next rank tier (or null if already Quester).
  static RankTier? nextTier(RankTier current) {
    final idx = RankTier.values.indexOf(current);
    if (idx < RankTier.values.length - 1) {
      return RankTier.values[idx + 1];
    }
    return null;
  }

  /// Whether reaching [newXp] crosses a tier boundary compared to [oldXp].
  static RankTier? tierChanged(int oldXp, int newXp, {int totalCompletions = 0}) {
    final oldTier = tierForXp(oldXp, totalCompletions: totalCompletions);
    final newTier = tierForXp(newXp, totalCompletions: totalCompletions);
    if (newTier != oldTier && newTier != RankTier.unranked) return newTier;
    return null;
  }

  /// String representation of the XP range for a tier.
  static String rangeLabel(RankTierData data) {
    if (data.tier == RankTier.quester) return '${data.minXp}+ XP';
    return '${data.minXp} – ${data.maxXp - 1} XP';
  }
}
