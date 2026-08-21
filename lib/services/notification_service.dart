import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

/// Schedules and manages Questify's local notifications: a daily habit
/// reminder at the user's chosen time, a streak-saver nudge late in the
/// evening, plus per-quest coach pings from Qubi at each quest's own time.
/// Every method is defensive — on unsupported platforms (web, desktop,
/// tests) or when the OS denies permission it silently no-ops, so the rest of
/// the app never depends on notifications being available.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 1001;
  static const int _streakAlertId = 1002;
  static const int _habitReminderBaseId = 2000;

  static const String _dailyChannelId = 'questify_daily_reminders';
  static const String _dailyChannelName = 'Daily quest reminders';
  static const String _habitChannelId = 'questify_habit_pings';
  static const String _habitChannelName = 'Qubi quest pings';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initDone = false;
  bool _initAttempted = false;

  /// Local notifications are only meaningful on Android/iOS.
  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> _ensureInitialized() async {
    if (_initDone) return true;
    if (!_supported) return false;
    if (_initAttempted) return false; // another attempt is already in flight
    _initAttempted = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      await _prepareTimezones();
      _initDone = true;
      return true;
    } catch (_) {
      return false;
    } finally {
      _initAttempted = false;
    }
  }

  Future<void> _prepareTimezones() async {
    try {
      tz_data.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC — reminders will fire at the wall-clock time in UTC.
    }
  }

  /// Asks the OS for permission to show notifications. Call from a user
  /// gesture (e.g. flipping the Daily Reminder switch on).
  Future<bool> requestPermissions() async {
    if (!await _ensureInitialized()) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final grantedAndroid =
          await android?.requestNotificationsPermission() ?? true;
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final grantedIos =
          await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
              true;
      return grantedAndroid && grantedIos;
    } catch (_) {
      return false;
    }
  }

  /// Reconciles the OS schedule with the user's settings: schedules (or
  /// cancels) the daily reminder and the streak-saver alert.
  Future<void> applySettings({
    required bool remindersEnabled,
    required String reminderTime,
    required bool streakAlerts,
  }) async {
    if (!await _ensureInitialized()) return;
    _habitRemindersEnabled = remindersEnabled;
    if (remindersEnabled) {
      await _scheduleDailyReminder(reminderTime);
      await _rescheduleHabitReminders();
    } else {
      await _cancel(_dailyReminderId);
      await _cancelHabitReminders();
    }
    if (streakAlerts) {
      await _scheduleStreakAlert();
    } else {
      await _cancel(_streakAlertId);
    }
  }

  /// Cancels every scheduled Questify notification (e.g. on sign-out).
  Future<void> cancelAll() async {
    if (!await _ensureInitialized()) return;
    await _cancel(_dailyReminderId);
    await _cancel(_streakAlertId);
    await _cancelHabitReminders();
  }

  bool _habitRemindersEnabled = false;
  List<Habit> _lastHabits = [];
  final List<int> _scheduledHabitIds = [];

  /// Re-syncs the Qubi coach pings so each quest nudges you at its own time.
  /// Stores the latest habit list even when reminders are off so a later
  /// enable can schedule immediately (boot ordering safe).
  Future<void> applyHabitReminders({required List<Habit> habits}) async {
    _lastHabits = habits;
    if (!_habitRemindersEnabled) return;
    await _rescheduleHabitReminders();
  }

  Future<void> _rescheduleHabitReminders() async {
    if (!await _ensureInitialized()) return;
    await _cancelHabitReminders();
    for (var i = 0; i < _lastHabits.length; i++) {
      final habit = _lastHabits[i];
      final parsed = _parseTime(habit.time);
      if (parsed == null) continue;
      final id = _habitReminderBaseId + i;
      _scheduledHabitIds.add(id);
      await _scheduleHabitReminder(
        id: id,
        habit: habit,
        hour: parsed.$1,
        minute: parsed.$2,
      );
    }
  }

  Future<void> _cancelHabitReminders() async {
    for (final id in _scheduledHabitIds) {
      await _cancel(id);
    }
    _scheduledHabitIds.clear();
  }

  /// Parses display times like "7:30 AM" / "21:00" into 24h hour/minute.
  static (int, int)? _parseTime(String time) {
    final m = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*(am|pm)?',
      caseSensitive: false,
    ).firstMatch(time.trim());
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final ap = m.group(3)?.toLowerCase();
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    return (h, minute);
  }

  Future<void> _scheduleHabitReminder({
    required int id,
    required Habit habit,
    required int hour,
    required int minute,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: 'Qubi · Time for ${habit.name}! ${habit.emoji}',
        body: 'Snap a photo proof and I’ll bank +50 XP. You’ve got this!',
        scheduledDate: _nextInstanceOf(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _habitChannelId,
            _habitChannelName,
            channelDescription: 'Coach pings at each quest time',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> _cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  Future<void> _scheduleDailyReminder(String hhmm) async {
    final parts = hhmm.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;
    try {
      await _plugin.zonedSchedule(
        id: _dailyReminderId,
        title: 'Questify — your quests are waiting 🎯',
        body: 'Snap your photo proofs today to bank XP and protect your streak!',
        scheduledDate: _nextInstanceOf(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _dailyChannelId,
            _dailyChannelName,
            channelDescription: 'Gentle nudges at your chosen quest time',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> _scheduleStreakAlert() async {
    try {
      await _plugin.zonedSchedule(
        id: _streakAlertId,
        title: 'Streak saver ⏳',
        body: 'Anything left unverified? A quick photo proof keeps your streak alive tonight.',
        scheduledDate: _nextInstanceOf(21, 0),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _dailyChannelId,
            _dailyChannelName,
            channelDescription: 'Evening nudge before your streak resets',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  /// The next occurrence of [hour]:[minute] in the device's local timezone.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
