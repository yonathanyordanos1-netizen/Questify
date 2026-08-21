import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/update_service.dart';

/// Global app state: auth profile, onboarding responses, quest matrix,
/// XP/streak, Qubi chat, custom habits, league roster and photo-proof ledger.
///
/// Local state is the fast source of truth for the UI; when Supabase is
/// configured and the user is signed in every mutation is mirrored to the
/// database through [SupabaseService], which is itself locked down by RLS.
class AppState extends ChangeNotifier {
  AppState() {
    _seedDemo();
  }

  // ── Persistence ──────────────────────────────────────────────────────────
  static const String _storageKey = 'questify_state_v3';

  bool _loaded = false;

  /// Loads persisted state (or a fresh demo state). Backend hydration is
  /// kicked off separately after the first frame (see `main()`), so a slow or
  /// unreachable network never blocks the app from launching.
  static Future<AppState> load() async {
    final state = AppState();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        state._apply(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt or legacy payload — fall back to the seeded demo state.
      }
    }
    state._loaded = true;
    state._scheduleHabitReminders();
    return state;
  }

  /// Syncs Qubi's per-quest coach pings with the current habit list
  /// (fire-and-forget; the service no-ops on unsupported platforms).
  void _scheduleHabitReminders() {
    NotificationService.instance
        .applyHabitReminders(habits: _allHabits)
        .catchError((_) {});
  }

  Timer? _persistTimer;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_loaded) _schedulePersist();
  }

  /// Coalesces the persisted write so bursts of state changes (typing, chat
  /// streaming, tab switches) don't trigger a SharedPreferences round-trip
  /// (an expensive JSON encode + disk write) on every single notification.
  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 300), () {
      _persistTimer = null;
      _persist();
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_toJson()));
  }

  // ── Backend binding ──────────────────────────────────────────────────────

  /// Demo mode when no backend is configured OR the configured credentials
  /// don't actually work (bad/mismatched key) — local state stays authoritative.
  bool get isDemo => !SupabaseService.instance.backendOnline;
  bool get isSignedIn => SupabaseService.instance.isSignedIn;
  String? get uid => SupabaseService.instance.userId;

  /// True when signed in via Supabase but no habits have been created yet.
  bool get isNewAccount => isSignedIn && _customHabits.isEmpty;

  /// Pulls habits, completions and profile from Supabase once on boot.
  Future<void> hydrateFromSupabase() async {
    await SupabaseService.instance.init();
    if (!SupabaseService.instance.isSignedIn) return;
    try {
      final profile = await SupabaseService.instance.fetchProfile();
      if (profile != null) {
        _displayName = (profile['display_name'] as String?) ?? _displayName;
        _username = (profile['username'] as String?) ?? _username;
        _email = (profile['email'] as String?) ?? _email;
        _avatar = (profile['avatar'] as String?) ?? _avatar;
        _xp = (profile['xp'] as int?) ?? _xp;
        _streak = (profile['streak'] as int?) ?? _streak;
        final last = profile['last_streak_date'] as String?;
        _lastStreakDate = last == null ? null : DateTime.tryParse(last);
        final member = profile['member_since'] as String?;
        _memberSince = member == null ? null : DateTime.tryParse(member);
        // Returning users who completed onboarding elsewhere skip the wizard.
        if (profile['onboarding_done'] == true) {
          _onboardingDone = true;
          _accountCreated = true;
        }
        if (profile['responses'] is Map) {
          final restored = (profile['responses'] as Map).cast<String, dynamic>();
          restored.forEach((key, value) {
            if (value is String) _responses[key] = value;
          });
        }
      }
      // Clear demo/seeded data before loading real Supabase data so the
      // matrix and chat only reflect what the user actually owns.
      _weekMatrix.clear();
      _chat.clear();
      final habits = await SupabaseService.instance.fetchHabits();
      if (habits.isNotEmpty) {
        _customHabits
          ..clear()
          ..addAll(
            habits.map(
              (h) => Habit(
                id: h['id'] as String,
                name: (h['title'] as String?) ?? 'Habit',
                icon: (h['icon'] as String?) ?? 'check',
                time: (h['time_of_day'] as String?) ?? '8:00 AM',
                category: (h['category'] as String?) ?? 'Wellness',
                emoji: (h['emoji'] as String?) ?? '✅',
              ),
            ),
          );
        for (final h in _customHabits) {
          _weekMatrix[h.id] ??= List.filled(7, QuestStatus.pending);
        }
      }
      final completions = await SupabaseService.instance.fetchCompletions();
      for (final row in completions) {
        final habitId = row['habit_id'] as String?;
        if (habitId == null) continue;
        final day = _parseDay(row['completed_on']);
        if (day == null) continue;
        final status = QuestStatus.values.asNameMap()[row['status']];
        if (status != null) {
          _weekMatrix[habitId] ??= List.filled(7, QuestStatus.pending);
          _weekMatrix[habitId]![day] = status;
        }
        final proof = row['proof_url'] as String?;
        if (proof != null && proof.isNotEmpty) {
          _proofs[habitId] ??= {};
          _proofs[habitId]![day] = proof;
        }
      }
      // Load persisted Qubi chat history from Supabase.
      final chats = await SupabaseService.instance.fetchChats();
      if (chats.isNotEmpty) {
        _chat.addAll(chats.map((c) => ChatMessage(
              fromUser: c['role'] == 'user',
              text: (c['content'] as String?) ?? '',
            )));
      }
      notifyListeners();
    } catch (_) {
      // Offline or transient — local state stays authoritative.
    }
  }

  int? _parseDay(Object? value) {
    final s = value is String ? value : value?.toString();
    if (s == null || s.length < 10) return null;
    final d = DateTime.tryParse(s.substring(0, 10));
    if (d == null) return null;
    return d.weekday - 1;
  }

  // ── Profile & Account ────────────────────────────────────────────────────

  String _displayName = 'Noah Cooper';
  String _username = 'noah';
  String _email = '';
  String _avatar = 'sun';
  String _password = '';
  bool _onboardingDone = false;
  bool _accountCreated = false;
  final Map<String, String> _responses = {};
  DateTime? _memberSince;

  static const Map<String, List<Color>> avatarPalettes = {
    'sun': [Color(0xFFFF6B35), Color(0xFFE76F51)],
    'ocean': [Color(0xFF2B6CB0), Color(0xFF38B2AC)],
    'grape': [Color(0xFF6B46C1), Color(0xFFD53F8C)],
    'forest': [Color(0xFF276749), Color(0xFF48BB78)],
    'ember': [Color(0xFFC53030), Color(0xFFED8936)],
    'sky': [Color(0xFF3182CE), Color(0xFF90CDF4)],
  };

  List<Color> avatarColors(String key) =>
      avatarPalettes[key] ?? avatarPalettes['sun']!;

  String get displayName => _displayName;
  String get username => _username;
  String get email => _email;
  String get avatar => _avatar;
  bool get onboardingDone => _onboardingDone;
  bool get accountCreated => _accountCreated;
  DateTime? get memberSince => _memberSince;
  Map<String, String> get responses => Map.unmodifiable(_responses);

  /// Full JSON-serializable map of onboarding responses (for Inspector mode).
  Map<String, dynamic> get onboardingDataJson => {
        'display_name': _displayName,
        'username': _username,
        'avatar': _avatar,
        'xp': _xp,
        'streak': _streak,
        'onboarding_done': _onboardingDone,
        ..._responses,
      };

  String get memberSinceLabel {
    final date = _memberSince;
    if (date == null) return 'Member · this week';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Member since ${months[date.month - 1]} ${date.year}';
  }

  /// Saves name/username locally and mirrors to Supabase.
  ///
  /// Returns a user-facing error string when the change is rejected (empty or
  /// invalid username, or a username already claimed by another player).
  /// Returns `null` on success. The unique index on `profiles.username` is the
  /// final authority — the availability RPC only avoids the race window.
  Future<String?> setProfile({required String name, required String username}) async {
    final newName = name.trim();
    final newUsername = username.trim().toLowerCase();
    if (newUsername.isEmpty) return 'Username can’t be empty.';
    if (newUsername.length < 3) {
      return 'Username must be at least 3 characters.';
    }
    if (newUsername.length > 16) {
      return 'Username must be 16 characters or fewer.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(newUsername)) {
      return 'Use only letters, numbers and underscores.';
    }

    final available = await SupabaseService.instance.usernameAvailable(newUsername);
    if (available == false) {
      return '“$newUsername” is already taken — try another one.';
    }

    _displayName = newName.isEmpty ? _displayName : newName;
    _username = newUsername;
    notifyListeners();
    _syncProfile();
    return null;
  }

  Future<void> _syncProfile() async {
    try {
      await SupabaseService.instance.upsertProfile({
        'display_name': _displayName,
        'username': _username,
        'onboarding_done': _onboardingDone,
        'responses': _responses,
      });
    } catch (_) {}
  }

  /// Applies a real Google OAuth identity (Supabase session already active).
  void applyGoogleAuth({required String name, required String email}) {
    _displayName = name.trim().isEmpty ? _displayName : name.trim();
    _email = email.trim();
    _accountCreated = true;
    _memberSince ??= DateTime.now();
    _syncProfile();
    notifyListeners();
  }

  /// Demo-mode account creation (offline). Real auth flows through Supabase.
  /// Does NOT complete onboarding — [finishOnboarding] is the single exit.
  void createAccount({
    required String name,
    required String username,
    String email = '',
    String avatar = 'sun',
    String password = '',
  }) {
    _displayName = name.trim().isEmpty ? _displayName : name.trim();
    _username = username.trim().isEmpty ? _username : username.trim();
    _email = email.trim();
    _avatar = avatarPalettes.containsKey(avatar) ? avatar : _avatar;
    _password = password;
    _accountCreated = true;
    _memberSince ??= DateTime.now();
    notifyListeners();
  }

  String? logIn({required String handle, required String password}) {
    final normalized = handle.trim().toLowerCase();
    if (!_accountCreated || _username.isEmpty) {
      return 'No Questify account yet — create one first.';
    }
    final handleMatches =
        normalized == _username.toLowerCase() ||
        (_email.isNotEmpty && normalized == _email.toLowerCase());
    if (!handleMatches) {
      return 'No account found for “$normalized”.';
    }
    if (_password.isEmpty || password != _password) {
      return 'Incorrect password. Try again.';
    }
    _accountCreated = true;
    notifyListeners();
    return null;
  }

  void saveResponse(String key, String value) {
    _responses[key] = value;
    notifyListeners();
  }

  void finishOnboarding() {
    _onboardingDone = true;
    _accountCreated = true;
    _responses['daily_quests'] = _responses['daily_quests'] ?? '3';
    _xp = math.max(_xp, 50);
    _streak = math.max(_streak, 1);
    _lastStreakDate ??= DateTime.now();
    _memberSince ??= DateTime.now();
    _notify();
    // Persist the "wizard complete" flag + answers so a future sign-in on a
    // new device skips straight to the dashboard.
    _syncProfile();
  }

  /// Resets onboarding so the wizard re-runs, preserving existing responses
  /// as pre-filled defaults. Used by "Replay Onboarding" in Settings/Profile.
  void resetOnboardingForReplay() {
    _onboardingDone = false;
    _accountCreated = true; // keep auth state
    _notify();
    _syncProfile();
  }

  /// Signs out of Supabase (if any) and resets to the onboarding flow.
  Future<void> signOut() async {
    try {
      await SupabaseService.instance.signOut();
    } catch (_) {}
    // Drop scheduled reminders — they belong to this session's local state.
    await NotificationService.instance.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _displayName = 'Noah Cooper';
    _username = 'noah';
    _email = '';
    _avatar = 'sun';
    _password = '';
    _onboardingDone = false;
    _accountCreated = false;
    _xp = 1250;
    _streak = 14;
    _lastStreakDate = null;
    _memberSince = null;
    _responses.clear();
    _customHabits.clear();
    _customCounter = 0;
    _activeTab = 0;
    _chat.clear();
    _proofs.clear();
    _seedDemo();
    notifyListeners();
  }

  // ── Update check ─────────────────────────────────────────────────────────
  UpdateInfo? _updateInfo;
  bool _updateCheckDone = false;

  UpdateInfo? get updateInfo => _updateInfo;
  bool get updateCheckDone => _updateCheckDone;

  bool? get updateAvailable {
    if (!_updateCheckDone) return null;
    final info = _updateInfo;
    if (info == null) return false;
    return info.isNewerThan('1.0.0', localBuildNumber: '1');
  }

  Future<void> checkForUpdate() async {
    final info = await fetchLatestUpdate();
    if (!_updateCheckDone) {
      _updateCheckDone = true;
      _updateInfo = info;
      notifyListeners();
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────
  int _activeTab = 0;

  int get activeTab => _activeTab;

  void setActiveTab(int index) {
    if (index == _activeTab) return;
    _activeTab = index;
    notifyListeners();
  }

  // ── Stats ────────────────────────────────────────────────────────────────
  int _xp = 1250;
  int _streak = 14;
  final int _readiness = 87;
  final int _position = 3;
  DateTime? _lastStreakDate;

  int get xp => _xp;
  int get streak => _streak;
  int get readiness => _readiness;
  int get position => _position;

  /// Verified cells ÷ total cells this week.
  int get weeklyRate {
    var verified = 0;
    var total = 0;
    for (final statuses in _weekMatrix.values) {
      for (final status in statuses) {
        total++;
        if (status == QuestStatus.verified) verified++;
      }
    }
    return total == 0 ? 0 : (verified / total * 100).round();
  }

  /// Distinct verified quests (all time this week).
  int get completedCount => _weekMatrix.values.fold(0, (sum, days) {
        return sum +
            days.where((s) => s == QuestStatus.verified).length;
      });

  /// How many quests still need a photo proof today.
  int get pendingTodayCount {
    final today = todayIndex;
    return _allHabits
        .where((h) => _weekMatrix[h.id]?[today] != QuestStatus.verified)
        .length;
  }

  /// Today's quests that are still pending verification.
  List<Habit> get pendingTodayHabits => [
        for (final h in _allHabits)
          if (_weekMatrix[h.id]?[todayIndex] != QuestStatus.verified) h,
      ];

  /// Badges the user has earned.
  List<({String name, String emoji, bool earned, String hint})> get badges => [
        (name: '7-Day Warrior', emoji: '⚔️', earned: _streak >= 7, hint: '7-day streak'),
        (name: 'Photo Master', emoji: '📷', earned: _proofs.isNotEmpty, hint: 'Verified with proof'),
        (name: 'Early Bird', emoji: '🌅', earned: _responses['wake_time'] == '05' || _responses['wake_time'] == '06', hint: 'Wakes before 7 AM'),
        (name: 'Streak Keeper', emoji: '🔥', earned: _streak >= 3, hint: '3+ day streak'),
        (name: 'Weekend Slayer', emoji: '💪', earned: _statusOn(5) == QuestStatus.verified || _statusOn(6) == QuestStatus.verified, hint: 'Verified on a weekend'),
        (name: 'Perfect Day', emoji: '✨', earned: _perfectDay(), hint: 'All quests verified in one day'),
      ];

  QuestStatus _statusOn(int day) {
    var verified = 0;
    for (final statuses in _weekMatrix.values) {
      if (statuses[day] == QuestStatus.verified) verified++;
    }
    return verified > 0 ? QuestStatus.verified : QuestStatus.pending;
  }

  bool _perfectDay() {
    for (final statuses in _weekMatrix.values) {
      if (statuses.contains(QuestStatus.pending) ||
          statuses.contains(QuestStatus.missed)) {
        return false;
      }
    }
    return true;
  }

  /// Weekly XP per day for the profile bar chart.
  List<int> get weeklyXpBars {
    final bars = List<int>.filled(7, 0);
    _weekMatrix.forEach((habitId, days) {
      for (var d = 0; d < 7; d++) {
        if (days[d] == QuestStatus.verified) bars[d] += 50;
      }
    });
    return bars;
  }

  // ── Habits ───────────────────────────────────────────────────────────────
  final List<Habit> _customHabits = [];
  int _customCounter = 0;

  List<Habit> get _allHabits => isSignedIn
      ? [..._customHabits]
      : [..._coreHabits, ..._customHabits];
  List<Habit> get habits => List.unmodifiable(_allHabits);

  static const List<Habit> _coreHabits = [
    Habit(id: 'hydrate', name: 'Hydrate', icon: 'droplet', time: '7:00 AM', category: 'Wellness', emoji: '💧'),
    Habit(id: 'gym', name: 'Gym Session', icon: 'dumbbell', time: '7:30 AM', category: 'Fitness', emoji: '🏋️'),
    Habit(id: 'reading', name: 'Read 20 min', icon: 'book', time: '9:00 PM', category: 'Learning', emoji: '📚'),
    Habit(id: 'cleanroom', name: 'Clean Room', icon: 'homeOutlined', time: '6:00 PM', category: 'Chores', emoji: '🧹'),
  ];

  Future<void> addHabit({
    required String name,
    required String category,
    required String time,
    String emoji = '✅',
    String icon = 'check',
  }) async {
    final id = 'custom_$_customCounter';
    _customCounter++;
    _customHabits.add(
      Habit(id: id, name: name.trim(), icon: icon, time: time, category: category, emoji: emoji),
    );
    _weekMatrix[id] = List.filled(7, QuestStatus.pending);
    notifyListeners();
    _scheduleHabitReminders();
    try {
      await SupabaseService.instance.insertHabit({
        'title': name.trim(),
        'icon': icon,
        'emoji': emoji,
        'category': category,
        'time_of_day': time,
        'frequency_days': [0, 1, 2, 3, 4, 5, 6],
        'is_custom': true,
        'sort_order': _customHabits.length,
      });
    } catch (_) {}
  }

  Future<void> removeHabit(String habitId) async {
    _customHabits.removeWhere((h) => h.id == habitId);
    _weekMatrix.remove(habitId);
    _proofs.remove(habitId);
    notifyListeners();
    _scheduleHabitReminders();
    try {
      await SupabaseService.instance.deleteHabit(habitId);
    } catch (_) {}
  }

  /// Bulk-applies a plan proposed by Qubi's `create_routine_plan` tool call.
  Future<void> applyAiPlan(List<PlannedHabit> plan) async {
    for (final item in plan) {
      await addHabit(
        name: item.title,
        category: item.category,
        time: item.timeOfDay,
        emoji: '✅',
        icon: 'check',
      );
    }
  }

  // ── Week matrix ──────────────────────────────────────────────────────────
  late Map<String, List<QuestStatus>> _weekMatrix;

  /// habitId → dayIndex → proof storage path (for thumbnails).
  final Map<String, Map<int, String>> _proofs = {};

  static const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  int get todayIndex => DateTime.now().weekday - 1;

  Map<String, QuestStatus> dayStatuses(int dayIndex) => Map.unmodifiable({
        for (final habit in _allHabits)
          habit.id: _weekMatrix[habit.id]?[dayIndex] ?? QuestStatus.pending,
      });

  QuestStatus statusOf(String habitId, int dayIndex) =>
      _weekMatrix[habitId]?[dayIndex] ?? QuestStatus.pending;

  String? proofOf(String habitId, int dayIndex) =>
      _proofs[habitId]?[dayIndex];

  void _seedDemo() {
    _weekMatrix = {
      for (final h in _allHabits) h.id: List.filled(7, QuestStatus.pending),
    };
    // Demo data so charts are alive before the first verify. Only days before
    // today get verified so today's quests stay actionable.
    const verified = {
      0: ['gym', 'reading'],
      1: ['hydrate', 'gym'],
      2: ['gym', 'reading', 'cleanroom'],
      3: ['hydrate', 'gym'],
      4: ['gym', 'reading', 'hydrate', 'cleanroom'],
      5: ['reading', 'cleanroom'],
      6: ['gym'],
    };
    final today = todayIndex;
    for (final entry in verified.entries) {
      if (entry.key >= today) continue;
      for (final id in entry.value) {
        _weekMatrix[id]?[entry.key] = QuestStatus.verified;
      }
    }
    _chat.clear();
    _chat.add(
      ChatMessage(
        fromUser: false,
        text: 'Hey $_username — I’ve locked your streak plan. '
            'Snap your first photo proof and I will bank +50 XP for you!',
      ),
    );
  }

  /// Verifies [habitId] today after a live photo proof passes AI verification.
  /// Banks +50 XP once per (habit, day); mirrors to Supabase.
  Future<void> verifyHabit(
    String habitId, {
    String? proofPath,
  }) async {
    final matrix = _weekMatrix[habitId];
    if (matrix == null) return;
    final today = todayIndex;
    if (matrix[today] == QuestStatus.verified) return;
    matrix[today] = QuestStatus.verified;
    if (proofPath != null) {
      _proofs[habitId] ??= {};
      _proofs[habitId]![today] = proofPath;
    }
    _xp += 50;
    _bumpStreak();
    notifyListeners();
    _syncVerification(habitId, proofPath);
  }

  Future<void> _syncVerification(String habitId, String? proofPath) async {
    try {
      if (uid == null) return;
      final day = DateTime.now();
      final completionId = await SupabaseService.instance.upsertCompletion(
        habitId: habitId,
        day: day,
        status: 'pending',
      );
      if (completionId != null) {
        await SupabaseService.instance
            .verifyCompletion(completionId, proofUrl: proofPath);
      }
      // Push aggregate stats so the profile + leaderboard stay in sync.
      await SupabaseService.instance.upsertProfile({
        'xp': _xp,
        'streak': _streak,
        'last_streak_date': day.toIso8601String().substring(0, 10),
      });
    } catch (_) {}
  }

  void _bumpStreak() {
    final now = DateTime.now();
    final last = _lastStreakDate;
    final sameDay =
        last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
    if (!sameDay) {
      _streak += 1;
      _lastStreakDate = now;
    }
  }

  // ── Qubi chat ────────────────────────────────────────────────────────────
  final List<ChatMessage> _chat = [];

  List<ChatMessage> get chat => List.unmodifiable(_chat);

  void addUserMessage(String text) {
    final message = text.trim();
    if (message.isEmpty) return;
    _chat.add(ChatMessage(fromUser: true, text: message));
    notifyListeners();
    _persistChat();
  }

  /// Clears the local Qubi thread and mirrors the delete to Supabase.
  void clearChats() {
    _chat.clear();
    SupabaseService.instance.clearChats().catchError((_) {});
    notifyListeners();
  }

  /// Persists the newest chat message to Supabase (fire-and-forget).
  void _persistChat() {
    final last = _chat.lastOrNull;
    if (last == null) return;
    SupabaseService.instance.insertChat({
      'role': last.fromUser ? 'user' : 'assistant',
      'content': last.text,
    }).catchError((_) {});
  }

  void addAssistantMessage(String text, {String? toolName}) {
    _chat.add(ChatMessage(fromUser: false, text: text));
    notifyListeners();
    if (toolName != null) {
      SupabaseService.instance
          .insertChat({'role': 'assistant', 'content': text, 'tool_name': toolName})
          .catchError((_) {});
    } else {
      _persistChat();
    }
  }

  void applyQubiSchedule() {
    final budget = _responses['daily_time_budget'];
    if (budget != null) {
      final minutes = int.tryParse(budget) ?? 30;
      _chat.add(
        ChatMessage(
          fromUser: false,
          text: 'I’ve tuned your daily plan to $minutes min. '
              'Balanced for your sleep window — nice.',
        ),
      );
    }
    _notify();
  }

  // ── League roster ────────────────────────────────────────────────────────
  List<LeagueEntry> get league => [
        const LeagueEntry(rank: 1, name: 'Zara Khan', initials: 'ZK', xp: 2780, streak: 31, tier: 'Silver', isMe: false, level: 18),
        const LeagueEntry(rank: 2, name: 'Liam Novak', initials: 'LN', xp: 2590, streak: 22, tier: 'Silver', isMe: false, level: 16),
        LeagueEntry(rank: 3, name: _displayName, initials: _initials, xp: _xp, streak: _streak, tier: 'Silver', isMe: true, level: 12),
        const LeagueEntry(rank: 4, name: 'Sofia Reyes', initials: 'SR', xp: 2140, streak: 12, tier: 'Silver', isMe: false, level: 11),
        const LeagueEntry(rank: 5, name: 'Marcus Bell', initials: 'MB', xp: 1890, streak: 9, tier: 'Silver', isMe: false, level: 10),
        const LeagueEntry(rank: 6, name: 'Priya Shah', initials: 'PS', xp: 1675, streak: 6, tier: 'Silver', isMe: false, level: 9),
        const LeagueEntry(rank: 7, name: 'Diego Torres', initials: 'DT', xp: 1490, streak: 4, tier: 'Silver', isMe: false, level: 8),
      ];

  String get _initials {
    final parts = _displayName.split(' ');
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return _displayName
        .substring(0, math.min(2, _displayName.length))
        .toUpperCase();
  }

  String get initials => _initials;

  // ── Serialization ────────────────────────────────────────────────────────
  Map<String, dynamic> _toJson() => {
        'onboarding_done': _onboardingDone,
        'account_created': _accountCreated,
        'display_name': _displayName,
        'username': _username,
        'email': _email,
        'avatar': _avatar,
        'password': _password,
        'xp': _xp,
        'streak': _streak,
        'last_streak_date': _lastStreakDate?.toIso8601String(),
        'member_since': _memberSince?.toIso8601String(),
        'responses': _responses,
        'custom_habits': [for (final h in _customHabits) h.toJson()],
        'week_matrix': {
          for (final e in _weekMatrix.entries)
            e.key: [for (final s in e.value) s.name],
        },
        'proofs': {
          for (final e in _proofs.entries)
            e.key: {
              for (final d in e.value.entries) '${d.key}': d.value,
            },
        },
        'chat': [for (final m in _chat) m.toJson()],
      };

  void _apply(Map<String, dynamic> json) {
    _onboardingDone = json['onboarding_done'] as bool? ?? _onboardingDone;
    _accountCreated = json['account_created'] as bool? ?? _accountCreated;
    _displayName = json['display_name'] as String? ?? _displayName;
    _username = json['username'] as String? ?? _username;
    _email = json['email'] as String? ?? _email;
    _avatar = json['avatar'] as String? ?? _avatar;
    _password = json['password'] as String? ?? _password;
    _xp = json['xp'] as int? ?? _xp;
    _streak = json['streak'] as int? ?? _streak;
    final streakDate = json['last_streak_date'] as String?;
    _lastStreakDate = streakDate == null ? null : DateTime.tryParse(streakDate);
    final member = json['member_since'] as String?;
    _memberSince = member == null ? null : DateTime.tryParse(member);
    if (json['responses'] is Map<String, dynamic>) {
      _responses
        ..clear()
        ..addAll((json['responses'] as Map<String, dynamic>).cast<String, String>());
    }
    if (json['custom_habits'] is List) {
      _customHabits
        ..clear()
        ..addAll(
          (json['custom_habits'] as List)
              .map((e) => Habit.fromJson(e as Map<String, dynamic>)),
        );
      _customCounter = _customHabits.fold(0, (max, h) {
        final n = int.tryParse(h.id.replaceFirst('custom_', ''));
        return n == null ? max : math.max(max, n + 1);
      });
    }
    if (json['week_matrix'] is Map<String, dynamic>) {
      final restored = <String, List<QuestStatus>>{};
      (json['week_matrix'] as Map<String, dynamic>).forEach((id, list) {
        restored[id] = [
          for (final s in (list as List)) QuestStatus.values.asNameMap()[s]!,
        ];
      });
      for (final h in _allHabits) {
        restored.putIfAbsent(h.id, () => List.filled(7, QuestStatus.pending));
      }
      _weekMatrix = restored;
    }
    if (json['proofs'] is Map<String, dynamic>) {
      (json['proofs'] as Map<String, dynamic>).forEach((id, days) {
        final map = (days as Map<String, dynamic>);
        _proofs[id] = {
          for (final entry in map.entries)
            int.tryParse(entry.key) ?? 0: entry.value as String,
        };
      });
    }
    if (json['chat'] is List) {
      _chat
        ..clear()
        ..addAll(
          (json['chat'] as List)
              .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)),
        );
    }
  }

  void _notify() => notifyListeners();
}

/// A habit proposed by the AI `create_routine_plan` tool call.
class PlannedHabit {
  const PlannedHabit({
    required this.title,
    required this.category,
    required this.timeOfDay,
    this.frequencyDays = const [0, 1, 2, 3, 4, 5, 6],
  });

  final String title;
  final String category;
  final String timeOfDay;
  final List<int> frequencyDays;

  static PlannedHabit fromArgs(Map<String, dynamic> args) => PlannedHabit(
        title: (args['title'] as String?) ?? 'New Quest',
        category: (args['category'] as String?) ?? 'Wellness',
        timeOfDay: (args['time_of_day'] as String?) ?? '8:00 AM',
        frequencyDays: [
          for (final d in (args['frequency_days'] as List? ?? []))
            (d as num).toInt(),
        ],
      );
}
