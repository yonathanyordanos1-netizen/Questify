import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/supabase_service.dart';

/// User preference state: theme, haptics, notifications. Persisted to
/// SharedPreferences for instant offline reads and mirrored to the
/// `user_settings` table (owner-scoped by RLS) when signed in.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider._();

  static const String _themeKey = 'settings_theme_mode';
  static const String _hapticsKey = 'settings_haptics';
  static const String _remindersKey = 'settings_reminders_enabled';
  static const String _reminderTimeKey = 'settings_reminder_time';
  static const String _streakAlertsKey = 'settings_streak_alerts';

  static Future<SettingsProvider> load() async {
    final provider = SettingsProvider._();
    final prefs = await SharedPreferences.getInstance();
    provider._themeMode = _themeModeOf(prefs.getString(_themeKey));
    provider._haptics = prefs.getBool(_hapticsKey) ?? true;
    provider._remindersEnabled = prefs.getBool(_remindersKey) ?? true;
    provider._reminderTime = prefs.getString(_reminderTimeKey) ?? '08:00';
    provider._streakAlerts = prefs.getBool(_streakAlertsKey) ?? true;
    provider._prefs = prefs;
    // Align the OS notification schedule with the restored prefs.
    provider._applyNotifications();
    return provider;
  }

  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  bool _haptics = true;
  bool _remindersEnabled = true;
  String _reminderTime = '08:00';
  bool _streakAlerts = true;
  bool _syncing = false;

  ThemeMode get themeMode => _themeMode;
  bool get haptics => _haptics;
  bool get remindersEnabled => _remindersEnabled;
  String get reminderTime => _reminderTime;
  bool get streakAlerts => _streakAlerts;

  static ThemeMode _themeModeOf(String? name) =>
      ThemeMode.values.asNameMap()[name] ?? ThemeMode.system;

  Future<void> _save(String key, Object value) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    switch (value) {
      case final String v:
        await prefs.setString(key, v);
      case final bool v:
        await prefs.setBool(key, v);
      default:
        break;
    }
    _syncToSupabase();
  }

  Future<void> _syncToSupabase() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await SupabaseService.instance.upsertSettings({
        'theme_mode': _themeMode.name,
        'haptics': _haptics,
        'reminders_enabled': _remindersEnabled,
        'reminder_time': _reminderTime,
        'streak_alerts': _streakAlerts,
      });
    } catch (_) {
      // Offline or demo — local prefs remain the source of truth.
    } finally {
      _syncing = false;
    }
  }

  /// Pulls server-side settings once on boot (new devices / re-login).
  Future<void> hydrateFromSupabase() async {
    final remote = await SupabaseService.instance.fetchSettings();
    if (remote == null) return;
    var changed = false;
    final theme = _themeModeOf(remote['theme_mode'] as String?);
    if (theme != _themeMode) {
      _themeMode = theme;
      changed = true;
    }
    final haptics = remote['haptics'] as bool?;
    if (haptics != null && haptics != _haptics) {
      _haptics = haptics;
      changed = true;
    }
    final reminders = remote['reminders_enabled'] as bool?;
    if (reminders != null && reminders != _remindersEnabled) {
      _remindersEnabled = reminders;
      changed = true;
    }
    final time = remote['reminder_time'] as String?;
    if (time != null && time != _reminderTime) {
      _reminderTime = time;
      changed = true;
    }
    final alerts = remote['streak_alerts'] as bool?;
    if (alerts != null && alerts != _streakAlerts) {
      _streakAlerts = alerts;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // ── Mutators ──────────────────────────────────────────────────────────────

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _save(_themeKey, mode.name);
    tap();
  }

  Future<void> setHaptics(bool enabled) async {
    if (enabled == _haptics) return;
    _haptics = enabled;
    notifyListeners();
    await _save(_hapticsKey, enabled);
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    if (enabled == _remindersEnabled) return;
    _remindersEnabled = enabled;
    notifyListeners();
    await _save(_remindersKey, enabled);
    if (enabled) {
      // Ask the OS for permission from this user gesture, then schedule.
      await NotificationService.instance.requestPermissions();
      tap();
    }
    _applyNotifications();
  }

  Future<void> setReminderTime(String hhmm) async {
    if (hhmm == _reminderTime) return;
    _reminderTime = hhmm;
    notifyListeners();
    await _save(_reminderTimeKey, hhmm);
    _applyNotifications();
  }

  Future<void> setStreakAlerts(bool enabled) async {
    if (enabled == _streakAlerts) return;
    _streakAlerts = enabled;
    notifyListeners();
    await _save(_streakAlertsKey, enabled);
    _applyNotifications();
  }

  /// Pushes the current notification prefs to the OS scheduler (fire-and-forget;
  /// the service no-ops on unsupported platforms).
  void _applyNotifications() {
    unawaited(
      NotificationService.instance.applySettings(
        remindersEnabled: _remindersEnabled,
        reminderTime: _reminderTime,
        streakAlerts: _streakAlerts,
      ),
    );
  }

  /// Light, friendly confirm haptic if enabled.
  void tap() {
    if (!_haptics) return;
    HapticFeedback.selectionClick();
  }

  /// Strong celebratory feedback for verified quests.
  void celebrate() {
    if (!_haptics) return;
    HapticFeedback.heavyImpact();
  }

  /// Resets local image/thumbnail cache. The proof thumbnails live in the
  /// private storage bucket, so we only clear the in-memory + disk image cache.
  Future<void> clearCache() async {
    await _clearImageCache();
    tap();
  }

  Future<void> _clearImageCache() async {
    try {
      // Flutter's global image cache + ImageIO disk cache.
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    } catch (_) {}
  }
}
