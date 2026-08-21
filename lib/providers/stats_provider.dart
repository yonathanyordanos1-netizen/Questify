import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/rank_service.dart';
import 'app_provider.dart';

/// A simulated user that appears on the live leaderboard.
class SimulatedUser {
  final String name;
  final String initials;
  int xp;
  int streak;
  int level;
  final int baseXp;

  SimulatedUser({
    required this.name,
    required this.initials,
    required this.xp,
    required this.streak,
    required this.level,
  }) : baseXp = xp;

  String get tier => RankService.tierForXp(xp, totalCompletions: xp > 0 ? 1 : 0).label;
}

/// The last activity event emitted by the ticker engine.
class ActivityEvent {
  final SimulatedUser user;
  final String habitName;
  final int xpGain;
  final DateTime timestamp;

  ActivityEvent({
    required this.user,
    required this.habitName,
    required this.xpGain,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Hybrid analytics engine: real Supabase stats + 5 dynamic simulated users.
///
/// The ticker picks a random simulated user every 8–15 seconds and awards
/// them +25–100 XP for completing a habit. This creates the appearance of
/// a live, active community without requiring real multiplayer backend.
class StatsProvider extends ChangeNotifier {
  StatsProvider({bool autoStart = true}) {
    if (autoStart) _ticker = Timer.periodic(_randomInterval(), _onTick);
  }

  /// Optional callback invoked when a simulated user crosses a rank boundary.
  void Function(SimulatedUser user, RankTier newTier)? onRankChange;

  // ── Simulated user roster ──────────────────────────────────────────────
  final List<SimulatedUser> simulatedUsers = [
    SimulatedUser(name: 'Alex M.', initials: 'AM', xp: 2340, streak: 19, level: 15),
    SimulatedUser(name: 'Elena R.', initials: 'ER', xp: 1980, streak: 14, level: 12),
    SimulatedUser(name: 'Marcus K.', initials: 'MK', xp: 2670, streak: 28, level: 17),
    SimulatedUser(name: 'Priya S.', initials: 'PS', xp: 1750, streak: 8, level: 10),
    SimulatedUser(name: 'Liam T.', initials: 'LT', xp: 2120, streak: 16, level: 13),
  ];

  // ── Activity feed ──────────────────────────────────────────────────────
  final List<ActivityEvent> _recentActivity = [];
  Timer? _ticker;

  /// Most recent 20 simulated activity events (newest first).
  List<ActivityEvent> get recentActivity =>
      List.unmodifiable(_recentActivity.take(20));

  /// Latest event for toast display.
  ActivityEvent? get latestActivity =>
      _recentActivity.isEmpty ? null : _recentActivity.first;

  // ── Habit names simulated users "complete" ─────────────────────────────
  static const _habitNames = [
    'Morning Run',
    'Meditation',
    'Read 30 min',
    'Gym Session',
    'Hydration Goal',
    'Journaling',
    'Cold Shower',
    'Yoga Flow',
    'No Sugar Diet',
    'Code Practice',
    'Gratitude Log',
    'Protein Intake',
  ];

  // ── Ticker engine ──────────────────────────────────────────────────────
  final _rng = math.Random();

  Duration _randomInterval() =>
      Duration(seconds: 8 + _rng.nextInt(8)); // 8–15 seconds

  void _onTick(Timer timer) {
    // Pick a random user
    final user = simulatedUsers[_rng.nextInt(simulatedUsers.length)];

    // Random XP gain: +25 to +100
    final xpGain = 25 + _rng.nextInt(76);

    // Random habit
    final habit = _habitNames[_rng.nextInt(_habitNames.length)];

    // Track tier before XP gain
    final oldTier = RankService.tierForXp(user.xp, totalCompletions: 1);

    // Update user stats
    user.xp += xpGain;
    user.streak += 1;
    user.level = 1 + (user.xp / 200).floor();

    // Check for rank change
    final newTier = RankService.tierForXp(user.xp, totalCompletions: 1);
    if (newTier != oldTier && newTier != RankTier.unranked) {
      onRankChange?.call(user, newTier);
    }

    // Record activity
    _recentActivity.insert(
      0,
      ActivityEvent(user: user, habitName: habit, xpGain: xpGain),
    );
    if (_recentActivity.length > 50) _recentActivity.removeLast();

    // Reschedule with a fresh random interval
    _ticker?.cancel();
    _ticker = Timer.periodic(_randomInterval(), _onTick);

    notifyListeners();
  }

  /// Merges real user (from [AppState]) + simulated users into a unified
  /// leaderboard sorted by XP descending. Returns a list of [LeagueEntry].
  List<LeagueEntry> mergedLeaderboard({
    required String displayName,
    required String initials,
    required int realXp,
    required int realStreak,
  }) {
    final entries = <LeagueEntry>[];

    // Add real user
    entries.add(LeagueEntry(
      rank: 0, // will be recalculated
      name: displayName,
      initials: initials,
      xp: realXp,
      streak: realStreak,
      tier: _tierFor(realXp),
      isMe: true,
      level: 1 + (realXp / 200).floor(),
    ));

    // Add simulated users
    for (final u in simulatedUsers) {
      entries.add(LeagueEntry(
        rank: 0,
        name: u.name,
        initials: u.initials,
        xp: u.xp,
        streak: u.streak,
        tier: u.tier,
        isMe: false,
        level: u.level,
      ));
    }

    // Sort by XP descending
    entries.sort((a, b) => b.xp.compareTo(a.xp));

    // Assign ranks
    for (var i = 0; i < entries.length; i++) {
      entries[i] = LeagueEntry(
        rank: i + 1,
        name: entries[i].name,
        initials: entries[i].initials,
        xp: entries[i].xp,
        streak: entries[i].streak,
        tier: entries[i].tier,
        isMe: entries[i].isMe,
        level: entries[i].level,
      );
    }

    return entries;
  }

  String _tierFor(int xp) =>
      RankService.tierForXp(xp, totalCompletions: xp > 0 ? 1 : 0).label;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
